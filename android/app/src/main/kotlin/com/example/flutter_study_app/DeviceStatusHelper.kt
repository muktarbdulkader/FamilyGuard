package com.example.flutter_study_app

import android.content.Context
import android.content.pm.PackageManager
import android.provider.Settings
import android.app.usage.UsageStatsManager
import android.os.Build
import android.content.Intent
import kotlinx.coroutines.*
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.auth.FirebaseAuth
import java.util.*

class DeviceStatusHelper(private val context: Context) {
    private val functions = FirebaseFunctions.getInstance()
    private val auth = FirebaseAuth.getInstance()
    private var statusMonitorJob: Job? = null
    
    companion object {
        private const val PERMISSION_CHECK_INTERVAL = 30_000L // 30 seconds
        private const val DEVICE_STATUS_CHECK_INTERVAL = 60_000L // 1 minute
        
        // Permission types
        const val PERMISSION_USAGE_STATS = "Usage Stats Access"
        const val PERMISSION_DISPLAY_OVERLAY = "Display Over Apps"
        const val PERMISSION_LOCATION = "Location Access"
        const val PERMISSION_NOTIFICATIONS = "Notification Access"
    }
    
    fun startStatusMonitoring(familyId: String, childId: String) {
        statusMonitorJob?.cancel()
        
        statusMonitorJob = CoroutineScope(Dispatchers.IO).launch {
            var lastPermissionStatus = getCurrentPermissionStatus()
            var lastDeviceOnlineStatus = true // Assume online initially
            
            while (isActive) {
                try {
                    // Check permission status
                    val currentPermissionStatus = getCurrentPermissionStatus()
                    checkForPermissionChanges(
                        lastPermissionStatus,
                        currentPermissionStatus,
                        familyId,
                        childId
                    )
                    lastPermissionStatus = currentPermissionStatus
                    
                    // Check service status
                    checkServiceStatus(familyId, childId)
                    
                    // Simulate device online status (in real implementation, you'd check connectivity)
                    val currentOnlineStatus = isDeviceOnline()
                    if (currentOnlineStatus != lastDeviceOnlineStatus) {
                        sendDeviceStatusNotification(familyId, childId, currentOnlineStatus)
                        lastDeviceOnlineStatus = currentOnlineStatus
                    }
                    
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                
                delay(PERMISSION_CHECK_INTERVAL)
            }
        }
    }
    
    fun stopStatusMonitoring() {
        statusMonitorJob?.cancel()
    }
    
    private fun getCurrentPermissionStatus(): Map<String, Boolean> {
        return mapOf(
            PERMISSION_USAGE_STATS to hasUsageStatsPermission(),
            PERMISSION_DISPLAY_OVERLAY to hasDisplayOverlayPermission(),
            PERMISSION_LOCATION to hasLocationPermission(),
            PERMISSION_NOTIFICATIONS to hasNotificationPermission()
        )
    }
    
    private fun hasUsageStatsPermission(): Boolean {
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            time - 1000 * 60,
            time
        )
        return stats != null && stats.isNotEmpty()
    }
    
    private fun hasDisplayOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }
    
    private fun hasLocationPermission(): Boolean {
        return context.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) == 
               PackageManager.PERMISSION_GRANTED ||
               context.checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) == 
               PackageManager.PERMISSION_GRANTED
    }
    
    private fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == 
            PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }
    
    private fun checkForPermissionChanges(
        oldStatus: Map<String, Boolean>,
        newStatus: Map<String, Boolean>,
        familyId: String,
        childId: String
    ) {
        for ((permission, isGranted) in newStatus) {
            val wasGranted = oldStatus[permission] ?: false
            
            // Permission was disabled
            if (wasGranted && !isGranted) {
                sendPermissionDisabledNotification(familyId, childId, permission)
            }
        }
    }
    
    private fun checkServiceStatus(familyId: String, childId: String) {
        // Check if monitoring service is running
        val isServiceRunning = MonitoringHelper.isServiceRunning(context)
        
        if (!isServiceRunning) {
            sendServiceUnavailableNotification(familyId, childId, "Monitoring Service")
        }
    }
    
    private fun isDeviceOnline(): Boolean {
        // In a real implementation, you'd check network connectivity
        // For now, we'll always return true (device is online)
        // You could integrate with ConnectivityManager or network monitoring
        return true
    }
    
    private fun sendDeviceStatusNotification(familyId: String, childId: String, isOnline: Boolean) {
        val user = auth.currentUser ?: return
        
        val data = hashMapOf(
            "familyId" to familyId,
            "childId" to childId,
            "isOnline" to isOnline
        )
        
        functions
            .getHttpsCallable("sendDeviceStatusNotification")
            .call(data)
            .addOnSuccessListener { result ->
                println("Device status notification sent: $isOnline")
            }
            .addOnFailureListener { exception ->
                println("Failed to send device status notification: ${exception.message}")
            }
    }
    
    private fun sendPermissionDisabledNotification(
        familyId: String,
        childId: String,
        permission: String
    ) {
        val user = auth.currentUser ?: return
        
        val data = hashMapOf(
            "familyId" to familyId,
            "childId" to childId,
            "type" to "permission_disabled",
            "details" to permission
        )
        
        functions
            .getHttpsCallable("sendSystemStatusNotification")
            .call(data)
            .addOnSuccessListener { result ->
                println("Permission disabled notification sent: $permission")
            }
            .addOnFailureListener { exception ->
                println("Failed to send permission notification: ${exception.message}")
            }
    }
    
    private fun sendServiceUnavailableNotification(
        familyId: String,
        childId: String,
        service: String
    ) {
        val user = auth.currentUser ?: return
        
        val data = hashMapOf(
            "familyId" to familyId,
            "childId" to childId,
            "type" to "service_unavailable",
            "details" to service
        )
        
        functions
            .getHttpsCallable("sendSystemStatusNotification")
            .call(data)
            .addOnSuccessListener { result ->
                println("Service unavailable notification sent: $service")
            }
            .addOnFailureListener { exception ->
                println("Failed to send service notification: ${exception.message}")
            }
    }
    
    fun checkPermissionsManually(familyId: String, childId: String) {
        CoroutineScope(Dispatchers.IO).launch {
            val permissionStatus = getCurrentPermissionStatus()
            
            for ((permission, isGranted) in permissionStatus) {
                if (!isGranted) {
                    sendPermissionDisabledNotification(familyId, childId, permission)
                }
            }
        }
    }
}