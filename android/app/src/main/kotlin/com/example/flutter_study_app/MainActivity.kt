package com.example.flutter_study_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val PERMISSION_CHANNEL = "family_guardian/permissions"
    private val APP_SCANNER_CHANNEL = "family_guard/app_scanner"
    
    private lateinit var permissionHelper: PermissionHelper
    private lateinit var appScannerHelper: AppScannerHelper

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        permissionHelper = PermissionHelper(this)
        appScannerHelper = AppScannerHelper(this)
        
        // Permission method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSION_CHANNEL)
            .setMethodCallHandler { call, result ->
                permissionHelper.handleMethodCall(call.method, result)
            }
        
        // App scanner method channel
        val appScannerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_SCANNER_CHANNEL)
        appScannerChannel.setMethodCallHandler { call, result ->
            appScannerHelper.handleMethodCall(call.method, call.arguments, result)
        }
        
        // Set method channel for app scanner callbacks
        appScannerHelper.setMethodChannel(appScannerChannel)
    }
}
