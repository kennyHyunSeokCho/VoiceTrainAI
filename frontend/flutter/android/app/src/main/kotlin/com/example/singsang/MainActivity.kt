package com.example.singsang

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "audio_compare_plugin/method"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "startAnalysis" -> {
                    Log.d("AudioCompare", "startAnalysis 호출됨! arguments: ${call.arguments}")
                    result.success(null)
                }
                "stopAnalysis" -> {
                    Log.d("AudioCompare", "stopAnalysis 호출됨!")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
