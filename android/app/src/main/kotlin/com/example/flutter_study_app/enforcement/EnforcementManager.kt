package com.example.flutter_study_app.enforcement

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.example.flutter_study_app.R
import com.example.flutter_study_app.database.LocalDatabase
import kotlinx.coroutines.*
import java.time.LocalDateTime

/**
 * Manages the enforcement of parental control rules.
 * 
 * IMPORTANT: This class does NOT terminate applications, as that requires
 * system-level permissions not available to regular apps. Instead, it
 * provides enforcement through:
 * 
 * 1. BLOCKED apps: Shows overlay warning, requests user to close app
 * 2. ASK_PARENT rules: Sends notification to parents, logs request
 * 3. TIME_LIMIT rules: Shows time warnings and usage notifications
 * 4. TIME_WINDOW rules: Shows "outside allowed hours" overlay
 * 
 * This is the correct and legitimate approach for parental control apps
 * on Android, as demonstrated by established apps like Qustodio, Circle, etc.
 */
class EnforcementManager(
    private val context: Context,
    private val database: LocalDatabase,
    private val ruleEngine: RuleEngine
) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val notificationManager = NotificationManagerCompat.from(context)
    private var currentOverlay: View? = null
    private var currentOverlayPackage: String? = null
    
    companion object {
        private const val NOTIFICATION_CHANNEL_ENFORCEMENT = "enforcement_notifications"
        private const val NOTIFICATION_CHANNEL_PARENT_REQUEST = "parent_requests"
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
                    notifyParentsOfRequest(packageName, currentTime)
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
            // Show notification instead
            showEnforcementNotification(
                "App Blocked",
                "This app is not allowed. Please close it and choose a different activity.",
                packageName
            )
            return
        }
        
        val appName = getAppName(packageName)
        val overlayView = createOverlay(
            title = "App Blocked",
            message = "$appName is not allowed on this device.\n\nPlease close the app and choose a different activity.",
            actionText = "Close App",
            onAction = {
                // Guide user to close app (we cannot force close)
                showAppSwitcher()
            }
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
            title = "Ask Parent Permission",
            message = "You need permission to use $appName.\n\nA request has been sent to your parents.",
            actionText = "Wait for Approval",
            onAction = {
                removeCurrentOverlay()
                showAppSwitcher()
            }
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
            title = "Daily Time Limit Reached",
            message = "$appName time is up!\n\nDaily limit: ${limitHours}h ${limitMins}m\nTry again tomorrow.",
            actionText = "Close App",
            onAction = {
                showAppSwitcher()
            }
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
        val startTime = rule?.allowedStartTime?.toString() ?: "unknown"
        val endTime = rule?.allowedEndTime?.toString() ?: "unknown"
        
        val timeMessage = if (minutesUntilAllowed != null && minutesUntilAllowed < 1440) { // Less than 24 hours
            val hours = minutesUntilAllowed / 60
            val mins = minutesUntilAllowed % 60
            "\n\nAvailable in ${hours}h ${mins}m"
        } else {
            ""
        }
        
        val overlayView = createOverlay(
            title = "Outside Allowed Hours",
            message = "$appName is only available from $startTime to $endTime.$timeMessage",
            actionText = "Close App",
            onAction = {
                showAppSwitcher()
            }
        )
        
        showOverlay(overlayView, packageName)
    }
    
    /**
     * Create enforcement overlay view
     */
    private fun createOverlay(title: String, message: String, actionText: String, onAction: () -> Unit): View {
        val inflater = LayoutInflater.from(context)
        val overlayView = inflater.inflate(R.layout.enforcement_overlay, null)
        
        overlayView.findViewById<TextView>(R.id.overlay_title)?.text = title
        overlayView.findViewById<TextView>(R.id.overlay_message)?.text = message
        overlayView.findViewById<TextView>(R.id.overlay_action)?.apply {
            text = actionText
            setOnClickListener { onAction() }
        }
        
        // Close button
        overlayView.findViewById<View>(R.id.overlay_close)?.setOnClickListener {
            removeCurrentOverlay()
            showAppSwitcher()
        }
        
        return overlayView
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
            // Fallback to notification
            showEnforcementNotification("App Restricted", "This app has usage restrictions.", packageName)
        }
    }
    
    /**
     * Remove current overlay if it belongs to the specified package
     */
    private fun removeOverlayIfPresent(packageName: String) {
        if (currentOverlayPackage == packageName) {
            removeCurrentOverlay()
        }
    }
    
    /**
     * Remove current overlay
     */
    private fun removeCurrentOverlay() {
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
    private fun showAppSwitcher() {
        try {
            // Show recent apps (task switcher)
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
     * Send notification to parents about app request
     */
    private fun notifyParentsOfRequest(packageName: String, currentTime: LocalDateTime) {
        val appName = getAppName(packageName)
        
        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_PARENT_REQUEST)
            .setContentTitle("Child App Request")
            .setContentText("Child requested permission to use $appName")
            .setSmallIcon(R.drawable.ic_notification)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        
        try {
            notificationManager.notify(packageName.hashCode(), notification)
        } catch (e: SecurityException) {
            android.util.Log.w("EnforcementManager", "Cannot post notification", e)
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
     * Show notification for temporary approval
     */
    private fun showTemporaryApprovalNotification(packageName: String, approval: RuleEngine.TemporaryApproval) {
        val appName = getAppName(packageName)
        val endTime = approval.approvedAt.plusMinutes(approval.durationMinutes.toLong())
        
        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ENFORCEMENT)
            .setContentTitle("Temporary Access Granted")
            .setContentText("$appName approved until ${endTime.toLocalTime()}")
            .setSmallIcon(R.drawable.ic_notification)
            .setPriority(NotificationCompat.PRIORITY_LOW)
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

/**
 * ENFORCEMENT STRATEGY EXPLANATION:
 * 
 * This implementation uses the only legitimate approaches available to regular
 * Android apps for parental control:
 * 
 * 1. DETECTION: UsageStatsManager API (requires PACKAGE_USAGE_STATS permission)
 *    - Official Android API for app usage monitoring
 *    - Used by legitimate parental control apps
 *    - Granted through device Settings > Special app access
 * 
 * 2. ENFORCEMENT LIMITATIONS:
 *    - Cannot force-close apps (requires system/root permissions)
 *    - Cannot prevent app launches (requires system-level access)
 *    - Cannot modify other apps' behavior
 * 
 * 3. LEGITIMATE ENFORCEMENT METHODS:
 *    - Screen overlays (with SYSTEM_ALERT_WINDOW permission)
 *    - Notifications to child and parents
 *    - Usage tracking and reporting
 *    - Guidance to manually close restricted apps
 * 
 * 4. USER DISCLOSURE:
 *    - Service runs with visible notification (required for foreground service)
 *    - Overlay permission explicitly requested from user
 *    - All permissions clearly documented and requested
 * 
 * 5. PLAY STORE COMPLIANCE:
 *    - Uses only documented, public Android APIs
 *    - Does not attempt to hide monitoring functionality
 *    - Respects Android's security model
 *    - Provides clear user controls and transparency
 * 
 * This approach is used successfully by apps like:
 * - Qustodio Parental Control
 * - Circle Home Plus
 * - Norton Family
 * - Google Family Link
 */