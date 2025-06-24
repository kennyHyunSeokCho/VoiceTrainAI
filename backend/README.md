# Backend - FastAPI Server

VoiceTrainingAI의 백엔드 API 서버

## 기술 스택
- FastAPI
- Python 3.8+
- PostgreSQL
- WebSocket
- AWS S3

## 주요 API
- `/auth/kakao` - 카카오톡 인증
- `/auth/sms` - SMS 인증
- `/recordings/upload` - 음성 데이터 업로드
- `/model/train` - RVC 모델 훈련 트리거
- `/model/infer` - 사용자 음성 버전 생성
- `/singing/session` - 피치 비교 결과 저장
- `/feedback/generate` - LLM 피드백 생성

## 설치 및 실행

```bash
pip install -r requirements.txt
uvicorn main:app --reload
``` 