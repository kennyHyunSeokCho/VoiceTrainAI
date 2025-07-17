import os
import boto3
from pathlib import Path

BUCKET_NAME = 'ai-vocal-training'
ORIGINAL_PREFIX = 'original/'
LOCAL_INPUT_DIR = 'data/music_file/s3_down'
os.makedirs(LOCAL_INPUT_DIR, exist_ok=True)
s3 = boto3.client('s3')

def list_s3_audio_files(bucket, prefix):
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
    s3.download_file(bucket, s3_key, local_path)

def main():
    success_log = 'download_success_list.txt'
    fail_log = 'download_fail_list.txt'
    with open(success_log, 'w', encoding='utf-8') as success_f, \
         open(fail_log, 'w', encoding='utf-8') as fail_f:
        audio_files = list_s3_audio_files(BUCKET_NAME, ORIGINAL_PREFIX)
        print(f"총 {len(audio_files)}개 파일 발견")
        for s3_key in audio_files:
            filename = os.path.basename(s3_key)
            local_path = os.path.join(LOCAL_INPUT_DIR, filename)
            try:
                print(f"다운로드: {s3_key} → {local_path}")
                download_s3_file(BUCKET_NAME, s3_key, local_path)
                success_f.write(f"{s3_key},{local_path},성공\n")
            except Exception as e:
                print(f"다운로드 실패: {s3_key}, 에러: {e}")
                fail_f.write(f"{s3_key},,{e}\n")

if __name__ == "__main__":
    main() 