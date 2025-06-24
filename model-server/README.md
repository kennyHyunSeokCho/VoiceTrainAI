# Model Server - RVC V2

VoiceTrainingAI의 음성 모델 훈련 및 추론 서버

## 기술 스택
- PyTorch
- RVC V2 (Real-time Voice Conversion)
- CREPE (피치 추출)
- librosa (오디오 처리)

## 주요 기능
- 사용자 음성 데이터로 개인 음성 모델 훈련
- 훈련된 모델을 사용한 음성 합성
- 실시간 피치 추출 및 분석

## GPU 요구사항
- RTX 4090 또는 동급 GPU 권장
- CUDA 11.8+

## 설치 및 실행

```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
pip install -r requirements.txt
python server.py
``` 