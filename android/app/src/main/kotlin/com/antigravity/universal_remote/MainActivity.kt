package com.antigravity.universal_remote

import com.antigravity.universal_remote.apps.AppLauncherBridge
import com.antigravity.universal_remote.ir.ConsumerIrBridge
import com.antigravity.universal_remote.network.NetworkBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var irBridge: ConsumerIrBridge? = null
    private var networkBridge: NetworkBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val bridge = ConsumerIrBridge(applicationContext)
        irBridge = bridge
        MethodChannel(messenger, ConsumerIrBridge.CHANNEL).setMethodCallHandler(bridge)
        MethodChannel(messenger, AppLauncherBridge.CHANNEL).setMethodCallHandler(AppLauncherBridge(applicationContext))
        val network = NetworkBridge(applicationContext)
        networkBridge = network
        MethodChannel(messenger, NetworkBridge.CHANNEL).setMethodCallHandler(network)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, ConsumerIrBridge.CHANNEL).setMethodCallHandler(null)
        MethodChannel(messenger, AppLauncherBridge.CHANNEL).setMethodCallHandler(null)
        MethodChannel(messenger, NetworkBridge.CHANNEL).setMethodCallHandler(null)
        irBridge?.dispose()
        irBridge = null
        networkBridge?.release()
        networkBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
