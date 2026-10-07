package com.example.flutter_study_app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val PERMISSION_CHANNEL = "family_guardian/permissions"
    private val APP_SCANNER_CHANNEL = "family_guard/app_scanner"
    private val MONITORING_CHANNEL = "family_guard/monitoring"
    private val LOCATION_CHANNEL = "com.example.flutter_study_app/location"
    
    private lateinit var permissionHelper: PermissionHelper
    private lateinit var appScannerHelper: AppScannerHelper
    private lateinit var appDiscoveryHelper: AppDiscoveryHelper
    private lateinit var monitoringHelper: MonitoringHelper
    private lateinit var locationHelper: LocationHelper
    private var packageChangeReceiver: PackageChangeReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register the child monitoring plugin
        flutterEngine.plugins.add(ChildMonitoringPlugin())
        
        permissionHelper = PermissionHelper(this)
        appScannerHelper = AppScannerHelper(this)
        appDiscoveryHelper = AppDiscoveryHelper(this)
        monitoringHelper = MonitoringHelper(this)
        locationHelper = LocationHelper(this)
        
        // Permission method channel - enhanced with monitoring service methods
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Enhanced permission methods
                    "hasUsageStatsPermission" -> {
                        result.success(hasUsageStatsPermission())
                    }
                    "openUsageStatsSettings" -> {
                        openUsageStatsSettings()
                        result.success(null)
                    }
                    "hasOverlayPermission" -> {
                        result.success(hasOverlayPermission())
                    }
                    "openOverlaySettings" -> {
                        openOverlaySettings()
                        result.success(null)
                    }
                    "isBatteryOptimizationDisabled" -> {
                        result.success(isBatteryOptimizationDisabled())
                    }
                    "openBatteryOptimizationSettings" -> {
                        openBatteryOptimizationSettings()
                        result.success(null)
                    }
                    "startMonitoringService" -> {
                        val started = startMonitoringService()
                        result.success(started)
                    }
                    "stopMonitoringService" -> {
                        val stopped = stopMonitoringService()
                        result.success(stopped)
                    }
                    "isMonitoringServiceRunning" -> {
                        result.success(isMonitoringServiceRunning())
                    }
                    else -> {
                        // Delegate to original permission helper for other methods
                        permissionHelper.handleMethodCall(call.method, result)
                    }
                }
            }
        
        // App scanner method channel (existing)
        val appScannerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_SCANNER_CHANNEL)
        appScannerChannel.setMethodCallHandler { call, result ->
            // Delegate to app discovery helper for new functionality
            when (call.method) {
                "scanInstalledApps", "getAppIcon", "isAppInstalled" -> {
                    appDiscoveryHelper.handleMethodCall(call.method, call.arguments, result)
                }
                else -> {
                    // Fallback to existing app scanner helper
                    appScannerHelper.handleMethodCall(call.method, call.arguments, result)
                }
            }
        }
        appScannerHelper.setMethodChannel(appScannerChannel)
        appDiscoveryHelper.setMethodChannel(appScannerChannel)
        
        // Set up package change receiver for real-time detection
        setupPackageChangeReceiver(appScannerChannel)
        
        // Monitoring service method channel
        val monitoringChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MONITORING_CHANNEL)
        monitoringChannel.setMethodCallHandler { call, result ->
            monitoringHelper.handleMethodCall(call.method, call.arguments, result)
        }
        monitoringHelper.setMethodChannel(monitoringChannel)
        
        // Location method channel
        val locationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL)
        locationChannel.setMethodCallHandler { call, result ->
            locationHelper.handleMethodCall(call, result)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Unregister package change receiver
        packageChangeReceiver?.let { receiver ->
            PackageChangeReceiver.unregister(this, receiver)
            packageChangeReceiver = null
        }
    }
    
    /**
     * Set up package change receiver for real-time app detection
     */
    private fun setupPackageChangeReceiver(appScannerChannel: MethodChannel) {
        try {
            packageChangeReceiver = PackageChangeReceiver()
            packageChangeReceiver?.setMethodChannel(appScannerChannel)
            packageChangeReceiver?.setAppDiscoveryHelper(appDiscoveryHelper)
            PackageChangeReceiver.register(this, packageChangeReceiver!!)
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "Failed to set up package change receiver", e)
        }
    }
    
    /**
     * Check if Usage Access permission is granted
     * Uses AppOpsManager to check USAGE_STATS permission
     */
    private fun hasUsageStatsPermission(): Boolean {
        return try {
            val appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOpsManager.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOpsManager.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Open Usage Access settings page
     * NOTE: This is NOT a runtime permission - user must manually enable
     */
    private fun openUsageStatsSettings() {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback to app settings if usage access settings not available
            openAppSettings()
        }
    }
    
    /**
     * Check if System Alert Window (overlay) permission is granted
     */
    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            // Permission granted by default on older versions
            true
        }
    }
    
    /**
     * Open System Alert Window (overlay) settings page
     * NOTE: This is NOT a runtime permission - user must manually enable
     */
    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivity(intent)
            } catch (e: Exception) {
                // Fallback to app settings
                openAppSettings()
            }
        }
    }
    
    /**
     * Check if battery optimization is disabled for this app
     */
    private fun isBatteryOptimizationDisabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            // Not applicable on older versions
            true
        }
    }
    
    /**
     * Open battery optimization settings for this app
     */
    private fun openBatteryOptimizationSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            } catch (e: Exception) {
                // Fallback to battery optimization settings page
                try {
                    val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    startActivity(intent)
                } catch (e2: Exception) {
                    openAppSettings()
                }
            }
        }
    }
    
    /**
     * Start the monitoring foreground service
     */
    private fun startMonitoringService(): Boolean {
        return try {
            MonitoringForegroundService.startService(this)
            // Save monitoring state
            val sharedPrefs = getSharedPreferences("family_guardian_prefs", Context.MODE_PRIVATE)
            sharedPrefs.edit().putBoolean("monitoring_enabled", true).apply()
            true
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Stop the monitoring foreground service
     */
    private fun stopMonitoringService(): Boolean {
        return try {
            MonitoringForegroundService.stopService(this)
            // Save monitoring state
            val sharedPrefs = getSharedPreferences("family_guardian_prefs", Context.MODE_PRIVATE)
            sharedPrefs.edit().putBoolean("monitoring_enabled", false).apply()
            true
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Check if monitoring service is currently running
     */
    private fun isMonitoringServiceRunning(): Boolean {
        // This is a simplified check - in production you might want to use ActivityManager
        val sharedPrefs = getSharedPreferences("family_guardian_prefs", Context.MODE_PRIVATE)
        return sharedPrefs.getBoolean("monitoring_enabled", false)
    }
    
    /**
     * Open app settings page as fallback
     */
    private fun openAppSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        } catch (e: Exception) {
            // Last fallback - general settings
            val intent = Intent(Settings.ACTION_SETTINGS)
            startActivity(intent)
        }
    }
}
