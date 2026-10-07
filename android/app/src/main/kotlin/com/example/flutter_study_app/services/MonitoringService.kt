package com.example.flutter_study_app.services

import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.*
import androidx.core.app.NotificationCompat
import com.example.flutter_study_app.R
import com.example.flutter_study_app.MainActivity
import com.example.flutter_study_app.DeviceStatusHelper
import com.example.flutter_study_app.database.LocalDatabase
import com.example.flutter_study_app.enforcement.RuleEngine
import com.example.flutter_study_app.enforcement.EnforcementManager
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.Timestamp
import kotlinx.coroutines.*
import java.time.LocalDateTime
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
    
    private var lastForegroundApp: String? = null
    private var lastCheckTime: Long = 0
    private val checkIntervalMs = 2000L // Check every 2 seconds
    
    // For notification tracking
    private var currentFamilyId: String? = null
    private var currentChildId: String? = null
    
    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "parental_control_monitoring"
        
        const val ACTION_START_MONITORING = "START_MONITORING"
        const val ACTION_STOP_MONITORING = "STOP_MONITORING"
        
        fun startService(context: Context) {
            val intent = Intent(context, MonitoringService::class.java).apply {
                action = ACTION_START_MONITORING
            }
            context.startForegroundService(intent)
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
        lastCheckTime = System.currentTimeMillis()
        
        // Initialize user context for notifications
        initializeUserContext()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_MONITORING -> startMonitoring()
            ACTION_STOP_MONITORING -> stopMonitoring()
        }
        
        // Service should restart if killed by the system
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
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
    }
    
    private fun stopMonitoring() {
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
            val foregroundApp = getCurrentForegroundApp()
            
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
            if (foregroundApp != null) {
                enforcementManager.enforceRuleForApp(foregroundApp, currentTime)
            }
            
        } catch (e: SecurityException) {
            android.util.Log.w("MonitoringService", "UsageStats permission not granted", e)
        }
    }
    
    /**
     * Get the currently active foreground application
     * Uses UsageStatsManager to determine the most recent app
     */
    private fun getCurrentForegroundApp(): String? {
        if (!hasUsageStatsPermission()) {
            return null
        }
        
        try {
            val currentTime = System.currentTimeMillis()
            val usageEvents = usageStatsManager.queryEvents(
                currentTime - checkIntervalMs * 2, // Look back slightly further
                currentTime
            )
            
            var lastForegroundPackage: String? = null
            var lastEventTime: Long = 0
            
            val event = UsageEvents.Event()
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND &&
                    event.timeStamp > lastEventTime) {
                    lastForegroundPackage = event.packageName
                    lastEventTime = event.timeStamp
                }
            }
            
            return lastForegroundPackage
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
        
        // Check for daily limit notifications
        checkDailyLimitAndNotify(packageName)
        
        // Immediate rule evaluation for the new app
        enforcementManager.enforceRuleForApp(packageName, currentTime)
    }
    
    /**
     * Update usage tracking for the current foreground app
     */
    private suspend fun updateUsageTracking(packageName: String, currentTime: LocalDateTime) {
        if (isSystemApp(packageName)) return
        
        val timeSinceLastCheck = System.currentTimeMillis() - lastCheckTime
        if (timeSinceLastCheck > checkIntervalMs) {
            // Convert to minutes (rounded up)
            val minutesToAdd = ((timeSinceLastCheck + 30000) / 60000).toInt() // Round to nearest minute
            if (minutesToAdd > 0) {
                database.incrementUsageMinutes(packageName, minutesToAdd, currentTime)
            }
        }
        
        lastCheckTime = System.currentTimeMillis()
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
                    firestore.collection("users").document(user.uid)
                        .get()
                        .addOnSuccessListener { userDoc ->
                            currentFamilyId = userDoc.getString("familyId")
                            currentChildId = user.uid
                            
                            // Start device status monitoring
                            if (currentFamilyId != null && currentChildId != null) {
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
                
                // Create notification in Firestore (triggers Cloud Function)
                val notificationData = hashMapOf(
                    "familyId" to familyId,
                    "childId" to childId,
                    "childName" to getCurrentChildName(),
                    "type" to "new_app_detected",
                    "priority" to "low",
                    "title" to "New App Detected",
                    "body" to "${appInfo.name} was installed on ${getCurrentChildName()}'s device.",
                    "data" to hashMapOf(
                        "type" to "new_app_detected",
                        "familyId" to familyId,
                        "childId" to childId,
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
     * Send notification when daily limit is reached
     */
    private suspend fun sendDailyLimitNotification(packageName: String, appName: String, limitMinutes: Int) {
        val familyId = currentFamilyId ?: return
        val childId = currentChildId ?: return
        
        try {
            val firestore = com.google.firebase.firestore.FirebaseFirestore.getInstance()
            
            val notificationData = hashMapOf(
                "familyId" to familyId,
                "childId" to childId,
                "childName" to getCurrentChildName(),
                "type" to "daily_limit_reached",
                "priority" to "normal",
                "title" to "Daily Limit Reached",
                "body" to "${getCurrentChildName()} has reached their daily limit for $appName.",
                "data" to hashMapOf(
                    "type" to "daily_limit_reached",
                    "familyId" to familyId,
                    "childId" to childId,
                    "appName" to appName,
                    "packageName" to packageName,
                    "dailyLimitMinutes" to limitMinutes
                ),
                "createdAt" to com.google.firebase.Timestamp.now(),
                "expiresAt" to com.google.firebase.Timestamp(
                    java.util.Date(System.currentTimeMillis() + 8 * 60 * 60 * 1000) // 8 hours
                )
            )

            firestore.collection("notifications")
                .add(notificationData)
                
        } catch (e: Exception) {
            android.util.Log.e("MonitoringService", "Error sending daily limit notification", e)
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
    
    /**
     * Check if daily limit reached and send notification
     */
    private suspend fun checkDailyLimitAndNotify(packageName: String) {
        try {
            val rule = database.getRule(packageName) ?: return
            
            if (rule.type == RuleEngine.RuleType.TIME_LIMIT && rule.dailyLimitMinutes != null) {
                val usage = database.getUsage(packageName)
                val currentUsage = usage?.todayMinutes ?: 0
                val limitMinutes = rule.dailyLimitMinutes
                
                // Check if we just reached the daily limit
                if (currentUsage >= limitMinutes && 
                    (currentUsage - (checkIntervalMs / 60000).toInt()) < limitMinutes) {
                    
                    val appInfo = getAppInfo(packageName)
                    if (appInfo != null) {
                        sendDailyLimitNotification(packageName, appInfo.name, limitMinutes)
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MonitoringService", "Error checking daily limit", e)
        }
    }
    
    /**
     * Get current child name from user data
     */
    private fun getCurrentChildName(): String {
        // In a real implementation, you'd cache this from user data
        return "Your child"
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
        deviceStatusHelper.stopStatusMonitoring()
        
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