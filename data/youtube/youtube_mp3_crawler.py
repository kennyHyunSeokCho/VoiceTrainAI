import os
import yt_dlp
import pandas as pd

# 곡명/가수명/가사 CSV 파일 경로 (data/info/chart_song_singer_lyrics.csv)
CSV_PATH = os.path.join(os.path.dirname(__file__), '..', 'info', 'chart_song_singer_lyrics.csv')

# wav 파일이 저장될 폴더 경로 (data/music_file)
download_dir = os.path.join(os.path.dirname(__file__), '..', 'music_file')
os.makedirs(download_dir, exist_ok=True)

def download_youtube_as_wav(search_queries, output_dir):
    """
    yt-dlp를 이용해 유튜브에서 검색 후 상위 1개 영상을 wav로 다운로드합니다.
    :param search_queries: (곡명, 가수명) 튜플 리스트
    :param output_dir: wav 파일 저장 경로
    """
    for song, artist in search_queries:
        # 검색어: 가수명 곡명 가사 (뮤직비디오 대신 가사 영상 우선)
        query = f"{artist} {song} 가사"
        # 파일명: 곡명_가수명 (확장자 없이)
        base_filename = f"{song}_{artist}".replace(" ", "_")
        # 혹시 .wav가 이미 붙어있으면 제거
        if base_filename.lower().endswith('.wav'):
            base_filename = base_filename[:-4]
        output_path = os.path.join(output_dir, base_filename)
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
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            try:
                print(f"검색 및 다운로드: {query}")
                ydl.download([f"ytsearch1:{query}"])
                print(f"다운로드 완료: {base_filename}.wav")
            except Exception as e:
                print(f"다운로드 실패: {query}\n에러: {e}")

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
        download_youtube_as_wav(search_queries, download_dir) 