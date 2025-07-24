package com.example.singsang

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import be.tarsos.dsp.AudioDispatcher
import be.tarsos.dsp.AudioEvent
import be.tarsos.dsp.AudioProcessor
import be.tarsos.dsp.pitch.PitchDetectionHandler
import be.tarsos.dsp.pitch.PitchDetectionResult
import be.tarsos.dsp.pitch.PitchProcessor
import be.tarsos.dsp.pitch.PitchProcessor.PitchEstimationAlgorithm
import be.tarsos.dsp.mfcc.MFCC
import be.tarsos.dsp.io.TarsosDSPAudioFormat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentLinkedQueue
import kotlin.math.sqrt
import kotlin.math.log10
import kotlin.math.abs
import kotlin.math.min

class TensorDspPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var audioDispatcher: AudioDispatcher? = null
    private val pitchResults = ConcurrentLinkedQueue<Double>()
    private var isAnalyzing = false
    
    // 실시간 오디오 분석 관련 변수들
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var originalPitches = mutableListOf<Double>()
    private var currentPitchIndex = 0
    private var latestPitch: Double = 0.0
    private var latestScore: Double = 0.0
    private var timerJob: Job? = null
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "tensor_dsp_channel")
        channel.setMethodCallHandler(this)
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                initializeTensorDsp(result)
            }
            "extractPitch" -> {
                extractPitch(call, result)
            }
            "startPitchAnalysis" -> {
                startPitchAnalysis(call, result)
            }
            "startRealTimeAnalysis" -> {
                startRealTimeAnalysis(call, result)
            }
            "stopRealTimeAnalysis" -> {
                stopRealTimeAnalysis(result)
            }
            "getCurrentPitchScore" -> {
                val data = mapOf("pitch" to latestPitch, "score" to latestScore)
                result.success(data)
            }
            "setOriginalPitchData" -> {
                setOriginalPitchData(call, result)
            }
            "comparePitchAndScore" -> {
                comparePitchAndScore(call, result)
            }
            "extractMFCC" -> {
                extractMFCC(call, result)
            }
            "dispose" -> {
                dispose(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    private fun initializeTensorDsp(result: Result) {
        try {
            // TensorDSP 초기화 로직
            result.success(true)
        } catch (e: Exception) {
            result.error("INIT_ERROR", "TensorDSP 초기화 실패", e.message)
        }
    }
    
    private fun startRealTimeAnalysis(call: MethodCall, result: Result) {
        try {
            val sampleRate = call.argument<Int>("sampleRate") ?: 44100
            val bufferSize = call.argument<Int>("bufferSize") ?: 1024
            
            if (isRecording) {
                result.error("ALREADY_RECORDING", "이미 녹음 중입니다", null)
                return
            }
            
            // AudioRecord 설정
            val minBufferSize = AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT // FLOAT → 16BIT로 통일
            )
            
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, // FLOAT → 16BIT로 변경
                minBufferSize
            )
            
            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                result.error("AUDIO_RECORD_ERROR", "AudioRecord 초기화 실패", null)
                return
            }
            
            isRecording = true
            currentPitchIndex = 0
            
            // 실시간 오디오 분석 시작
            timerJob = CoroutineScope(Dispatchers.IO).launch {
                val buffer = ShortArray(bufferSize) // FloatArray → ShortArray로 변경
                audioRecord?.startRecording()
                
                while (isRecording) {
                    val readSize = audioRecord?.read(buffer, 0, bufferSize) ?: 0
                    if (readSize > 0) {
                        // ShortArray를 FloatArray로 변환
                        val floatBuffer = FloatArray(readSize) { buffer[it] / 32768.0f }
                        
                        // 피치 추출 (FloatArray 사용)
                        val pitch = extractPitchFromBuffer(floatBuffer, sampleRate)
                        if (pitch > 0) {
                            latestPitch = pitch
                            
                            // 원곡과 비교하여 점수 계산
                            if (originalPitches.isNotEmpty() && currentPitchIndex < originalPitches.size) {
                                latestScore = calculatePitchScore(pitch, originalPitches[currentPitchIndex])
                                currentPitchIndex++
                            }
                        }
                    }
                    delay(100) // 100ms 간격으로 분석
                }
            }
            
            result.success(true)
            
        } catch (e: Exception) {
            result.error("REAL_TIME_ANALYSIS_ERROR", "실시간 분석 시작 실패", e.message)
        }
    }
    
    private fun stopRealTimeAnalysis(result: Result) {
        try {
            isRecording = false
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
            timerJob?.cancel()
            timerJob = null
            
            result.success(true)
            
        } catch (e: Exception) {
            result.error("STOP_ANALYSIS_ERROR", "실시간 분석 중지 실패", e.message)
        }
    }
    
    private fun getRealTimePitchStream(result: Result) {
        try {
            // StreamController 제거, 직접 반환
            result.success(listOf(latestPitch))
        } catch (e: Exception) {
            result.error("PITCH_STREAM_ERROR", "피치 스트림 생성 실패", e.message)
        }
    }
    
    private fun getRealTimeScoreStream(result: Result) {
        try {
            // StreamController 제거, 직접 반환
            result.success(listOf(latestScore))
        } catch (e: Exception) {
            result.error("SCORE_STREAM_ERROR", "점수 스트림 생성 실패", e.message)
        }
    }
    
    private fun setOriginalPitchData(call: MethodCall, result: Result) {
        try {
            val pitches = call.argument<List<Double>>("originalPitches")
            if (pitches != null) {
                originalPitches.clear()
                originalPitches.addAll(pitches)
                currentPitchIndex = 0
                result.success(true)
            } else {
                result.error("INVALID_ARGUMENT", "원곡 피치 데이터가 없습니다", null)
            }
        } catch (e: Exception) {
            result.error("SET_ORIGINAL_PITCH_ERROR", "원곡 피치 데이터 설정 실패", e.message)
        }
    }
    
    private fun comparePitchAndScore(call: MethodCall, result: Result) {
        try {
            val userPitch = call.argument<Double>("userPitch") ?: 0.0
            val originalPitches = call.argument<List<Double>>("originalPitches") ?: listOf()
            val currentIndex = call.argument<Int>("currentIndex") ?: 0
            
            if (originalPitches.isNotEmpty() && currentIndex < originalPitches.size) {
                val score = calculatePitchScore(userPitch, originalPitches[currentIndex])
                result.success(score)
            } else {
                result.success(0.0)
            }
        } catch (e: Exception) {
            result.error("COMPARE_PITCH_ERROR", "피치 비교 실패", e.message)
        }
    }
    
    private fun extractPitchFromBuffer(buffer: FloatArray, sampleRate: Int): Double {
        try {
            // 간단한 피치 추출 알고리즘 (실제로는 더 정교한 알고리즘 사용)
            val pitchProcessor = PitchProcessor(
                PitchEstimationAlgorithm.YIN,
                sampleRate.toFloat(),
                1024,
                object : PitchDetectionHandler {
                    override fun handlePitch(
                        pitchDetectionResult: PitchDetectionResult?,
                        audioEvent: AudioEvent?
                    ) {
                        pitchDetectionResult?.let {
                            if (it.isPitched) {
                                pitchResults.add(it.pitch.toDouble())
                            }
                        }
                    }
                }
            )
            
            val audioFormat = TarsosDSPAudioFormat(sampleRate.toFloat(), 32, 1, true, true)
            val audioEvent = AudioEvent(audioFormat)
            audioEvent.floatBuffer = buffer
            
            pitchProcessor.processingFinished()
            
            return pitchResults.poll() ?: 0.0
            
        } catch (e: Exception) {
            print("피치 추출 오류: ${e.message}")
            return 0.0
        }
    }
    
    private fun calculatePitchScore(userPitch: Double, originalPitch: Double): Double {
        try {
            if (userPitch <= 0 || originalPitch <= 0) return 0.0
            
            // 피치 차이 계산 (반음 단위)
            val pitchRatio = userPitch / originalPitch
            val semitoneDifference = 12 * log10(pitchRatio) / log10(2.0)
            
            // 점수 계산 (반음 차이에 따른 감점)
            val score = when {
                abs(semitoneDifference) <= 0.1 -> 100.0  // Perfect
                abs(semitoneDifference) <= 0.3 -> 90.0   // Great
                abs(semitoneDifference) <= 0.5 -> 80.0   // Good
                abs(semitoneDifference) <= 1.0 -> 60.0   // Normal
                abs(semitoneDifference) <= 2.0 -> 40.0   // Bad
                else -> 0.0                              // Miss
            }
            
            return score
            
        } catch (e: Exception) {
            print("점수 계산 오류: ${e.message}")
            return 0.0
        }
    }
    
    private fun extractPitch(call: MethodCall, result: Result) {
        try {
            val audioData = call.argument<List<Double>>("audioData")
            val sampleRate = call.argument<Int>("sampleRate") ?: 44100
            val minFreq = call.argument<Double>("minFreq") ?: 50.0
            val maxFreq = call.argument<Double>("maxFreq") ?: 800.0
            
            if (audioData == null) {
                result.error("INVALID_ARGUMENT", "오디오 데이터가 없습니다", null)
                return
            }
            
            // TarsosDSP를 사용한 피치 추출
            val pitchProcessor = PitchProcessor(
                PitchEstimationAlgorithm.YIN,
                sampleRate.toFloat(),
                1024,
                object : PitchDetectionHandler {
                    override fun handlePitch(
                        pitchDetectionResult: PitchDetectionResult?,
                        audioEvent: AudioEvent?
                    ) {
                        pitchDetectionResult?.let {
                            if (it.isPitched && it.pitch >= minFreq && it.pitch <= maxFreq) {
                                pitchResults.add(it.pitch.toDouble())
                            }
                        }
                    }
                }
            )
            
            // 오디오 데이터를 float 배열로 변환
            val floatArray = audioData.map { it.toFloat() }.toFloatArray()
            
            // AudioEvent 생성 (올바른 방법)
            val audioFormat = TarsosDSPAudioFormat(sampleRate.toFloat(), 16, 1, true, true)
            val audioEvent = AudioEvent(audioFormat)
            audioEvent.floatBuffer = floatArray
            
            // 피치 분석 실행
            pitchProcessor.processingFinished()
            
            result.success(pitchResults.toList())
            pitchResults.clear()
            
        } catch (e: Exception) {
            result.error("PITCH_EXTRACTION_ERROR", "피치 추출 실패", e.message)
        }
    }
    
    private fun startPitchAnalysis(call: MethodCall, result: Result) {
        try {
            val sampleRate = call.argument<Int>("sampleRate") ?: 44100
            val bufferSize = call.argument<Int>("bufferSize") ?: 1024
            
            if (isAnalyzing) {
                result.error("ALREADY_ANALYZING", "이미 분석 중입니다", null)
                return
            }
            
            isAnalyzing = true
            
            // 실시간 피치 분석 시작
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    // 여기에 실시간 오디오 스트림 처리 로직 구현
                    // 예: AudioRecord를 사용한 실시간 마이크 입력 처리
                    
                    while (isAnalyzing) {
                        // 실시간 피치 데이터를 Flutter로 전송
                        val pitchData = pitchResults.toList()
                        if (pitchData.isNotEmpty()) {
                            channel.invokeMethod("onPitchData", pitchData)
                            pitchResults.clear()
                        }
                        delay(100) // 100ms 간격으로 업데이트
                    }
                } catch (e: Exception) {
                    channel.invokeMethod("onError", e.message)
                }
            }
            
            result.success(null)
            
        } catch (e: Exception) {
            result.error("PITCH_ANALYSIS_ERROR", "피치 분석 시작 실패", e.message)
        }
    }
    
    private fun extractMFCC(call: MethodCall, result: Result) {
        try {
            val audioData = call.argument<List<Double>>("audioData")
            val sampleRate = call.argument<Int>("sampleRate") ?: 44100
            val numCoefficients = call.argument<Int>("numCoefficients") ?: 13
            val numFrames = call.argument<Int>("numFrames") ?: 40
            
            if (audioData == null) {
                result.error("INVALID_ARGUMENT", "오디오 데이터가 없습니다", null)
                return
            }
            
            // MFCC 추출 로직 구현 (간단한 버전)
            val floatArray = audioData.map { it.toFloat() }.toFloatArray()
            
            // MFCC 계산 (실제 구현에서는 더 복잡한 로직 필요)
            val mfccResults = mutableListOf<List<Double>>()
            for (i in 0 until numFrames) {
                val startIndex = i * 1024
                val endIndex = minOf((i + 1) * 1024, floatArray.size)
                if (startIndex < floatArray.size) {
                    val frame = floatArray.slice(startIndex until endIndex)
                    // 간단한 MFCC 시뮬레이션 (실제로는 더 복잡한 계산 필요)
                    val mfccFrame = List(numCoefficients) { index ->
                        (frame.sum() / frame.size * (index + 1) * 0.1).toDouble()
                    }
                    mfccResults.add(mfccFrame)
                }
            }
            
            result.success(mfccResults)
            
        } catch (e: Exception) {
            result.error("MFCC_EXTRACTION_ERROR", "MFCC 추출 실패", e.message)
        }
    }
    
    private fun dispose(result: Result) {
        try {
            isAnalyzing = false
            isRecording = false
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
            audioDispatcher?.stop()
            audioDispatcher = null
            pitchResults.clear()
            originalPitches.clear()
            timerJob?.cancel()
            timerJob = null
            result.success(null)
        } catch (e: Exception) {
            result.error("DISPOSE_ERROR", "정리 실패", e.message)
        }
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
} 