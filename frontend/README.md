# 🎤 Voice Training AI - Frontend

AI 보컬 트레이닝을 위한 Flutter 애플리케이션입니다.

## 📁 새로운 프로젝트 구조 (Features 기반)

```
frontend/                            # 🎯 Flutter 프로젝트 루트 (간소화!)
├── lib/                             # 📱 메인 앱 소스 코드
│   ├── main.dart                    # 🚀 앱 진입점 및 메인 화면
│   │
│   ├── features/                    # ✨ 기능별 모듈 구성 (Feature-driven Development)
│   │   ├── record/                  # 🎤 녹음 기능 모듈
│   │   │   ├── providers/           # 📊 상태 관리 (Provider)
│   │   │   │   └── recording_provider.dart
│   │   │   ├── screens/             # 📱 화면 UI 컴포넌트
│   │   │   ├── widgets/             # 🧩 재사용 가능한 위젯
│   │   │   └── models/              # 📦 데이터 모델
│   │   │
│   │   ├── voice_training/          # 🎵 음성 훈련 기능 (준비 중)
│   │   ├── analysis/                # 📊 분석 기능 (준비 중)
│   │   ├── profile/                 # 👤 프로필 기능 (준비 중)
│   │   └── dashboard/               # 📈 대시보드 기능 (준비 중)
│   │
│   ├── core/                        # 🔧 공통 핵심 기능
│   │   ├── constants/               # 📋 상수 정의
│   │   ├── utils/                   # 🛠️ 유틸리티 함수
│   │   │   ├── web_download_stub.dart
│   │   │   └── web_download_web.dart
│   │   └── services/                # 🌐 API 서비스
│   │
│   └── shared/                      # 🔄 공유 컴포넌트
│       ├── widgets/                 # 🧩 공통 위젯
│       └── models/                  # 📦 공통 데이터 모델
│
├── assets/                          # 📂 리소스 파일들
│   └── recordings/                  # 🎵 녹음 파일 저장소
├── android/                         # 🤖 안드로이드 플랫폼 설정
├── ios/                             # 🍎 iOS 플랫폼 설정
├── web/                             # 🌐 웹 플랫폼 설정
├── windows/                         # 🪟 윈도우 플랫폼 설정
├── linux/                           # 🐧 리눅스 플랫폼 설정
├── macos/                           # 💻 macOS 플랫폼 설정
├── test/                            # 🧪 테스트 파일들
├── pubspec.yaml                     # 📦 패키지 의존성 관리
└── analysis_options.yaml           # 🔍 코드 분석 설정
```

## ✨ Features 기반 아키텍처의 장점

### 🎯 **확장성**
- 새로운 기능을 독립적인 모듈로 추가 가능
- 기능별로 팀 작업 분할 용이
- 코드 충돌 최소화

### 🔧 **유지보수성**
- 기능별로 관련 코드가 한 곳에 집중
- 버그 수정 시 영향 범위 명확
- 테스트 코드 작성 용이

### 📊 **모듈성**
- 각 feature는 독립적으로 개발/테스트 가능
- 재사용 가능한 컴포넌트는 shared에 배치
- 공통 기능은 core에 중앙화

## 🎯 현재 구현된 기능

### 🎤 음성 녹음 시스템 (`features/record/`)
- **실시간 녹음**: 마이크를 통한 음성 입력 및 저장
- **녹음 관리**: 녹음 파일 목록 보기, 재생, 삭제
- **상태 관리**: Provider 패턴을 사용한 녹음 상태 관리
- **멀티플랫폼**: 웹/모바일 환경별 최적화

### 🔧 기술 스택
- **프레임워크**: Flutter 3.32.5
- **상태 관리**: Provider
- **녹음 라이브러리**: record ^5.1.0
- **오디오 재생**: audioplayers ^6.0.0
- **권한 관리**: permission_handler ^11.3.1

### 🌐 멀티플랫폼 지원
- Android 📱
- iOS 📱  
- Web 🌐
- Windows 💻
- macOS 🍎
- Linux 🐧

## 🚀 개발 시작하기

### 1. **환경 설정**
```bash
# Flutter 설치 확인
flutter doctor

# 프로젝트 의존성 설치
flutter pub get
```

### 2. **앱 실행**
```bash
# 웹에서 실행
flutter run -d chrome

# 모바일 기기에서 실행 (Android/iOS)
flutter run

# 데스크톱에서 실행
flutter run -d windows   # Windows
flutter run -d macos     # macOS
flutter run -d linux     # Linux
```

### 3. **빌드**
```bash
# 웹용 빌드
flutter build web --release

# 안드로이드 APK 빌드
flutter build apk --release

# iOS 빌드 (macOS에서만)
flutter build ios --release
```

### 4. **테스트 실행**
```bash
# 모든 테스트 실행
flutter test

# 코드 분석
flutter analyze
```

## 🏗️ 새로운 기능 추가 가이드

### Feature 모듈 생성
```bash
# 새로운 기능 폴더 구조 생성
mkdir -p lib/features/새기능/{providers,screens,widgets,models}
```

### 예시: `voice_training` 기능 추가
```
lib/features/voice_training/
├── providers/
│   └── voice_training_provider.dart
├── screens/
│   ├── training_screen.dart
│   └── lesson_screen.dart
├── widgets/
│   ├── pitch_display.dart
│   └── lesson_card.dart
└── models/
    ├── lesson.dart
    └── training_session.dart
```

## 📝 개발 현황

### ✅ 완료된 작업
- [x] 기본 프로젝트 구조 설정
- [x] Features 기반 아키텍처 적용
- [x] 음성 녹음 기능 구현
- [x] 멀티플랫폼 지원
- [x] 상태 관리 시스템 구축

### 🚧 진행 중인 작업
- [ ] 오디오 품질 최적화
- [ ] 실시간 음정 분석
- [ ] 백엔드 API 연동

### 📋 계획된 기능
- [ ] AI 음성 분석 기능
- [ ] 사용자 프로필 시스템
- [ ] 진도 추적 대시보드
- [ ] 소셜 기능 (피드백 공유)

## 🔗 관련 문서

- [Flutter 공식 문서](https://docs.flutter.dev/)
- [Provider 패키지](https://pub.dev/packages/provider)
- [Audio Recording 가이드](https://pub.dev/packages/record)

---

