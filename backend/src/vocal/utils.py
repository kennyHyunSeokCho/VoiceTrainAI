from pathlib import Path
import re
import logging

logger = logging.getLogger(__name__)

def extract_song_name_from_s3_key(s3_key: str) -> str:
    try:
        filename = Path(s3_key).name
        song_name = Path(filename).stem
        if "_vocal" in song_name:
            song_name = song_name.split("_vocal")[0]
        song_name = re.sub(r'_\d{8}_\d{6}', '', song_name)
        song_name = re.sub(r'_\d{8}', '', song_name)
        song_name = re.sub(r'_\d{6}', '', song_name)
        if not song_name.strip():
            song_name = "녹음곡"
        return song_name.strip()
    except Exception as e:
        logger.warning(f"곡명 추출 실패: {str(e)}")
        return "녹음곡" 