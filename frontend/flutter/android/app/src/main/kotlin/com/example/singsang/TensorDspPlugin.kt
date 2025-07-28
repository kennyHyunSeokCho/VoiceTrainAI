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
import kotlin.math.pow
import kotlin.system.measureTimeMillis

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
    private var latestAudioLevel: Double = 0.0
    private var latestTimingScore: Double = 0.0
    private var recordingStartTime: Long = 0
    private var currentMidiNotes: List<MidiNote> = listOf()
    private var timerJob: Job? = null
    
    // 누적 점수 계산을 위한 변수들
    private var accumulatedPitchScores = mutableListOf<Double>()
    private var accumulatedTimingScores = mutableListOf<Double>()
    private var totalScoreCount = 0
    private var averagePitchScore: Double = 0.0
    private var averageTimingScore: Double = 0.0
    
    private data class MidiNote(
        val startTime: Double,  // 시작 시간 (초)
        val duration: Double,   // 길이 (초)
        val pitch: Int,        // MIDI 음정
        val velocity: Int = 64 // 기본 세기
    )
    
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
                val currentPitchScore: Double
                val currentTimingScore: Double
                val currentTotalCount: Int
                
                synchronized(this) {
                    currentPitchScore = averagePitchScore
                    currentTimingScore = averageTimingScore
                    currentTotalCount = totalScoreCount
                }
                
                val data = mapOf(
                    "pitch" to latestPitch,
                    "score" to currentPitchScore,  // 누적 평균 피치 점수
                    "audioLevel" to latestAudioLevel,
                    "timingScore" to currentTimingScore  // 누적 평균 타이밍 점수
                )
                println("[TensorDSP] getCurrentPitchScore 호출: data=$data (누적평균: 피치=${currentPitchScore.toInt()}, 타이밍=${currentTimingScore.toInt()}, 총점수수=$currentTotalCount)")
                result.success(data)
            }
            "setOriginalPitchData" -> {
                setOriginalPitchData(call, result)
            }
            "comparePitchAndScore" -> {
                comparePitchAndScore(call, result)
            }
            // "extractMFCC" -> {
            //     extractMFCC(call, result)
            // }
            "setMidiNotes" -> {
                try {
                    val notes = call.argument<List<Map<String, Any>>>("notes")
                    if (notes != null) {
                        currentMidiNotes = notes.map { note ->
                            MidiNote(
                                startTime = (note["startTime"] as Number).toDouble(),
                                duration = (note["duration"] as Number).toDouble(),
                                pitch = (note["pitch"] as Number).toInt(),
                                velocity = (note["velocity"] as? Number)?.toInt() ?: 64
                            )
                        }
                        // 로그 출력: 노트 개수와 첫 3개 노트 정보
                        println("[TensorDSP] MIDI 노트 전달받음: 총 ${currentMidiNotes.size}개")
                        currentMidiNotes.take(3).forEachIndexed { idx, note ->
                            println("[TensorDSP] 노트 ${idx+1}: 시작=${note.startTime}s, 길이=${note.duration}s, 음정=${note.pitch}, 벨로시티=${note.velocity}")
                        }
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "MIDI 노트 데이터가 없습니다", null)
                    }
                } catch (e: Exception) {
                    result.error("MIDI_NOTES_ERROR", "MIDI 노트 설정 실패", e.message)
                }
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
            println("[TensorDSP] 실시간 분석 시작 요청")
            
            val sampleRate = 44100
            val bufferSize = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
            
            println("[TensorDSP] AudioRecord 설정: sampleRate=$sampleRate, bufferSize=$bufferSize")
            
            // AudioRecord 초기화 시도 (여러 오디오 소스 시도)
            val audioSources = listOf(
                MediaRecorder.AudioSource.MIC,
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                MediaRecorder.AudioSource.DEFAULT
            )
            
            
            var audioRecord: AudioRecord? = null
            var selectedSource = MediaRecorder.AudioSource.MIC
            
            for (source in audioSources) {
                try {
                    println("[TensorDSP] AudioRecord 초기화 시도: source=$source")
                    audioRecord = AudioRecord(source, sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, bufferSize)
                    
                    if (audioRecord.state == AudioRecord.STATE_INITIALIZED) {
                        selectedSource = source
                        println("[TensorDSP] AudioRecord 초기화 성공: source=$source")
                        break
                    } else {
                        println("[TensorDSP] AudioRecord 초기화 실패: source=$source, state=${audioRecord.state}")
                        audioRecord.release()
                        audioRecord = null
                    }
                } catch (e: Exception) {
                    println("[TensorDSP] AudioRecord 초기화 예외: source=$source, error=${e.message}")
                    audioRecord?.release()
                    audioRecord = null
                }
            }
            
            if (audioRecord == null) {
                println("[TensorDSP] 모든 AudioRecord 초기화 실패")
                result.error("AUDIO_INIT_ERROR", "AudioRecord 초기화에 실패했습니다", null)
                return
            }
            
            // 분석 상태 초기화
            isAnalyzing = true
            var currentTime = 0.0
            latestPitch = 0.0
            latestScore = 0.0
            latestTimingScore = 0.0
            latestAudioLevel = 0.0
            
            // 누적 점수 초기화
            accumulatedPitchScores.clear()
            accumulatedTimingScores.clear()
            totalScoreCount = 0
            averagePitchScore = 0.0
            averageTimingScore = 0.0
            
            // 연속 0값 카운터 (디버깅용)
            var consecutiveZeroCount = 0
            
            println("[TensorDSP] 분석 상태 초기화 완료")
            
            // 분석 스레드 시작
            Thread {
                try {
                    audioRecord.startRecording()
                    println("[TensorDSP] AudioRecord 녹음 시작")
                    
                    val buffer = ShortArray(bufferSize)
                    val floatBuffer = FloatArray(bufferSize)
                    
                    while (isAnalyzing) {
                        val readSize = audioRecord.read(buffer, 0, bufferSize)
                        
                        if (readSize > 0) {
                            // 버퍼 분석 (더 자세한 로그)
                            var nonZeroCount = 0
                            var maxValue = 0
                            var minValue = 0
                            var sum = 0L
                            
                            for (i in 0 until readSize) {
                                val value = buffer[i]
                                if (value != 0.toShort()) {
                                    nonZeroCount++
                                    if (value > maxValue) maxValue = value.toInt()
                                    if (value < minValue) minValue = value.toInt()
                                }
                                sum += value.toLong()
                            }
                            
                            // 연속 0값 카운트
                            if (nonZeroCount == 0) {
                                consecutiveZeroCount++
                            } else {
                                consecutiveZeroCount = 0
                            }
                            
                            // Float 변환
                            for (i in 0 until readSize) {
                                floatBuffer[i] = buffer[i] / 32768.0f
                            }
                            
                            // 오디오 레벨 계산 (더 민감한 방법)
                            latestAudioLevel = calculateAudioLevelSensitive(floatBuffer, readSize)
                            
                            println("[TensorDSP] AudioRecord read 성공: readSize=$readSize, buffer[0]=${buffer[0]}, nonZeroCount=$nonZeroCount, maxValue=$maxValue, minValue=$minValue, avg=${if (readSize > 0) sum / readSize else 0}, consecutiveZeroCount=$consecutiveZeroCount")
                            
                            // 피치 추출
                            val pitch = extractPitchFromBuffer(floatBuffer, sampleRate)
                            if (pitch > 0) {
                                latestPitch = pitch
                                println("[TensorDSP] 피치 감지: pitch=$pitch")
                            }
                            
                            // 점수 계산 (오디오 레벨이 낮아도 일정 수준까진 계산)
                            if (latestAudioLevel > 0.1) {  // 더 낮은 임계값
                                val scores = calculateScores(latestPitch, currentTime)
                                val pitchScore = scores.first
                                val timingScore = scores.second
                                
                                if (pitchScore > 0 || timingScore > 0) {
                                    synchronized(this) {
                                        accumulatedPitchScores.add(pitchScore)
                                        accumulatedTimingScores.add(timingScore)
                                        totalScoreCount++
                                        
                                        // 평균 계산
                                        averagePitchScore = accumulatedPitchScores.average()
                                        averageTimingScore = accumulatedTimingScores.average()
                                    }
                                    
                                    println("[TensorDSP] 점수 계산: pitchScore=$pitchScore, timingScore=$timingScore, 누적평균: 피치=${averagePitchScore.toInt()}, 타이밍=${averageTimingScore.toInt()}")
                                }
                            } else {
                                println("[TensorDSP] 오디오 레벨이 너무 낮음: $latestAudioLevel, 점수 계산 생략")
                            }
                            
                            currentTime += readSize.toDouble() / sampleRate
                        } else {
                            println("[TensorDSP] AudioRecord read 실패: readSize=$readSize")
                        }
                        
                        Thread.sleep(10) // 10ms 대기
                    }
                    
                    audioRecord.stop()
                    audioRecord.release()
                    println("[TensorDSP] AudioRecord 정리 완료")
                    
                } catch (e: Exception) {
                    println("[TensorDSP] 분석 스레드 예외: ${e.message}")
                    e.printStackTrace()
                    audioRecord?.release()
                }
            }.start()
            
            result.success(true)
            
        } catch (e: Exception) {
            println("[TensorDSP] startRealTimeAnalysis 예외: ${e.message}")
            e.printStackTrace()
            result.error("ANALYSIS_ERROR", "실시간 분석 시작 실패: ${e.message}", null)
        }
    }
    
    private fun stopRealTimeAnalysis(result: Result) {
        try {
            println("[TensorDSP] 실시간 분석 중지 요청")
            
            // 분석 플래그들을 모두 false로 설정
            isAnalyzing = false
            isRecording = false
            
            // AudioRecord 정리
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
            
            // 타이머 작업 취소
            timerJob?.cancel()
            timerJob = null
            
            println("[TensorDSP] 실시간 분석 중지 완료")
            result.success(true)
            
        } catch (e: Exception) {
            println("[TensorDSP] 실시간 분석 중지 오류: ${e.message}")
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
        return try {
            var detectedPitch = 0.0
            var maxProbability = 0.0f
            
            // 버퍼 값 로그 추가
            println("[TensorDSP] extractPitchFromBuffer 시작: buffer.size=${buffer.size}, buffer[0]=${buffer.getOrNull(0)}")
            
            val handler = PitchDetectionHandler { pitchDetectionResult, _ ->
                println("[TensorDSP] PitchDetectionHandler 호출: pitchInHz=${pitchDetectionResult?.pitch}, probability=${pitchDetectionResult?.probability}, isPitched=${pitchDetectionResult?.isPitched}")
                if (pitchDetectionResult != null) {
                    // 더 관대한 피치 감지 조건 (확률 임계값을 더 낮게 조정)
                    if (pitchDetectionResult.pitch > 50.0 && 
                        pitchDetectionResult.pitch < 2000.0 && 
                        pitchDetectionResult.probability > 0.05) {  // 0.1에서 0.05로 변경
                        if (pitchDetectionResult.probability > maxProbability) {
                            maxProbability = pitchDetectionResult.probability
                            detectedPitch = pitchDetectionResult.pitch.toDouble()
                            println("[TensorDSP] 피치 감지됨: $detectedPitch Hz (확률: ${pitchDetectionResult.probability})")
                        }
                    }
                }
            }
            
            val pitchProcessor = PitchProcessor(
                PitchEstimationAlgorithm.YIN,
                sampleRate.toFloat(),
                buffer.size,
                handler
            )
            
            // AudioEvent 생성 방식 개선
            val audioFormat = TarsosDSPAudioFormat(sampleRate.toFloat(), 16, 1, true, false)
            val audioEvent = AudioEvent(audioFormat)
            
            // 버퍼 할당 방식 개선
            audioEvent.floatBuffer = buffer
            
            println("[TensorDSP] AudioEvent 생성 완료: format=$audioFormat, bufferSize=${audioEvent.floatBuffer.size}")
            
            // 피치 처리 실행
            pitchProcessor.process(audioEvent)
            pitchProcessor.processingFinished()
            
            println("[TensorDSP] extractPitchFromBuffer 완료: detectedPitch=$detectedPitch, maxProbability=$maxProbability")
            detectedPitch
            
        } catch (e: Exception) {
            println("[TensorDSP] 피치 추출 오류: ${e.message}")
            e.printStackTrace()
            0.0
        }
    }
    
    private fun calculatePitchScore(userPitch: Double, originalPitch: Double): Double {
        try {
            if (userPitch <= 0 || originalPitch <= 0) {
                println("[TensorDSP] 피치 점수 계산 실패: 사용자=$userPitch Hz, 기준=$originalPitch Hz")
                return 0.0
            }
            
            // 피치 차이 계산 (반음 단위)
            val pitchRatio = userPitch / originalPitch
            val semitoneDifference = 12 * log10(pitchRatio) / log10(2.0)
            
            println("[TensorDSP] 피치 점수 계산: 사용자=$userPitch Hz, 기준=$originalPitch Hz, 반음차이=${abs(semitoneDifference)}")
            
            // 더 관대한 점수 계산 (옥타브 차이까지 고려)
            val absSemitoneDiff = abs(semitoneDifference)
            val score = when {
                absSemitoneDiff <= 0.5 -> 100.0      // Perfect (정확)
                absSemitoneDiff <= 1.0 -> 95.0       // Great (거의 정확)
                absSemitoneDiff <= 2.0 -> 90.0       // Good (좋음)
                absSemitoneDiff <= 4.0 -> 80.0       // Normal (보통)
                absSemitoneDiff <= 6.0 -> 65.0       // Fair (양호)
                absSemitoneDiff <= 8.0 -> 50.0       // Poor (미흡)
                absSemitoneDiff <= 12.0 -> 35.0      // Very Poor (매우 미흡, 옥타브 차이 허용)
                absSemitoneDiff <= 16.0 -> 20.0      // Barely Acceptable (간신히 허용)
                absSemitoneDiff <= 24.0 -> 10.0      // Octave Error (옥타브 오차)
                else -> 5.0                          // Miss (완전히 벗어남도 최소 점수)
            }
            
            println("[TensorDSP] 피치 점수 결과: $score (반음차이: $absSemitoneDiff)")
            return score
            
        } catch (e: Exception) {
            println("[TensorDSP] 점수 계산 오류: ${e.message}")
            e.printStackTrace()
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

    private fun findCurrentMidiNote(currentTime: Double): MidiNote? {
        if (currentMidiNotes.isEmpty()) {
            println("[TensorDSP] [findCurrentMidiNote] MIDI 노트가 없음")
            return null
        }
        
        val first = currentMidiNotes.first()
        val last = currentMidiNotes.last()
        println("[TensorDSP] [findCurrentMidiNote] MIDI 노트 범위: ${first.startTime} ~ ${last.startTime + last.duration}, currentTime: $currentTime")
        
        // 가장 가까운 노트 찾기 (더 관대한 매칭)
        val note = currentMidiNotes.firstOrNull { n ->
            val noteEnd = n.startTime + n.duration
            // 노트 시작 전 0.5초부터 노트 끝 후 0.5초까지 허용
            currentTime >= (n.startTime - 0.5) && currentTime <= (noteEnd + 0.5)
        }
        
        if (note != null) {
            println("[TensorDSP] [findCurrentMidiNote] 매칭된 노트: start=${note.startTime}, dur=${note.duration}, pitch=${note.pitch}")
        } else {
            println("[TensorDSP] [findCurrentMidiNote] 매칭되는 노트 없음")
        }
        return note
    }

    // MIDI 노트 번호를 주파수로 변환하는 함수
    private fun midiNoteToFrequency(midiNote: Int): Double {
        return 440.0 * Math.pow(2.0, (midiNote - 69) / 12.0)
    }

    private fun calculateScores(userPitch: Double, currentTime: Double): Pair<Double, Double> {
        // MIDI 노트 번호를 실제 주파수로 변환
        val midiFrequency = midiNoteToFrequency(currentMidiNotes.first().pitch) // 현재 노트의 주파수
        
        println("[TensorDSP] 점수 계산: 사용자피치=${userPitch}Hz, MIDI노트=${currentMidiNotes.first().pitch}번(${midiFrequency}Hz)")
        
        // 피치 점수 계산 (실제 주파수 비교)
        val pitchScore = calculatePitchScore(userPitch, midiFrequency)
        
        // 타이밍 점수 계산
        val timingScore = calculateTimingScore(currentTime, currentMidiNotes.first())
        
        println("[TensorDSP] 점수 결과: 피치점수=$pitchScore, 타이밍점수=$timingScore")
        
        return Pair(pitchScore, timingScore)
    }

    private fun calculateTimingScore(currentTime: Double, midiNote: MidiNote): Double {
        val noteStart = midiNote.startTime
        val noteEnd = noteStart + midiNote.duration
        
        // 허용 오차 범위를 더 관대하게 조정 (초)
        val tolerance = 0.2
        
        val timingScore = when {
            // 정확한 타이밍 (허용 오차 내)
            abs(currentTime - noteStart) <= tolerance -> 100.0
            
            // 노트 중간 부분
            currentTime in noteStart..noteEnd -> 80.0
            
            // 노트 시작 전이나 후 (더 관대한 범위)
            abs(currentTime - noteStart) <= tolerance * 3 -> 60.0
            abs(currentTime - noteEnd) <= tolerance * 3 -> 40.0
            
            // 완전히 벗어남
            else -> 0.0
        }
        
        println("[TensorDSP] 타이밍 점수 계산: 현재시간=$currentTime, 노트시작=$noteStart, 노트끝=$noteEnd, 점수=$timingScore")
        
        return timingScore
    }
    
    private fun calculateAudioLevel(buffer: FloatArray): Double {
        if (buffer.isEmpty()) {
            println("[TensorDSP] calculateAudioLevel: 버퍼가 비어있음")
            return 0.0
        }
        
        // RMS (Root Mean Square) 계산
        var sum = 0.0
        for (sample in buffer) {
            sum += (sample * sample).toDouble()
        }
        val rms = kotlin.math.sqrt(sum / buffer.size)
        
        // 더 민감한 오디오 레벨 계산 (매우 작은 소리도 감지)
        // RMS 값을 더 민감하게 매핑하여 작은 소리도 감지할 수 있도록 함
        val normalizedLevel = when {
            rms <= 0.00001 -> 0.0     // 완전 무음
            rms <= 0.0001 -> rms * 100000.0  // 극도로 작은 소리 (0-10%)
            rms <= 0.001 -> rms * 10000.0    // 매우 작은 소리 (10-100%)
            rms <= 0.01 -> rms * 1000.0      // 작은 소리 (100-1000%)
            rms <= 0.1 -> rms * 100.0        // 보통 소리 (1000-10000%)
            else -> 100.0                     // 큰 소리 (최대)
        }
        
        // 0-100 범위로 제한
        val finalLevel = kotlin.math.max(0.0, kotlin.math.min(100.0, normalizedLevel))
        
        println("[TensorDSP] calculateAudioLevel: buffer.size=${buffer.size}, buffer[0]=${buffer.getOrNull(0)}, rms=$rms, normalizedLevel=$finalLevel")
        
        return finalLevel
    }

    private fun calculateAudioLevelSensitive(buffer: FloatArray, readSize: Int): Double {
        if (readSize == 0) return 0.0

        var sum = 0.0
        for (i in 0 until readSize) {
            sum += (buffer[i] * buffer[i]).toDouble()
        }
        val rms = kotlin.math.sqrt(sum / readSize)

        // 더 민감한 오디오 레벨 계산 (매우 작은 소리도 감지)
        // RMS 값을 더 민감하게 매핑하여 작은 소리도 감지할 수 있도록 함
        val normalizedLevel = when {
            rms <= 0.00001 -> 0.0     // 완전 무음
            rms <= 0.0001 -> rms * 100000.0  // 극도로 작은 소리 (0-10%)
            rms <= 0.001 -> rms * 10000.0    // 매우 작은 소리 (10-100%)
            rms <= 0.01 -> rms * 1000.0      // 작은 소리 (100-1000%)
            rms <= 0.1 -> rms * 100.0        // 보통 소리 (1000-10000%)
            else -> 100.0                     // 큰 소리 (최대)
        }

        // 0-100 범위로 제한
        val finalLevel = kotlin.math.max(0.0, kotlin.math.min(100.0, normalizedLevel))

        return finalLevel
    }
} 