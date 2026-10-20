package com.antigravity.universal_remote.ir

import android.content.Context
import android.hardware.ConsumerIrManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * MethodChannel handler for `universal_remote/ir`, adapting [ConsumerIrManager].
 *
 * `ConsumerIrManager.transmit` is synchronous: it returns only after the whole pattern has been
 * emitted (up to ~1 s for AC frames with toggle commands). Running it on the main thread froze
 * touch input and Flutter's vsync for that long, so transmissions run on one dedicated thread,
 * one at a time, and their results are posted back to the main thread.
 */
class ConsumerIrBridge(context: Context) : MethodChannel.MethodCallHandler {
    private val irManager = context.getSystemService(Context.CONSUMER_IR_SERVICE) as? ConsumerIrManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val transmitExecutor: ExecutorService = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, THREAD_NAME).apply { isDaemon = true }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasIrEmitter" -> result.success(irManager?.hasIrEmitter() ?: false)
            "getCarrierFrequencies" -> result.success(carrierFrequencies())
            "transmit" -> transmit(call, result)
            else -> result.notImplemented()
        }
    }

    /** Stops accepting transmissions; one already running still finishes. */
    fun dispose() {
        transmitExecutor.shutdown()
    }

    private fun carrierFrequencies(): List<Map<String, Int>> {
        val manager = irManager
        if (manager == null || !manager.hasIrEmitter()) return emptyList()
        return manager.carrierFrequencies?.map { range ->
            mapOf("minFrequency" to range.minFrequency, "maxFrequency" to range.maxFrequency)
        } ?: emptyList()
    }

    private fun transmit(call: MethodCall, result: MethodChannel.Result) {
        val manager = irManager
        if (manager == null) {
            result.error("NO_IR_SERVICE", "ConsumerIrManager service is not available on this device", null)
            return
        }
        if (!manager.hasIrEmitter()) {
            result.error("NO_IR_EMITTER", "Device does not have an active IR emitter", null)
            return
        }
        val frequency = call.argument<Int>("frequency")
        val pattern = call.argument<List<Int>>("pattern")?.toIntArray()
        if (frequency == null || pattern == null || pattern.isEmpty()) {
            result.error("INVALID_ARGUMENTS", "Frequency and non-empty pattern list are required", null)
            return
        }

        try {
            transmitExecutor.execute {
                val start = SystemClock.elapsedRealtime()
                try {
                    manager.transmit(frequency, pattern)
                    val elapsed = SystemClock.elapsedRealtime() - start
                    Log.d(TAG, "transmit ok: $frequency Hz, ${pattern.size} pulses, ${elapsed} ms on ${Thread.currentThread().name}")
                    mainHandler.post { result.success(true) }
                } catch (e: Exception) {
                    Log.w(TAG, "transmit failed: $frequency Hz, ${pattern.size} pulses", e)
                    mainHandler.post { result.error("TRANSMIT_FAILED", e.message, null) }
                }
            }
        } catch (e: RejectedExecutionException) {
            result.error("TRANSMIT_FAILED", "IR transmitter is shutting down", null)
        }
    }

    companion object {
        const val CHANNEL = "universal_remote/ir"
        private const val TAG = "ConsumerIrBridge"
        private const val THREAD_NAME = "ir-transmit"
    }
}
