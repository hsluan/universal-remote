package com.antigravity.universal_remote

import android.content.Context
import android.hardware.ConsumerIrManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "universal_remote/ir"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            val irManager = getSystemService(Context.CONSUMER_IR_SERVICE) as? ConsumerIrManager

            when (call.method) {
                "hasIrEmitter" -> {
                    if (irManager == null) {
                        result.success(false)
                    } else {
                        result.success(irManager.hasIrEmitter())
                    }
                }
                "getCarrierFrequencies" -> {
                    if (irManager == null || !irManager.hasIrEmitter()) {
                        result.success(emptyList<Map<String, Int>>())
                    } else {
                        val ranges = irManager.carrierFrequencies
                        val list = ranges?.map { range ->
                            mapOf(
                                "minFrequency" to range.minFrequency,
                                "maxFrequency" to range.maxFrequency
                            )
                        } ?: emptyList()
                        result.success(list)
                    }
                }
                "transmit" -> {
                    if (irManager == null) {
                        result.error("NO_IR_SERVICE", "ConsumerIrManager service is not available on this device", null)
                        return@setMethodCallHandler
                    }
                    if (!irManager.hasIrEmitter()) {
                        result.error("NO_IR_EMITTER", "Device does not have an active IR emitter", null)
                        return@setMethodCallHandler
                    }

                    val frequency = call.argument<Int>("frequency")
                    val patternList = call.argument<List<Int>>("pattern")

                    if (frequency == null || patternList == null || patternList.isEmpty()) {
                        result.error("INVALID_ARGUMENTS", "Frequency and non-empty pattern list are required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val pattern = patternList.toIntArray()
                        irManager.transmit(frequency, pattern)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("TRANSMIT_FAILED", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
