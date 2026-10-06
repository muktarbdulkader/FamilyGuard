package com.example.flutter_study_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * PackageChangeReceiver for Family Guardian
 * 
 * Detects app installation/removal events in real-time when possible.
 * 
 * IMPORTANT LIMITATIONS:
 * - Only works when app is running (foreground or background service)
 * - Not received when app is force-stopped or in deep sleep
 * - May be delayed or batched by Android system
 * - Should complement periodic scanning, not replace it
 */
class PackageChangeReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "FamilyGuardian.PackageReceiver"
        
        /**
         * Register receiver to listen for package changes
         */
        fun register(context: Context, receiver: PackageChangeReceiver): IntentFilter {
            val filter = IntentFilter().apply {
                // App installation events
                addAction(Intent.ACTION_PACKAGE_ADDED)
                addAction(Intent.ACTION_PACKAGE_REPLACED)
                addAction(Intent.ACTION_PACKAGE_INSTALL)
                
                // App removal events  
                addAction(Intent.ACTION_PACKAGE_REMOVED)
                addAction(Intent.ACTION_PACKAGE_FULLY_REMOVED)
                
                // App state changes
                addAction(Intent.ACTION_PACKAGE_CHANGED)
                addAction(Intent.ACTION_PACKAGE_ENABLED_STATE_CHANGED)
                
                // Required for package-related intents
                addDataScheme("package")
            }
            
            context.registerReceiver(receiver, filter)
            Log.i(TAG, "Package change receiver registered")
            return filter
        }
        
        /**
         * Unregister receiver
         */
        fun unregister(context: Context, receiver: PackageChangeReceiver) {
            try {
                context.unregisterReceiver(receiver)
                Log.i(TAG, "Package change receiver unregistered")
            } catch (e: Exception) {
                Log.w(TAG, "Error unregistering receiver", e)
            }
        }
    }
    
    private var methodChannel: MethodChannel? = null
    private var appDiscoveryHelper: AppDiscoveryHelper? = null
    
    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
    }
    
    fun setAppDiscoveryHelper(helper: AppDiscoveryHelper) {
        appDiscoveryHelper = helper
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val packageName = intent.data?.schemeSpecificPart ?: return
        
        // Skip our own package
        if (packageName == context.packageName) {
            return
        }
        
        Log.i(TAG, "Package change detected: $action for $packageName")
        
        try {
            handlePackageChange(context, action, packageName, intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error handling package change", e)
        }
    }
    
    /**
     * Handle specific package change event
     */
    private fun handlePackageChange(context: Context, action: String, packageName: String, intent: Intent) {
        val helper = appDiscoveryHelper ?: return
        
        when (action) {
            Intent.ACTION_PACKAGE_ADDED -> {
                val isReplacing = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)
                if (!isReplacing) {
                    handleAppInstalled(context, packageName)
                }
            }
            
            Intent.ACTION_PACKAGE_REPLACED -> {
                handleAppUpdated(context, packageName)
            }
            
            Intent.ACTION_PACKAGE_REMOVED -> {
                val isReplacing = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)
                if (!isReplacing) {
                    handleAppUninstalled(context, packageName)
                }
            }
            
            Intent.ACTION_PACKAGE_FULLY_REMOVED -> {
                handleAppUninstalled(context, packageName)
            }
            
            Intent.ACTION_PACKAGE_CHANGED,
            Intent.ACTION_PACKAGE_ENABLED_STATE_CHANGED -> {
                handleAppStateChanged(context, packageName)
            }
        }
    }
    
    /**
     * Handle app installation event
     */
    private fun handleAppInstalled(context: Context, packageName: String) {
        Log.i(TAG, "App installed: $packageName")
        
        val helper = appDiscoveryHelper ?: return
        val appDetails = helper.getAppDetails(packageName)
        
        if (appDetails != null) {
            // Notify Flutter about new app installation
            notifyFlutter("onAppInstalled", mapOf(
                "packageName" to packageName,
                "appDetails" to appDetails,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }
    
    /**
     * Handle app uninstallation event
     */
    private fun handleAppUninstalled(context: Context, packageName: String) {
        Log.i(TAG, "App uninstalled: $packageName")
        
        // Notify Flutter about app removal
        notifyFlutter("onAppUninstalled", mapOf(
            "packageName" to packageName,
            "timestamp" to System.currentTimeMillis()
        ))
    }
    
    /**
     * Handle app update event
     */
    private fun handleAppUpdated(context: Context, packageName: String) {
        Log.i(TAG, "App updated: $packageName")
        
        val helper = appDiscoveryHelper ?: return
        val appDetails = helper.getAppDetails(packageName)
        
        if (appDetails != null) {
            // Notify Flutter about app update
            notifyFlutter("onAppUpdated", mapOf(
                "packageName" to packageName,
                "appDetails" to appDetails,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }
    
    /**
     * Handle app state change (enabled/disabled)
     */
    private fun handleAppStateChanged(context: Context, packageName: String) {
        Log.i(TAG, "App state changed: $packageName")
        
        val helper = appDiscoveryHelper ?: return
        val appDetails = helper.getAppDetails(packageName)
        
        if (appDetails != null) {
            // Notify Flutter about app state change
            notifyFlutter("onAppStateChanged", mapOf(
                "packageName" to packageName,
                "appDetails" to appDetails,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }
    
    /**
     * Notify Flutter about package changes via method channel
     */
    private fun notifyFlutter(method: String, data: Map<String, Any>) {
        try {
            methodChannel?.invokeMethod(method, data)
        } catch (e: Exception) {
            Log.w(TAG, "Error notifying Flutter about $method", e)
        }
    }
}