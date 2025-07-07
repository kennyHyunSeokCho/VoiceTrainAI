# /data 폴더 구조 및 설명

이 문서는 VoiceTrainingAI 프로젝트의 `/data` 폴더 내 구조와 각 폴더/파일의 역할을 설명합니다.

---

## 폴더 구조

```
data/
├── chart/
│   ├── melon_chart_crawler.py
│   └── .gitkeep
├── info/
│   └── chart_song_singer_lyrics.csv
├── music_file/
│   ├── Golden_HUNTR/
│   │   └── X.wav
│   ├── ... (여러 .wav 파일)
│   └── .gitkeep
├── music_png/
├── youtube/
│   ├── youtube_mp3_crawler.py
│   └── .gitkeep
```

---

## 각 폴더/파일 설명

### chart/
- **melon_chart_crawler.py**
  - 멜론 차트 데이터를 크롤링하는 파이썬 스크립트입니다.
- **.gitkeep**
  - 빈 폴더의 git 추적을 위해 사용됩니다.

### info/
- **chart_song_singer_lyrics.csv**
  - 크롤링된 차트 곡, 가수, 가사 등의 정보를 담고 있는 CSV 파일입니다.

### music_file/
- **여러 .wav 파일**
  - 실제 음원 파일들이 저장되어 있습니다. 파일명은 곡명, 가수명 등으로 구성되어 있습니다.
- **Golden_HUNTR/X.wav**
  - Golden_HUNTR라는 하위 폴더에 포함된 음원 파일입니다.
- **.gitkeep**
  - 빈 폴더의 git 추적을 위해 사용됩니다.

### music_png/
- (설명 필요시 추가)
  - 음원 관련 이미지 파일이 저장될 수 있는 폴더입니다. 현재 파일 목록은 미확인 상태입니다.

### youtube/
- **youtube_mp3_crawler.py**
  - 유튜브에서 mp3 파일을 크롤링하는 파이썬 스크립트입니다.
- **.gitkeep**
  - 빈 폴더의 git 추적을 위해 사용됩니다.

---

## 참고 사항
- 각 폴더는 데이터 수집, 저장, 전처리 등 다양한 목적에 따라 구성되어 있습니다.
- 실제 음원 파일(.wav)은 용량이 크므로, git에는 업로드하지 않는 것이 일반적입니다.
- 필요에 따라 music_png 폴더 등 추가 폴더의 용도도 명확히 정의해 주세요. 