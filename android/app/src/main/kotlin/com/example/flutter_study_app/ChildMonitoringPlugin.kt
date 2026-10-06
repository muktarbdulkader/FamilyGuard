package com.example.flutter_study_app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import com.example.flutter_study_app.database.LocalDatabase
import com.example.flutter_study_app.enforcement.EnforcementManager
import com.example.flutter_study_app.enforcement.RuleEngine
import com.example.flutter_study_app.services.MonitoringService
import com.example.flutter_study_app.sync.RuleSyncService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.*
import kotlinx.coroutines.*
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Flutter plugin that bridges native Android monitoring functionality
 * with the Flutter UI layer.
 */
class ChildMonitoringPlugin: FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    
    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var activityBinding: ActivityPluginBinding? = null
    
    private lateinit var database: LocalDatabase
    private lateinit var ruleEngine: RuleEngine
    private lateinit var enforcementManager: EnforcementManager
    private var ruleSyncService: RuleSyncService? = null
    
    private val pluginScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    companion object {
        private const val CHANNEL_METHOD = "child_monitoring"
        private const val CHANNEL_EVENT = "child_monitoring_events"
        
        // Permission request codes
        private const val REQUEST_USAGE_STATS = 1001
        private const val REQUEST_OVERLAY_PERMISSION = 1002
    }
    
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        
        // Initialize native components
        database = LocalDatabase.getInstance(context)
        ruleEngine = RuleEngine()
        enforcementManager = EnforcementManager(context, database, ruleEngine)
        
        // Set up method channel
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_METHOD)
        methodChannel.setMethodCallHandler(this)
        
        // Set up event channel for real-time updates
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, CHANNEL_EVENT)
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        pluginScope.cancel()
    }
    
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener { requestCode, permissions, grantResults ->
            // Handle permission results if needed
            false
        }
        binding.addActivityResultListener { requestCode, resultCode, data ->
            when (requestCode) {
                REQUEST_USAGE_STATS -> {
                    sendEvent(mapOf(
                        "type" to "permission_result",
                        "permission" to "usage_stats",
                        "granted" to hasUsageStatsPermission()
                    ))
                    true
                }
                REQUEST_OVERLAY_PERMISSION -> {
                    sendEvent(mapOf(
                        "type" to "permission_result",
                        "permission" to "overlay",
                        "granted" to canDrawOverlays()
                    ))
                    true
                }
                else -> false
            }
        }
    }
    
    override fun onDetachedFromActivity() {
        activityBinding = null
    }
    
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }
    
    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }
    
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            
            // Service Management
            "startMonitoring" -> {
                val familyId = call.argument<String>("familyId")
                val childId = call.argument<String>("childId")
                
                if (familyId != null && childId != null) {
                    startMonitoring(familyId, childId, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing familyId or childId", null)
                }
            }
            
            "stopMonitoring" -> {
                stopMonitoring(result)
            }
            
            "isMonitoringActive" -> {
                result.success(isMonitoringServiceRunning())
            }
            
            // Permission Management
            "checkPermissions" -> {
                result.success(mapOf(
                    "usageStats" to hasUsageStatsPermission(),
                    "overlay" to canDrawOverlays()
                ))
            }
            
            "requestUsageStatsPermission" -> {
                requestUsageStatsPermission()
                result.success(true)
            }
            
            "requestOverlayPermission" -> {
                enforcementManager.requestOverlayPermission()
                result.success(true)
            }
            
            // Rule Management
            "syncRules" -> {
                val familyId = call.argument<String>("familyId")
                if (familyId != null) {
                    syncRules(familyId, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing familyId", null)
                }
            }
            
            "getRules" -> {
                getRules(result)
            }
            
            "evaluateApp" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    evaluateApp(packageName, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing packageName", null)
                }
            }
            
            // Usage Data
            "getUsageData" -> {
                getUsageData(result)
            }
            
            "resetUsageData" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    resetUsageData(packageName, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing packageName", null)
                }
            }
            
            // Temporary Approvals
            "addTemporaryApproval" -> {
                val packageName = call.argument<String>("packageName")
                val durationMinutes = call.argument<Int>("durationMinutes")
                val approvedBy = call.argument<String>("approvedBy")
                
                if (packageName != null && durationMinutes != null && approvedBy != null) {
                    addTemporaryApproval(packageName, durationMinutes, approvedBy, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing required parameters", null)
                }
            }
            
            else -> {
                result.notImplemented()
            }
        }
    }
    
    // Event Channel Implementation
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
    
    private fun sendEvent(data: Map<String, Any>) {
        pluginScope.launch(Dispatchers.Main) {
            eventSink?.success(data)
        }
    }
    
    // Service Management Methods
    
    private fun startMonitoring(familyId: String, childId: String, result: MethodChannel.Result) {
        pluginScope.launch {
            try {
                // Start rule synchronization
                ruleSyncService?.stopSync()
                ruleSyncService = RuleSyncService(context, database, childId)
                ruleSyncService?.startSync(familyId)
                
                // Start monitoring service
                MonitoringService.startService(context)
                
                sendEvent(mapOf(
                    "type" to "monitoring_started",
                    "familyId" to familyId,
                    "childId" to childId
                ))
                
                result.success(true)
            } catch (e: Exception) {
                result.error("START_FAILED", "Failed to start monitoring: ${e.message}", e.toString())
            }
        }
    }
    
    private fun stopMonitoring(result: MethodChannel.Result) {
        pluginScope.launch {
            try {
                // Stop rule synchronization
                ruleSyncService?.stopSync()
                ruleSyncService = null
                
                // Stop monitoring service
                MonitoringService.stopService(context)
                
                sendEvent(mapOf("type" to "monitoring_stopped"))
                
                result.success(true)
            } catch (e: Exception) {
                result.error("STOP_FAILED", "Failed to stop monitoring: ${e.message}", e.toString())
            }
        }
    }
    
    private fun isMonitoringServiceRunning(): Boolean {
        // Check if monitoring service is running
        // This is a simplified check - in production you might want to use ActivityManager
        return true // Placeholder implementation
    }
    
    // Permission Methods
    
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            context.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }
    
    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }
    
    private fun requestUsageStatsPermission() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        activityBinding?.activity?.startActivityForResult(intent, REQUEST_USAGE_STATS)
    }
    
    // Rule Management Methods
    
    private fun syncRules(familyId: String, result: MethodChannel.Result) {
        pluginScope.launch {
            try {
                // Manual sync trigger
                ruleSyncService?.let { service ->
                    // Force a sync operation
                    sendEvent(mapOf("type" to "rules_syncing"))
                    
                    // In a real implementation, you'd trigger a manual sync here
                    result.success(true)
                    
                    sendEvent(mapOf("type" to "rules_synced"))
                } ?: run {
                    result.error("SYNC_FAILED", "Rule sync service not initialized", null)
                }
            } catch (e: Exception) {
                result.error("SYNC_FAILED", "Failed to sync rules: ${e.message}", e.toString())
            }
        }
    }
    
    private fun getRules(result: MethodChannel.Result) {
        pluginScope.launch(Dispatchers.IO) {
            try {
                val rules = database.getAllRules()
                val rulesData = rules.map { rule ->
                    mapOf(
                        "packageName" to rule.packageName,
                        "type" to rule.type.name,
                        "dailyLimitMinutes" to rule.dailyLimitMinutes,
                        "allowedStartTime" to rule.allowedStartTime?.toString(),
                        "allowedEndTime" to rule.allowedEndTime?.toString(),
                        "createdAt" to rule.createdAt.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                        "updatedAt" to rule.updatedAt.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                    )
                }
                
                withContext(Dispatchers.Main) {
                    result.success(rulesData)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("GET_RULES_FAILED", "Failed to get rules: ${e.message}", e.toString())
                }
            }
        }
    }
    
    private fun evaluateApp(packageName: String, result: MethodChannel.Result) {
        pluginScope.launch(Dispatchers.IO) {
            try {
                val currentTime = LocalDateTime.now()
                val rule = database.getRule(packageName)
                val usage = database.getUsage(packageName)
                val approval = database.getActiveTemporaryApproval(packageName)
                
                val evaluation = ruleEngine.evaluate(packageName, currentTime, rule, usage, approval)
                
                val evaluationData = mapOf(
                    "packageName" to packageName,
                    "result" to evaluation.name,
                    "remainingMinutes" to ruleEngine.getRemainingMinutes(rule, usage, currentTime),
                    "minutesUntilAllowed" to ruleEngine.getMinutesUntilAllowed(rule, currentTime)
                )
                
                withContext(Dispatchers.Main) {
                    result.success(evaluationData)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("EVALUATE_FAILED", "Failed to evaluate app: ${e.message}", e.toString())
                }
            }
        }
    }
    
    // Usage Data Methods
    
    private fun getUsageData(result: MethodChannel.Result) {
        pluginScope.launch(Dispatchers.IO) {
            try {
                val usageData = database.getAllUsageData()
                val usageList = usageData.map { (packageName, usage) ->
                    mapOf(
                        "packageName" to packageName,
                        "todayMinutes" to usage.todayMinutes,
                        "lastUsed" to usage.lastUsed.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                        "dailyResetDate" to usage.dailyResetDate
                    )
                }
                
                withContext(Dispatchers.Main) {
                    result.success(usageList)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("GET_USAGE_FAILED", "Failed to get usage data: ${e.message}", e.toString())
                }
            }
        }
    }
    
    private fun resetUsageData(packageName: String, result: MethodChannel.Result) {
        pluginScope.launch(Dispatchers.IO) {
            try {
                val today = LocalDateTime.now().toLocalDate().toString()
                database.resetUsageForDate(packageName, today)
                
                withContext(Dispatchers.Main) {
                    result.success(true)
                    sendEvent(mapOf(
                        "type" to "usage_reset",
                        "packageName" to packageName
                    ))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("RESET_FAILED", "Failed to reset usage: ${e.message}", e.toString())
                }
            }
        }
    }
    
    // Temporary Approval Methods
    
    private fun addTemporaryApproval(packageName: String, durationMinutes: Int, approvedBy: String, result: MethodChannel.Result) {
        pluginScope.launch(Dispatchers.IO) {
            try {
                val approval = RuleEngine.TemporaryApproval(
                    packageName = packageName,
                    approvedAt = LocalDateTime.now(),
                    durationMinutes = durationMinutes,
                    approvedBy = approvedBy
                )
                
                database.insertTemporaryApproval(approval)
                
                withContext(Dispatchers.Main) {
                    result.success(true)
                    sendEvent(mapOf(
                        "type" to "temporary_approval_added",
                        "packageName" to packageName,
                        "durationMinutes" to durationMinutes,
                        "approvedBy" to approvedBy
                    ))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("APPROVAL_FAILED", "Failed to add temporary approval: ${e.message}", e.toString())
                }
            }
        }
    }
}