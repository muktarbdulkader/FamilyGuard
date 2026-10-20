package com.example.flutter_study_app.services

import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.*
import androidx.core.app.NotificationCompat
import com.example.flutter_study_app.R
import com.example.flutter_study_app.MainActivity
import com.example.flutter_study_app.DeviceStatusHelper
import com.example.flutter_study_app.database.LocalDatabase
import com.example.flutter_study_app.enforcement.RuleEngine
import com.example.flutter_study_app.enforcement.EnforcementManager
import com.example.flutter_study_app.sync.RuleSyncService
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.Timestamp
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.concurrent.TimeUnit

/**
 * Foreground service that monitors app usage and enforces parental control rules.
 * 
 * This service uses UsageStatsManager to detect foreground app changes and
 * applies rules through the EnforcementManager. It operates continuously
 * while respecting Android's background service limitations.
 * 
 * IMPORTANT: This service cannot force-close arbitrary apps. Enforcement
 * is done through:
 * 1. Overlay blocking UI for blocked apps
 * 2. Notifications to parents for ASK_PARENT rules
 * 3. Time tracking and warnings for time-limited apps
 */
class MonitoringService : Service() {
    
    private lateinit var database: LocalDatabase
    private lateinit var ruleEngine: RuleEngine
    private lateinit var enforcementManager: EnforcementManager
    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var notificationManager: NotificationManager
    private lateinit var deviceStatusHelper: DeviceStatusHelper
    
    private var serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(Dispatchers.Default + serviceJob)
    private var heartbeatJob: Job? = null
    
    private var lastForegroundApp: String? = null
    private var lastUsageUpdateAtMs: Long = 0
    private var activeUsagePackage: String? = null
    private var usageSecondRemainder = 0L
    private val checkIntervalMs = 1000L // Check every 1 second for fast blocking
    
    // For notification tracking
    private var currentFamilyId: String? = null
    private var currentChildId: String? = null
    private var ruleSyncService: RuleSyncService? = null

    // Throttle blocked-app notifications to at most once per 5 minutes per package
    private val lastBlockNotificationTime = java.util.concurrent.ConcurrentHashMap<String, Long>()

