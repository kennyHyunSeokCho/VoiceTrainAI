import boto3
import os
from dotenv import load_dotenv

load_dotenv()

def get_album_cover_url(artist: str, title: str) -> str:
    s3_client = boto3.client(
        "s3",
        AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID"),
        AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY"),
        AWS_REGION = os.getenv("AWS_REGION", "ap-northeast-2"),
        S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME", "ai-vocal-training"),
    )
    # 파일명: 가수_노래제목.jpg
    filename = f"{artist}_{title}.jpg"
    key = f"album_cover/{filename}"
    url = s3_client.generate_presigned_url(
        "get_object",
        Params={"Bucket": os.getenv("S3_BUCKET_NAME"), "Key": key},
        ExpiresIn=3600,  # 1시간 유효
    )
    return url
