import os
import boto3
from pathlib import Path

BUCKET_NAME = 'ai-vocal-training'
INST_PREFIX = 'inst/'
LOCAL_OUTPUT_DIR = 'data/music_file/seperated_inst'
s3 = boto3.client('s3')

def upload_s3_file(local_path, bucket, s3_key):
    s3.upload_file(local_path, bucket, s3_key)

def main():
    success_log = 'upload_success_list.txt'
    fail_log = 'upload_fail_list.txt'
    with open(success_log, 'w', encoding='utf-8') as success_f, \
         open(fail_log, 'w', encoding='utf-8') as fail_f:
        files = [f for f in os.listdir(LOCAL_OUTPUT_DIR) if f.endswith('_inst.wav')]
        print(f"총 {len(files)}개 inst 파일 발견")
        for filename in files:
            local_path = os.path.join(LOCAL_OUTPUT_DIR, filename)
            s3_key = INST_PREFIX + filename
            try:
                print(f"업로드: {local_path} → {s3_key}")
                upload_s3_file(local_path, BUCKET_NAME, s3_key)
                success_f.write(f"{local_path},{s3_key},성공\n")
            except Exception as e:
                print(f"업로드 실패: {local_path}, 에러: {e}")
                fail_f.write(f"{local_path},,{e}\n")

if __name__ == "__main__":
    main() 