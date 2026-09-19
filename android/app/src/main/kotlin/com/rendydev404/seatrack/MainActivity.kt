package com.rendydev404.seatrack

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import com.rendydev404.seatrack.update.AppUpdateRelauncher
import com.rendydev404.seatrack.update.UpdatePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val batteryChannel = "seatrack/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, batteryChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoring" -> result.success(isIgnoringBatteryOptimizations())
                "request" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        UpdatePlugin(applicationContext).attach(messenger)
    }

    override fun onResume() {
        super.onResume()
        // Menandai aplikasi terlihat: relauncher hanya boleh membuka layar sendiri
        // bila pembaruan dipasang saat aplikasi sedang dipakai.
        AppUpdateRelauncher.onAppVisible(applicationContext)
    }

    override fun onPause() {
        super.onPause()
        AppUpdateRelauncher.onAppHidden()
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            .setData(Uri.parse("package:$packageName"))
        try {
            startActivity(intent)
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
    }
}
