package com.example.flutter_study_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Monitoring Foreground Service for Family Guardian
 * 
 * This service provides transparent monitoring notification as required for parental control apps.
 * The notification clearly states that "FamilyGuard parental controls are active" and cannot be hidden.
 * 
 * IMPORTANT: This service does NOT hide its existence - it's designed for transparency.
 * Users will always see the monitoring notification while parental controls are active.
 * 
 * Android Version Support:
 * - Android 8.0+ (API 26+): Uses foreground service with required notification
 * - Android 14+ (API 34+): Uses special use foreground service for parental controls
 */
class MonitoringForegroundService : Service() {

    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "family_guardian_monitoring"
        private const val CHANNEL_NAME = "Family Guardian Monitoring"
        
        /**
         * Start the monitoring service
         */
        fun startService(context: Context) {
            val serviceIntent = Intent(context, MonitoringForegroundService::class.java)
            ContextCompat.startForegroundService(context, serviceIntent)
        }
        
        /**
         * Stop the monitoring service
         */
        fun stopService(context: Context) {
            val serviceIntent = Intent(context, MonitoringForegroundService::class.java)
            context.stopService(serviceIntent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        // This service doesn't support binding
        return null
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Create and show the monitoring notification
        val notification = createMonitoringNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // Return START_STICKY to restart service if killed by system
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        // Service is being destroyed - monitoring stopped
        stopForeground(true)
    }

    /**
     * Create notification channel for monitoring notifications
     * Required for Android 8.0+ (API 26+)
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW // Low importance = no sound/vibration
            ).apply {
                description = "Shows when Family Guardian parental controls are active"
                setShowBadge(false) // Don't show badge on app icon
                enableVibration(false) // No vibration for monitoring notification
                enableLights(false) // No LED light
                setSound(null, null) // No sound
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Create the persistent monitoring notification
     * 
     * This notification:
     * - Clearly states that monitoring is active
     * - Cannot be dismissed by the user
     * - Provides transparency about parental control status
     * - Complies with Google Play policies for parental control apps
     */
    private fun createMonitoringNotification(): Notification {
        // Intent to open main app when notification is tapped
        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or 
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        // Build the notification
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Family Guardian Active")
            .setContentText("Parental controls are monitoring this device")
            .setSmallIcon(R.drawable.ic_notification) // Will create this icon
            .setContentIntent(pendingIntent)
            .setOngoing(true) // Cannot be dismissed by user
            .setAutoCancel(false) // Cannot be auto-cancelled
            .setShowWhen(false) // Don't show time
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW) // Low priority = no sound/popup
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC) // Visible on lock screen
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            // Add action to view monitoring status
            .addAction(
                R.drawable.ic_info,
                "View Status",
                createStatusPendingIntent()
            )
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("Family Guardian parental controls are actively monitoring this device. Tap to view detailed status or adjust settings.")
            )
            .build()
    }

    /**
     * Create pending intent for viewing monitoring status
     */
    private fun createStatusPendingIntent(): PendingIntent {
        val statusIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            // Add extra to navigate to monitoring status screen
            putExtra("navigate_to", "monitoring_status")
        }
        
        return PendingIntent.getActivity(
            this,
            1,
            statusIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or 
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )
    }
}