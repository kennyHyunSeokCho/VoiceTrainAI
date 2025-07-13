import os
import yt_dlp
import pandas as pd
import time

# 곡명/가수명/가사 CSV 파일 경로 (data/info/all_chart_songs.csv)
CSV_PATH = os.path.join(os.path.dirname(__file__), '..', 'info', 'all_chart_songs.csv')

# wav 파일이 저장될 폴더 경로 (data/music_file)
download_dir = os.path.join(os.path.dirname(__file__), '..', 'music_file')
os.makedirs(download_dir, exist_ok=True)

# 성공/실패 로그 파일 경로
download_success_log = os.path.join(download_dir, 'success_list_inst.txt')
download_fail_log = os.path.join(download_dir, 'fail_list_inst.txt')


def download_youtube_inst_wav(search_queries, output_dir, max_retries=2):
    """
    yt-dlp를 이용해 유튜브에서 inst(반주) 영상을 검색 후 상위 1개 영상을 wav로 다운로드합니다.
    inst, instrumental, MR, 반주 순으로 검색어를 바꿔가며 시도합니다.
    이미 존재하는 파일은 건너뜁니다.
    성공/실패 결과를 각각 로그 파일에 기록합니다.
    :param search_queries: (곡명, 가수명) 튜플 리스트
    :param output_dir: wav 파일 저장 경로
    :param max_retries: 실패 시 재시도 횟수
    """
    search_keywords = ["inst", "instrumental", "MR", "반주"]
    with open(download_success_log, 'w', encoding='utf-8') as success_f, \
         open(download_fail_log, 'w', encoding='utf-8') as fail_f:
        for song, artist in search_queries:
            # 파일명: 곡명_가수명_inst (확장자 없이)
            base_filename = f"{song}_{artist}".replace(" ", "_") + "_inst"
            # 혹시 .wav가 이미 붙어있으면 제거
            if base_filename.lower().endswith('.wav'):
                base_filename = base_filename[:-4]
            output_path = os.path.join(output_dir, base_filename)
            wav_path = output_path + '.wav'

            # 이미 파일이 존재하면 건너뜀
            if os.path.exists(wav_path):
                print(f"이미 존재: {wav_path}, 건너뜀")
                success_f.write(f"{song},{artist},이미존재\n")
                continue

            success = False
            for keyword in search_keywords:
                # 검색어: 가수명 곡명 inst/반주 등
                query = f"{artist} {song} {keyword}"
                # yt-dlp 옵션 설정
                ydl_opts = {
                    'format': 'bestaudio/best',
                    'outtmpl': output_path,  # 확장자 없이 저장
                    'postprocessors': [{
                        'key': 'FFmpegExtractAudio',
                        'preferredcodec': 'wav',
                        'preferredquality': '192',
                    }],
                    'noplaylist': True,
                    'quiet': False,
                }
                # 다운로드 시도 (최대 max_retries+1회)
                for attempt in range(1, max_retries + 2):
                    try:
                        print(f"[시도 {attempt}] 검색 및 다운로드: {query}")
                        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                            ydl.download([f"ytsearch1:{query}"])
                        if os.path.exists(wav_path):
                            print(f"다운로드 성공: {wav_path}")
                            success_f.write(f"{song},{artist},성공,{keyword}\n")
                            success = True
                            break
                        else:
                            print(f"다운로드 후 파일이 존재하지 않음: {wav_path}")
                    except Exception as e:
                        print(f"다운로드 실패: {query}\n에러: {e}")
                        time.sleep(2)  # 잠시 대기 후 재시도
                if success:
                    break
            if not success:
                print(f"최종 실패: {song}, {artist}")
                fail_f.write(f"{song},{artist},실패\n")


def read_csv_queries(csv_path):
    """
    csv 파일에서 곡명, 가수명 컬럼을 읽어 리스트로 반환합니다.
    :param csv_path: csv 파일 경로
    :return: (곡명, 가수명) 튜플 리스트
    """
    df = pd.read_csv(csv_path)
    queries = []
    # 한글 주석: '노래제목', '가수' 컬럼에서 정보 추출
    for _, row in df.iterrows():
        song = str(row['노래제목']).strip()
        artist = str(row['가수']).strip()
        if song and artist:
            queries.append((song, artist))
    return queries

if __name__ == '__main__':
    # csv에서 검색어 리스트 읽기
    if not os.path.exists(CSV_PATH):
        print(f"곡/가수/가사 csv 파일을 찾을 수 없습니다: {CSV_PATH}")
    else:
        search_queries = read_csv_queries(CSV_PATH)
        download_youtube_inst_wav(search_queries, download_dir) 