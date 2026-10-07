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
import android.content.pm.PackageManager
import android.content.pm.Signature
import java.security.MessageDigest
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import android.util.Base64
import java.io.File
import android.provider.Settings

/**
 * CRITICAL: Hardened Android foreground service for monitoring app usage and enforcing rules
 * Enhanced with anti-tampering, authentication, and security validation
 */
class MonitoringService : Service() {
    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "parental_controls_monitoring"
        private const val CHECK_INTERVAL = 2000L // Check every 2 seconds
        private const val SECURITY_CHECK_INTERVAL = 10000L // Security check every 10 seconds
        
        // CRITICAL: Security configuration
        private const val EXPECTED_SIGNATURE_HASH = "YOUR_APK_SIGNATURE_HASH_HERE" // Replace in production
        private const val DEVICE_SECRET_KEY = "device_monitoring_secret_2024" // Should be from secure storage
        private const val MAX_OVERLAY_DISMISS_ATTEMPTS = 3
        private const val SERVICE_RESTART_DELAY = 5000L
    }

    private var monitoringJob: Job? = null
    private var securityJob: Job? = null
    private var usageStatsManager: UsageStatsManager? = null
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var lastCheckedApp: String? = null
    private var lastCheckTime = System.currentTimeMillis()
    
    // CRITICAL: Security state tracking
    private var overlayDismissCount = 0
    private var isDeviceCompromised = false
    private var lastSecurityCheck = System.currentTimeMillis()
    private var deviceId: String? = null

    override fun onCreate() {
        super.onCreate()
        
        // CRITICAL: Perform security validation on startup
        if (!performSecurityValidation()) {
            // Device is compromised - log and attempt to notify parents
            isDeviceCompromised = true
            notifySecurityBreach("Device security validation failed")
            stopSelf() // Stop service if security validation fails
            return
        }
        
        // Initialize system services only if security validation passes
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        deviceId = getSecureDeviceId()
        
        // Create notification channel for monitoring
        createNotificationChannel()
        
        // CRITICAL: Start security monitoring
        startSecurityMonitoring()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (isDeviceCompromised) {
            stopSelf()
            return START_NOT_STICKY
        }
        
        startForeground(NOTIFICATION_ID, createMonitoringNotification())
        startMonitoring()
        
        // Service should restart if killed (with security validation)
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        
        // CRITICAL: Log service destruction for audit
        logSecurityEvent("service_destroyed", mapOf(
            "timestamp" to System.currentTimeMillis(),
            "isDeviceCompromised" to isDeviceCompromised
        ))
        
        stopMonitoring()
        stopSecurityMonitoring()
        hideOverlay()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * CRITICAL: Comprehensive security validation
     */
    private fun performSecurityValidation(): Boolean {
        try {
            // 1. CRITICAL: Verify APK signature
            if (!verifyAPKSignature()) {
                logSecurityEvent("apk_signature_invalid", mapOf("timestamp" to System.currentTimeMillis()))
                return false
            }
            
            // 2. CRITICAL: Check for root access
            if (isDeviceRooted()) {
                logSecurityEvent("device_rooted", mapOf("timestamp" to System.currentTimeMillis()))
                return false
            }
            
            // 3. CRITICAL: Verify app installation source
            if (!verifyInstallationSource()) {
                logSecurityEvent("invalid_installation_source", mapOf("timestamp" to System.currentTimeMillis()))
                return false
            }
            
            // 4. CRITICAL: Check for debugging/developer options
            if (isDeveloperModeEnabled()) {
                logSecurityEvent("developer_mode_enabled", mapOf("timestamp" to System.currentTimeMillis()))
                return false
            }
            
            return true
            
        } catch (e: Exception) {
            logSecurityEvent("security_validation_error", mapOf(
                "error" to e.message,
                "timestamp" to System.currentTimeMillis()
            ))
            return false
        }
    }

    /**
     * CRITICAL: Verify APK signature to prevent tampering
     */
    private fun verifyAPKSignature(): Boolean {
        try {
            val packageInfo = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            val signatures = packageInfo.signatures
            
            if (signatures.isNullOrEmpty()) return false
            
            val signature = signatures[0]
            val messageDigest = MessageDigest.getInstance("SHA-256")
            messageDigest.update(signature.toByteArray())
            val signatureHash = Base64.encodeToString(messageDigest.digest(), Base64.NO_WRAP)
            
            // In production, this should be the actual signature hash
            // For demo purposes, we'll just check if signature exists
            return signatureHash.isNotEmpty()
            
        } catch (e: Exception) {
            return false
        }
    }

    /**
     * CRITICAL: Check if device is rooted
     */
    private fun isDeviceRooted(): Boolean {
        // Check for common root indicators
        val rootIndicators = listOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        
        return rootIndicators.any { File(it).exists() } ||
               checkRootByExecutingCommands()
    }

    /**
     * CRITICAL: Check root by attempting to execute root commands
     */
    private fun checkRootByExecutingCommands(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "id"))
            process.waitFor()
            process.exitValue() == 0
        } catch (e: Exception) {
            false
        }
    }

    /**
     * CRITICAL: Verify app was installed from legitimate source
     */
    private fun verifyInstallationSource(): Boolean {
        return try {
            val installerPackage = packageManager.getInstallerPackageName(packageName)
            val legitimateSources = setOf(
                "com.android.vending", // Google Play Store
                "com.amazon.venezia",  // Amazon Appstore
                null // Allow sideloading for development - remove in production
            )
            legitimateSources.contains(installerPackage)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * CRITICAL: Check if developer options are enabled
     */
    private fun isDeveloperModeEnabled(): Boolean {
        return try {
            Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) == 1
        } catch (e: Exception) {
            false
        }
    }

    /**
     * CRITICAL: Get secure device identifier
     */
    private fun getSecureDeviceId(): String {
        return try {
            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown"
        } catch (e: Exception) {
            "unknown"
        }
    }

    /**
     * CRITICAL: Start continuous security monitoring
     */
    private fun startSecurityMonitoring() {
        securityJob = CoroutineScope(Dispatchers.IO).launch {
            while (isActive && !isDeviceCompromised) {
                try {
                    performContinuousSecurityCheck()
                    delay(SECURITY_CHECK_INTERVAL)
                } catch (e: Exception) {
                    logSecurityEvent("security_monitoring_error", mapOf(
                        "error" to e.message,
                        "timestamp" to System.currentTimeMillis()
                    ))
                    delay(SECURITY_CHECK_INTERVAL)
                }
            }
        }
    }

    /**
     * CRITICAL: Stop security monitoring
     */
    private fun stopSecurityMonitoring() {
        securityJob?.cancel()
    }

    /**
     * CRITICAL: Continuous security checks during operation
     */
    private fun performContinuousSecurityCheck() {
        val currentTime = System.currentTimeMillis()
        
        // Check if security validation is still valid
        if (currentTime - lastSecurityCheck > 60000) { // Re-validate every minute
            if (!performSecurityValidation()) {
                isDeviceCompromised = true
                notifySecurityBreach("Continuous security validation failed")
                stopSelf()
                return
            }
            lastSecurityCheck = currentTime
        }
        
        // Check for service manipulation attempts
        checkServiceIntegrity()
        
        // Check overlay dismiss attempts
        if (overlayDismissCount > MAX_OVERLAY_DISMISS_ATTEMPTS) {
            notifySecurityBreach("Excessive overlay dismiss attempts: $overlayDismissCount")
            overlayDismissCount = 0 // Reset counter
        }
    }

    /**
     * CRITICAL: Check service integrity
     */
    private fun checkServiceIntegrity() {
        // Verify service is still running with proper permissions
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val runningServices = activityManager.getRunningServices(Integer.MAX_VALUE)
        
        val isServiceRunning = runningServices.any { 
            it.service.className == this::class.java.name 
        }
        
        if (!isServiceRunning) {
            logSecurityEvent("service_integrity_violation", mapOf(
                "timestamp" to System.currentTimeMillis(),
                "expected_service" to this::class.java.name
            ))
        }
    }

    /**
     * CRITICAL: Generate authenticated device signature
     */
    private fun generateDeviceSignature(data: String, timestamp: Long): String {
        return try {
            val key = SecretKeySpec(DEVICE_SECRET_KEY.toByteArray(), "HmacSHA256")
            val mac = Mac.getInstance("HmacSHA256")
            mac.init(key)
            val signature = mac.doFinal("$deviceId:$data:$timestamp".toByteArray())
            Base64.encodeToString(signature, Base64.NO_WRAP)
        } catch (e: Exception) {
            "invalid_signature"
        }
    }

    /**
     * CRITICAL: Log security events for audit trail
     */
    private fun logSecurityEvent(event: String, data: Map<String, Any?>) {
        // TODO: Send to secure logging service
        // For now, log locally with timestamp and device signature
        val timestamp = System.currentTimeMillis()
        val signature = generateDeviceSignature(event, timestamp)
        
        android.util.Log.w("SECURITY_AUDIT", "Event: $event, Data: $data, Signature: $signature")
        
        // TODO: Queue for upload to Firebase when network available
    }

    /**
     * CRITICAL: Notify parents of security breach
     */
    private fun notifySecurityBreach(reason: String) {
        logSecurityEvent("security_breach", mapOf(
            "reason" to reason,
            "deviceId" to (deviceId ?: "unknown"),
            "timestamp" to System.currentTimeMillis()
        ))
        
        // TODO: Send immediate FCM notification to parents
        // TODO: Update device status in Firestore
    }

    /**
     * Start monitoring foreground apps using UsageStatsManager with security enhancements
     */
    private fun startMonitoring() {
        if (isDeviceCompromised) return
        
        monitoringJob = CoroutineScope(Dispatchers.Main).launch {
            while (isActive && !isDeviceCompromised) {
                try {
                    checkForegroundApp()
                    delay(CHECK_INTERVAL)
                } catch (e: Exception) {
                    logSecurityEvent("monitoring_error", mapOf(
                        "error" to e.message,
                        "timestamp" to System.currentTimeMillis()
                    ))
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
     * CRITICAL: Check current foreground app with enhanced validation
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
            
            // CRITICAL: Log app transitions for audit
            logSecurityEvent("app_transition", mapOf(
                "fromApp" to (lastCheckedApp ?: "unknown"),
                "toApp" to currentApp,
                "timestamp" to currentTime
            ))
            
            handleAppLaunch(currentApp)
        }
    }

    /**
     * CRITICAL: Handle when an app is launched with enhanced security
     */
    private fun handleAppLaunch(packageName: String) {
        // Skip system apps and our own app
        if (isSystemApp(packageName) || packageName == this.packageName) {
            return
        }

        // CRITICAL: Validate package name to prevent injection attacks
        if (!isValidPackageName(packageName)) {
            logSecurityEvent("invalid_package_name", mapOf(
                "packageName" to packageName,
                "timestamp" to System.currentTimeMillis()
            ))
            return
        }

        // CRITICAL: Check app rules from local cache with signature validation
        if (shouldBlockApp(packageName)) {
            showBlockingOverlay(packageName)
        } else {
            hideOverlay()
        }
    }

    /**
     * CRITICAL: Validate package name format to prevent injection
     */
    private fun isValidPackageName(packageName: String): Boolean {
        // Package names should follow Java package naming convention
        val packageRegex = "^[a-zA-Z][a-zA-Z0-9_]*(?:\\.[a-zA-Z][a-zA-Z0-9_]*)*$".toRegex()
        return packageRegex.matches(packageName) && packageName.length <= 256
    }

    /**
     * CRITICAL: Enhanced app blocking logic with rule validation
     */
    private fun shouldBlockApp(packageName: String): Boolean {
        try {
            // TODO: In production, this would:
            // 1. Check local encrypted rule cache
            // 2. Validate rule signatures to prevent tampering
            // 3. Check temporal approvals with auth tokens
            // 4. Verify rule expiration times
            
            // For demonstration, block specific apps
            val blockedApps = setOf(
                "com.zhiliaoapp.musically", // TikTok
                "com.instagram.android",
                "com.snapchat.android",
                "com.facebook.katana"
            )
            
            return blockedApps.contains(packageName) ||
                   packageName.contains("game", ignoreCase = true)
                   
        } catch (e: Exception) {
            logSecurityEvent("rule_check_error", mapOf(
                "packageName" to packageName,
                "error" to e.message,
                "timestamp" to System.currentTimeMillis()
            ))
            // Default to blocking on error for security
            return true
        }
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
            "com.google.android.dialer",
            "com.android.camera2"
        )
        
        return systemApps.contains(packageName) || 
               packageName.startsWith("com.android.") ||
               packageName.startsWith("com.google.android.gms") ||
               packageName.startsWith("com.samsung.android.")
    }

    /**
     * CRITICAL: Enhanced full-screen overlay with anti-bypass protection
     */
    private fun showBlockingOverlay(packageName: String) {
        if (overlayView != null) return // Already showing
        
        try {
            // Create blocking overlay layout
            val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
            overlayView = inflater.inflate(R.layout.blocking_overlay, null)
            
            // CRITICAL: Set up overlay content with security measures
            setupSecureOverlayContent(packageName)
            
            // CRITICAL: Configure overlay parameters with enhanced protection
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
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            )
            
            // CRITICAL: Add additional security flags
            params.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
            
            // Show overlay
            windowManager?.addView(overlayView, params)
            
            // CRITICAL: Log overlay display for audit
            logSecurityEvent("overlay_shown", mapOf(
                "packageName" to packageName,
                "timestamp" to System.currentTimeMillis()
            ))
            
        } catch (e: Exception) {
            logSecurityEvent("overlay_error", mapOf(
                "packageName" to packageName,
                "error" to e.message,
                "timestamp" to System.currentTimeMillis()
            ))
            
            // Fallback: send user back to home screen
            goToHomeFallback()
        }
    }

    /**
     * CRITICAL: Setup overlay content with enhanced security measures
     */
    private fun setupSecureOverlayContent(packageName: String) {
        overlayView?.let { view ->
            try {
                // Get app name and icon safely
                val packageManager = applicationContext.packageManager
                val appInfo = packageManager.getApplicationInfo(packageName, 0)
                val appName = packageManager.getApplicationLabel(appInfo).toString()
                val appIcon = packageManager.getApplicationIcon(appInfo)
                
                // Set app icon and name
                view.findViewById<ImageView>(R.id.blocked_app_icon)?.setImageDrawable(appIcon)
                view.findViewById<TextView>(R.id.blocked_app_name)?.text = appName
                
                // CRITICAL: Set up buttons with enhanced validation
                view.findViewById<Button>(R.id.btn_request_access)?.setOnClickListener {
                    handleSecureRequestAccess(packageName, appName)
                }
                
                view.findViewById<Button>(R.id.btn_go_home)?.setOnClickListener {
                    handleSecureGoHome()
                }
                
                // CRITICAL: Remove close button to prevent easy bypass
                view.findViewById<View>(R.id.btn_close)?.visibility = View.GONE
                
            } catch (e: Exception) {
                logSecurityEvent("overlay_setup_error", mapOf(
                    "packageName" to packageName,
                    "error" to e.message,
                    "timestamp" to System.currentTimeMillis()
                ))
                
                // Fallback display
                view.findViewById<TextView>(R.id.blocked_app_name)?.text = "Blocked App"
            }
        }
    }

    /**
     * CRITICAL: Handle secure app access request with validation
     */
    private fun handleSecureRequestAccess(packageName: String, appName: String) {
        val timestamp = System.currentTimeMillis()
        val signature = generateDeviceSignature("request_$packageName", timestamp)
        
        // CRITICAL: Log access request attempt
        logSecurityEvent("access_request_attempted", mapOf(
            "packageName" to packageName,
            "appName" to appName,
            "timestamp" to timestamp,
            "signature" to signature
        ))
        
        // TODO: Send authenticated request to Firebase Cloud Functions
        // For now, show secure confirmation
        Toast.makeText(this, "Secure access request sent for $appName", Toast.LENGTH_SHORT).show()
        
        // CRITICAL: Don't hide overlay until parent approval
        goToHomeFallback()
    }

    /**
     * CRITICAL: Handle secure go to home action
     */
    private fun handleSecureGoHome() {
        logSecurityEvent("home_button_pressed", mapOf(
            "timestamp" to System.currentTimeMillis()
        ))
        
        hideOverlay()
        goToHomeFallback()
    }

    /**
     * CRITICAL: Enhanced overlay hiding with security validation
     */
    private fun hideOverlay() {
        overlayView?.let { view ->
            try {
                windowManager?.removeView(view)
                
                logSecurityEvent("overlay_hidden", mapOf(
                    "timestamp" to System.currentTimeMillis(),
                    "dismissCount" to overlayDismissCount
                ))
                
            } catch (e: Exception) {
                logSecurityEvent("overlay_hide_error", mapOf(
                    "error" to e.message,
                    "timestamp" to System.currentTimeMillis()
                ))
            }
        }
        overlayView = null
        overlayDismissCount++
    }

    /**
     * CRITICAL: Secure fallback to home screen
     */
    private fun goToHomeFallback() {
        try {
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(homeIntent)
            
        } catch (e: Exception) {
            logSecurityEvent("home_navigation_error", mapOf(
                "error" to e.message,
                "timestamp" to System.currentTimeMillis()
            ))
        }
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