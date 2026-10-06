package com.example.flutter_study_app.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.flutter_study_app.services.MonitoringService

/**
 * Boot receiver to restart monitoring service after device reboot.
 * 
 * This ensures continuous monitoring even after the device is restarted,
 * which is important for parental control functionality.
 */
class BootReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED -> {
                // Check if monitoring was previously enabled
                val sharedPrefs = context.getSharedPreferences("family_guardian_prefs", Context.MODE_PRIVATE)
                val monitoringEnabled = sharedPrefs.getBoolean("monitoring_enabled", false)
                
                if (monitoringEnabled) {
                    try {
                        // Restart monitoring service
                        MonitoringService.startService(context)
                        android.util.Log.i("BootReceiver", "Monitoring service restarted after boot")
                    } catch (e: Exception) {
                        android.util.Log.e("BootReceiver", "Failed to restart monitoring service", e)
                    }
                }
            }
        }
    }
}

/**
 * BOOT RECEIVER IMPLEMENTATION NOTES:
 * 
 * 1. ANDROID LIMITATIONS:
 *    - Boot receivers are heavily restricted in modern Android
 *    - Apps must be explicitly launched before boot receivers work
 *    - Some OEMs disable boot receivers for battery optimization
 * 
 * 2. USER DISCLOSURE:
 *    - This functionality is clearly documented as part of monitoring
 *    - Users are informed that monitoring continues after restart
 *    - Provides parental control continuity as expected
 * 
 * 3. ALTERNATIVE APPROACHES:
 *    - JobScheduler for deferred service restart
 *    - WorkManager for reliable background execution
 *    - Manual service restart when app is next opened
 * 
 * 4. BATTERY OPTIMIZATION:
 *    - Users may need to disable battery optimization
 *    - Some devices require manual whitelist addition
 *    - App guides users through these settings
 */