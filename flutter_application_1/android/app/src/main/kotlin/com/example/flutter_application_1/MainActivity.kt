package com.example.flutter_application_1

import android.content.pm.ActivityInfo
import android.os.Bundle
import android.os.Process
import android.os.Debug
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var lastWallNanos = System.nanoTime()
    private var lastCpuMillis = Process.getElapsedCpuTime()

    override fun onCreate(savedInstanceState: Bundle?) {
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        super.onCreate(savedInstanceState)
    }

    override fun onResume() {
        super.onResume()
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "okey/performance"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "trimMemory" -> {
                    val aggressive = call.argument<Boolean>("aggressive") ?: false
                    if (aggressive) {
                        flutterEngine.systemChannel.sendMemoryPressureWarning()
                        System.runFinalization()
                    }
                    Runtime.getRuntime().gc()
                    result.success(null)
                    return@setMethodCallHandler
                }
                "sample" -> Unit
                else -> {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
            }

            val nowWallNanos = System.nanoTime()
            val nowCpuMillis = Process.getElapsedCpuTime()
            val wallMillis = (nowWallNanos - lastWallNanos) / 1_000_000.0
            val cpuMillis = (nowCpuMillis - lastCpuMillis).toDouble()
            val cores = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)
            val cpuPercent = if (wallMillis > 0) {
                (cpuMillis / (wallMillis * cores) * 100.0).coerceIn(0.0, 100.0)
            } else 0.0
            lastWallNanos = nowWallNanos
            lastCpuMillis = nowCpuMillis

            val refreshRate = if (android.os.Build.VERSION.SDK_INT >= 30) {
                display?.refreshRate ?: 60f
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay.refreshRate
            }
            result.success(mapOf(
                "cpuPercent" to cpuPercent,
                "refreshRate" to refreshRate.toDouble(),
                "memoryMb" to Debug.getPss().toDouble() / 1024.0
            ))
        }
    }
}
