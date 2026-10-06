package com.example.flutter_study_app

import android.app.*
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import android.graphics.PixelFormat
import android.view.*
import android.widget.*
import kotlinx.coroutines.*
import java.util.*

/**
 * Real Android foreground service for monitoring app usage and enforcing rules
 * This provides ACTUAL app blocking using Android system APIs
 */
class MonitoringService : Service() {
    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "parental_controls_monitoring"
        private const val CHECK_INTERVAL = 2000L // Check every 2 seconds
    }

    private var monitoringJob: Job? = null
    private var usageStatsManager: UsageStatsManager? = null
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var lastCheckedApp: String? = null
    private var lastCheckTime = System.currentTimeMillis()

    override fun onCreate() {
        super.onCreate()
        
        // Initialize system services
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        // Create notification channel for monitoring
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, createMonitoringNotification())
        startMonitoring()
        
        // Service should restart if killed
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        stopMonitoring()
        hideOverlay()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * Start monitoring foreground apps using UsageStatsManager
     */
    private fun startMonitoring() {
        monitoringJob = CoroutineScope(Dispatchers.Main).launch {
            while (isActive) {
                try {
                    checkForegroundApp()
                    delay(CHECK_INTERVAL)
                } catch (e: Exception) {
                    // Continue monitoring even if individual checks fail
                    delay(CHECK_INTERVAL)
                }
            }
        }
    }

    /**
     * Stop monitoring and cleanup
     */
    private fun stopMonitoring() {
        monitoringJob?.cancel()
        hideOverlay()
    }

    /**
     * Check current foreground app using REAL Android UsageStatsManager
     */
    private fun checkForegroundApp() {
        val currentTime = System.currentTimeMillis()
        
        // Get usage stats for last few seconds
        val usageStats = usageStatsManager?.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            currentTime - 5000, // Last 5 seconds
            currentTime
        )
        
        // Find the most recently used app
        val currentApp = usageStats?.maxByOrNull { it.lastTimeUsed }?.packageName
        
        if (currentApp != null && currentApp != lastCheckedApp) {
            lastCheckedApp = currentApp
            handleAppLaunch(currentApp)
        }
    }

    /**
     * Handle when an app is launched - check rules and block if needed
     */
    private fun handleAppLaunch(packageName: String) {
        // Skip system apps and our own app
        if (isSystemApp(packageName) || packageName == this.packageName) {
            return
        }

        // TODO: Check app rules from local cache
        // For now, demonstrate blocking functionality with a test app
        if (shouldBlockApp(packageName)) {
            showBlockingOverlay(packageName)
        } else {
            hideOverlay()
        }
    }

    /**
     * Check if app should be blocked (placeholder - will connect to real rules later)
     */
    private fun shouldBlockApp(packageName: String): Boolean {
        // For demonstration, block any app with "game" in the name
        // In real implementation, this would check cached rules from Firestore
        return packageName.contains("game", ignoreCase = true) ||
               packageName.contains("tiktok", ignoreCase = true) ||
               packageName.contains("instagram", ignoreCase = true)
    }

    /**
     * Check if package is a system app that shouldn't be blocked
     */
    private fun isSystemApp(packageName: String): Boolean {
        val systemApps = setOf(
            "android",
            "com.android.systemui",
            "com.android.settings",
            "com.android.launcher",
            "com.android.launcher3",
            "com.android.phone",
            "com.android.dialer",
            "com.google.android.dialer"
        )
        
        return systemApps.contains(packageName) || 
               packageName.startsWith("com.android.") ||
               packageName.startsWith("com.google.android.gms")
    }

    /**
     * Show full-screen overlay to block the app
     * This is the REAL blocking mechanism using Android system overlay
     */
    private fun showBlockingOverlay(packageName: String) {
        if (overlayView != null) return // Already showing
        
        try {
            // Create blocking overlay layout
            val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
            overlayView = inflater.inflate(R.layout.blocking_overlay, null)
            
            // Set up overlay content
            setupOverlayContent(packageName)
            
            // Configure overlay parameters
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                },
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
                PixelFormat.TRANSLUCENT
            )
            
            // Show overlay
            windowManager?.addView(overlayView, params)
            
        } catch (e: Exception) {
            // Fallback: send user back to home screen
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(homeIntent)
        }
    }

    /**
     * Setup overlay content with app information and request button
     */
    private fun setupOverlayContent(packageName: String) {
        overlayView?.let { view ->
            try {
                // Get app name and icon
                val packageManager = applicationContext.packageManager
                val appInfo = packageManager.getApplicationInfo(packageName, 0)
                val appName = packageManager.getApplicationLabel(appInfo).toString()
                val appIcon = packageManager.getApplicationIcon(appInfo)
                
                // Set app icon and name
                view.findViewById<ImageView>(R.id.blocked_app_icon)?.setImageDrawable(appIcon)
                view.findViewById<TextView>(R.id.blocked_app_name)?.text = appName
                
                // Set up buttons
                view.findViewById<Button>(R.id.btn_request_access)?.setOnClickListener {
                    requestAppAccess(packageName, appName)
                }
                
                view.findViewById<Button>(R.id.btn_go_home)?.setOnClickListener {
                    goToHome()
                }
                
                view.findViewById<Button>(R.id.btn_close)?.setOnClickListener {
                    hideOverlay()
                    goToHome()
                }
                
            } catch (e: Exception) {
                // Fallback display
                view.findViewById<TextView>(R.id.blocked_app_name)?.text = "Blocked App"
            }
        }
    }

    /**
     * Hide the blocking overlay
     */
    private fun hideOverlay() {
        overlayView?.let { view ->
            try {
                windowManager?.removeView(view)
            } catch (e: Exception) {
                // Ignore errors when removing view
            }
        }
        overlayView = null
    }

    /**
     * Handle app access request
     */
    private fun requestAppAccess(packageName: String, appName: String) {
        // TODO: Send request to parent via Firebase/FCM
        // For now, show toast
        Toast.makeText(this, "Access request sent for $appName", Toast.LENGTH_SHORT).show()
        
        // Hide overlay and go home
        hideOverlay()
        goToHome()
    }

    /**
     * Go to home screen
     */
    private fun goToHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
    }

    /**
     * Create notification channel for monitoring service
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Parental Controls Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when parental controls are actively monitoring"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Create monitoring notification
     */
    private fun createMonitoringNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Parental Controls Active")
            .setContentText("Device monitoring is active for your safety")
            .setSmallIcon(R.drawable.ic_notification) // You'll need to add this icon
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
}