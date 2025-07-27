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
                val data = mapOf(
                    "pitch" to latestPitch,
                    "score" to averagePitchScore,  // 누적 평균 피치 점수
                    "audioLevel" to latestAudioLevel,
                    "timingScore" to averageTimingScore  // 누적 평균 타이밍 점수
                )
                println("[TensorDSP] getCurrentPitchScore 호출: data=$data (누적평균: 피치=${averagePitchScore.toInt()}, 타이밍=${averageTimingScore.toInt()}, 총점수수=$totalScoreCount)")
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
            if (isRecording) {
                println("[TensorDSP] 이미 분석 중입니다")
                result.success(true)
                return
            }
            
            val sampleRate = 44100
            val bufferSize = 1024
            
            println("[TensorDSP] 실시간 분석 시작 준비: sampleRate=$sampleRate, bufferSize=$bufferSize")
            
            // AudioRecord 설정
            val minBufferSize = AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            
            println("[TensorDSP] AudioRecord 설정: sampleRate=$sampleRate, minBufferSize=$minBufferSize, bufferSize=$bufferSize")
            
            // 여러 오디오 소스 시도
            val audioSources = listOf(
                MediaRecorder.AudioSource.MIC,
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                MediaRecorder.AudioSource.DEFAULT
            )
            
            var audioRecordCreated = false
            for (audioSource in audioSources) {
                try {
                    println("[TensorDSP] 오디오 소스 시도: $audioSource")
                    
                    audioRecord = AudioRecord(
                        audioSource,
                        sampleRate,
                        AudioFormat.CHANNEL_IN_MONO,
                        AudioFormat.ENCODING_PCM_16BIT,
                        minBufferSize
                    )
                    
                    if (audioRecord?.state == AudioRecord.STATE_INITIALIZED) {
                        println("[TensorDSP] AudioRecord 초기화 성공: audioSource=$audioSource")
                        audioRecordCreated = true
                        break
                    } else {
                        println("[TensorDSP] AudioRecord 초기화 실패: audioSource=$audioSource, state=${audioRecord?.state}")
                        audioRecord?.release()
                        audioRecord = null
                    }
                } catch (e: Exception) {
                    println("[TensorDSP] AudioRecord 생성 실패: audioSource=$audioSource, error=${e.message}")
                    audioRecord?.release()
                    audioRecord = null
                }
            }
            
            if (!audioRecordCreated) {
                println("[TensorDSP] 모든 오디오 소스에서 AudioRecord 생성 실패")
                result.error("AUDIO_RECORD_ERROR", "AudioRecord 초기화 실패", null)
                return
            }
            
            recordingStartTime = System.currentTimeMillis()
            isRecording = true
            currentPitchIndex = 0
            
            // 누적 점수 초기화
            accumulatedPitchScores.clear()
            accumulatedTimingScores.clear()
            totalScoreCount = 0
            averagePitchScore = 0.0
            averageTimingScore = 0.0
            println("[TensorDSP] 누적 점수 초기화 완료")
            
            // 실시간 오디오 분석 시작
            timerJob = CoroutineScope(Dispatchers.IO).launch {
                val buffer = ShortArray(bufferSize)
                audioRecord?.startRecording()
                println("[TensorDSP] 실시간 분석 시작: bufferSize=$bufferSize, sampleRate=$sampleRate")
                
                // 초기 버퍼 테스트
                val testReadSize = audioRecord?.read(buffer, 0, bufferSize) ?: 0
                println("[TensorDSP] 초기 버퍼 테스트: readSize=$testReadSize, buffer[0]=${buffer.getOrNull(0)}")
                
                while (isRecording) {
                    val readSize = audioRecord?.read(buffer, 0, bufferSize) ?: 0
                    
                    // AudioRecord read 결과 로그
                    if (readSize > 0) {
                        // 버퍼 값 상세 분석
                        val nonZeroCount = buffer.take(readSize).count { it != 0.toShort() }
                        val maxValue = buffer.take(readSize).maxOrNull() ?: 0.toShort()
                        val minValue = buffer.take(readSize).minOrNull() ?: 0.toShort()
                        
                        println("[TensorDSP] AudioRecord read 성공: readSize=$readSize, buffer[0]=${buffer.getOrNull(0)}, nonZeroCount=$nonZeroCount, maxValue=$maxValue, minValue=$minValue")
                        
                        val floatBuffer = FloatArray(readSize) { buffer[it] / 32768.0f }
                        println("[TensorDSP] Float 변환 완료: floatBuffer[0]=${floatBuffer.getOrNull(0)}, maxFloat=${floatBuffer.maxOrNull()}, minFloat=${floatBuffer.minOrNull()}")
                        
                        latestAudioLevel = calculateAudioLevel(floatBuffer)
                        println("[TensorDSP] 오디오 레벨 계산 완료: latestAudioLevel=$latestAudioLevel")
                        
                        val currentTime = (System.currentTimeMillis() - recordingStartTime) / 1000.0
                        val pitch = extractPitchFromBuffer(floatBuffer, sampleRate)
                        
                        // 디버깅을 위한 상세 로그
                        println("[TensorDSP] [디버그] currentTime=$currentTime, pitch=$pitch, audioLevel=$latestAudioLevel")
                        
                        // MIDI 노트 범위 및 마이크 입력 로그
                        if (currentMidiNotes.isNotEmpty()) {
                            val first = currentMidiNotes.first()
                            val last = currentMidiNotes.last()
                            println("[TensorDSP] [분석루프] currentTime: $currentTime, RMS: $latestAudioLevel, 피치: $pitch | MIDI 첫: start=${first.startTime}, pitch=${first.pitch}, dur=${first.duration} / 마지막: start=${last.startTime}, pitch=${last.pitch}, dur=${last.duration}")
                        } else {
                            println("[TensorDSP] [분석루프] currentTime: $currentTime, RMS: $latestAudioLevel, 피치: $pitch | MIDI 노트 없음")
                        }
                        
                                // 오디오 레벨이 너무 낮으면 점수 계산하지 않음
        if (latestAudioLevel < 5.0) {
            println("[TensorDSP] 오디오 레벨이 너무 낮음: $latestAudioLevel, 점수 계산 생략")
            latestScore = 0.0
            latestTimingScore = 0.0
            // 피치도 리셋 (소리가 없으면 피치도 의미없음)
            if (latestAudioLevel < 1.0) {
                latestPitch = 0.0
            }
        } else {
            // 피치 감지 조건 수정 (실제로 감지된 피치인지 확인)
            if (pitch > 0) {
                latestPitch = pitch
                println("[TensorDSP] 피치 감지됨: $pitch Hz")

                val currentNote = findCurrentMidiNote(currentTime)
                if (currentNote != null) {
                    val (pitchScore, timingScore) = calculateScores(pitch, currentTime, currentNote)
                    latestScore = pitchScore
                    latestTimingScore = timingScore
                    
                    // 누적 점수 업데이트 (0이 아닌 점수만 누적)
                    if (pitchScore > 0.0) {
                        accumulatedPitchScores.add(pitchScore)
                        totalScoreCount++
                    }
                    if (timingScore > 0.0) {
                        accumulatedTimingScores.add(timingScore)
                    }
                    
                    // 평균 계산
                    averagePitchScore = if (accumulatedPitchScores.isNotEmpty()) accumulatedPitchScores.average() else 0.0
                    averageTimingScore = if (accumulatedTimingScores.isNotEmpty()) accumulatedTimingScores.average() else 0.0
                    
                    println("🎵 분석: 시간=${currentTime.toInt()}초, 피치=${pitch.toInt()}Hz, 점수=$pitchScore, 타이밍=$timingScore, MIDI=${currentNote.pitch}")
                    println("📊 누적평균: 피치=${averagePitchScore.toInt()}, 타이밍=${averageTimingScore.toInt()}, 총점수수=$totalScoreCount")
                } else {
                    println("[TensorDSP] 현재 시간(${currentTime.toInt()}초)에 해당하는 MIDI 노트 없음")
                    // MIDI 노트가 없어도 기본 점수 설정
                    latestScore = 0.0
                    latestTimingScore = 0.0
                }
            } else {
                // 피치가 감지되지 않았지만 이전 피치 값이 있고 오디오 레벨이 충분하면 유지
                if (latestPitch > 0 && latestAudioLevel >= 10.0) {
                    println("[TensorDSP] 피치 추출 실패했지만 이전 피치 유지: pitch=$pitch, latestPitch=$latestPitch, audioLevel=$latestAudioLevel")
                    // 이전 피치 값으로 계속 분석
                    val currentNote = findCurrentMidiNote(currentTime)
                    if (currentNote != null) {
                        val (pitchScore, timingScore) = calculateScores(latestPitch, currentTime, currentNote)
                        latestScore = pitchScore
                        latestTimingScore = timingScore
                        
                        // 누적 점수 업데이트 (0이 아닌 점수만 누적)
                        if (pitchScore > 0.0) {
                            accumulatedPitchScores.add(pitchScore)
                            totalScoreCount++
                        }
                        if (timingScore > 0.0) {
                            accumulatedTimingScores.add(timingScore)
                        }
                        
                        // 평균 계산
                        averagePitchScore = if (accumulatedPitchScores.isNotEmpty()) accumulatedPitchScores.average() else 0.0
                        averageTimingScore = if (accumulatedTimingScores.isNotEmpty()) accumulatedTimingScores.average() else 0.0
                        
                        println("🎵 분석(이전피치): 시간=${currentTime.toInt()}초, 피치=${latestPitch.toInt()}Hz, 점수=$pitchScore, 타이밍=$timingScore, MIDI=${currentNote.pitch}")
                        println("📊 누적평균: 피치=${averagePitchScore.toInt()}, 타이밍=${averageTimingScore.toInt()}, 총점수수=$totalScoreCount")
                    } else {
                        println("[TensorDSP] 현재 시간(${currentTime.toInt()}초)에 해당하는 MIDI 노트 없음")
                        latestScore = 0.0
                        latestTimingScore = 0.0
                    }
                } else {
                    println("[TensorDSP] 피치 추출 실패 또는 오디오 레벨 부족: pitch=$pitch, audioLevel=$latestAudioLevel")
                    // 피치가 없어도 기본값 설정
                    latestPitch = 0.0
                    latestScore = 0.0
                    latestTimingScore = 0.0
                }
            }
        }
                    } else {
                        println("[TensorDSP] AudioRecord read 실패: readSize=$readSize")
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
        return try {
            var detectedPitch = 0.0
            var maxProbability = 0.0f
            
            // 버퍼 값 로그 추가
            println("[TensorDSP] extractPitchFromBuffer 시작: buffer.size=${buffer.size}, buffer[0]=${buffer.getOrNull(0)}")
            
            val handler = PitchDetectionHandler { pitchDetectionResult, _ ->
                println("[TensorDSP] PitchDetectionHandler 호출: pitchInHz=${pitchDetectionResult?.pitch}, probability=${pitchDetectionResult?.probability}, isPitched=${pitchDetectionResult?.isPitched}")
                if (pitchDetectionResult != null) {
                    // 더 관대한 피치 감지 조건 (확률도 고려)
                    if (pitchDetectionResult.pitch > 50.0 && 
                        pitchDetectionResult.pitch < 2000.0 && 
                        pitchDetectionResult.probability > 0.1) {  // 확률 임계값 추가
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
            
            // 옥타브 차이를 고려한 점수 계산 (더 관대한 기준)
            val absSemitoneDiff = abs(semitoneDifference)
            val score = when {
                absSemitoneDiff <= 0.5 -> 100.0      // Perfect (정확)
                absSemitoneDiff <= 1.0 -> 95.0       // Great (거의 정확)
                absSemitoneDiff <= 2.0 -> 85.0       // Good (좋음)
                absSemitoneDiff <= 4.0 -> 70.0       // Normal (보통)
                absSemitoneDiff <= 6.0 -> 50.0       // Fair (양호)
                absSemitoneDiff <= 8.0 -> 30.0       // Poor (미흡)
                absSemitoneDiff <= 12.0 -> 15.0      // Very Poor (매우 미흡, 옥타브 차이 허용)
                absSemitoneDiff <= 16.0 -> 5.0       // Barely Acceptable (간신히 허용)
                else -> 0.0                          // Miss (완전히 벗어남)
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

    private fun calculateScores(userPitch: Double, currentTime: Double, midiNote: MidiNote): Pair<Double, Double> {
        // MIDI 노트 번호를 실제 주파수로 변환
        val midiFrequency = midiNoteToFrequency(midiNote.pitch)
        
        println("[TensorDSP] 점수 계산: 사용자피치=${userPitch}Hz, MIDI노트=${midiNote.pitch}번(${midiFrequency}Hz)")
        
        // 피치 점수 계산 (실제 주파수 비교)
        val pitchScore = calculatePitchScore(userPitch, midiFrequency)
        
        // 타이밍 점수 계산
        val timingScore = calculateTimingScore(currentTime, midiNote)
        
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
        
        // 더 민감한 오디오 레벨 계산 (RMS를 직접 사용)
        // RMS 값이 0.001 정도면 약 10-20% 레벨로 계산
        val normalizedLevel = when {
            rms <= 0.0001 -> 0.0      // 무음
            rms <= 0.001 -> rms * 10000.0  // 매우 작은 소리 (0-10%)
            rms <= 0.01 -> rms * 1000.0    // 작은 소리 (10-100%)
            rms <= 0.1 -> rms * 100.0      // 보통 소리 (100-1000%)
            else -> 100.0                   // 큰 소리 (최대)
        }
        
        // 0-100 범위로 제한
        val finalLevel = kotlin.math.max(0.0, kotlin.math.min(100.0, normalizedLevel))
        
        println("[TensorDSP] calculateAudioLevel: buffer.size=${buffer.size}, buffer[0]=${buffer.getOrNull(0)}, rms=$rms, normalizedLevel=$finalLevel")
        
        return finalLevel
    }
} 