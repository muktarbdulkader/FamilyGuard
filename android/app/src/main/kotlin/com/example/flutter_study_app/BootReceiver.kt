package com.example.flutter_study_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Boot Receiver for Family Guardian
 * 
 * This receiver automatically restarts the monitoring service after:
 * - Device reboot (BOOT_COMPLETED)
 * - App update (MY_PACKAGE_REPLACED, PACKAGE_REPLACED)
 * 
 * This ensures parental controls remain active even after device restart,
 * which is essential for continuous monitoring and child safety.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "FamilyGuardian.BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.i(TAG, "Device boot completed - restarting monitoring service")
                startMonitoringService(context, "Boot completed")
            }
            
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.i(TAG, "App updated - restarting monitoring service") 
                startMonitoringService(context, "App updated")
            }
            
            Intent.ACTION_PACKAGE_REPLACED -> {
                // Only restart if it's our package that was replaced
                val packageName = intent.data?.schemeSpecificPart
                if (packageName == context.packageName) {
                    Log.i(TAG, "Our package was replaced - restarting monitoring service")
                    startMonitoringService(context, "Package replaced")
                }
            }
        }
    }

    /**
     * Start the monitoring service if conditions are met
     */
    private fun startMonitoringService(context: Context, reason: String) {
        try {
            // Check if monitoring should be active
            if (shouldStartMonitoring(context)) {
                Log.i(TAG, "Starting monitoring service: $reason")
                MonitoringForegroundService.startService(context)
            } else {
                Log.i(TAG, "Monitoring service not started: conditions not met")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start monitoring service after $reason", e)
        }
    }

    /**
     * Check if monitoring service should be started
     * 
     * Only start monitoring if:
     * 1. User has granted necessary permissions
     * 2. User is logged in as a child user
     * 3. Parental controls are enabled
     */
    private fun shouldStartMonitoring(context: Context): Boolean {
        val sharedPrefs = context.getSharedPreferences("family_guardian_prefs", Context.MODE_PRIVATE)
        
        // Check if user is logged in
        val isLoggedIn = sharedPrefs.getBoolean("is_logged_in", false)
        if (!isLoggedIn) {
            Log.d(TAG, "User not logged in - monitoring not started")
            return false
        }
        
        // Check if user role is child
        val userRole = sharedPrefs.getString("user_role", "none")
        if (userRole != "child") {
            Log.d(TAG, "User is not child role ($userRole) - monitoring not started")
            return false
        }
        
        // Check if monitoring is enabled
        val monitoringEnabled = sharedPrefs.getBoolean("monitoring_enabled", false)
        if (!monitoringEnabled) {
            Log.d(TAG, "Monitoring is disabled - service not started")
            return false
        }
        
        Log.d(TAG, "All conditions met - monitoring service can start")
        return true
    }
}