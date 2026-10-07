package com.example.flutter_study_app

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodResult
import io.flutter.plugin.common.MethodChannel

class LocationHelper(private val context: Context) {
    companion object {
        const val CHANNEL = "com.example.flutter_study_app/location"
        
        // Permission request codes
        const val LOCATION_PERMISSION_REQUEST_CODE = 1001
        const val BACKGROUND_LOCATION_PERMISSION_REQUEST_CODE = 1002
        
        // Permission types
        const val FINE_LOCATION = Manifest.permission.ACCESS_FINE_LOCATION
        const val COARSE_LOCATION = Manifest.permission.ACCESS_COARSE_LOCATION
        const val BACKGROUND_LOCATION = Manifest.permission.ACCESS_BACKGROUND_LOCATION
    }
    
    fun handleMethodCall(call: MethodCall, result: MethodResult) {
        when (call.method) {
            "checkLocationPermission" -> checkLocationPermission(result)
            "requestLocationPermission" -> requestLocationPermission(result)
            "checkLocationServices" -> checkLocationServices(result)
            "openLocationSettings" -> openLocationSettings(result)
            "checkBatteryOptimization" -> checkBatteryOptimization(result)
            "requestBatteryOptimizationExemption" -> requestBatteryOptimizationExemption(result)
            else -> result.notImplemented()
        }
    }
    
    private fun checkLocationPermission(result: MethodResult) {
        try {
            val hasCoarse = ContextCompat.checkSelfPermission(
                context, 
                COARSE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            
            val hasFine = ContextCompat.checkSelfPermission(
                context, 
                FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            
            val hasBackground = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ContextCompat.checkSelfPermission(
                    context, 
                    BACKGROUND_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
            } else {
                hasFine || hasCoarse // Background allowed if foreground is granted on older versions
            }
            
            val status = when {
                !hasFine && !hasCoarse -> "denied"
                (hasFine || hasCoarse) && !hasBackground -> "foregroundOnly"
                hasBackground -> "backgroundAllowed"
                else -> "denied"
            }
            
            val permissionInfo = mapOf(
                "status" to status,
                "isPrecise" to hasFine,
                "hasCoarse" to hasCoarse,
                "hasFine" to hasFine,
                "hasBackground" to hasBackground,
                "canShareLocation" to (hasFine || hasCoarse),
                "canShareInBackground" to hasBackground
            )
            
            result.success(permissionInfo)
            
        } catch (e: Exception) {
            result.error("PERMISSION_CHECK_ERROR", "Error checking location permission", e.message)
        }
    }
    
    private fun requestLocationPermission(result: MethodResult) {
        if (context !is Activity) {
            result.error("CONTEXT_ERROR", "Context is not an Activity", null)
            return
        }
        
        try {
            val permissions = mutableListOf<String>()
            
            // Always request fine location for better accuracy
            permissions.add(FINE_LOCATION)
            permissions.add(COARSE_LOCATION)
            
            // Request foreground permissions first
            ActivityCompat.requestPermissions(
                context,
                permissions.toTypedArray(),
                LOCATION_PERMISSION_REQUEST_CODE
            )
            
            // For now, return success. The actual result will be handled by onRequestPermissionsResult
            result.success(mapOf("requested" to true))
            
        } catch (e: Exception) {
            result.error("PERMISSION_REQUEST_ERROR", "Error requesting location permission", e.message)
        }
    }
    
    fun requestBackgroundLocationPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Check if foreground permission is already granted
            val hasForeground = ContextCompat.checkSelfPermission(
                activity, 
                FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(
                activity, 
                COARSE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
            
            if (hasForeground) {
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(BACKGROUND_LOCATION),
                    BACKGROUND_LOCATION_PERMISSION_REQUEST_CODE
                )
            }
        }
    }
    
    private fun checkLocationServices(result: MethodResult) {
        try {
            val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            
            val isGpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
            val isNetworkEnabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            val isLocationEnabled = isGpsEnabled || isNetworkEnabled
            
            val serviceInfo = mapOf(
                "isLocationEnabled" to isLocationEnabled,
                "isGpsEnabled" to isGpsEnabled,
                "isNetworkEnabled" to isNetworkEnabled
            )
            
            result.success(serviceInfo)
            
        } catch (e: Exception) {
            result.error("LOCATION_SERVICE_ERROR", "Error checking location services", e.message)
        }
    }
    
    private fun openLocationSettings(result: MethodResult) {
        try {
            val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)
            result.success(true)
            
        } catch (e: Exception) {
            result.error("SETTINGS_ERROR", "Error opening location settings", e.message)
        }
    }
    
