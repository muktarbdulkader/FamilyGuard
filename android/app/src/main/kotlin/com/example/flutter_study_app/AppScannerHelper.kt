package com.example.flutter_study_app

import android.app.Activity
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.*

/**
 * Real Android app scanner using PackageManager and UsageStatsManager APIs
 * This provides ACTUAL app information from the device, not fake/simulated data
 */
class AppScannerHelper(private val activity: Activity) {

    private var appInstallationReceiver: BroadcastReceiver? = null
    private var methodChannel: MethodChannel? = null

    /**
     * Scan all installed user applications using PackageManager
     * Returns real app data from Android system
     */
    fun scanInstalledApps(): List<Map<String, Any?>> {
        val packageManager = activity.packageManager
        val installedApps = mutableListOf<Map<String, Any?>>()

        try {
            // Get all installed packages
            val packages = packageManager.getInstalledPackages(PackageManager.GET_META_DATA)

            for (packageInfo in packages) {
                try {
                    val appInfo = packageInfo.applicationInfo ?: continue
                    
                    // Skip system apps unless they're user-facing
                    if (isSystemApp(appInfo) && !isUserFacingSystemApp(appInfo, packageManager)) {
                        continue
                    }

                    // Get app icon as byte array
                    val iconBytes = try {
                        val icon = packageManager.getApplicationIcon(appInfo)
                        drawableToByteArray(icon)
                    } catch (e: Exception) {
                        null
                    }

                    val appData: Map<String, Any?> = mapOf(
                        "packageName" to appInfo.packageName,
                        "appName" to packageManager.getApplicationLabel(appInfo).toString(),
                        "iconBytes" to iconBytes,
                        "version" to (packageInfo.versionName ?: "Unknown"),
                        "installTime" to packageInfo.firstInstallTime,
                        "lastUpdateTime" to packageInfo.lastUpdateTime,
                        "isSystemApp" to isSystemApp(appInfo)
                    )

                    installedApps.add(appData)
                } catch (e: Exception) {
                    // Skip apps that can't be processed
                    continue
                }
            }
        } catch (e: Exception) {
            throw Exception("Failed to scan installed apps: ${e.message}")
        }

        return installedApps
    }

    /**
     * Get system package names that should not be managed by parental controls
     */
    fun getSystemPackages(): List<String> {
        val packageManager = activity.packageManager
        val systemPackages = mutableListOf<String>()

        try {
            val packages = packageManager.getInstalledPackages(0)
            
            for (packageInfo in packages) {
                val appInfo = packageInfo.applicationInfo ?: continue
                
                // Add critical system packages that should never be blocked
                if (isSystemApp(appInfo) && isCriticalSystemApp(appInfo)) {
                    systemPackages.add(appInfo.packageName)
                }
            }
        } catch (e: Exception) {
            // Return fallback list of critical system packages
            return listOf(
                "android",
                "com.android.systemui",
                "com.android.settings",
                "com.android.launcher",
                "com.android.launcher3",
                "com.android.phone",
                "com.android.dialer",
                "com.google.android.dialer"
            )
        }

        return systemPackages
    }

    /**
     * Get app usage statistics using UsageStatsManager
     * Returns REAL usage data from Android system
     */
    fun getAppUsageStats(startTime: Long, endTime: Long): Map<String, Long> {
        val usageStatsManager = activity.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val usageStats = mutableMapOf<String, Long>()

        try {
            // Get usage stats for the specified time period
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                startTime,
                endTime
            )

            // Aggregate usage time by package name
            for (usageStat in stats) {
                val packageName = usageStat.packageName
                val totalTimeInForeground = usageStat.totalTimeInForeground

                usageStats[packageName] = (usageStats[packageName] ?: 0) + totalTimeInForeground
            }
        } catch (e: Exception) {
            throw Exception("Failed to get app usage stats: ${e.message}")
        }

