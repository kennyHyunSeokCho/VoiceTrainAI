import pandas as pd
import re

def format_lyrics(lyrics):
    """가사에 줄바꿈을 추가하는 함수"""
    if pd.isna(lyrics) or lyrics == '':
        return lyrics
    
    # 문장 끝 부호들 (마침표, 느낌표, 물음표) 뒤에 줄바꿈 추가
    formatted_lyrics = lyrics
    formatted_lyrics = re.sub(r'([.!?。！？])\s+', r'\1\n', formatted_lyrics)
    
    # 마지막 문장도 줄바꿈 처리
    if formatted_lyrics and formatted_lyrics[-1] in '.!?。！？':
        formatted_lyrics += '\n'
    
    return formatted_lyrics

def process_csv_file(input_file, output_file):
    """CSV 파일의 가사에 줄바꿈을 추가하는 함수"""
    # CSV 파일 읽기
    df = pd.read_csv(input_file)
    
    # 가사 컬럼에 줄바꿈 추가
    if '가사' in df.columns:
        df['가사'] = df['가사'].apply(format_lyrics)
        print(f"가사 처리 완료: {len(df)}개 곡")
    else:
        print("'가사' 컬럼을 찾을 수 없습니다.")
        return
    
    # 수정된 CSV 파일 저장
    df.to_csv(output_file, index=False, encoding='utf-8')
    print(f"수정된 파일이 {output_file}에 저장되었습니다.")

if __name__ == "__main__":
    input_file = "all_chart_songs.csv"
    output_file = "all_chart_songs_formatted.csv"
    
    try:
        process_csv_file(input_file, output_file)
        print("가사 포맷팅이 완료되었습니다!")
    except Exception as e:
        print(f"오류가 발생했습니다: {e}") 