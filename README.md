# AI 보컬 트레이닝 시스템 (AVTS) 🎤✨

> **개인화된 AI 기반 보컬 트레이닝으로 당신의 노래 실력을 한 단계 업그레이드하세요**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-6DB33F?style=flat&logo=spring-boot&logoColor=white)](https://spring.io/projects/spring-boot)
[![Java](https://img.shields.io/badge/Java-ED8B00?style=flat&logo=java&logoColor=white)](https://www.oracle.com/java/)
[![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)](https://python.org)

## 📖 프로젝트 개요

**AI 보컬 트레이닝 시스템(AVTS)**은 사용자가 자신의 음성을 녹음하여 개인화된 음성 합성 모델을 만들고, 노래를 따라 부르며 실시간 피드백을 받을 수 있는 혁신적인 AI 기반 보컬 트레이닝 앱입니다.

기존 보컬 교육의 한계를 극복하여 **실시간 피드백**, **개인화된 학습**, **RVC 기반 음성 비교 분석** 기능을 통합, 초보자부터 입시생까지 폭넓은 사용자가 자기주도적으로 실력을 향상시킬 수 있도록 설계되었습니다.

## 🌟 핵심 기능

### 🎯 개인화된 음성 모델 생성
- **RVC V2 기반** 개인 보이스 모델 생성 (3~5분 녹음)
- 사용자의 목소리로 노래 합성 및 원곡과 비교 청취

### 🎵 스마트 노래 분석
- **보컬 분리**: 원곡에서 보컬과 반주 자동 분리
- **실시간 피치 시각화**: 노래방 스타일 음정 비교
- **음역대 & 음색 분석**: HuBERT 기반 1024차원 음색 임베딩 분석

### 🤖 AI 기반 피드백 시스템
- **GPT-4o 자연어 피드백**: "고음 구간에서 음정이 흔들렸습니다. 복식호흡 연습을 권장합니다."
- **RVC 기반 음성 비교**: 원곡-변환된 노래-사용자 녹음을 3-way 비교하여 구체적 가이드라인 제공
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
- **Spring Boot** - RESTful API + WebSocket 실시간 통신
- **Spring WebFlux** - 비동기 반응형 프로그래밍
- **Spring Security** - JWT 인증 및 권한 관리
- **Spring Data JPA** - 데이터베이스 연동
- **PostgreSQL** - Supabase 기반 데이터베이스
- **Firebase/AWS S3** - 파일 저장소

### AI/ML Stack
- **RVC V2** - PyTorch 기반 음성 합성 모델
- **CREPE/YIN** - 피치 분석
- **HuBERT** - 1024차원 음색 분석 및 화자 임베딩 (superb/hubert-large-superb-sid)
- **DTW, MFCC, Mel-spectrogram** - 음성 비교 분석
- **GPT-4o** - 자연어 피드백 생성

### Authentication & Security
- **Spring Security** - Kakao/Google OAuth, SMS 인증
- **JWT** - 안전한 세션 관리

## 📁 프로젝트 구조

```
VoiceTrainingAI/
├── 📱 frontend/              # Flutter 모바일 앱
│   ├── lib/                  # Dart 소스 코드
│   ├── assets/               # 이미지, 폰트 등 리소스
│   └── pubspec.yaml         # Flutter 의존성
├── 🖥️ backend/               # Spring Boot 백엔드 서버  
│   ├── src/main/java/        # Java 소스 코드
│   │   ├── controller/       # REST API 컨트롤러
│   │   ├── service/          # 비즈니스 로직
│   │   ├── repository/       # 데이터베이스 접근
│   │   └── config/           # 설정 클래스
│   ├── src/main/resources/   # 설정 파일
│   │   ├── application.yml   # Spring Boot 설정
│   │   └── static/           # 정적 파일
│   └── pom.xml               # Maven 의존성
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
- **Java 17+** (Spring Boot 백엔드용)
- **Maven 3.6+** (의존성 관리)
- **Python 3.8+** (AI 모델 서버용)
- **Flutter SDK 3.0+** (모바일 앱)
- **CUDA GPU** (모델 훈련, 선택사항)

### 1️⃣ 저장소 클론
```bash
git clone https://github.com/kennyHyunSeokCho/VoiceTrainAI.git
cd VoiceTrainingAI
```

### 2️⃣ 백엔드 설정 (Spring Boot)
```bash
cd backend
# Maven을 사용한 의존성 설치 및 빌드
mvn clean install
# 또는 Gradle을 사용하는 경우
./gradlew build
```

### 3️⃣ 모델 서버 설정
```bash
cd model-server
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
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
Spring Boot 설정 파일인 `application.yml`에 다음 설정들을 추가하세요:

```yaml
# application.yml
spring:
  datasource:
    url: ${SUPABASE_URL}
    username: ${SUPABASE_USER}
    password: ${SUPABASE_PASSWORD}
  
  security:
    oauth2:
      client:
        registration:
          google:
            client-id: ${GOOGLE_CLIENT_ID}
            client-secret: ${GOOGLE_CLIENT_SECRET}
          kakao:
            client-id: ${KAKAO_CLIENT_ID}
            client-secret: ${KAKAO_CLIENT_SECRET}

openai:
  api-key: ${OPENAI_API_KEY}

firebase:
  api-key: ${FIREBASE_API_KEY}
  
server:
  port: 8080
```

또는 `.env` 파일을 사용하여 환경 변수를 설정할 수 있습니다:
```env
# OpenAI API (GPT-4o 피드백용)
OPENAI_API_KEY=your_openai_api_key

# Firebase (인증 및 저장소)
FIREBASE_API_KEY=your_firebase_key

# Kakao OAuth
KAKAO_CLIENT_ID=your_kakao_client_id
KAKAO_CLIENT_SECRET=your_kakao_client_secret

# Google OAuth
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Database
SUPABASE_URL=your_supabase_url
SUPABASE_USER=your_supabase_user
SUPABASE_PASSWORD=your_supabase_password
```

### 6️⃣ 애플리케이션 실행
```bash
# 백엔드 서버 실행
cd backend
mvn spring-boot:run
# 또는 Gradle을 사용하는 경우
./gradlew bootRun

# 모델 서버 실행
cd model-server
python app.py

# 프론트엔드 실행
cd frontend
flutter run
```

## 📋 개발 로드맵

### 🏁 Phase 1 - MVP (현재 단계)
- [x] **프로젝트 저장소 설정** - Git 구조 및 초기 설정
- [ ] **사용자 인증 구현** - Spring Security + Kakao/Google OAuth + SMS
- [ ] **음성 녹음 기능** - 고품질 음성 캡처 및 저장
- [ ] **RVC V2 모델 훈련** - 개인화된 음성 모델 생성
- [ ] **노래 가져오기 & 음성 교체** - 보컬 분리 및 합성
- [ ] **실시간 피치 시각화** - 노래방 스타일 UI

### 🚀 Phase 2 - 고도화 기능
- [ ] **GPT-4o 자연어 피드백** - AI 기반 개인화된 조언
- [ ] **RVC 기반 음성 비교 분석** - 3-way 비교를 통한 구체적 가이드라인 제공
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

- **Spring Boot** - 현대적인 Java 웹 프레임워크
- **RVC V2** - 음성 변환 기술
- **OpenAI GPT-4o** - 자연어 피드백
- **Flutter 팀** - 크로스 플랫폼 프레임워크

## 📞 연락처

프로젝트에 대한 질문이나 제안이 있으시면 이슈를 생성해 주세요.

---

<div align="center">
  <strong>🎤 AI 보컬 트레이닝 시스템으로 당신의 노래 실력을 새로운 차원으로! 🎵</strong>
</div>
프로젝트에 기여하고 싶다면 이슈를 생성하거나 풀 리퀘스트를 보내주세요.

# 멜론 월간 차트 크롤러 (Melon Monthly Chart Crawler)

## 주요 기능
- 멜론 월간 차트에서 원하는 월의 TOP10 곡 정보를 크롤링하여 하나의 통합 CSV 파일(`data/info/all_chart_songs.csv`)에 누적 저장합니다.
- 곡 제목+가수 기준으로 중복 곡은 절대 다시 저장되지 않습니다.
- 파이썬을 껐다 켜도 기존에 저장된 곡은 다시 저장되지 않습니다.
- 사용자가 직접 원하는 월을 선택하고, 엔터를 누를 때마다 새로운 곡만 누적 저장됩니다.

## 사용법
1. `data/chart/chart_month_crawler.py` 실행
2. 크롬 브라우저가 열리면 멜론 월간 차트 페이지에서 원하는 월을 직접 선택
3. 터미널에서 엔터를 누르면 해당 월의 곡 정보(최대 10곡)가 누적 저장됨
4. 월을 바꿔가며 엔터를 반복하면 새로운 곡만 계속 추가됨
5. 모든 곡은 `data/info/all_chart_songs.csv`에 누적 저장됨

## 중복 방지 로직
- 곡 제목과 가수명을 정규화(공백/대소문자/특수문자 통일)하여 중복 체크
- 이미 저장된 곡은 "중복 곡 스킵: 곡명 - 가수" 메시지와 함께 저장되지 않음
- 세션 시작 시 기존 CSV 파일을 읽어와 중복 키를 미리 등록함

## 예시
```
python3 data/chart/chart_month_crawler.py
```
- 원하는 월을 선택 → 엔터 → 누적 저장
- 월을 바꿔가며 반복

## 주의사항
- 크롤링 속도는 곡 수와 네트워크 상황에 따라 다소 느릴 수 있습니다.
- 멜론 사이트 구조가 바뀌면 CSS Selector 등 일부 코드 수정이 필요할 수 있습니다.
- 크롬 드라이버가 설치되어 있어야 합니다.

---

문의/기여/이슈는 Github PR 또는 Issue로 남겨주세요. 