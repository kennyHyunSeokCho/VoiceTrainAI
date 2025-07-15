import os
from pathlib import Path
from vocal_separation import VocalSeparator

# 음악 파일 루트 폴더
MUSIC_ROOT = Path("data/music_file")
# 분리된 파일 저장 폴더 (요청에 따라 경로 변경)
VOCAL_DIR = "data/seperated_voice"
INST_DIR = "data/seperated-inst"
os.makedirs(VOCAL_DIR, exist_ok=True)
os.makedirs(INST_DIR, exist_ok=True)

# 지원하는 오디오 확장자
AUDIO_EXTS = [".mp3", ".wav", ".flac", ".m4a", ".aac"]

# 성공/실패 로그 파일
SUCCESS_LOG = "local_separation_success.txt"
FAIL_LOG = "local_separation_fail.txt"

def find_audio_files(root_dir):
    """모든 하위 폴더에서 오디오 파일 경로 리스트 반환"""
    for dirpath, _, filenames in os.walk(root_dir):
        for fname in filenames:
            if any(fname.lower().endswith(ext) for ext in AUDIO_EXTS):
                yield os.path.join(dirpath, fname)

def make_unique_basename(audio_path):
    """아티스트/곡명 기반 고유 파일명 생성 (특수문자/공백 안전 변환)"""
    p = Path(audio_path)
    artist = p.parent.name
    song = p.stem
    safe_artist = "".join(c if c.isalnum() else "_" for c in artist)
    safe_song = "".join(c if c.isalnum() else "_" for c in song)
    return f"{safe_artist}_{safe_song}"

def main():
    with open(SUCCESS_LOG, "a", encoding="utf-8") as success_f, \
         open(FAIL_LOG, "a", encoding="utf-8") as fail_f:
        # 보컬 분리기 준비
        separator = VocalSeparator("htdemucs")
        audio_files = list(find_audio_files(MUSIC_ROOT))
        print(f"총 {len(audio_files)}개 파일 발견")
        for audio_path in audio_files:
            base = make_unique_basename(audio_path)
            vocal_path = os.path.join(VOCAL_DIR, f"{base}_vocal.wav")
            inst_path = os.path.join(INST_DIR, f"{base}_inst.wav")
            # 이미 분리된 파일이 모두 존재하면 원본 삭제
            if os.path.exists(vocal_path) and os.path.exists(inst_path):
                try:
                    os.remove(audio_path)
                    print(f"이미 분리됨, 원본 삭제: {audio_path}")
                    success_f.write(f"{audio_path},{vocal_path},{inst_path},이미 분리됨-원본삭제\n")
                except Exception as e:
                    print(f"원본 삭제 실패: {audio_path}, 에러: {e}")
                    fail_f.write(f"{audio_path},,{e},원본삭제실패\n")
                continue
            # 분리 시도
            try:
                print(f"분리 중: {audio_path}")
                result = separator.separate_audio(
                    audio_path,
                    vocal_dir=VOCAL_DIR,
                    inst_dir=INST_DIR,
                    audio_format="wav"
                )
                # 결과 파일명을 강제로 덮어쓰기 (중복 방지)
                if os.path.exists(result.get("vocal")):
                    os.replace(result["vocal"], vocal_path)
                if os.path.exists(result.get("inst")):
                    os.replace(result["inst"], inst_path)
                if os.path.exists(vocal_path) and os.path.exists(inst_path):
                    os.remove(audio_path)
                    print(f"분리 성공, 원본 삭제: {audio_path}")
                    success_f.write(f"{audio_path},{vocal_path},{inst_path},성공-원본삭제\n")
                else:
                    print(f"분리 결과 없음: {audio_path}")
                    fail_f.write(f"{audio_path},,분리 결과 없음\n")
            except Exception as e:
                print(f"분리 실패: {audio_path}, 에러: {e}")
                fail_f.write(f"{audio_path},,{e},분리실패\n")

if __name__ == "__main__":
    main() 