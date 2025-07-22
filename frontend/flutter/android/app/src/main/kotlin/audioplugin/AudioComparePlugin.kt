package com.yourcompany.audio_compare_plugin

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import android.util.Log

class AudioComparePlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var scoreEventChannel: EventChannel
    private var scoreEventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "audio_compare_plugin/method")
        methodChannel.setMethodCallHandler(this)

        scoreEventChannel = EventChannel(binding.binaryMessenger, "audio_compare_plugin/score")
        scoreEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                scoreEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                scoreEventSink = null
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startAnalysis" -> {
                Log.d("AudioCompare", "startAnalysis 호출됨! arguments: ${call.arguments}")
                // 분석 시작 (예: 오디오 캡처, 피치/온셋 추출 등)
                startAudioAnalysis()
                result.success(null)
            }
            "stopAnalysis" -> {
                Log.d("AudioCompare", "stopAnalysis 호출됨!")
                // 분석 중지
                stopAudioAnalysis()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startAudioAnalysis() {
        // 예시: 1초마다 점수(더미) 전송
        Handler(Looper.getMainLooper()).postDelayed(object : Runnable {
            override fun run() {
                scoreEventSink?.success(Math.random() * 100)
                Handler(Looper.getMainLooper()).postDelayed(this, 1000)
            }
        }, 1000)
    }

    private fun stopAudioAnalysis() {
        // 분석 중지 로직 구현
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        scoreEventChannel.setStreamHandler(null)
    }
}