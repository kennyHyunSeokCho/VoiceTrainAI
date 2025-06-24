# VoiceTrainingAI 🎤

AI 기반 개인 맞춤형 음성 훈련 모바일 애플리케이션

## 프로젝트 개요

VoiceTrainingAI는 사용자가 자신만의 개인화된 음성 모델을 구축하고 노래 성능에 대한 피치 기반 피드백을 받을 수 있는 AI 기반 음성 훈련 모바일 애플리케이션입니다.

### 주요 기능

- **개인 음성 모델 생성**: RVC V2 기반으로 사용자 음성 모델 생성
- **노래 가져오기 및 음성 교체**: 원본 버전 또는 개인 음성 모델 버전 선택
- **실시간 피치 시각화**: 노래방 스타일 인터페이스로 피치 비교
- **LLM 기반 음성 성능 피드백**: 자연어로 개선 방향 제시
- **카카오톡/SMS 인증**: 안전한 사용자 인증

## 기술 스택

### Frontend
- **Framework**: Flutter (iOS/Android 크로스 플랫폼)

### Backend
- **API**: FastAPI (RESTful API + WebSocket)
- **Database**: PostgreSQL
- **Storage**: AWS S3

### AI/ML
- **Voice Model**: RVC V2
- **Pitch Analysis**: CREPE 또는 YIN
- **LLM**: GPT-4o 또는 로컬 LLM

### Tools
- **Audio Processing**: ffmpeg, demucs, librosa
- **ML Framework**: PyTorch, TensorFlow/ONNX

## 프로젝트 구조

```
VoiceTrainingAI/
├── frontend/           # Flutter 모바일 앱
├── backend/           # FastAPI 백엔드 서버
├── model-server/      # RVC V2 모델 서버
├── docs/             # 프로젝트 문서
├── tests/            # 테스트 코드
├── scripts/          # 유틸리티 스크립트
└── .taskmaster/      # 작업 관리 파일
```

## 설치 및 실행

### 사전 요구사항
- Python 3.8+
- Node.js 16+
- Flutter SDK
- GPU (모델 훈련용)

### 설정 방법

1. **저장소 클론**
```bash
git clone <repository-url>
cd VoiceTrainingAI
```

2. **백엔드 설정**
```bash
cd backend
pip install -r requirements.txt
```

3. **프론트엔드 설정**
```bash
cd frontend
flutter pub get
```

4. **환경 변수 설정**
```bash
cp .env.example .env
# .env 파일에 필요한 API 키들 설정
```

## 개발 로드맵

### Phase 1 - MVP
- [x] KakaoTalk/SMS 사용자 인증
- [ ] 음성 녹음 및 RVC V2 모델 생성
- [ ] 노래 업로드 및 보컬 분리
- [ ] 기본 노래방 UI (실시간 피치 비교)
- [ ] 규칙 기반 피드백 (LLM 아님)

### Phase 2 - 향상된 기능
- [ ] LLM 통합으로 개인화된 피드백
- [ ] 음성 성능 분석 (히트맵, 피치 점수)
- [ ] 모바일 성능 및 접근성을 위한 UI/UX 개선

### Phase 3 - 커뮤니티 및 확장
- [ ] 사용자 생성 커버 소셜 공유
- [ ] 리더보드 또는 챌린지 모드
- [ ] 프리미엄 기능 또는 노래 구독 모델

## 라이센스

이 프로젝트는 MIT 라이센스 하에 배포됩니다.

## 기여하기

프로젝트에 기여하고 싶다면 이슈를 생성하거나 풀 리퀘스트를 보내주세요. 