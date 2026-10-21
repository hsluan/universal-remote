package com.antigravity.universal_remote

import com.antigravity.universal_remote.apps.AppLauncherBridge
import com.antigravity.universal_remote.ir.ConsumerIrBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var irBridge: ConsumerIrBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val bridge = ConsumerIrBridge(applicationContext)
        irBridge = bridge
        MethodChannel(messenger, ConsumerIrBridge.CHANNEL).setMethodCallHandler(bridge)
        MethodChannel(messenger, AppLauncherBridge.CHANNEL).setMethodCallHandler(AppLauncherBridge(applicationContext))
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, ConsumerIrBridge.CHANNEL).setMethodCallHandler(null)
        MethodChannel(messenger, AppLauncherBridge.CHANNEL).setMethodCallHandler(null)
        irBridge?.dispose()
        irBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
