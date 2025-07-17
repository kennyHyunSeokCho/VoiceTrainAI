import boto3
import json
import numpy as np
from tqdm import tqdm
from sklearn.metrics.pairwise import cosine_similarity as sk_cosine
from sklearn.metrics.pairwise import euclidean_distances
from s3_config import AWS_ACCESS_KEY, AWS_SECRET_KEY, BUCKET_NAME, REGION_NAME

# S3 정보 입력 (직접 입력 필요

# 사용자 임베딩 로드 함수 (로컬 파일)
def load_user_embedding(path='backend/src/vocal/test_audio/hubert_embedding_result.json'):
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    if 'embedding' in data:
        return np.array(data['embedding'])
    raise KeyError(f"'embedding' 키가 없습니다. 실제 키: {list(data.keys())}")

# S3 클라이언트 생성
def get_s3_client():
    return boto3.client(
        's3',
        aws_access_key_id=AWS_ACCESS_KEY,
        aws_secret_access_key=AWS_SECRET_KEY,
        region_name=REGION_NAME
    )

# S3에서 곡 임베딩 파일 리스트 가져오기
def list_song_embedding_files(s3):
    result = []
    paginator = s3.get_paginator('list_objects_v2')
    for page in paginator.paginate(Bucket=BUCKET_NAME):
        for obj in page.get('Contents', []):
            key = obj['Key']
            if key.startswith('timbre_embeddings/') and key.endswith('_embedding.json'):
                result.append(key)
    return result

# S3에서 summary 파일 리스트 가져오기
def list_summary_files(s3):
    result = []
    paginator = s3.get_paginator('list_objects_v2')
    for page in paginator.paginate(Bucket=BUCKET_NAME):
        for obj in page.get('Contents', []):
            key = obj['Key']
            if key.startswith('timbre_embeddings/') and \
               key.endswith('_summary.json') and \
               not key.endswith('overall_summary.json') and \
               not key.endswith('/summary.json'):
                result.append(key)
    return result

# S3에서 곡 임베딩 로드
def load_song_embedding_from_s3(s3, key):
    obj = s3.get_object(Bucket=BUCKET_NAME, Key=key)
    data = json.loads(obj['Body'].read().decode('utf-8'))
    # 여러 키 후보 지원: 'embedding', 'song_embedding', 'unified_embedding'
    for k in ['embedding', 'song_embedding', 'unified_embedding']:
        if k in data:
            return np.array(data[k])
    raise KeyError(f"지원되는 임베딩 키가 없습니다: {list(data.keys())}")

# S3에서 summary 임베딩 로드
# 여러 키 후보 지원: 'embedding', 'unified_embedding', 'summary_embedding'
def load_summary_embedding_from_s3(s3, key):
    obj = s3.get_object(Bucket=BUCKET_NAME, Key=key)
    data = json.loads(obj['Body'].read().decode('utf-8'))
    for k in ['embedding', 'unified_embedding', 'summary_embedding']:
        if k in data:
            return np.array(data[k])
    raise KeyError(f"지원되는 임베딩 키가 없습니다: {list(data.keys())}")

# 모든 벡터 간 평균 유클리디안 거리 계산
def estimate_max_distance(reference, vectors):
    distances = [euclidean_distances(reference.reshape(1, -1), v.reshape(1, -1))[0][0] for v in vectors]
    return max(distances)

# 유사도 계산 함수 (코사인 + 정규화된 유클리디안 혼합, max_dist는 사전 계산)
def combined_similarity(a, b, max_dist, alpha=0.7):
    a = a.reshape(1, -1)
    b = b.reshape(1, -1)
    cosine_sim = sk_cosine(a, b)[0][0]
    euclidean_dist = euclidean_distances(a, b)[0][0]
    norm_dist = min(euclidean_dist / max_dist, 1.0)
    euclid_sim = 1 - norm_dist
    return alpha * cosine_sim + (1 - alpha) * euclid_sim

# 최신 사용자 임베딩 로드
# 여러 키 후보 지원: 'embedding', 'song_embedding', 'unified_embedding'
def load_latest_user_embedding_from_s3(s3, singer_name='도경수'):
    prefix = f'user_embeddings/{singer_name}/'
    response = s3.list_objects_v2(Bucket=BUCKET_NAME, Prefix=prefix)
    files = [obj['Key'] for obj in response.get('Contents', []) if obj['Key'].endswith('.json')]
    if not files:
        raise FileNotFoundError(f"S3에 {singer_name} 임베딩 파일이 없습니다.")
    latest_file = sorted(files)[-1]
    obj = s3.get_object(Bucket=BUCKET_NAME, Key=latest_file)
    data = json.loads(obj['Body'].read().decode('utf-8'))
    for k in ['embedding', 'song_embedding', 'unified_embedding']:
        if k in data:
            return np.array(data[k])
    raise KeyError(f"지원되는 임베딩 키가 없습니다: {list(data.keys())}")

def main():
    s3 = get_s3_client()
    user_emb = load_latest_user_embedding_from_s3(s3, singer_name='도경수')

    # 1. 곡 추천
    song_files = list_song_embedding_files(s3)
    all_embeddings = []
    for key in tqdm(song_files, desc='곡 임베딩 로드 중'):
        try:
            emb = load_song_embedding_from_s3(s3, key)
            all_embeddings.append(emb)
        except Exception as e:
            print(f"Error loading {key}: {e}")

    max_dist = estimate_max_distance(user_emb, all_embeddings)

    song_scores = []
    for emb, key in zip(all_embeddings, song_files):
        sim = combined_similarity(user_emb, emb, max_dist)
        song_scores.append((key, sim))

    top5_songs = sorted(song_scores, key=lambda x: x[1], reverse=True)[:5]

    print("\n[추천 곡 Top 5]")
    for key, score in top5_songs:
        print(f"{key} (유사도: {score:.4f})")

    # 2. 가수 추천
    summary_files = list_summary_files(s3)
    summary_embeddings = []
    summary_keys = []
    for key in tqdm(summary_files, desc='가수 summary 로드 중'):
        try:
            emb = load_summary_embedding_from_s3(s3, key)
            summary_embeddings.append(emb)
            summary_keys.append(key)
        except Exception as e:
            print(f"Error loading {key} (singer_unified_embedding): {e}")

    max_dist_summary = estimate_max_distance(user_emb, summary_embeddings)

    singer_scores = []
    for emb, key in zip(summary_embeddings, summary_keys):
        sim = combined_similarity(user_emb, emb, max_dist_summary)
        singer = key.split('/')[1]
        singer_scores.append((singer, sim))

    top3_singers = sorted(singer_scores, key=lambda x: x[1], reverse=True)[:3]

    print("\n[추천 가수 Top 3]")
    for singer, score in top3_singers:
        print(f"{singer} (유사도: {score:.4f})")

if __name__ == "__main__":
    main()
