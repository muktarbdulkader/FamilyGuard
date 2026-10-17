package com.example.flutter_study_app.enforcement

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.example.flutter_study_app.R
import com.example.flutter_study_app.database.LocalDatabase
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.withTimeoutOrNull
import java.time.LocalDateTime
import java.util.UUID

/**
 * Legitimate Android parental control enforcement manager.
 * 
 * Provides transparent, policy-compliant enforcement using standard Android APIs:
 * 1. Screen overlays (SYSTEM_ALERT_WINDOW) - explicitly granted by user
 * 2. Notifications to child and parent
 * 3. App switcher guidance to help child exit restricted apps
 * 4. TIME_WINDOW rules: Shows "outside allowed hours" overlay
 */
class EnforcementManager(
    private val context: Context,
    private val database: LocalDatabase,
    private val ruleEngine: RuleEngine
) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val notificationManager = NotificationManagerCompat.from(context)
    private var currentOverlay: View? = null
    var currentOverlayPackage: String? = null
        private set
    
    private val enforcementScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val pendingRequestPackages = java.util.concurrent.ConcurrentHashMap.newKeySet<String>()
    private val notifiedApprovalPackages = java.util.concurrent.ConcurrentHashMap.newKeySet<String>()
    
    companion object {
        private const val NOTIFICATION_CHANNEL_ENFORCEMENT = "enforcement_notifications"
        private const val NOTIFICATION_CHANNEL_PARENT_REQUEST = "parent_requests"
        private const val PREFS_NAME = "family_guardian_prefs"
    }
    
    /**
     * Main enforcement entry point - evaluates and enforces rules for an app
     */
    suspend fun enforceRuleForApp(packageName: String, currentTime: LocalDateTime) = withContext(Dispatchers.Main) {
        try {
            // Get rule and usage data
            val rule = database.getRule(packageName)
            val usage = database.getUsage(packageName)
            val temporaryApproval = database.getActiveTemporaryApproval(packageName)
            
            // Evaluate rule
            val result = ruleEngine.evaluate(packageName, currentTime, rule, usage, temporaryApproval)
            
            // Apply enforcement based on result
            when (result) {
                RuleEngine.EvaluationResult.ALLOW -> {
                    removeOverlayIfPresent(packageName)
                }
                
                RuleEngine.EvaluationResult.BLOCK -> {
                    showBlockedAppOverlay(packageName, rule)
                }
                
                RuleEngine.EvaluationResult.REQUEST -> {
                    showAskParentOverlay(packageName, rule)
                }
                
                RuleEngine.EvaluationResult.TIME_EXPIRED -> {
                    val remaining = ruleEngine.getRemainingMinutes(rule, usage, currentTime)
                    showTimeExpiredOverlay(packageName, rule, remaining ?: 0)
                }
                
                RuleEngine.EvaluationResult.OUTSIDE_ALLOWED_WINDOW -> {
                    val minutesUntilAllowed = ruleEngine.getMinutesUntilAllowed(rule, currentTime)
                    showTimeWindowOverlay(packageName, rule, minutesUntilAllowed)
                }
                
                RuleEngine.EvaluationResult.TEMPORARY_APPROVAL -> {
                    removeOverlayIfPresent(packageName)
                    showTemporaryApprovalNotification(packageName, temporaryApproval!!)
                }
            }
            
        } catch (e: Exception) {
            android.util.Log.e("EnforcementManager", "Error enforcing rule for $packageName", e)
        }
    }
    
    /**
     * Show overlay for blocked apps
     */
    private fun showBlockedAppOverlay(packageName: String, rule: RuleEngine.AppRule?) {
        if (currentOverlayPackage == packageName) return // Already showing
        
        removeCurrentOverlay()
        
        if (!canDrawOverlays()) {
            showEnforcementNotification(
                "App Blocked",
                "This app is not allowed. Please choose a different activity.",
                packageName
            )
            return
        }
        
        val appName = getAppName(packageName)
        val overlayView = createOverlay(
            packageName = packageName,
            title = "App Blocked",
            message = "$appName is currently blocked by your parents. Tap below to ask for permission.",
            actionText = "Ask Parent",
            secondaryActionText = "Close App"
        )
        
        showOverlay(overlayView, packageName)
    }
    
    /**
     * Show overlay for ask parent requests
     */
    private fun showAskParentOverlay(packageName: String, rule: RuleEngine.AppRule?) {
        if (currentOverlayPackage == packageName) return
        
        removeCurrentOverlay()
        
        if (!canDrawOverlays()) {
            showEnforcementNotification(
                "Permission Required",
                "You need to ask for permission to use this app.",
                packageName
            )
            return
        }
        
        val appName = getAppName(packageName)
        val overlayView = createOverlay(
            packageName = packageName,
            title = "Permission Required",
            message = "You need permission to use $appName. Tap below to send a request to your parents.",
            actionText = "Ask Parent",
            secondaryActionText = "Close App"
        )
        
        showOverlay(overlayView, packageName)
    }
    
    /**
     * Show overlay for time expired apps
     */
    private fun showTimeExpiredOverlay(packageName: String, rule: RuleEngine.AppRule?, remainingMinutes: Int) {
        if (currentOverlayPackage == packageName) return
        
        removeCurrentOverlay()
        
        if (!canDrawOverlays()) {
            showEnforcementNotification(
                "Time Limit Reached",
                "Daily time limit reached for this app. Try again tomorrow.",
                packageName
            )
            return
        }
        
        val appName = getAppName(packageName)
        val limitHours = (rule?.dailyLimitMinutes ?: 0) / 60
        val limitMins = (rule?.dailyLimitMinutes ?: 0) % 60
        
        val overlayView = createOverlay(
            packageName = packageName,
            title = "Daily Limit Reached",
            message = "$appName time is up today (limit: ${limitHours}h ${limitMins}m). You can ask your parents for extra time.",
            actionText = "Ask Parent for More Time",
            secondaryActionText = "Close App"
        )
        
        showOverlay(overlayView, packageName)
    }
    
    /**
     * Show overlay for time window restrictions
     */
    private fun showTimeWindowOverlay(packageName: String, rule: RuleEngine.AppRule?, minutesUntilAllowed: Int?) {
        if (currentOverlayPackage == packageName) return
        
        removeCurrentOverlay()
        
        val appName = getAppName(packageName)
        val startTime = rule?.allowedStartTime?.toString() ?: "allowed hours"
        val endTime = rule?.allowedEndTime?.toString() ?: ""
        
        val timeMessage = if (minutesUntilAllowed != null && minutesUntilAllowed < 1440) {
            val hours = minutesUntilAllowed / 60
            val mins = minutesUntilAllowed % 60
            " Available in ${hours}h ${mins}m."
        } else {
            ""
        }
        
        val overlayView = createOverlay(
            packageName = packageName,
            title = "Outside Allowed Hours",
            message = "$appName is only available from $startTime to $endTime.$timeMessage Tap below to ask for permission.",
            actionText = "Ask Parent",
            secondaryActionText = "Close App"
        )
        
        showOverlay(overlayView, packageName)
    }
    
    /**
     * Create enforcement overlay view
     */
    private fun createOverlay(
        packageName: String,
        title: String,
        message: String,
        actionText: String,
        secondaryActionText: String
    ): View {
        val inflater = LayoutInflater.from(context)
        val overlayView = inflater.inflate(R.layout.enforcement_overlay, null)
        
        overlayView.findViewById<TextView>(R.id.overlay_title)?.text = title
        overlayView.findViewById<TextView>(R.id.overlay_message)?.text = message
        
        val statusContainer = overlayView.findViewById<View>(R.id.overlay_status_container)
        val statusText = overlayView.findViewById<TextView>(R.id.overlay_status_text)
        val actionBtn = overlayView.findViewById<Button>(R.id.overlay_action)
        val secondaryBtn = overlayView.findViewById<Button>(R.id.overlay_secondary_action)
        val closeBtn = overlayView.findViewById<View>(R.id.overlay_close)
        
        // Check if there is already a pending request for this app
        if (pendingRequestPackages.contains(packageName)) {
            statusContainer?.visibility = View.VISIBLE
            statusText?.text = "⏳ Request Sent! Waiting for parent..."
            actionBtn?.isEnabled = false
            actionBtn?.text = "Request Pending"
        } else {
            statusContainer?.visibility = View.GONE
            actionBtn?.isEnabled = true
            actionBtn?.text = actionText
            actionBtn?.setOnClickListener {
                requestParentPermission(packageName, overlayView)
            }
        }
        
        // Secondary action: close app & switch to home screen
        secondaryBtn?.apply {
            text = secondaryActionText
            setOnClickListener {
                removeCurrentOverlay()
                showAppSwitcher()
            }
        }
        
        // Top-right close button
        closeBtn?.setOnClickListener {
            removeCurrentOverlay()
            showAppSwitcher()
        }
        
        return overlayView
    }
    
    /**
     * Send real request to Firestore and notify parents quickly and reliably
     */
    fun requestParentPermission(packageName: String, overlayView: View?) {
        val appName = getAppName(packageName)
        val childId = getCachedChildId()
        if (childId.isNullOrEmpty()) {
            Toast.makeText(context, "Child account not found. Please open Family Guardian.", Toast.LENGTH_LONG).show()
            return
        }

        val actionBtn = overlayView?.findViewById<Button>(R.id.overlay_action)
        val statusContainer = overlayView?.findViewById<View>(R.id.overlay_status_container)
        val statusText = overlayView?.findViewById<TextView>(R.id.overlay_status_text)
        
        actionBtn?.isEnabled = false
        actionBtn?.text = "Sending Request..."
        
        enforcementScope.launch {
            try {
                val familyId = resolveFamilyId(childId)
                if (familyId.isNullOrEmpty()) {
                    withContext(Dispatchers.Main) {
                        Toast.makeText(context, "Family ID not found. Please connect to a family.", Toast.LENGTH_LONG).show()
                        actionBtn?.isEnabled = true
                        actionBtn?.text = "Ask Parent"
                    }
                    return@launch
                }

                val childName = getCachedChildName()
                val firestore = FirebaseFirestore.getInstance()
                val reqId = "${childId}_${packageName.replace(".", "_")}"
                val now = Timestamp.now()
                val expiresAt = Timestamp(java.util.Date(System.currentTimeMillis() + 86400000L)) // 24 hours

                val requestData = hashMapOf(
                    "id" to reqId,
                    "familyId" to familyId,
                    "childId" to childId,
                    "childName" to childName,
                    "packageName" to packageName,
                    "appName" to appName,
                    "status" to "pending",
                    "requestedMinutes" to 30,
                    "createdAt" to now,
                    "expiresAt" to expiresAt,
                    "deviceInfo" to Build.MODEL,
                    "requestNonce" to UUID.randomUUID().toString()
                )

                // 1. Fast atomic write of request docs with 15s timeout
                withTimeout(15000L) {
                    val batch = firestore.batch()
                    val famReq = firestore.collection("families")
                        .document(familyId)
                        .collection("requests")
                        .document(reqId)
                    val childReq = firestore.collection("families")
                        .document(familyId)
                        .collection("children")
                        .document(childId)
                        .collection("requests")
                        .document(reqId)

                    batch.set(famReq, requestData, SetOptions.merge())
                    batch.set(childReq, requestData, SetOptions.merge())
                    batch.commit().await()
                }

                pendingRequestPackages.add(packageName)

                // Immediately inform the child UI that the request was successfully sent
                withContext(Dispatchers.Main) {
                    statusContainer?.visibility = View.VISIBLE
                    statusText?.text = "⏳ Request Sent! Waiting for parent..."
                    actionBtn?.isEnabled = false
                    actionBtn?.text = "Request Pending"
                    Toast.makeText(context, "Request sent to parents!", Toast.LENGTH_SHORT).show()
                }

                // 2. Send high-priority notification to parent in background (non-blocking)
                launch {
                    try {
                        val notificationData = hashMapOf(
                            "familyId" to familyId,
                            "childId" to childId,
                            "childName" to childName,
                            "type" to "appRequest",
                            "priority" to "urgent",
                            "status" to "pending",
                            "title" to "📱 $childName: App Permission Request",
                            "body" to "$childName requested access to use $appName (30 min). Tap to approve or deny.",
                            "data" to hashMapOf(
                                "type" to "appRequest",
                                "requestId" to reqId,
                                "familyId" to familyId,
                                "childId" to childId,
                                "childName" to childName,
                                "appName" to appName,
                                "packageName" to packageName,
                                "requestedMinutes" to 30,
                                "status" to "pending"
                            ),
                            "createdAt" to now,
                            "isRead" to false
                        )
                        firestore.collection("notifications").add(notificationData).await()
                        try {
                            firestore.collection("families")
                                .document(familyId)
                                .collection("notifications")
                                .add(notificationData).await()
                        } catch (ignored: Exception) {}
                    } catch (e: Exception) {
                        android.util.Log.w("EnforcementManager", "Background notification write: ${e.message}")
                    }
                }

                // 3. Directly listen for instant approval on this specific request document
                launch(Dispatchers.Main) {
                    firestore.collection("families")
                        .document(familyId)
                        .collection("requests")
                        .document(reqId)
                        .addSnapshotListener { snapshot, error ->
                            if (error != null || snapshot == null || !snapshot.exists()) return@addSnapshotListener
                            val status = snapshot.getString("status")
                            if (status != null && status.equals("approved", ignoreCase = true)) {
                                val mins = snapshot.getLong("grantedMinutes")?.toInt() ?: 30
                                onAppApproved(packageName, mins)
                            }
                        }
                }

                android.util.Log.d("EnforcementManager", "Successfully created pending app request for $appName ($packageName)")
            } catch (e: Exception) {
                android.util.Log.e("EnforcementManager", "Failed to create app request for $packageName", e)
                withContext(Dispatchers.Main) {
                    actionBtn?.isEnabled = true
                    actionBtn?.text = "Ask Parent"
                    Toast.makeText(context, "Could not send: ${e.localizedMessage ?: "Please retry"}", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
    
    private fun getCachedFamilyId(): String? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val fid = prefs.getString("family_id", null)
        if (!fid.isNullOrBlank()) return fid
        return context.getSharedPreferences("family_guardian", Context.MODE_PRIVATE).getString("family_id", null)
    }

    private fun getCachedChildId(): String? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val cid = prefs.getString("child_id", null)
        if (!cid.isNullOrBlank()) return cid
        return FirebaseAuth.getInstance().currentUser?.uid
    }

    private fun getCachedChildName(): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val name = prefs.getString("child_name", null)
        if (!name.isNullOrBlank()) return name
        val user = FirebaseAuth.getInstance().currentUser
        val displayName = user?.displayName
        if (!displayName.isNullOrBlank()) return displayName
        return "Child"
    }

    private suspend fun resolveFamilyId(childId: String): String? {
        val cached = getCachedFamilyId()
        if (!cached.isNullOrBlank()) return cached
        return withTimeoutOrNull(4000L) {
            try {
                val firestore = FirebaseFirestore.getInstance()
                val userDoc = firestore.collection("users").document(childId).get().await()
                val fid = userDoc.getString("familyId")
                if (!fid.isNullOrBlank()) {
                    context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        .edit().putString("family_id", fid).apply()
                    fid
                } else null
            } catch (e: Exception) {
                android.util.Log.e("EnforcementManager", "Error resolving familyId from user doc", e)
                null
            }
        }
    }

    /**
     * Show overlay on screen
     */
    private fun showOverlay(overlayView: View, packageName: String) {
        try {
            val layoutParams = WindowManager.LayoutParams().apply {
                type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }
                
                flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR
                
                format = PixelFormat.TRANSLUCENT
                width = WindowManager.LayoutParams.MATCH_PARENT
                height = WindowManager.LayoutParams.MATCH_PARENT
            }
            
            windowManager.addView(overlayView, layoutParams)
            currentOverlay = overlayView
            currentOverlayPackage = packageName
            
        } catch (e: Exception) {
            android.util.Log.e("EnforcementManager", "Failed to show overlay", e)
            showEnforcementNotification("App Restricted", "This app has usage restrictions.", packageName)
        }
    }
    
    /**
     * Remove current overlay if it belongs to the specified package
     */
    fun removeOverlayIfPresent(packageName: String) {
        pendingRequestPackages.remove(packageName)
        if (currentOverlayPackage == packageName) {
            removeCurrentOverlay()
        }
    }
    
    /**
     * Remove current overlay
     */
    fun removeCurrentOverlay() {
        try {
            currentOverlay?.let { overlay ->
                windowManager.removeView(overlay)
            }
        } catch (e: Exception) {
            android.util.Log.w("EnforcementManager", "Error removing overlay", e)
        } finally {
            currentOverlay = null
            currentOverlayPackage = null
        }
    }
    
    /**
     * Show app switcher to help user close restricted app
     */
    fun showAppSwitcher() {
        try {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.w("EnforcementManager", "Could not show app switcher", e)
        }
    }
    
    /**
     * Show enforcement notification as fallback when overlays aren't available
     */
    private fun showEnforcementNotification(title: String, message: String, packageName: String) {
        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ENFORCEMENT)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(R.drawable.ic_notification)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        
        try {
            notificationManager.notify("enforcement_$packageName".hashCode(), notification)
        } catch (e: SecurityException) {
            android.util.Log.w("EnforcementManager", "Cannot post notification", e)
        }
    }
    
    /**
     * Called when an app is approved by a parent in real time.
     * Updates overlay to show approved message, persists temporary approval to local DB, and launches app.
     */
    fun onAppApproved(packageName: String, grantedMinutes: Int? = null) {
        pendingRequestPackages.remove(packageName)
        val mins = grantedMinutes ?: 30
        
        // Ensure local database immediately has the active temporary approval
        val temporaryApproval = RuleEngine.TemporaryApproval(
            packageName = packageName,
            approvedAt = LocalDateTime.now(),
            durationMinutes = mins,
            approvedBy = "parent"
        )
        database.insertTemporaryApproval(temporaryApproval)
        android.util.Log.d("EnforcementManager", "Inserted fresh temporary approval locally for $packageName ($mins min)")

        // Show Approved status on overlay if currently showing
        if (currentOverlayPackage == packageName && currentOverlay != null) {
            try {
                val statusContainer = currentOverlay?.findViewById<View>(R.id.overlay_status_container)
                val statusText = currentOverlay?.findViewById<TextView>(R.id.overlay_status_text)
                val actionBtn = currentOverlay?.findViewById<Button>(R.id.overlay_action)
                statusContainer?.setBackgroundColor(android.graphics.Color.parseColor("#D1FAE5"))
                statusContainer?.visibility = View.VISIBLE
                statusText?.setTextColor(android.graphics.Color.parseColor("#065F46"))
                statusText?.text = "✅ Access Approved by parent for $mins minutes!"
                actionBtn?.isEnabled = true
                actionBtn?.text = "Open App"
                actionBtn?.setOnClickListener {
                    removeOverlayIfPresent(packageName)
                    launchApprovedApp(packageName)
                }
            } catch (e: Exception) {
                android.util.Log.w("EnforcementManager", "Error updating overlay to approved: ${e.message}")
            }
        }
        
        showTemporaryApprovalNotification(packageName, temporaryApproval, force = true)

        // Auto-launch after brief delay so user sees "Approved" confirmation
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            removeOverlayIfPresent(packageName)
            launchApprovedApp(packageName)
        }, 1200L)
    }

    private fun launchApprovedApp(packageName: String) {
        try {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            }
            if (launchIntent != null) {
                context.startActivity(launchIntent)
                android.util.Log.d("EnforcementManager", "Launched approved app: $packageName")
            }
        } catch (e: Exception) {
            android.util.Log.w("EnforcementManager", "Could not launch $packageName", e)
        }
    }

    /**
     * Show notification for temporary approval with tap-to-open action
     */
    fun showTemporaryApprovalNotification(
        packageName: String, 
        approval: RuleEngine.TemporaryApproval, 
        force: Boolean = false
    ) {
        // Prevent spamming the notification every second
        if (!force && notifiedApprovalPackages.contains(packageName)) {
            return
        }
        notifiedApprovalPackages.add(packageName)

        val appName = getAppName(packageName)
        val endTime = approval.approvedAt.plusMinutes(approval.durationMinutes.toLong())
        
        val launchIntent = context.packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val pendingIntent = if (launchIntent != null) {
            PendingIntent.getActivity(
                context,
                packageName.hashCode(),
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ENFORCEMENT)
            .setContentTitle("🎉 Access Approved: $appName")
            .setContentText("$appName is approved until ${endTime.toLocalTime()}. Tap to open.")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        
        try {
            notificationManager.notify("approval_$packageName".hashCode(), notification)
        } catch (e: SecurityException) {
            android.util.Log.w("EnforcementManager", "Cannot post notification", e)
        }
    }
    
    /**
     * Check if app can draw overlays
     */
    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }
    
    /**
     * Get user-friendly app name
     */
    private fun getAppName(packageName: String): String {
        return try {
            val packageManager = context.packageManager
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }
    
    /**
     * Request overlay permission
     */
    fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                data = Uri.parse("package:${context.packageName}")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            try {
                context.startActivity(intent)
            } catch (e: Exception) {
                android.util.Log.e("EnforcementManager", "Cannot request overlay permission", e)
            }
        }
    }
}