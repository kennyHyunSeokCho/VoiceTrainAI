import os
import boto3
from pathlib import Path

# S3 설정
BUCKET_NAME = 'ai-vocal-training'
VOCAL_PREFIX = 'vocal/'
INST_PREFIX = 'inst/'

# 로컬 폴더 경로 (실제 폴더명으로 수정)
VOCAL_DIR = 'data/seperated_voice'
INST_DIR = 'data/seperated-inst'

# S3 클라이언트 생성
s3 = boto3.client('s3')

def upload_all_files_recursive(local_dir, s3_prefix, log_file):
    """하위 폴더까지 모든 파일을 S3에 업로드 (한글 주석)"""
    total, success, fail = 0, 0, 0
    with open(log_file, "w", encoding="utf-8") as logf:
        for dirpath, _, filenames in os.walk(local_dir):
            for fname in filenames:
                local_path = os.path.join(dirpath, fname)
                # S3 경로: vocal/가수명/파일명 (local_dir 이후 경로를 S3에 그대로 반영)
                rel_path = os.path.relpath(local_path, local_dir)
                s3_key = f"{s3_prefix}{rel_path.replace(os.sep, '/')}"
                total += 1
                try:
                    print(f"S3 업로드: {local_path} → {s3_key}")
                    s3.upload_file(local_path, BUCKET_NAME, s3_key)
                    logf.write(f"SUCCESS,{local_path},{s3_key}\n")
                    success += 1
                except Exception as e:
                    print(f"업로드 실패: {local_path} → {s3_key}, 에러: {e}")
                    logf.write(f"FAIL,{local_path},{s3_key},{e}\n")
                    fail += 1
    print(f"총 {total}개 중 성공 {success}개, 실패 {fail}개")

def main():
    print("보컬 파일 S3 업로드(가수별 폴더) 시작")
    upload_all_files_recursive(VOCAL_DIR, VOCAL_PREFIX, "vocal_upload_log.txt")
    print("inst 파일 S3 업로드(가수별 폴더) 시작")
    upload_all_files_recursive(INST_DIR, INST_PREFIX, "inst_upload_log.txt")
    print("모든 업로드 완료!")

if __name__ == "__main__":
    main() 