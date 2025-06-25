# AI 보컬 트레이닝 시스템 (AVTS) 🎤✨

> **개인화된 AI 기반 보컬 트레이닝으로 당신의 노래 실력을 한 단계 업그레이드하세요**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=flat&logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)](https://python.org)

## 📖 프로젝트 개요

**AI 보컬 트레이닝 시스템(AVTS)**은 사용자가 자신의 음성을 녹음하여 개인화된 음성 합성 모델을 만들고, 노래를 따라 부르며 실시간 피드백을 받을 수 있는 혁신적인 AI 기반 보컬 트레이닝 앱입니다.

기존 보컬 교육의 한계를 극복하여 **실시간 피드백**, **개인화된 학습**, **감정 및 스타일 분석** 기능을 통합, 초보자부터 입시생까지 폭넓은 사용자가 자기주도적으로 실력을 향상시킬 수 있도록 설계되었습니다.

## 🌟 핵심 기능

### 🎯 개인화된 음성 모델 생성
- **RVC V2 기반** 개인 보이스 모델 생성 (3~5분 녹음)
- 사용자의 목소리로 노래 합성 및 원곡과 비교 청취

### 🎵 스마트 노래 분석
- **보컬 분리**: 원곡에서 보컬과 반주 자동 분리
- **실시간 피치 시각화**: 노래방 스타일 음정 비교
- **음역대 & 음색 분석**: ECAPA-TDNN 기반 개인 특성 분석

### 🤖 AI 기반 피드백 시스템
- **GPT-4o 자연어 피드백**: "고음 구간에서 음정이 흔들렸습니다. 복식호흡 연습을 권장합니다."
- **감정 인식**: MFCC, Energy, Whisper 활용 감정 분석
- **창법 분석**: vibrato, pitch bending 등 스타일 특징 분석

### 📊 개인 맞춤 추천 & 인사이트
- **곡 추천**: 음역대·음색 기반 맞춤 곡 추천
- **성장 추적**: 연습 이력 및 실력 변화 시각화
- **스타일 매칭**: 유사한 창법을 가진 가수와 비교 분석

## 🏗️ 기술 아키텍처

### Frontend
- **Flutter** - iOS/Android 크로스 플랫폼 모바일 앱
- **Chart.js** - 데이터 시각화 (WebView 연동)

### Backend
- **FastAPI** - RESTful API + WebSocket 실시간 통신
- **PostgreSQL** - Supabase 기반 데이터베이스
- **Firebase/AWS S3** - 파일 저장소

### AI/ML Stack
- **RVC V2** - PyTorch 기반 음성 합성 모델
- **CREPE/YIN** - 피치 분석
- **ECAPA-TDNN** - 음색 분석 및 화자 임베딩
- **Whisper, Wav2Vec2.0** - 감정 인식
- **GPT-4o** - 자연어 피드백 생성

### Authentication & Security
- **Firebase Auth** - Kakao/Google OAuth, SMS 인증
- **JWT** - 안전한 세션 관리

## 📁 프로젝트 구조

```
VoiceTrainingAI/
├── 📱 frontend/              # Flutter 모바일 앱
│   ├── lib/                  # Dart 소스 코드
│   ├── assets/               # 이미지, 폰트 등 리소스
│   └── pubspec.yaml         # Flutter 의존성
├── 🖥️ backend/               # FastAPI 백엔드 서버  
│   ├── app/                  # API 라우터 및 서비스
│   ├── models/               # 데이터베이스 모델
│   └── requirements.txt      # Python 의존성
├── 🤖 model-server/          # RVC V2 모델 서버
│   ├── rvc/                  # RVC V2 구현
│   ├── training/             # 모델 훈련 스크립트
│   └── inference/            # 추론 서버
├── 📚 docs/                  # 프로젝트 문서
├── 🧪 tests/                 # 테스트 코드
├── 🔧 scripts/               # 유틸리티 스크립트
└── 📋 .taskmaster/           # 프로젝트 관리
    ├── tasks/                # 개별 태스크 파일
    └── docs/                 # PRD 및 기술 문서
```

## 🚀 빠른 시작 가이드

### 사전 요구사항
- **Python 3.8+** (AI 모델 서버용)
- **Node.js 16+** (백엔드 의존성)
- **Flutter SDK 3.0+** (모바일 앱)
- **CUDA GPU** (모델 훈련, 선택사항)

### 1️⃣ 저장소 클론
```bash
git clone https://github.com/kennyHyunSeokCho/VoiceTrainAI.git
cd VoiceTrainingAI
```

### 2️⃣ 백엔드 설정
```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 3️⃣ 모델 서버 설정
```bash
cd model-server
pip install -r requirements.txt
# GPU 사용 시 PyTorch CUDA 버전 설치
```

### 4️⃣ 프론트엔드 설정
```bash
cd frontend
flutter pub get
flutter run
```

### 5️⃣ 환경 변수 설정
```bash
cp .env.example .env
```

`.env` 파일에 다음 API 키들을 설정하세요:
```env
# OpenAI API (GPT-4o 피드백용)
OPENAI_API_KEY=your_openai_api_key

# Firebase (인증 및 저장소)
FIREBASE_API_KEY=your_firebase_key

# Kakao OAuth
KAKAO_API_KEY=your_kakao_key

# Database
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_key
```

## 📋 개발 로드맵

### 🏁 Phase 1 - MVP (현재 단계)
- [x] **프로젝트 저장소 설정** - Git 구조 및 초기 설정
- [ ] **사용자 인증 구현** - Firebase Auth + Kakao/Google OAuth + SMS
- [ ] **음성 녹음 기능** - 고품질 음성 캡처 및 저장
- [ ] **RVC V2 모델 훈련** - 개인화된 음성 모델 생성
- [ ] **노래 가져오기 & 음성 교체** - 보컬 분리 및 합성
- [ ] **실시간 피치 시각화** - 노래방 스타일 UI

### 🚀 Phase 2 - 고도화 기능
- [ ] **GPT-4o 자연어 피드백** - AI 기반 개인화된 조언
- [ ] **감정 분석 피드백** - 감정 표현력 평가
- [ ] **음역대·음색 기반 추천** - 맞춤형 곡 추천
- [ ] **연습 이력 시각화** - 성장 추적 대시보드

### 🌟 Phase 3 - 확장 기능  
- [ ] **가창 스타일 분석** - 유사 가수 매칭
- [ ] **커뮤니티 기능** - 랭킹, 챌린지 모드
- [ ] **프리미엄 구독** - 고급 기능 및 콘텐츠

## 👥 대상 사용자

- **🎤 일반 노래 연습자** - 취미로 노래를 즐기는 사용자
- **🎓 보컬 입시생** - 전문적인 보컬 훈련이 필요한 학생
- **📹 보컬 유튜버** - 콘텐츠 제작을 위한 보컬 개선
- **🎵 음악 창작자** - 자신의 곡에 보컬 추가

## 🤝 기여하기

프로젝트에 기여하고 싶다면 다음 단계를 따라주세요:

1. **Fork** 이 저장소
2. **Feature 브랜치** 생성 (`git checkout -b feature/AmazingFeature`)
3. **변경사항 커밋** (`git commit -m 'Add some AmazingFeature'`)
4. **브랜치에 Push** (`git push origin feature/AmazingFeature`)
5. **Pull Request** 생성

### 개발 워크플로우
```bash
# 다음 작업할 태스크 확인
task-master next

# 특정 태스크 상세보기  
task-master show 1

# 태스크 상태 변경
task-master set-status --id=1 --status=in-progress

# 서브태스크 진행상황 업데이트
task-master update-subtask --id=1.1 --prompt="구현 완료"
```

## 📄 라이센스

이 프로젝트는 [MIT License](LICENSE) 하에 배포됩니다.

## 🙏 감사인사

- **RVC V2** - 음성 변환 기술
- **OpenAI GPT-4o** - 자연어 피드백
- **Flutter 팀** - 크로스 플랫폼 프레임워크
- **FastAPI** - 현대적인 Python 웹 프레임워크

## 📞 연락처

프로젝트에 대한 질문이나 제안이 있으시면 이슈를 생성해 주세요.

---

<div align="center">
  <strong>🎤 AI 보컬 트레이닝 시스템으로 당신의 노래 실력을 새로운 차원으로! 🎵</strong>
</div> 
프로젝트에 기여하고 싶다면 이슈를 생성하거나 풀 리퀘스트를 보내주세요. 