    // Receiver that clears any overlay the instant the Family Guardian app comes to foreground
    private val clearOverlayReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.flutter_study_app.CLEAR_OVERLAY") {
                enforcementManager.removeCurrentOverlay()
                android.util.Log.d("MonitoringService", "Cleared overlay on app resume")
            }
        }
    }
    
    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "parental_control_monitoring"
        private const val PREFS_NAME = "family_guardian_prefs"
        private const val KEY_FAMILY_ID = "family_id"
        private const val KEY_CHILD_ID = "child_id"
        private const val KEY_CHILD_NAME = "child_name"
        
        const val ACTION_START_MONITORING = "START_MONITORING"
        const val ACTION_STOP_MONITORING = "STOP_MONITORING"
        
        fun startService(context: Context, familyId: String? = null, childId: String? = null) {
            val intent = Intent(context, MonitoringService::class.java).apply {
                action = ACTION_START_MONITORING
                if (!familyId.isNullOrEmpty()) putExtra(KEY_FAMILY_ID, familyId)
                if (!childId.isNullOrEmpty()) putExtra(KEY_CHILD_ID, childId)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                android.util.Log.e("MonitoringService", "Error starting service", e)
            }
        }
        
        fun stopService(context: Context) {
            val intent = Intent(context, MonitoringService::class.java).apply {
                action = ACTION_STOP_MONITORING
            }
            context.stopService(intent)
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        
        database = LocalDatabase.getInstance(this)
        ruleEngine = RuleEngine()
        enforcementManager = EnforcementManager(this, database, ruleEngine)
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        deviceStatusHelper = DeviceStatusHelper(this)
        
        createNotificationChannel()
        
        // Restore cached familyId & childId for background runs
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        currentFamilyId = prefs.getString(KEY_FAMILY_ID, null)
        currentChildId = prefs.getString(KEY_CHILD_ID, null)
        if (!currentFamilyId.isNullOrEmpty() && !currentChildId.isNullOrEmpty()) {
            startRuleSync(currentFamilyId!!, currentChildId!!)
        }
        
        // Initialize user context for notifications from Auth as well
        initializeUserContext()

        // Register receiver to clear overlay instantly when this app comes to foreground
        val filter = IntentFilter("com.example.flutter_study_app.CLEAR_OVERLAY")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(clearOverlayReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(clearOverlayReceiver, filter)
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val familyId = intent?.getStringExtra("familyId")
        val childId = intent?.getStringExtra("childId")
        val childName = intent?.getStringExtra("childName")
        if (!familyId.isNullOrEmpty() && !childId.isNullOrEmpty()) {
            currentFamilyId = familyId
            currentChildId = childId
            val editor = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
                .putString(KEY_FAMILY_ID, familyId)
                .putString(KEY_CHILD_ID, childId)
            if (!childName.isNullOrEmpty()) {
                editor.putString(KEY_CHILD_NAME, childName)
            }
            editor.apply()
            startRuleSync(familyId, childId)
        }

        when (intent?.action) {
            ACTION_START_MONITORING -> startMonitoring()
            ACTION_STOP_MONITORING -> stopMonitoring()
            else -> startMonitoring() // Default to starting monitoring
        }
        
        // Service should restart if killed by the system
        return START_STICKY
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // Ensure service restarts when user swipes the app away from recents
        try {
            val restartIntent = Intent(applicationContext, MonitoringService::class.java).apply {
                action = ACTION_START_MONITORING
            }
            val restartPendingIntent = PendingIntent.getService(
                applicationContext, 1001, restartIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.set(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + 1000,
                restartPendingIntent
            )
            android.util.Log.d("MonitoringService", "Scheduled service restart via AlarmManager after onTaskRemoved")
        } catch (e: Exception) {
            android.util.Log.e("MonitoringService", "Error scheduling restart in onTaskRemoved", e)
        }
    }
    
    override fun onBind(intent: Intent?): IBinder? = null

    private fun startRuleSync(familyId: String, childId: String) {
        try {
            ruleSyncService = RuleSyncService(this, database, childId).apply {
                onApprovalChanged = { approvedPkg ->
                    enforcementManager.onAppApproved(approvedPkg)
                }
                onRuleChanged = { pkg, ruleType ->
                    serviceScope.launch {
                        try {
                            val fg = getCurrentForegroundApp() ?: lastForegroundApp
                            if (fg == pkg) {
                                android.util.Log.d("MonitoringService", "Rule changed for current app $pkg -> $ruleType, re-enforcing immediately")
                                checkForegroundAppAndEnforce()
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("MonitoringService", "Error re-enforcing on rule change", e)
                        }
                    }
                }
            }
            ruleSyncService?.startSync(familyId)
            android.util.Log.d("MonitoringService", "Started rule sync for family: $familyId, child: $childId")
        } catch (e: Exception) {
            android.util.Log.e("MonitoringService", "Error starting rule sync", e)
        }
    }
    
    private fun startMonitoring() {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // Start monitoring coroutine
        serviceScope.launch {
            while (isActive) {
                try {
                    checkForegroundAppAndEnforce()
                    delay(checkIntervalMs)
                } catch (e: Exception) {
                    // Log error but continue monitoring
                    android.util.Log.e("MonitoringService", "Error in monitoring loop", e)
                    delay(5000) // Wait longer before retrying on error
                }
            }
        }
        
        // Start cleanup coroutine (runs less frequently)
        serviceScope.launch {
            while (isActive) {
                try {
                    performPeriodicCleanup()
                    delay(TimeUnit.MINUTES.toMillis(15)) // Run every 15 minutes
                } catch (e: Exception) {
                    android.util.Log.e("MonitoringService", "Error in cleanup", e)
                }
            }
        }

        // Start usage sync to Firestore coroutine (runs every 5 minutes to conserve Firestore quota)
        serviceScope.launch {
            while (isActive) {
                try {
                    delay(300_000L) // 5 minutes
                    syncUsageToFirestore()
                } catch (e: Exception) {
                    android.util.Log.e("MonitoringService", "Error in usage sync coroutine", e)
                }
            }
        }

        // Keep presence fresh independently of GPS movement or app usage.
        if (heartbeatJob?.isActive != true) {
            heartbeatJob = serviceScope.launch {
                while (isActive) {
                    writeHeartbeat()
                    delay(TimeUnit.MINUTES.toMillis(3))
                }
            }
        }
    }

    private fun writeHeartbeat() {
        val familyId = currentFamilyId ?: return
        val childId = currentChildId ?: return
        val authenticatedUserId = FirebaseAuth.getInstance().currentUser?.uid
        if (authenticatedUserId != childId) {
            android.util.Log.w(
                "MonitoringService",
                "Skipping heartbeat because the signed-in user does not match the monitored child"
            )
            return
        }

        val firestore = FirebaseFirestore.getInstance()
        val heartbeat = mapOf("lastSeen" to com.google.firebase.firestore.FieldValue.serverTimestamp())
        val batch = firestore.batch()
        batch.set(
            firestore.collection("users").document(childId),
            heartbeat,
            com.google.firebase.firestore.SetOptions.merge()
        )
        batch.set(
            firestore.collection("families").document(familyId)
                .collection("children").document(childId),
            heartbeat,
            com.google.firebase.firestore.SetOptions.merge()
        )
        batch.commit().addOnFailureListener { error ->
            android.util.Log.w("MonitoringService", "Heartbeat write failed", error)
        }
    }
    
    private fun stopMonitoring() {
        ruleSyncService?.stopSync()
        ruleSyncService = null
        serviceJob.cancel()
        stopForeground(true)
        stopSelf()
    }
    
    /**
     * Main monitoring logic - checks foreground app and applies enforcement
     */
    private suspend fun checkForegroundAppAndEnforce() = withContext(Dispatchers.IO) {
        try {
            val currentTime = LocalDateTime.now()
            val foregroundApp = getCurrentForegroundApp() ?: lastForegroundApp
            
            if (foregroundApp != null && foregroundApp != lastForegroundApp) {
                // New app came to foreground
                handleForegroundAppChange(foregroundApp, currentTime)
                lastForegroundApp = foregroundApp
            }
            
            // Update usage for current app if it's been running for a while
            if (foregroundApp != null) {
                updateUsageTracking(foregroundApp, currentTime)
            }
            
            // Check if current app should be enforced
            // SAFETY: never enforce on our own package — remove any stale overlay immediately
            if (foregroundApp != null && foregroundApp == applicationContext.packageName) {
                enforcementManager.removeCurrentOverlay()
            } else if (foregroundApp != null && !isSystemApp(foregroundApp)) {
                val rule = database.getRule(foregroundApp)
                val temporaryApproval = database.getActiveTemporaryApproval(foregroundApp)
                val isTemporarilyApproved = temporaryApproval != null && !temporaryApproval.isExpired(currentTime)

                // Only notify parent of blocked app attempt if NOT temporarily approved
                if (rule?.type == RuleEngine.RuleType.BLOCKED && !isTemporarilyApproved) {
                    val appName = getAppInfo(foregroundApp)?.name ?: foregroundApp
                    sendBlockedAppNotification(foregroundApp, appName)
                }
                
                enforcementManager.enforceRuleForApp(foregroundApp, currentTime)
            }
            
        } catch (e: SecurityException) {
            android.util.Log.w("MonitoringService", "UsageStats permission not granted", e)
        }
    }
    
    /**
     * Get the currently active foreground application
     * Uses UsageEvents with fallback to queryUsageStats
     */
    private fun getCurrentForegroundApp(): String? {
        if (!hasUsageStatsPermission()) {
            return null
        }
        
        try {
            val currentTime = System.currentTimeMillis()
            
            // 1. Check UsageEvents in the last 30 seconds
            val usageEvents = usageStatsManager.queryEvents(
                currentTime - 30_000L,
                currentTime
            )
            
            var lastForegroundPackage: String? = null
            var lastEventTime: Long = 0
            
            val event = UsageEvents.Event()
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                
                val isForegroundEvent = event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                        event.eventType == UsageEvents.Event.ACTIVITY_RESUMED
                
                if (isForegroundEvent && event.timeStamp > lastEventTime) {
                    lastForegroundPackage = event.packageName
                    lastEventTime = event.timeStamp
                }
            }
            
            if (lastForegroundPackage != null) {
                return lastForegroundPackage
            }
            
            // 2. Fallback: queryUsageStats for top recent app
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                currentTime - 120_000L,
                currentTime
            )
            return stats?.maxByOrNull { it.lastTimeUsed }?.packageName
        } catch (e: Exception) {
            android.util.Log.e("MonitoringService", "Error getting foreground app", e)
            return null
        }
    }
    
    /**
     * Handle when a new app comes to foreground
     */
    private suspend fun handleForegroundAppChange(packageName: String, currentTime: LocalDateTime) {
        // Skip system apps and launcher
        if (isSystemApp(packageName)) {
            return
        }
        
        android.util.Log.d("MonitoringService", "Foreground app changed to: $packageName")
        
        // Check if this is a new app (not in local database)
        val rule = database.getRule(packageName)
        if (rule == null) {
            // This is a new app, send notification
            sendNewAppNotification(packageName)
        }
        
        // Increment usage tracking
        database.incrementUsageMinutes(packageName, 0, currentTime) // Initialize if needed
        
        // Immediate rule evaluation for the new app
        enforcementManager.enforceRuleForApp(packageName, currentTime)
    }
    
    /**
     * Update usage tracking for the current foreground app
     */
    private suspend fun updateUsageTracking(packageName: String, currentTime: LocalDateTime) {
        val nowMs = System.currentTimeMillis()
        if (isSystemApp(packageName)) {
            activeUsagePackage = null
            lastUsageUpdateAtMs = 0
            usageSecondRemainder = 0
            return
        }

        if (activeUsagePackage != packageName || lastUsageUpdateAtMs == 0L) {
            activeUsagePackage = packageName
            lastUsageUpdateAtMs = nowMs
            usageSecondRemainder = 0
            return
        }

        val elapsedMs = (nowMs - lastUsageUpdateAtMs).coerceAtLeast(0L)
        lastUsageUpdateAtMs = nowMs
        usageSecondRemainder += minOf(elapsedMs, 5_000L) / 1_000L
        val minutesToAdd = (usageSecondRemainder / 60L).toInt()
        if (minutesToAdd <= 0) return

        usageSecondRemainder %= 60L
        val previousUsage = database.getUsage(packageName)
        val previousMinutes = if (previousUsage?.dailyResetDate == currentTime.toLocalDate().toString()) {
            previousUsage.todayMinutes
        } else {
            0
        }
        database.incrementUsageMinutes(packageName, minutesToAdd, currentTime)

        val updatedUsage = database.getUsage(packageName) ?: return
        val rule = database.getRule(packageName) ?: return
        val limit = rule.dailyLimitMinutes
        if (rule.type != RuleEngine.RuleType.TIME_LIMIT || limit == null || limit <= 0) return

        val thresholdMinutes = kotlin.math.ceil(
            limit * rule.usageAlertThresholdPercent.coerceIn(1, 99) / 100.0
        ).toInt()
        val crossedThreshold = previousMinutes < thresholdMinutes &&
            updatedUsage.todayMinutes >= thresholdMinutes
        val crossedLimit = previousMinutes < limit && updatedUsage.todayMinutes >= limit
        if (crossedThreshold || crossedLimit) {
            syncUsageToFirestore(packageName)
        }
    }
    
    /**
     * Check if package is a system app that should be ignored
     */
    private fun isSystemApp(packageName: String): Boolean {
        // System packages to ignore
        val systemPackages = setOf(
            "com.android.systemui",
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.googlequicksearchbox",
            "com.android.settings",
            applicationContext.packageName // Our own app
        )
        
        if (systemPackages.contains(packageName)) {
            return true
        }
        
        try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            val applicationInfo = packageInfo.applicationInfo
            return ((applicationInfo?.flags ?: 0) and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
        } catch (e: PackageManager.NameNotFoundException) {
            return true // If we can't find the package, treat as system
        }
    }
    
    /**
     * Periodic cleanup tasks
     */
    private suspend fun performPeriodicCleanup() = withContext(Dispatchers.IO) {
        val currentTime = LocalDateTime.now()
        
        // Clean up expired temporary approvals
        database.cleanupExpiredApprovals(currentTime)
        
        // Reset usage data for apps that need daily reset
        val allUsage = database.getAllUsageData()
        val today = currentTime.toLocalDate().toString()
        
        for ((packageName, usage) in allUsage) {
            if (ruleEngine.shouldResetUsageData(usage, currentTime)) {
                database.resetUsageForDate(packageName, today)
            }
        }
    }
    
    /**
     * Check if app has Usage Stats permission
     */
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }
    
    /**
     * Create notification channel for service
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Parental Control Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors app usage for parental control enforcement"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    /**
     * Create ongoing notification for foreground service
     */
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Family Guardian Active")
            .setContentText("Monitoring app usage and enforcing rules")
            .setSmallIcon(R.drawable.ic_notification) // You'll need to add this icon
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    /**
     * Initialize user context for notifications
     */
    private fun initializeUserContext() {
        serviceScope.launch {
            try {
                val auth = com.google.firebase.auth.FirebaseAuth.getInstance()
                val firestore = com.google.firebase.firestore.FirebaseFirestore.getInstance()
                
                val user = auth.currentUser
                if (user != null) {
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    if (!user.displayName.isNullOrEmpty()) {
                        prefs.edit().putString(KEY_CHILD_NAME, user.displayName).apply()
                    }
                    firestore.collection("users").document(user.uid)
                        .get()
                        .addOnSuccessListener { userDoc ->
                            currentFamilyId = userDoc.getString("familyId")
                            currentChildId = user.uid
                            val name = userDoc.getString("displayName")
                            if (!name.isNullOrEmpty()) {
                                prefs.edit().putString(KEY_CHILD_NAME, name).apply()
                            }
                            
                            // Start device status monitoring and rule sync
                            if (currentFamilyId != null && currentChildId != null) {
                                startRuleSync(currentFamilyId!!, currentChildId!!)
                                deviceStatusHelper.startStatusMonitoring(currentFamilyId!!, currentChildId!!)
                            }
                        }
                }
            } catch (e: Exception) {
                android.util.Log.e("MonitoringService", "Error initializing user context", e)
            }
        }
    }
    
    /**
     * Send notification for new app detection
     */
    private suspend fun sendNewAppNotification(packageName: String) {
        val familyId = currentFamilyId ?: return
        val childId = currentChildId ?: return
        
        try {
            val appInfo = getAppInfo(packageName)
            if (appInfo != null) {
                val firestore = com.google.firebase.firestore.FirebaseFirestore.getInstance()
                
                val childName = getCurrentChildName()
                val notificationData = hashMapOf(
                    "familyId" to familyId,
                    "childId" to childId,
                    "childName" to childName,
                    "type" to "newAppDetected",
                    "priority" to "low",
                    "title" to "$childName: New App Detected",
                    "body" to "${appInfo.name} was newly installed on $childName's device.",
                    "data" to hashMapOf(
                        "type" to "newAppDetected",
                        "familyId" to familyId,
                        "childId" to childId,
                        "childName" to childName,
                        "appName" to appInfo.name,
                        "packageName" to packageName
                    ),
                    "createdAt" to com.google.firebase.Timestamp.now(),
                    "expiresAt" to com.google.firebase.Timestamp(
                        java.util.Date(System.currentTimeMillis() + 24 * 60 * 60 * 1000) // 24 hours
                    )
                )

                firestore.collection("notifications")
                    .add(notificationData)
            }
        } catch (e: Exception) {
            android.util.Log.e("MonitoringService", "Error sending new app notification", e)
        }
    }
    
    /**
     * Send real-time notification to parent when child attempts to use a blocked app
     */
    private suspend fun sendBlockedAppNotification(packageName: String, appName: String) {
        val familyId = currentFamilyId ?: return
        val childId = currentChildId ?: return
        
        val now = System.currentTimeMillis()
        val lastNotif = lastBlockNotificationTime[packageName] ?: 0L
        if (now - lastNotif < 300_000L) { // Throttle to at most once per 5 minutes per app to protect quota
            return
        }
        lastBlockNotificationTime[packageName] = now
        
        try {
            val firestore = com.google.firebase.firestore.FirebaseFirestore.getInstance()
            val childName = getCurrentChildName()
            
            val notificationData = hashMapOf(
                "familyId" to familyId,
                "childId" to childId,
                "childName" to childName,
                "type" to "appRequest",
                "priority" to "urgent",
                "title" to "🚫 $childName: Blocked App Attempted",
                "body" to "$childName attempted to open $appName which is blocked.",
                "data" to hashMapOf(
                    "type" to "blocked_app_attempt",
                    "familyId" to familyId,
                    "childId" to childId,
                    "childName" to childName,
                    "appName" to appName,
                    "packageName" to packageName
                ),
                "createdAt" to com.google.firebase.Timestamp.now(),
                "isRead" to false
            )

            firestore.collection("notifications").add(notificationData)
            
            // Also add event to family event log
            firestore.collection("families")
                .document(familyId)
                .collection("events")
                .add(hashMapOf(
                    "type" to "blocked_app_attempt",
                    "familyId" to familyId,
                    "childId" to childId,
                    "childName" to childName,
                    "appName" to appName,
                    "packageName" to packageName,
                    "timestamp" to com.google.firebase.Timestamp.now()
                ))
                
            android.util.Log.d("MonitoringService", "Sent blocked app notification and request to parent for $appName")
        } catch (e: Exception) {
            android.util.Log.e("MonitoringService", "Error sending blocked app notification", e)
        }
    }
    
    /**
     * Get app information for a package
     */
    private fun getAppInfo(packageName: String): AppInfo? {
        return try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            val applicationInfo = packageInfo.applicationInfo ?: return null
            
            AppInfo(
                name = packageManager.getApplicationLabel(applicationInfo).toString(),
                packageName = packageName
            )
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
    }
    
    private val lastSyncedUsageMinutes = java.util.concurrent.ConcurrentHashMap<String, Int>()
    private val lastSyncedUsageDates = java.util.concurrent.ConcurrentHashMap<String, String>()

    /**
     * Periodically sync only CHANGED app usage minutes to Firestore (quota-optimized)
     */
    private suspend fun syncUsageToFirestore(urgentPackage: String? = null) = withContext(Dispatchers.IO) {
        val familyId = currentFamilyId ?: return@withContext
        val childId = currentChildId ?: return@withContext

        try {
            val allUsage = database.getAllUsageData()
            if (allUsage.isEmpty()) return@withContext

            val firestore = com.google.firebase.firestore.FirebaseFirestore.getInstance()
            val batch = firestore.batch()
            var count = 0
            val syncedEntries = mutableListOf<Pair<String, RuleEngine.UsageData>>()

            for ((pkg, usage) in allUsage) {
                if (urgentPackage != null && pkg != urgentPackage) continue
                val currentMinutes = usage.todayMinutes
                val lastMinutes = lastSyncedUsageMinutes[pkg] ?: 0
                val lastDate = lastSyncedUsageDates[pkg]

                if (currentMinutes <= 0 ||
                    (usage.dailyResetDate == lastDate && currentMinutes == lastMinutes)
                ) {
                    continue
                }

                val appInfo = getAppInfo(pkg)
                val appDoc = firestore.collection("families")
                    .document(familyId)
                    .collection("children")
                    .document(childId)
                    .collection("usage")
                    .document(pkg.replace(".", "_"))

                val usageData = hashMapOf(
                    "packageName" to pkg,
                    "appName" to (appInfo?.name ?: pkg),
                    "todayMinutes" to currentMinutes,
                    "weekMinutes" to currentMinutes,
                    "monthMinutes" to currentMinutes,
                    "dailyResetDate" to usage.dailyResetDate,
                    "timeZoneId" to ZoneId.systemDefault().id,
                    "lastUsed" to com.google.firebase.Timestamp.now(),
                    "openCount" to 1,
                    "updatedAt" to com.google.firebase.firestore.FieldValue.serverTimestamp()
                )
                batch.set(appDoc, usageData, com.google.firebase.firestore.SetOptions.merge())
                syncedEntries.add(pkg to usage)
                count++
                if (count >= 50) break
            }

            if (count > 0) {
                batch.commit().await()
                syncedEntries.forEach { (pkg, usage) ->
                    lastSyncedUsageMinutes[pkg] = usage.todayMinutes
                    lastSyncedUsageDates[pkg] = usage.dailyResetDate
                }
                android.util.Log.d("MonitoringService", "Synced $count changed app usage records to Firestore")
            }
        } catch (e: Exception) {
            android.util.Log.e("MonitoringService", "Failed to sync usage to Firestore", e)
        }
    }
    
    /**
     * Get current child name from user data
     */
    private fun getCurrentChildName(): String {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val cached = prefs.getString(KEY_CHILD_NAME, null)
        if (!cached.isNullOrEmpty() && cached != "Child" && cached != "Your child") return cached

        val auth = com.google.firebase.auth.FirebaseAuth.getInstance()
        val displayName = auth.currentUser?.displayName
        if (!displayName.isNullOrEmpty()) {
            prefs.edit().putString(KEY_CHILD_NAME, displayName).apply()
            return displayName
        }

        // Fetch from child document in Firestore if not cached
        val childId = currentChildId ?: auth.currentUser?.uid
        val familyId = currentFamilyId
        if (childId != null) {
            try {
                val db = com.google.firebase.firestore.FirebaseFirestore.getInstance()
                if (familyId != null) {
                    db.collection("families").document(familyId)
                        .collection("children").document(childId)
                        .get().addOnSuccessListener { doc ->
                            val name = doc.getString("displayName") ?: doc.getString("name")
                            if (!name.isNullOrEmpty()) {
                                prefs.edit().putString(KEY_CHILD_NAME, name).apply()
                            }
                        }
                }
                db.collection("users").document(childId)
                    .get().addOnSuccessListener { doc ->
                        val name = doc.getString("displayName") ?: doc.getString("name")
                        if (!name.isNullOrEmpty()) {
                            prefs.edit().putString(KEY_CHILD_NAME, name).apply()
                        }
                    }
            } catch (_: Exception) {}
        }

        return cached ?: "Child"
    }
    
    /**
     * Data class for app information
     */
    private data class AppInfo(
        val name: String,
        val packageName: String
    )
    
    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(clearOverlayReceiver) } catch (_: Exception) {}
        deviceStatusHelper.stopStatusMonitoring()
        ruleSyncService?.stopSync()
        ruleSyncService = null
        
        // Send service unavailable notification
        serviceScope.launch {
            sendServiceUnavailableNotification()
        }
        
        stopMonitoring()
        serviceJob.cancel()
    }
    
    /**
     * Send notification when monitoring service stops
     */
    private suspend fun sendServiceUnavailableNotification() {
        val familyId = currentFamilyId ?: return
        val childId = currentChildId ?: return
        
        try {
            val firestore = com.google.firebase.firestore.FirebaseFirestore.getInstance()
            
            val notificationData = hashMapOf(
                "familyId" to familyId,
                "childId" to childId,
                "childName" to getCurrentChildName(),
                "type" to "service_unavailable",
                "priority" to "urgent",
                "title" to "Monitoring Unavailable",
                "body" to "Monitoring service stopped on ${getCurrentChildName()}'s device.",
                "data" to hashMapOf(
                    "type" to "service_unavailable",
                    "familyId" to familyId,
                    "childId" to childId,
                    "service" to "Monitoring Service"
                ),
                "createdAt" to com.google.firebase.Timestamp.now()
            )

            firestore.collection("notifications")
                .add(notificationData)
                
        } catch (e: Exception) {
            android.util.Log.e("MonitoringService", "Error sending service unavailable notification", e)
        }
    }
}

