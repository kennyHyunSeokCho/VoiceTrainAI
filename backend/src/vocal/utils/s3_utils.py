import boto3
from config import AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, S3_BUCKET_NAME

def get_album_cover_url(artist: str, title: str) -> str:
    s3_client = boto3.client(
        "s3",
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        region_name=AWS_REGION,
    )
    # 파일명: 가수_노래제목.jpg
    filename = f"{artist}_{title}.jpg"
    key = f"album_cover/{filename}"
    url = s3_client.generate_presigned_url(
        "get_object",
        Params={"Bucket": S3_BUCKET_NAME, "Key": key},
        ExpiresIn=3600,  # 1시간 유효
    )
    return url
