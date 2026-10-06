package com.example.flutter_study_app

import android.app.Activity
import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodChannel

class PermissionHelper(private val activity: Activity) {
    
    companion object {
        const val NOTIFICATION_CHANNEL_ID = "monitoring_channel"
        const val MONITORING_NOTIFICATION_ID = 1001
    }

    /**
     * Check if Usage Access permission is granted
     */
    fun hasUsageStatsPermission(): Boolean {
        val appOps = activity.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                activity.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                activity.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Open Usage Access settings page
     */
    fun openUsageStatsSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        activity.startActivity(intent)
    }

    /**
     * Check if Display Over Other Apps permission is granted
     */
    fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(activity)
        } else {
            true // Permission not required on older versions
        }
    }

    /**
     * Open Display Over Other Apps settings page
     */
    fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}")
            )
            activity.startActivity(intent)
        }
    }

    /**
     * Check if Accessibility Service is enabled
     * Note: This is a placeholder - actual implementation would require
     * creating an AccessibilityService and checking if it's enabled
     */
    fun hasAccessibilityPermission(): Boolean {
        // For now, return false as accessibility service implementation
        // would be part of the native blocking system in Prompt 7
        return false
    }

    /**
     * Open Accessibility Service settings page
     */
    fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        activity.startActivity(intent)
    }

    /**
     * Check if device admin permission is granted
     */
    fun hasDeviceAdminPermission(): Boolean {
        // Device admin is typically not needed for parental controls
        // This is here for completeness but may not be used
        return false
    }

    /**
     * Request device admin permission
     */
    fun requestDeviceAdminPermission() {
        // Implementation would depend on specific device admin requirements
        // Not typically needed for parental control apps
    }

    /**
     * Check if battery optimization is disabled for this app
     */
    fun isBatteryOptimizationDisabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(activity.packageName)
        } else {
            true // Not applicable on older versions
        }
    }

    /**
     * Open battery optimization settings
     */
    fun openBatteryOptimizationSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent()
            intent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
            intent.data = Uri.parse("package:${activity.packageName}")
            activity.startActivity(intent)
        }
    }

    /**
     * Create persistent notification showing monitoring is active
     */
    fun createMonitoringNotification() {
        createNotificationChannel()
        
        val notification = NotificationCompat.Builder(activity, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Parental Controls Active")
            .setContentText("Family Guardian is monitoring this device for your safety")
            .setSmallIcon(android.R.drawable.ic_menu_view) // Use built-in icon for now
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true) // Make it persistent
            .setAutoCancel(false)
            .build()

        val notificationManager = NotificationManagerCompat.from(activity)
        try {
            notificationManager.notify(MONITORING_NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            // Handle case where notification permission is not granted
            throw Exception("Notification permission required")
        }
    }

    /**
     * Remove monitoring notification
     */
    fun removeMonitoringNotification() {
        val notificationManager = NotificationManagerCompat.from(activity)
        notificationManager.cancel(MONITORING_NOTIFICATION_ID)
    }

    /**
     * Create notification channel for monitoring notifications
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Monitoring Status",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when parental controls are active"
                setShowBadge(false)
            }

            val notificationManager = activity.getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }

    /**
     * Handle method channel calls from Flutter
     */
    fun handleMethodCall(call: String, result: MethodChannel.Result) {
        try {
            when (call) {
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
                "hasAccessibilityPermission" -> {
                    result.success(hasAccessibilityPermission())
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                "hasDeviceAdminPermission" -> {
                    result.success(hasDeviceAdminPermission())
                }
                "requestDeviceAdminPermission" -> {
                    requestDeviceAdminPermission()
                    result.success(null)
                }
                "isBatteryOptimizationDisabled" -> {
                    result.success(isBatteryOptimizationDisabled())
                }
                "openBatteryOptimizationSettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(null)
                }
                "createMonitoringNotification" -> {
                    createMonitoringNotification()
                    result.success(null)
                }
                "removeMonitoringNotification" -> {
                    removeMonitoringNotification()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }
}