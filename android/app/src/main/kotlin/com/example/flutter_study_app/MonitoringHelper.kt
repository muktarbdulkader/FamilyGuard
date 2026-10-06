package com.example.flutter_study_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.MethodChannel

/**
 * Helper class to bridge Flutter and native Android monitoring service
 * Handles method channel calls for monitoring service control
 */
class MonitoringHelper(private val activity: Activity) {
    
    private var methodChannel: MethodChannel? = null

    /**
     * Set method channel for communication back to Flutter
     */
    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
    }

    /**
     * Handle method channel calls from Flutter
     */
    fun handleMethodCall(call: String, arguments: Any?, result: MethodChannel.Result) {
        try {
            when (call) {
                "startMonitoring" -> {
                    val args = arguments as Map<String, Any>
                    val familyId = args["familyId"] as String
                    val childId = args["childId"] as String
                    startMonitoringService(familyId, childId)
                    result.success(null)
                }
                "stopMonitoring" -> {
                    stopMonitoringService()
                    result.success(null)
                }
                "isMonitoringActive" -> {
                    result.success(isServiceRunning())
                }
                "getMonitoringStatus" -> {
                    result.success(getMonitoringStatus())
                }
                "updateRules" -> {
                    val args = arguments as Map<String, Any>
                    val rules = args["rules"] as List<Map<String, Any>>
                    updateRules(rules)
                    result.success(null)
                }
                "setChildDeviceFlag" -> {
                    val args = arguments as Map<String, Any>
                    val isChild = args["isChild"] as Boolean
                    setChildDeviceFlag(isChild)
                    result.success(null)
                }
                "setPermissionsFlag" -> {
                    val args = arguments as Map<String, Any>
                    val hasPermissions = args["hasPermissions"] as Boolean
                    setPermissionsFlag(hasPermissions)
                    result.success(null)
                }
                "createMonitoringNotification" -> {
                    createMonitoringNotification()
                    result.success(null)
                }
                "updateMonitoringNotification" -> {
                    val args = arguments as Map<String, Any>
                    val message = args["message"] as String
                    updateMonitoringNotification(message)
                    result.success(null)
                }
                "isAppBlocked" -> {
                    val args = arguments as Map<String, Any>
                    val packageName = args["packageName"] as String
                    result.success(isAppBlocked(packageName))
                }
                "getCurrentForegroundApp" -> {
                    result.success(getCurrentForegroundApp())
                }
                "getUsageStats" -> {
                    result.success(getUsageStats())
                }
                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            result.error("MONITORING_ERROR", e.message, null)
        }
    }

    /**
     * Start the monitoring service
     */
    private fun startMonitoringService(familyId: String, childId: String) {
        val serviceIntent = Intent(activity, MonitoringService::class.java).apply {
            putExtra("familyId", familyId)
            putExtra("childId", childId)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.startForegroundService(serviceIntent)
        } else {
            activity.startService(serviceIntent)
        }
    }

    /**
     * Stop the monitoring service
     */
    private fun stopMonitoringService() {
        val serviceIntent = Intent(activity, MonitoringService::class.java)
        activity.stopService(serviceIntent)
    }

    /**
     * Check if monitoring service is running
     */
    private fun isServiceRunning(): Boolean {
        // Simple check - in production you'd check ActivityManager
        return true // Placeholder
    }

    /**
     * Get monitoring service status
     */
    private fun getMonitoringStatus(): Map<String, Any> {
        return mapOf(
            "isActive" to isServiceRunning(),
            "lastCheck" to System.currentTimeMillis(),
            "blockedCount" to 0 // Placeholder
        )
    }

    /**
     * Update app rules in the service
     */
    private fun updateRules(rules: List<Map<String, Any>>) {
        // TODO: Send rules to monitoring service
        // For now, just log the update
        println("Updating ${rules.size} app rules")
    }

    /**
     * Set child device flag in shared preferences
     */
    private fun setChildDeviceFlag(isChild: Boolean) {
        val sharedPrefs = activity.getSharedPreferences("family_guardian", Context.MODE_PRIVATE)
        sharedPrefs.edit().putBoolean("is_child_device", isChild).apply()
    }

    /**
     * Set permissions flag in shared preferences
     */
    private fun setPermissionsFlag(hasPermissions: Boolean) {
        val sharedPrefs = activity.getSharedPreferences("family_guardian", Context.MODE_PRIVATE)
        sharedPrefs.edit().putBoolean("has_monitoring_permissions", hasPermissions).apply()
    }

    /**
     * Create monitoring notification
     */
    private fun createMonitoringNotification() {
        // Monitoring notification is created by the service itself
        // This is just a trigger
    }

    /**
     * Update monitoring notification message
     */
    private fun updateMonitoringNotification(message: String) {
        // TODO: Update notification message
    }

    /**
     * Check if specific app is blocked
     */
    private fun isAppBlocked(packageName: String): Boolean {
        // TODO: Check against cached rules
        return false // Placeholder
    }

    /**
     * Get current foreground app
     */
    private fun getCurrentForegroundApp(): String? {
        // TODO: Get from monitoring service
        return null // Placeholder
    }

    /**
     * Get app usage statistics
     */
    private fun getUsageStats(): Map<String, Long> {
        // TODO: Get from monitoring service
        return emptyMap() // Placeholder
    }
}