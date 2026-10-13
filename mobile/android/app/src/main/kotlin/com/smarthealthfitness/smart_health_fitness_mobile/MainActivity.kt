package com.smarthealthfitness.smart_health_fitness_mobile

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smart_health_fitness/health")
            .setMethodCallHandler { call, result ->
                if (call.method != "openHealthSettings") {
                    result.notImplemented()
                } else {
                    try {
                        val actions = listOf(
                            "android.health.connect.action.HEALTH_CONNECT_SETTINGS",
                            "androidx.health.ACTION_HEALTH_CONNECT_SETTINGS"
                        )
                        val intent = actions.map { Intent(it) }
                            .firstOrNull { it.resolveActivity(packageManager) != null }
                            ?: Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName"))
                        startActivity(intent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("HEALTH_SETTINGS", "Sağlık izinleri açılamadı.", null)
                    }
                }
            }
    }
}