/**
 * IMPORTANT IMPLEMENTATION NOTES:
 * 
 * 1. FOREGROUND APP DETECTION:
 *    - Uses UsageStatsManager.queryEvents() to detect MOVE_TO_FOREGROUND events
 *    - This is the official Android API for app usage monitoring
 *    - Requires PACKAGE_USAGE_STATS permission (granted through Settings)
 * 
 * 2. ENFORCEMENT LIMITATIONS:
 *    - Cannot force-close arbitrary applications (Android security restriction)
 *    - Cannot prevent app launches (requires system-level permissions)
 *    - Enforcement is reactive through EnforcementManager
 * 
 * 3. SERVICE LIFECYCLE:
 *    - Runs as foreground service with persistent notification
 *    - Automatically restarts if killed by system (START_STICKY)
 *    - Properly handles service lifecycle and resource cleanup
 * 
 * 4. PERMISSIONS REQUIRED:
 *    - PACKAGE_USAGE_STATS: For detecting foreground apps
 *    - FOREGROUND_SERVICE: For running continuous monitoring
 *    - SYSTEM_ALERT_WINDOW: For enforcement overlays (handled by EnforcementManager)
 * 
 * 5. OFFLINE OPERATION:
 *    - Works entirely with local database
 *    - No network dependencies for core monitoring
 *    - Rules cached locally for offline enforcement
 */