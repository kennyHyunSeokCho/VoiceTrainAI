import os
import boto3
from pathlib import Path
from vocal_separation import VocalSeparator

# AWS S3 설정
BUCKET_NAME = 'ai-vocal-training'
ORIGINAL_PREFIX = 'original/'  # 원본 오디오 파일 S3 경로
INST_PREFIX = 'inst/'          # 분리된 inst 파일 S3 경로

# 로컬 임시 폴더 경로 수정
LOCAL_INPUT_DIR = 'data/music_file/s3_down'      # S3에서 다운로드한 원본 파일 저장 경로
LOCAL_OUTPUT_DIR = 'data/music_file/seperated'  # 분리된 inst 파일 저장 경로
os.makedirs(LOCAL_INPUT_DIR, exist_ok=True)
os.makedirs(LOCAL_OUTPUT_DIR, exist_ok=True)

# S3 클라이언트 생성
s3 = boto3.client('s3')

def list_s3_audio_files(bucket, prefix):
    """
    S3 버킷에서 지정된 prefix 하위의 오디오 파일 리스트를 반환합니다.
    """
    paginator = s3.get_paginator('list_objects_v2')
    page_iterator = paginator.paginate(Bucket=bucket, Prefix=prefix)
    audio_files = []
    for page in page_iterator:
        for obj in page.get('Contents', []):
            key = obj['Key']
            if key.endswith('.wav') or key.endswith('.mp3'):
                audio_files.append(key)
    return audio_files

def download_s3_file(bucket, s3_key, local_path):
    """
    S3에서 파일을 로컬로 다운로드합니다.
    """
    s3.download_file(bucket, s3_key, local_path)

def upload_s3_file(local_path, bucket, s3_key):
    """
    로컬 파일을 S3로 업로드합니다.
    """
    s3.upload_file(local_path, bucket, s3_key)

def main():
    # 성공/실패 로그 파일 경로
    success_log_path = 'success_list.txt'
    fail_log_path = 'fail_list.txt'
    with open(success_log_path, 'w', encoding='utf-8') as success_f, \
         open(fail_log_path, 'w', encoding='utf-8') as fail_f:
        # 1. S3에서 오디오 파일 리스트 가져오기
        audio_files = list_s3_audio_files(BUCKET_NAME, ORIGINAL_PREFIX)
        print(f"총 {len(audio_files)}개 파일 발견")

        # 2. 분리기 준비
        separator = VocalSeparator('htdemucs')

        for s3_key in audio_files:
            filename = os.path.basename(s3_key)
            local_input_path = os.path.join(LOCAL_INPUT_DIR, filename)
            # 3. S3에서 파일 다운로드
            print(f"S3에서 다운로드: {s3_key} → {local_input_path}")
            download_s3_file(BUCKET_NAME, s3_key, local_input_path)
            try:
                # 4. 보컬/inst 분리
                result = separator.separate_audio(local_input_path, LOCAL_OUTPUT_DIR)
                inst_path = result.get('inst')
                if inst_path and os.path.exists(inst_path):
                    # 5. inst 파일 S3로 업로드 (경로: inst/원본파일명_inst.wav)
                    inst_filename = Path(inst_path).name
                    s3_inst_key = INST_PREFIX + inst_filename
                    print(f"inst 업로드: {inst_path} → {s3_inst_key}")
                    upload_s3_file(inst_path, BUCKET_NAME, s3_inst_key)
                    # 성공 로그 기록
                    success_f.write(f"{s3_key},{s3_inst_key},성공\n")
                else:
                    print(f"inst 파일 생성 실패: {local_input_path}")
                    fail_f.write(f"{s3_key},,inst 파일 생성 실패\n")
            except Exception as e:
                print(f"분리 실패: {local_input_path}, 에러: {e}")
                fail_f.write(f"{s3_key},,{e}\n")
            # 임시 파일 삭제
            try:
                if os.path.exists(local_input_path):
                    os.remove(local_input_path)
                if inst_path and os.path.exists(inst_path):
                    os.remove(inst_path)
            except Exception as e:
                print(f"임시 파일 삭제 실패: {e}")

if __name__ == "__main__":
    main() 