package com.healthwing.healthwing_mobile

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val SECURITY_CHANNEL = "healthwing/security"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SECURITY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecureScreen" -> {
                    val enabled: Boolean? = when (val args = call.arguments) {
                        is Boolean -> args
                        is Map<*, *> -> args["enabled"] as? Boolean
                        else -> null
                    }

                    if (enabled == null) {
                        result.error(
                            "invalid_argument",
                            "Boolean argument 'enabled' is required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(enabled)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
