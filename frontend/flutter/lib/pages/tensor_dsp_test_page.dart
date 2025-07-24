import 'package:flutter/material.dart';
import 'dart:math';
import '../services/tensor_dsp_service.dart';

class TensorDspTestPage extends StatefulWidget {
  @override
  _TensorDspTestPageState createState() => _TensorDspTestPageState();
}

class _TensorDspTestPageState extends State<TensorDspTestPage> {
  bool _isInitialized = false;
  bool _isAnalyzing = false;
  List<double> _pitchData = [];
  List<List<double>> _mfccData = [];
  Map<String, dynamic> _spectrumData = {};
  Map<String, double> _voiceQualityData = {};
  String _statusMessage = '초기화되지 않음';

  @override
  void initState() {
    super.initState();
    _initializeTensorDsp();
  }

  Future<void> _initializeTensorDsp() async {
    setState(() {
      _statusMessage = 'TensorDSP 초기화 중...';
    });

    try {
      final success = await TensorDspService.initialize();
      setState(() {
        _isInitialized = success;
        _statusMessage = success ? '초기화 완료' : '초기화 실패';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '초기화 오류: $e';
      });
    }
  }

  Future<void> _testPitchExtraction() async {
    if (!_isInitialized) {
      _showSnackBar('먼저 TensorDSP를 초기화해주세요.');
      return;
    }

    setState(() {
      _statusMessage = '피치 추출 테스트 중...';
    });

    try {
      // 샘플 오디오 데이터 (440Hz 사인파)
      final sampleRate = 44100;
      final duration = 1.0; // 1초
      final frequency = 440.0; // A4 음

      final audioData = List<double>.generate(
        (sampleRate * duration).round(),
        (i) => 0.5 * sin(i / sampleRate * 2 * pi * frequency),
      );

      final pitchResults = await TensorDspService.extractPitch(
        audioData,
        sampleRate: sampleRate,
        minFreq: 50.0,
        maxFreq: 800.0,
      );

      setState(() {
        _pitchData = pitchResults;
        _statusMessage = '피치 추출 완료: ${pitchResults.length}개 데이터';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '피치 추출 오류: $e';
      });
    }
  }

  Future<void> _testMFCCExtraction() async {
    if (!_isInitialized) {
      _showSnackBar('먼저 TensorDSP를 초기화해주세요.');
      return;
    }

    setState(() {
      _statusMessage = 'MFCC 추출 테스트 중...';
    });

    try {
      // 샘플 오디오 데이터
      final sampleRate = 44100;
      final duration = 2.0; // 2초

      final audioData = List<double>.generate(
        (sampleRate * duration).round(),
        (i) =>
            0.3 * sin(i / sampleRate * 2 * pi * 440) +
            0.2 * sin(i / sampleRate * 2 * pi * 880),
      );

      final mfccResults = await TensorDspService.extractMFCC(
        audioData,
        sampleRate: sampleRate,
        numCoefficients: 13,
        numFrames: 20,
      );

      setState(() {
        _mfccData = mfccResults;
        _statusMessage = 'MFCC 추출 완료: ${mfccResults.length}개 프레임';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'MFCC 추출 오류: $e';
      });
    }
  }

  Future<void> _testSpectrumAnalysis() async {
    if (!_isInitialized) {
      _showSnackBar('먼저 TensorDSP를 초기화해주세요.');
      return;
    }

    setState(() {
      _statusMessage = '스펙트럼 분석 테스트 중...';
    });

    try {
      // 샘플 오디오 데이터
      final sampleRate = 44100;
      final duration = 1.0; // 1초

      final audioData = List<double>.generate(
        (sampleRate * duration).round(),
        (i) =>
            0.4 * sin(i / sampleRate * 2 * pi * 440) +
            0.3 * sin(i / sampleRate * 2 * pi * 660),
      );

      final spectrumResults = await TensorDspService.analyzeSpectrum(
        audioData,
        sampleRate: sampleRate,
        fftSize: 2048,
      );

      setState(() {
        _spectrumData = spectrumResults;
        _statusMessage = '스펙트럼 분석 완료';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '스펙트럼 분석 오류: $e';
      });
    }
  }

  Future<void> _testVoiceQualityAnalysis() async {
    if (!_isInitialized) {
      _showSnackBar('먼저 TensorDSP를 초기화해주세요.');
      return;
    }

    setState(() {
      _statusMessage = '음성 품질 분석 테스트 중...';
    });

    try {
      // 샘플 오디오 데이터
      final sampleRate = 44100;
      final duration = 3.0; // 3초

      final audioData = List<double>.generate(
        (sampleRate * duration).round(),
        (i) =>
            0.5 * sin(i / sampleRate * 2 * pi * 440) +
            0.1 * sin(i / sampleRate * 2 * pi * 220),
      );

      final qualityResults = await TensorDspService.analyzeVoiceQuality(
        audioData,
        sampleRate: sampleRate,
      );

      setState(() {
        _voiceQualityData = qualityResults;
        _statusMessage = '음성 품질 분석 완료';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '음성 품질 분석 오류: $e';
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TensorDSP 테스트'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 표시
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TensorDSP 상태',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isInitialized ? Icons.check_circle : Icons.error,
                          color: _isInitialized ? Colors.green : Colors.red,
                        ),
                        SizedBox(width: 8),
                        Expanded(child: Text(_statusMessage)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // 테스트 버튼들
            Text(
              '기능 테스트',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _testPitchExtraction,
                  child: Text('피치 추출'),
                ),
                ElevatedButton(
                  onPressed: _testMFCCExtraction,
                  child: Text('MFCC 추출'),
                ),
                ElevatedButton(
                  onPressed: _testSpectrumAnalysis,
                  child: Text('스펙트럼 분석'),
                ),
                ElevatedButton(
                  onPressed: _testVoiceQualityAnalysis,
                  child: Text('음성 품질'),
                ),
              ],
            ),

            SizedBox(height: 16),

            // 결과 표시
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_pitchData.isNotEmpty) ...[
                      _buildResultCard('피치 데이터', '${_pitchData.length}개 데이터'),
                      SizedBox(height: 8),
                    ],

                    if (_mfccData.isNotEmpty) ...[
                      _buildResultCard('MFCC 데이터', '${_mfccData.length}개 프레임'),
                      SizedBox(height: 8),
                    ],

                    if (_spectrumData.isNotEmpty) ...[
                      _buildResultCard('스펙트럼 데이터', '분석 완료'),
                      SizedBox(height: 8),
                    ],

                    if (_voiceQualityData.isNotEmpty) ...[
                      _buildResultCard('음성 품질 데이터', '분석 완료'),
                      SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(String title, String subtitle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    TensorDspService.dispose();
    super.dispose();
  }
}
