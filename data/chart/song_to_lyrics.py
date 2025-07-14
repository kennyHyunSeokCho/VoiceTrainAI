#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
동기화된 가사(LRC) 추출기
온라인 데이터베이스에서 동기화된 가사를 검색하고 저장합니다.
"""

import syncedlyrics
import argparse
import re
from pathlib import Path
import csv
from datetime import timedelta
import datetime  # datetime 모듈 추가

class LyricsFetcher:
    def __init__(self, search_term, output_file):
        """
        가사 추출기 초기화
        
        Args:
            search_term: 검색어 (예: "아티스트 - 노래 제목")
            output_file: 출력 파일 경로
        """
        self.search_term = search_term
        self.output_file = output_file
        self.lrc_data = None

    def fetch_lyrics(self):
        """동기화된 가사를 검색하고 가져옵니다."""
        print(f"'{self.search_term}'에 대한 동기화된 가사를 검색합니다...")
        lrc = syncedlyrics.search(self.search_term, save_path=False)
        
        if lrc:
            if re.search(r'\[\d{2}:\d{2}\.\d{2,3}\]', lrc):
                print("동기화된 가사를 찾았습니다!")
            else:
                print("일반 가사를 찾았습니다. (타임스탬프 없음)")
            self.lrc_data = lrc
            return True
        else:
            print("어떤 가사도 찾지 못했습니다.")
            return False

    def save_results(self):
        """가져온 결과를 다양한 형식으로 저장합니다."""
        if not self.lrc_data:
            print("저장할 데이터가 없습니다.")
            return

        output_path = Path(self.output_file)
        
        if output_path.suffix.lower() == '.lrc':
            self._save_lrc(self.lrc_data, self.output_file)
        elif output_path.suffix.lower() == '.srt':
            self._save_srt(self.lrc_data, self.output_file)
        elif output_path.suffix.lower() == '.txt':
            self._save_txt(self.lrc_data, self.output_file)
        else:
            default_file = output_path.with_suffix('.lrc')
            print(f"알 수 없는 확장자입니다. LRC 형식으로 저장합니다: {default_file}")
            self._save_lrc(self.lrc_data, default_file)
            
    def _save_lrc(self, lrc_data, output_file):
        """LRC 형식으로 저장"""
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(lrc_data)
        print(f"LRC 파일로 저장 완료: {output_file}")

    def _save_srt(self, lrc_data, output_file):
        """SRT 자막 형식으로 저장"""
        lines = lrc_data.strip().split('\n')
        srt_lines = []
        
        # [mm:ss.xx] 형식의 타임스탬프를 파싱하는 정규식
        time_pattern = re.compile(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)')
        
        lyrics_with_time = []
        for line in lines:
            match = time_pattern.match(line)
            if match:
                minutes, seconds, ms, text = match.groups()
                total_seconds = int(minutes) * 60 + int(seconds) + int(ms.ljust(3, '0')) / 1000
                lyrics_with_time.append({'time': total_seconds, 'text': text.strip()})

        if not lyrics_with_time:
            print("SRT 변환 실패: LRC에 타임스탬프가 없습니다.")
            self._save_txt(lrc_data, Path(output_file).with_suffix('.txt'))
            return

        for i, current_lyric in enumerate(lyrics_with_time):
            start_time_sec = current_lyric['time']
            # 다음 가사의 시작 시간을 현재 가사의 끝 시간으로 사용
            # 마지막 가사는 5초 동안 표시하도록 설정
            end_time_sec = lyrics_with_time[i + 1]['time'] if i + 1 < len(lyrics_with_time) else start_time_sec + 5
            
            start_time_srt = self._seconds_to_srt_time(start_time_sec)
            end_time_srt = self._seconds_to_srt_time(end_time_sec)
            
            text = current_lyric['text']
            if not text:  # 가사가 비어있으면 건너뜀 (간주 등)
                continue
                
            srt_lines.append(f"{len(srt_lines) + 1}\n{start_time_srt} --> {end_time_srt}\n{text}\n")

        with open(output_file, 'w', encoding='utf-8') as f:
            f.writelines(srt_lines)
            
        print(f"SRT 자막 파일로 저장 완료: {output_file}")
        
    def _save_txt(self, lrc_data, output_file):
        """간단한 텍스트 형식으로 저장"""
        # LRC 태그 제거
        plain_text = re.sub(r'\[.*?\]', '', lrc_data)
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(plain_text.strip())
        print(f"텍스트 파일로 저장 완료: {output_file}")

    def _seconds_to_srt_time(self, seconds):
        """초를 SRT 시간 형식으로 변환"""
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = seconds % 60
        return f"{hours:02d}:{minutes:02d}:{int(secs):02d},{int((secs % 1) * 1000):03d}"

def lrc_to_srt(lrc_text):
    """
    LRC 포맷 가사를 SRT 포맷 문자열로 변환
    """
    # LRC 라인 파싱: [(시작초, 가사)]
    pattern = re.compile(r"\[(\d+):(\d+)[.,](\d+)](.*)")
    entries = []
    for line in lrc_text.splitlines():
        m = pattern.match(line)
        if m:
            min, sec, ms, lyric = m.groups()
            start = int(min) * 60 + int(sec) + int(ms.ljust(3, '0')) / 1000
            entries.append((start, lyric.strip()))
    if not entries:
        return ""
    # SRT 변환
    srt_lines = []
    for i, (start, lyric) in enumerate(entries):
        end = entries[i+1][0] if i+1 < len(entries) else start + 3.0  # 마지막 줄은 +3초
        # SRT 시간 포맷 변환
        def sec_to_srt(t):
            td = timedelta(seconds=t)
            total = (datetime.min + td)
            return total.strftime('%H:%M:%S,%f')[:-3]
        srt_lines.append(f"{i+1}\n{sec_to_srt(start)} --> {sec_to_srt(end)}\n{lyric}\n")
    return "\n".join(srt_lines)

def main():
    parser = argparse.ArgumentParser(description="동기화된 가사(LRC) 추출기")
    parser.add_argument("--csv", help="CSV 파일 경로 (노래제목, 가수 컬럼 필요)", default="data/info/all_chart_songs_to.csv")
    parser.add_argument("--outdir", help="가사 저장 폴더", default="data/info")
    parser.add_argument("--ext", help="저장 확장자 (.srt, .lrc, .txt)", default=".srt")
    parser.add_argument("--single", help="단일 곡 검색어 (ex: '아이유 - 밤편지')", default=None)
    parser.add_argument("--output", help="단일 곡 저장 파일명", default=None)
    args = parser.parse_args()

    # 단일 곡 처리: --single 옵션이 있을 때만 실행
    if args.single:
        output_file = args.output or f"lyrics{args.ext}"
        fetcher = LyricsFetcher(args.single, output_file)
        if fetcher.fetch_lyrics():
            fetcher.save_results()
    else:
        # 아무 인자 없이 실행하면 CSV 일괄 처리
        main_csv(args.csv, args.outdir, args.ext)

def main_csv(csv_path, output_dir, ext):
    """
    CSV 파일에서 노래제목, 가수 정보를 읽어 각 곡의 동기화 가사를 지정한 폴더에 저장
    Args:
        csv_path: CSV 파일 경로
        output_dir: 저장 폴더 경로
        ext: 저장 확장자 (.srt, .lrc, .txt)
    """
    csv_path = Path(csv_path)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    with open(csv_path, newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        # 컬럼명에서 BOM 자동 제거
        fieldnames = [fn.lstrip('\ufeff') for fn in reader.fieldnames]
        reader.fieldnames = fieldnames
        # 곡 리스트 추출
        songs = []
        for row in reader:
            title = row.get('노래제목', '').strip()
            artist = row.get('가수', '').strip()
            if not title or not artist:
                print(f"제목 또는 가수 정보가 누락된 행: {row}")
                continue
            songs.append({'title': title, 'artist': artist})

    for song in songs:
        title = song['title']
        artist = song['artist']
        search_term = f"{artist} - {title}"
        # 파일명 안전하게 변환
        safe_artist = re.sub(r'[^\w\-가-힣 ]', '', artist)
        safe_title = re.sub(r'[^\w\-가-힣 ]', '', title)
        filename = f"{safe_artist}-{safe_title}{ext}"
        filepath = output_dir / filename
        fetcher = LyricsFetcher(search_term, filepath)
        if fetcher.fetch_lyrics():
            fetcher.save_results()
        else:
            # fetch 실패 시 일반 TXT로 저장
            txt_path = output_dir / f"{safe_artist}-{safe_title}.txt"
            with open(txt_path, 'w', encoding='utf-8') as f:
                f.write(f"[{search_term}]\n가사를 찾지 못했습니다.")
            print(f"일반 TXT로 저장: {txt_path}")

# 파일명 안전하게 변환
def sanitize_filename(s):
    """파일명에 사용할 수 없는 문자 제거 (한글, 영문, 숫자, 공백, -, _)"""
    return re.sub(r'[^\w\-가-힣 ]', '', s)

# CSV 일괄 처리 함수
def batch_from_csv(csv_path, output_dir):
    """
    CSV 파일에서 노래제목, 가수 정보를 읽어 SRT 파일로 저장. SRT 변환 실패 시 TXT로 저장.
    Args:
        csv_path: CSV 파일 경로
        output_dir: 저장 폴더 경로
    """
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    with open(csv_path, newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            title = row.get('노래제목', '').strip()
            artist = row.get('가수', '').strip()
            if not title or not artist:
                print(f"제목 또는 가수 정보가 누락된 행: {row}")
                continue
            search_term = f"{artist} - {title}"
            safe_artist = sanitize_filename(artist)
            safe_title = sanitize_filename(title)
            srt_filename = f"{safe_artist}-{safe_title}.srt"
            txt_filename = f"{safe_artist}-{safe_title}.txt"
            srt_path = output_dir / srt_filename
            txt_path = output_dir / txt_filename
            fetcher = LyricsFetcher(search_term, srt_path)
            if fetcher.fetch_lyrics():
                # SRT 저장 시도
                fetcher._save_srt(fetcher.lrc_data, srt_path)
                # SRT 파일이 실제로 생성됐는지 확인
                if not srt_path.exists() or srt_path.stat().st_size == 0:
                    print(f"SRT 저장 실패, TXT로 저장: {txt_path}")
                    fetcher._save_txt(fetcher.lrc_data, txt_path)
            else:
                print(f"가사 검색 실패: {search_term}")

if __name__ == "__main__":
    import sys
    if len(sys.argv) == 1:
        # 인자 없이 실행하면 CSV 일괄 처리
        batch_from_csv("data/info/all_chart_songs_to.csv", "data/info")
    else:
        main() 