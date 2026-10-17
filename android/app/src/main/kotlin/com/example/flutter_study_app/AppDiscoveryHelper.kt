package com.example.flutter_study_app

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Base64
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.*

/**
 * AppDiscoveryHelper for Family Guardian
 * 
 * Discovers and manages installed user applications on Android device.
 * Implements efficient app scanning with proper filtering for parental control use.
 * 
 * Features:
 * - Discovers user-installed applications (excludes system apps)
 * - Extracts app metadata (name, package, version, icon)
 * - Filters apps appropriate for parental control
 * - Handles Android 11+ package visibility restrictions
 * - Optimized for battery and performance
 */
class AppDiscoveryHelper(private val context: Context) {
    
    companion object {
        private const val TAG = "FamilyGuardian.AppDiscovery"
        private const val MAX_ICON_SIZE = 48
        private const val ICON_QUALITY = 80
    }
    
    private val packageManager: PackageManager = context.packageManager
    private var methodChannel: MethodChannel? = null
    
    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
    }
    
    /**
     * Handle method calls from Flutter
     */
    fun handleMethodCall(method: String, arguments: Any?, result: MethodChannel.Result) {
        when (method) {
            "scanInstalledApps" -> {
                try {
                    val apps = scanInstalledApps()
                    result.success(apps)
                } catch (e: Exception) {
                    Log.e(TAG, "Error scanning apps", e)
                    result.error("SCAN_ERROR", e.message, null)
                }
            }
            "getAppIcon" -> {
                try {
                    val packageName = arguments as String
                    val iconBase64 = getAppIconBase64(packageName)
                    result.success(iconBase64)
                } catch (e: Exception) {
                    Log.e(TAG, "Error getting app icon", e)
                    result.success(null) // Return null if icon not available
                }
            }
            "isAppInstalled" -> {
                try {
                    val packageName = arguments as String
                    val isInstalled = isAppInstalled(packageName)
                    result.success(isInstalled)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * Scan all installed user applications
     * Returns list of app info maps suitable for Flutter consumption
     */
    fun scanInstalledApps(): List<Map<String, Any?>> {
        Log.i(TAG, "Starting comprehensive app scan...")
        
        // 1. Discover all launchable apps via standard launcher intent
        val launcherIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val launcherResolveInfos = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.queryIntentActivities(
                    launcherIntent,
                    PackageManager.ResolveInfoFlags.of(0L)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.queryIntentActivities(launcherIntent, 0)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to query launcher activities", e)
            emptyList()
        }
        
        val launcherPackageNames = launcherResolveInfos.mapNotNull { it.activityInfo?.packageName }.toSet()
        Log.i(TAG, "Found ${launcherPackageNames.size} packages via launcher intent")

        // 2. Discover installed packages (use flag 0 to prevent TransactionTooLargeException)
        val installedPackages = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getInstalledPackages(PackageManager.PackageInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getInstalledPackages(0)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get installed packages", e)
            emptyList()
        }

        // Combine all package names
        val allPackageNames = mutableSetOf<String>()
        allPackageNames.addAll(launcherPackageNames)
        for (pkg in installedPackages) {
            val appInfo = pkg.applicationInfo
            if (appInfo != null) {
                // If it's a non-system app, include it even if it didn't show in launcher
                val isSystem = ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0) &&
                               ((appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0)
                if (!isSystem) {
                    allPackageNames.add(pkg.packageName)
                }
            }
        }

        val userApps = mutableListOf<Map<String, Any?>>()
        val processedPackages = mutableSetOf<String>()
        
        for (packageName in allPackageNames) {
            if (processedPackages.contains(packageName)) continue
            processedPackages.add(packageName)

            try {
                if (isPackageAllowedForControl(packageName, launcherPackageNames.contains(packageName))) {
                    val packageInfo = try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0L))
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, 0)
                        }
                    } catch (e: Exception) {
                        null
                    }

                    if (packageInfo != null) {
                        val appInfo = extractAppInfo(packageInfo)
                        if (appInfo != null) {
                            userApps.add(appInfo)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error processing package $packageName", e)
            }
        }
        
        Log.i(TAG, "App scan completed. Discovered ${userApps.size} apps for parental control")
        return userApps
    }
    
    /**
     * Check if a package should be manageable by parental controls
     */
    private fun isPackageAllowedForControl(packageName: String, hasLauncherIcon: Boolean): Boolean {
        // Skip our own app
        if (packageName == context.packageName) {
            return false
        }
        
        // Skip critical OS services (SystemUI, Settings, core dialer)
        if (isSystemPackage(packageName)) {
            return false
        }
        
        // If it has a launcher icon (like TikTok, Facebook, YouTube, games), always include it!
        if (hasLauncherIcon) {
            return true
        }

        // Otherwise check if it has a launch intent
        return hasLauncherActivity(packageName)
    }

    /**
     * Check if a package represents a user app suitable for parental control
     */
    fun isUserApp(packageInfo: PackageInfo): Boolean {
        val packageName = packageInfo.packageName
        return isPackageAllowedForControl(packageName, hasLauncherActivity(packageName))
    }

    
    /**
     * Check if package has a launcher activity
     */
    private fun hasLauncherActivity(packageName: String): Boolean {
        try {
            if (packageManager.getLaunchIntentForPackage(packageName) != null) {
                return true
            }
        } catch (e: Exception) {
            // Fallback
        }

        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
            setPackage(packageName)
        }
        
        return try {
            val activities = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.queryIntentActivities(
                    intent,
                    PackageManager.ResolveInfoFlags.of(0L)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.queryIntentActivities(intent, 0)
            }
            activities.isNotEmpty()
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Check if package is a known system package that should be excluded
     */
    private fun isSystemPackage(packageName: String): Boolean {
        val systemPackages = setOf(
            // Android system
            "android",
            "com.android.systemui",
            "com.android.settings",
            "com.android.launcher",
            "com.android.launcher3",
            
            // Google system services
            "com.google.android.gms",
            "com.google.android.gsf",
            "com.google.android.webview",
            
            // Common system apps that shouldn't be controlled
            "com.android.phone",
            "com.android.contacts",
            "com.android.mms",
            "com.android.emergency",
            
            // Carrier/OEM system apps
            "com.samsung.android.dialer",
            "com.samsung.android.messaging",
        )
        
        return systemPackages.contains(packageName) || 
               packageName.startsWith("com.android.internal") ||
               packageName.startsWith("com.google.android.gms") ||
               packageName.startsWith("com.qualcomm") ||
               packageName.startsWith("com.samsung.android.knox")
    }
    
    /**
     * Extract app information from PackageInfo including real base64 icon
     */
    private fun extractAppInfo(packageInfo: PackageInfo): Map<String, Any?>? {
        return try {
            val packageName = packageInfo.packageName
            val applicationInfo = packageInfo.applicationInfo
            
            val appName = try {
                applicationInfo?.loadLabel(packageManager)?.toString() ?: packageName
            } catch (e: Exception) {
                packageName // Fallback to package name
            }
            
            val version = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    packageInfo.longVersionCode.toString()
                } else {
                    @Suppress("DEPRECATION")
                    packageInfo.versionCode.toString()
                }
            } catch (e: Exception) {
                null
            }
            
            val versionName = try {
                packageInfo.versionName
            } catch (e: Exception) {
                null
            }
            
            val isSystemApp = ((applicationInfo?.flags ?: 0) and ApplicationInfo.FLAG_SYSTEM) != 0
            
            val firstInstallTime = try {
                Date(packageInfo.firstInstallTime).toInstant().epochSecond
            } catch (e: Exception) {
                System.currentTimeMillis() / 1000
            }
            
            val lastUpdateTime = try {
                Date(packageInfo.lastUpdateTime).toInstant().epochSecond
            } catch (e: Exception) {
                firstInstallTime
            }

            // Extract real application icon as Base64
            val iconBase64 = getAppIconBase64(packageName)
            
            mapOf(
                "packageName" to packageName,
                "name" to appName,
                "appName" to appName,
                "iconBase64" to iconBase64,
                "version" to (versionName ?: version ?: ""),
                "versionName" to versionName,
                "isSystemApp" to isSystemApp,
                "firstInstallTime" to firstInstallTime,
                "installTime" to packageInfo.firstInstallTime,
                "lastUpdateTime" to packageInfo.lastUpdateTime,
                "isEnabled" to (applicationInfo?.enabled ?: false)
            )
        } catch (e: Exception) {
            Log.w(TAG, "Error extracting app info for ${packageInfo.packageName}", e)
            null
        }
    }
    
    /**
     * Get app icon as base64 encoded string
     */
    fun getAppIconBase64(packageName: String): String? {
        return try {
            val drawable = packageManager.getApplicationIcon(packageName)
            val bitmap = drawableToBitmap(drawable)
            
            if (bitmap != null) {
                // Resize if too large
                val resizedBitmap = if (bitmap.width > MAX_ICON_SIZE || bitmap.height > MAX_ICON_SIZE) {
                    Bitmap.createScaledBitmap(bitmap, MAX_ICON_SIZE, MAX_ICON_SIZE, true)
                } else {
                    bitmap
                }
                
                // Convert to base64 PNG
                val outputStream = ByteArrayOutputStream()
                resizedBitmap.compress(Bitmap.CompressFormat.PNG, ICON_QUALITY, outputStream)
                val byteArray = outputStream.toByteArray()
                Base64.encodeToString(byteArray, Base64.NO_WRAP)
            } else {
                null
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error getting icon for $packageName", e)
            null
        }
    }
    
    /**
     * Convert drawable to bitmap safely (handles AdaptiveIconDrawable, VectorDrawable, BitmapDrawable)
     */
    private fun drawableToBitmap(drawable: Drawable): Bitmap? {
        return try {
            if (drawable is BitmapDrawable && drawable.bitmap != null) {
                return drawable.bitmap
            }
            
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else MAX_ICON_SIZE
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else MAX_ICON_SIZE
            
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bitmap
        } catch (e: Exception) {
            Log.w(TAG, "Error converting drawable to bitmap", e)
            null
        }
    }
    
    /**
     * Check if specific app is installed
     */
    fun isAppInstalled(packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        } catch (e: Exception) {
            Log.w(TAG, "Error checking if app $packageName is installed", e)
            false
        }
    }
    
    /**
     * Get detailed info for specific app
     */
    fun getAppDetails(packageName: String): Map<String, Any?>? {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(PackageManager.GET_META_DATA.toLong())
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_META_DATA)
            }
            
            if (isUserApp(packageInfo)) {
                extractAppInfo(packageInfo)
            } else {
                null
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error getting details for app $packageName", e)
            null
        }
    }
}