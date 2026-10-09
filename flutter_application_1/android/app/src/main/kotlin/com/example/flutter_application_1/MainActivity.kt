package com.example.flutter_application_1

import android.content.pm.ActivityInfo
import android.os.Bundle
import android.os.Process
import android.os.Debug
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var notificationPermissionResult: MethodChannel.Result? = null
    private var lastWallNanos = System.nanoTime()
    private var lastCpuMillis = Process.getElapsedCpuTime()

    override fun onCreate(savedInstanceState: Bundle?) {
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        super.onCreate(savedInstanceState)
        enterImmersiveMode()
    }

    override fun onResume() {
        super.onResume()
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        enterImmersiveMode()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) enterImmersiveMode()
    }

    @Suppress("DEPRECATION")
    private fun enterImmersiveMode() {
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "okey/league_reminder")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        LeagueReminder.update(this,
                            call.argument<Number>("deadline")?.toLong() ?: 0L,
                            call.argument<Boolean>("enabled") ?: false)
                        result.success(null)
                    }
                    "requestPermission" -> {
                        val prefs = getSharedPreferences("league_reminder", MODE_PRIVATE)
                        if (android.os.Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
                                android.content.pm.PackageManager.PERMISSION_GRANTED &&
                            !prefs.getBoolean("permissionAsked", false)) {
                            if (notificationPermissionResult != null) {
                                result.success(false)
                            } else {
                                prefs.edit().putBoolean("permissionAsked", true).apply()
                                notificationPermissionResult = result
                                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 3101)
                            }
                        } else {
                            result.success(LeagueReminder.permitted(this))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
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

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 3101) {
            notificationPermissionResult?.success(LeagueReminder.permitted(this))
            notificationPermissionResult = null
            LeagueReminder.restore(this)
        }
    }
}
