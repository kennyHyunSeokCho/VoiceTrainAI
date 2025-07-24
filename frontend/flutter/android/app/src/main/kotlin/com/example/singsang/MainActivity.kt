package com.example.singsang

import android.os.Handler
import android.os.Looper
import android.util.Log
import be.tarsos.dsp.AudioDispatcher
import be.tarsos.dsp.pitch.PitchDetectionHandler
import be.tarsos.dsp.pitch.PitchProcessor
import be.tarsos.dsp.onsets.OnsetHandler
import be.tarsos.dsp.onsets.OnsetDetector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import kotlin.math.abs
import kotlin.math.min

class MainActivity: FlutterActivity() {
    private val METHOD_CHANNEL = "audio_compare_plugin/method"
    private val SCORE_EVENT_CHANNEL = "audio_compare_plugin/score"
    // 필요시 피치/온셋 EventChannel도 추가 가능

    private var scoreEventSink: EventChannel.EventSink? = null
    private var dispatcher: AudioDispatcher? = null
    private var handler: Handler? = null

    // 원본 시퀀스
    private var originalPitchSeq: List<Float> = listOf()
    private var originalOnsetSeq: List<Float> = listOf()

    // 실시간 분석값 저장
    private val livePitchSeq = mutableListOf<Float>()
    private val liveOnsetSeq = mutableListOf<Float>()

    // 피치 EventChannel
    private val PITCH_EVENT_CHANNEL = "audio_compare_plugin/pitch"
    private var pitchEventSink: EventChannel.EventSink? = null

    // 온셋 EventChannel
    private val ONSET_EVENT_CHANNEL = "audio_compare_plugin/onset"
    private var onsetEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // TensorDSP 플러그인 등록
        flutterEngine.plugins.add(TensorDspPlugin())

        // MethodChannel: Flutter → Native
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAnalysis" -> {
                        val args = call.arguments as Map<String, Any>
                        originalPitchSeq = (args["originalPitch"] as List<Double>).map { it.toFloat() }
                        originalOnsetSeq = (args["originalOnsets"] as List<Double>).map { it.toFloat() }
                        startAudioAnalysis()
                        result.success(null)
                    }
                    "stopAnalysis" -> {
                        stopAudioAnalysis()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // EventChannel: Native → Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCORE_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    scoreEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    scoreEventSink = null
                }
            })

        // 피치 EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PITCH_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    pitchEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    pitchEventSink = null
                }
            })
        // 온셋 EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, ONSET_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    onsetEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    onsetEventSink = null
                }
            })
    }

    private fun startAudioAnalysis() {
        stopAudioAnalysis() // 혹시 이전 dispatcher가 남아있으면 정리

        livePitchSeq.clear()
        liveOnsetSeq.clear()
        handler = Handler(Looper.getMainLooper())

        try {
            // TarsosDSP Android 의존성 문제로 인해 기본 기능만 사용
            // 실제 마이크 입력은 나중에 구현
            Log.d("MainActivity", "오디오 분석 준비 완료")
            
            // 임시로 더미 데이터 생성
            handler?.postDelayed({
                val dummyPitch = 440f // A4 음
                livePitchSeq.add(dummyPitch)
                pitchEventSink?.success(dummyPitch)
                val score = calculatePitchScore(livePitchSeq, originalPitchSeq)
                scoreEventSink?.success(score)
            }, 1000)
            
        } catch (e: Exception) {
            Log.e("MainActivity", "오디오 분석 시작 실패: ${e.message}")
        }
    }

    private fun stopAudioAnalysis() {
        dispatcher?.stop()
        dispatcher = null
        handler = null
    }

    // 피치 점수 계산 (간단 예시: 평균 오차 기반)
    private fun calculatePitchScore(live: List<Float>, original: List<Float>): Float {
        if (live.isEmpty() || original.isEmpty()) return 0f
        val minLen = min(live.size, original.size)
        var errorSum = 0f
        for (i in 0 until minLen) {
            errorSum += abs(live[i] - original[i])
        }
        val avgError = errorSum / minLen
        // 오차가 작을수록 점수 높음 (100점 만점)
        return (100f - avgError).coerceIn(0f, 100f)
    }
}
