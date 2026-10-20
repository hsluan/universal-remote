package com.antigravity.universal_remote

import com.antigravity.universal_remote.ir.ConsumerIrBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var irBridge: ConsumerIrBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = ConsumerIrBridge(applicationContext)
        irBridge = bridge
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ConsumerIrBridge.CHANNEL).setMethodCallHandler(bridge)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ConsumerIrBridge.CHANNEL).setMethodCallHandler(null)
        irBridge?.dispose()
        irBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