    private fun checkBatteryOptimization(result: MethodResult) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                val isIgnoringBatteryOptimizations = powerManager.isIgnoringBatteryOptimizations(context.packageName)
                
                result.success(mapOf(
                    "isIgnoringBatteryOptimizations" to isIgnoringBatteryOptimizations,
                    "canRequestExemption" to true
                ))
            } else {
                // Battery optimization not available on older versions
                result.success(mapOf(
                    "isIgnoringBatteryOptimizations" to true,
                    "canRequestExemption" to false
                ))
            }
            
        } catch (e: Exception) {
            result.error("BATTERY_OPTIMIZATION_ERROR", "Error checking battery optimization", e.message)
        }
    }
    
    private fun requestBatteryOptimizationExemption(result: MethodResult) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                result.success(true)
            } else {
                result.success(false)
            }
            
        } catch (e: Exception) {
            result.error("BATTERY_EXEMPTION_ERROR", "Error requesting battery optimization exemption", e.message)
        }
    }
    
    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
        callback: ((Map<String, Any>) -> Unit)?
    ) {
        when (requestCode) {
            LOCATION_PERMISSION_REQUEST_CODE -> {
                val results = mutableMapOf<String, Any>()
                
                for (i in permissions.indices) {
                    val permission = permissions[i]
                    val granted = grantResults[i] == PackageManager.PERMISSION_GRANTED
                    
                    when (permission) {
                        FINE_LOCATION -> results["hasFine"] = granted
                        COARSE_LOCATION -> results["hasCoarse"] = granted
                    }
                }
                
                val hasAnyLocation = (results["hasFine"] as? Boolean == true) || 
                                   (results["hasCoarse"] as? Boolean == true)
                
                results["canShareLocation"] = hasAnyLocation
                results["requestCode"] = requestCode
                
                callback?.invoke(results)
            }
            
            BACKGROUND_LOCATION_PERMISSION_REQUEST_CODE -> {
                val backgroundGranted = grantResults.isNotEmpty() && 
                                       grantResults[0] == PackageManager.PERMISSION_GRANTED
                
                val results = mapOf(
                    "hasBackground" to backgroundGranted,
                    "canShareInBackground" to backgroundGranted,
                    "requestCode" to requestCode
                )
                
                callback?.invoke(results)
            }
        }
    }
    
    /**
     * Get user-friendly explanation for location permission
     */
    fun getLocationPermissionExplanation(): Map<String, String> {
        return mapOf(
            "title" to "Location Sharing for Family Safety",
            "description" to "Family Guardian uses your location to help keep your family safe and connected. Your location is only shared with your family members and is never shared with third parties.",
            "foreground" to "Location access allows the app to share your location when you're using it.",
            "background" to "Background location allows automatic location sharing even when the app is closed, ensuring your family always knows you're safe.",
            "privacy" to "Your location data is encrypted, stored securely, and only shared within your family group. You can turn off location sharing at any time."
        )
    }
    
    /**
     * Check if we should show permission rationale
     */
    fun shouldShowLocationPermissionRationale(activity: Activity): Boolean {
        return ActivityCompat.shouldShowRequestPermissionRationale(activity, FINE_LOCATION) ||
               ActivityCompat.shouldShowRequestPermissionRationale(activity, COARSE_LOCATION) ||
               (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && 
                ActivityCompat.shouldShowRequestPermissionRationale(activity, BACKGROUND_LOCATION))
    }
}