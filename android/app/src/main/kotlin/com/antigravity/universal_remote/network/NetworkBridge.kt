package com.antigravity.universal_remote.network

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel handler for `universal_remote/network`.
 *
 * Android Wi-Fi drops multicast packets to save battery unless an app holds a
 * MulticastLock; device searches (ONVIF WS-Discovery, mDNS, SSDP) hold it while they run.
 */
class NetworkBridge(context: Context) : MethodChannel.MethodCallHandler {
    private val multicastLock: WifiManager.MulticastLock? =
        (context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager)
            ?.createMulticastLock("universal_remote:discovery")
            ?.apply { setReferenceCounted(false) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "acquireMulticastLock" -> {
                multicastLock?.acquire()
                result.success(multicastLock != null)
            }
            "releaseMulticastLock" -> {
                release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun release() {
        if (multicastLock?.isHeld == true) multicastLock.release()
    }

    companion object {
        const val CHANNEL = "universal_remote/network"
    }
}