        return usageStats
    }

    /**
     * Start monitoring for app installations and removals
     */
    fun startAppInstallationMonitoring(familyId: String, childId: String) {
        try {
            // Register broadcast receiver for package events
            appInstallationReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    when (intent?.action) {
                        Intent.ACTION_PACKAGE_ADDED -> {
                            val packageName = intent.dataString?.removePrefix("package:")
                            if (packageName != null) {
                                notifyAppInstalled(packageName, familyId, childId)
                            }
                        }
                        Intent.ACTION_PACKAGE_REMOVED -> {
                            val packageName = intent.dataString?.removePrefix("package:")
                            if (packageName != null) {
                                notifyAppRemoved(packageName, familyId, childId)
                            }
                        }
                    }
                }
            }

            val intentFilter = IntentFilter().apply {
                addAction(Intent.ACTION_PACKAGE_ADDED)
                addAction(Intent.ACTION_PACKAGE_REMOVED)
                addDataScheme("package")
            }

            activity.registerReceiver(appInstallationReceiver, intentFilter)
        } catch (e: Exception) {
            throw Exception("Failed to start app installation monitoring: ${e.message}")
        }
    }

    /**
     * Stop monitoring for app installations
     */
    fun stopAppInstallationMonitoring() {
        try {
            appInstallationReceiver?.let {
                activity.unregisterReceiver(it)
                appInstallationReceiver = null
            }
        } catch (e: Exception) {
            // Ignore errors when stopping monitoring
        }
    }

    /**
     * Set method channel for communicating app installation events back to Flutter
     */
    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
    }

    /**
     * Check if an app is a system app
     */
    private fun isSystemApp(appInfo: ApplicationInfo): Boolean {
        return (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
    }

    /**
     * Check if system app should be shown to users (like Calculator, Camera, etc.)
     */
    private fun isUserFacingSystemApp(appInfo: ApplicationInfo, packageManager: PackageManager): Boolean {
        // Check if app has a launcher intent (user can launch it)
        val launchIntent = packageManager.getLaunchIntentForPackage(appInfo.packageName)
        return launchIntent != null
    }

    /**
     * Check if system app is critical and should never be blocked
     */
    private fun isCriticalSystemApp(appInfo: ApplicationInfo): Boolean {
        val criticalPackages = setOf(
            "android",
            "com.android.systemui",
            "com.android.settings",
            "com.android.launcher",
            "com.android.launcher3",
            "com.android.phone",
            "com.android.dialer"
        )
        
        return criticalPackages.contains(appInfo.packageName) ||
               appInfo.packageName.startsWith("com.android.") ||
               appInfo.packageName.startsWith("com.google.android.gms")
    }

    /**
     * Convert drawable to byte array for sending to Flutter
     */
    private fun drawableToByteArray(drawable: Drawable): ByteArray? {
        try {
            val bitmap = when (drawable) {
                is BitmapDrawable -> drawable.bitmap
                else -> {
                    val bitmap = Bitmap.createBitmap(
                        drawable.intrinsicWidth,
                        drawable.intrinsicHeight,
                        Bitmap.Config.ARGB_8888
                    )
                    val canvas = Canvas(bitmap)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                    bitmap
                }
            }

            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            return outputStream.toByteArray()
        } catch (e: Exception) {
            return null
        }
    }

    /**
     * Notify Flutter about newly installed app
     */
    private fun notifyAppInstalled(packageName: String, familyId: String, childId: String) {
        methodChannel?.invokeMethod("onAppInstalled", mapOf(
            "packageName" to packageName,
            "familyId" to familyId,
            "childId" to childId
        ))
    }

    /**
     * Notify Flutter about removed app
     */
    private fun notifyAppRemoved(packageName: String, familyId: String, childId: String) {
        methodChannel?.invokeMethod("onAppRemoved", mapOf(
            "packageName" to packageName,
            "familyId" to familyId,
            "childId" to childId
        ))
    }

    /**
     * Handle method channel calls from Flutter
     */
    fun handleMethodCall(call: String, arguments: Any?, result: MethodChannel.Result) {
        try {
            when (call) {
                "scanInstalledApps" -> {
                    result.success(scanInstalledApps())
                }
                "getSystemPackages" -> {
                    result.success(getSystemPackages())
                }
                "getAppUsageStats" -> {
                    val args = arguments as Map<String, Any>
                    val startTime = args["startTime"] as Long
                    val endTime = args["endTime"] as Long
                    result.success(getAppUsageStats(startTime, endTime))
                }
                "startAppInstallationMonitoring" -> {
                    val args = arguments as Map<String, Any>
                    val familyId = args["familyId"] as String
                    val childId = args["childId"] as String
                    startAppInstallationMonitoring(familyId, childId)
                    result.success(null)
                }
                "stopAppInstallationMonitoring" -> {
                    stopAppInstallationMonitoring()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            result.error("APP_SCANNER_ERROR", e.message, null)
        }
    }
}