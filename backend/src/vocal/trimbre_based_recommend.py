import boto3
import json
import numpy as np
from tqdm import tqdm
from sklearn.metrics.pairwise import cosine_similarity as sk_cosine
from sklearn.metrics.pairwise import euclidean_distances
from src.vocal.s3_config import AWS_ACCESS_KEY, AWS_SECRET_KEY, BUCKET_NAME, USER_BUCKET_NAME, REGION_NAME
import sys
import os

# 데이터베이스 관련 import
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
from src.DB.database import SessionLocal
from src.DB.models import RecommendSongs, Song

# 사용자 임베딩 로드 함수 (로컬 파일)
def load_user_embedding(path):
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

# S3에서 곡 임베딩 파일 리스트 가져오기 (BUCKET_NAME)
def list_song_embedding_files(s3):
    result = []
    paginator = s3.get_paginator('list_objects_v2')
    for page in paginator.paginate(Bucket=BUCKET_NAME):
        for obj in page.get('Contents', []):
            key = obj['Key']
            if key.startswith('timbre_embeddings/') and key.endswith('_embedding.json'):
                result.append(key)
    return result

# S3에서 summary 파일 리스트 가져오기 (BUCKET_NAME)
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

# S3에서 곡 임베딩 로드 (BUCKET_NAME)
def load_song_embedding_from_s3(s3, key):
    obj = s3.get_object(Bucket=BUCKET_NAME, Key=key)
    data = json.loads(obj['Body'].read().decode('utf-8'))
    for k in ['embedding', 'song_embedding', 'unified_embedding']:
        if k in data:
            return np.array(data[k])
    raise KeyError(f"지원되는 임베딩 키가 없습니다: {list(data.keys())}")

# S3에서 summary 임베딩 로드 (BUCKET_NAME)
def load_summary_embedding_from_s3(s3, key):
    obj = s3.get_object(Bucket=BUCKET_NAME, Key=key)
    data = json.loads(obj['Body'].read().decode('utf-8'))
    for k in ['embedding', 'unified_embedding', 'summary_embedding']:
        if k in data:
            return np.array(data[k])
    raise KeyError(f"지원되는 임베딩 키가 없습니다: {list(data.keys())}")

# 최신 사용자 임베딩 로드 (USER_BUCKET_NAME)
def load_latest_user_embedding_from_s3(s3, user_id):
    prefix = f'user_embeddings/{user_id}/'
    response = s3.list_objects_v2(Bucket=USER_BUCKET_NAME, Prefix=prefix)
    files = [obj['Key'] for obj in response.get('Contents', []) if obj['Key'].endswith('.json')]
    if not files:
        raise FileNotFoundError(f"USER_BUCKET에 {user_id} 임베딩 파일이 없습니다.")
    latest_file = sorted(files)[-1]
    obj = s3.get_object(Bucket=USER_BUCKET_NAME, Key=latest_file)
    data = json.loads(obj['Body'].read().decode('utf-8'))
    for k in ['embedding', 'song_embedding', 'unified_embedding']:
        if k in data:
            return np.array(data[k])
    raise KeyError(f"지원되는 임베딩 키가 없습니다: {list(data.keys())}")

# 사용자 summary 임베딩 로드 (USER_BUCKET_NAME)
def load_user_summary_from_s3(s3, user_id):
    # 먼저 summary 파일 시도
    summary_key = f"{user_id}/timbre/{user_id}_summary.json"
    try:
        obj = s3.get_object(Bucket=USER_BUCKET_NAME, Key=summary_key)
        data = json.loads(obj['Body'].read().decode('utf-8'))
        # embedding 키를 우선적으로 사용
        if 'embedding' in data and data['embedding'] is not None:
            return np.array(data['embedding'])
        # 다른 지원되는 임베딩 키들도 검사
        for k in ['unified_embedding', 'summary_embedding', 'song_embedding']:
            if k in data and data[k] is not None:
                return np.array(data[k])
    except Exception as e:
        print(f"⚠️  summary 파일 로드 실패: {str(e)}")
    
    # summary 파일에서 embedding을 찾을 수 없으면 vocal 파일들 확인
    try:
        prefix = f'{user_id}/timbre/'
        response = s3.list_objects_v2(Bucket=USER_BUCKET_NAME, Prefix=prefix)
        
        for obj in response.get('Contents', []):
            key = obj['Key']
            if key.endswith('.json') and 'vocal' in key:
                try:
                    obj = s3.get_object(Bucket=USER_BUCKET_NAME, Key=key)
                    data = json.loads(obj['Body'].read().decode('utf-8'))
                    
                    if 'embedding' in data and data['embedding'] is not None:
                        print(f"✅ vocal 파일에서 embedding 발견: {key}")
                        return np.array(data['embedding'])
                        
                except Exception as e:
                    print(f"⚠️  vocal 파일 로드 실패 {key}: {str(e)}")
                    continue
    except Exception as e:
        print(f"⚠️  vocal 파일 검색 실패: {str(e)}")
    
    raise KeyError(f"사용자 {user_id}의 유효한 임베딩을 찾을 수 없습니다.")

def estimate_max_distance(reference, vectors):
    distances = [euclidean_distances(reference.reshape(1, -1), v.reshape(1, -1))[0][0] for v in vectors]
    return max(distances)

def save_recommendations_to_db(user_id, song_names, singer_names):
    """추천 결과를 데이터베이스에 저장합니다."""
    try:
        db = SessionLocal()
        
        # 기존 추천 정보 삭제 (upsert 방식)
        existing_recommend = db.query(RecommendSongs).filter(RecommendSongs.user_id == user_id).first()
        if existing_recommend:
            db.delete(existing_recommend)
            db.commit()
        
        # 새로운 추천 정보 생성
        recommend = RecommendSongs(user_id=user_id)
        
        # 추천 노래 제목을 직접 저장 (song_id가 아닌 제목 문자열)
        for i, song_name in enumerate(song_names[:5], 1):  # 최대 5개
            setattr(recommend, f'song{i}', song_name)
            print(f"   📝 song{i}: {song_name}")
        
        # 추천 가수 이름 저장
        for i, singer_name in enumerate(singer_names[:3], 1):  # 최대 3개
            setattr(recommend, f'singer{i}', singer_name)
            print(f"   🎤 singer{i}: {singer_name}")
        
        # 데이터베이스에 저장
        db.add(recommend)
        db.commit()
        
        print(f"✅ 추천 결과가 데이터베이스에 저장되었습니다.")
        return True
        
    except Exception as e:
        print(f"❌ 데이터베이스 저장 중 오류: {e}")
        db.rollback()
        return False
    finally:
        db.close()

def combined_similarity(a, b, max_dist, alpha=0.7):
    a = a.reshape(1, -1)
    b = b.reshape(1, -1)
    cosine_sim = sk_cosine(a, b)[0][0]
    euclidean_dist = euclidean_distances(a, b)[0][0]
    norm_dist = min(euclidean_dist / max_dist, 1.0)
    euclid_sim = 1 - norm_dist
    return alpha * cosine_sim + (1 - alpha) * euclid_sim

def main(user_id):
    s3 = get_s3_client()
    user_emb = load_user_summary_from_s3(s3, user_id)

    # user_emb 타입 및 NaN 체크
    if not isinstance(user_emb, np.ndarray):
        raise TypeError(f"user_emb가 np.ndarray가 아닙니다. 실제 타입: {type(user_emb)}, 값: {user_emb}")
    if not (np.issubdtype(user_emb.dtype, np.floating) or np.issubdtype(user_emb.dtype, np.integer)):
        raise TypeError(f"user_emb의 dtype이 float 또는 int가 아닙니다. dtype: {user_emb.dtype}, 값: {user_emb}")
    if np.isnan(user_emb).any():
        raise ValueError(f"user_emb에 NaN 값이 포함되어 있습니다: {user_id}")

    # 1. 곡 추천 (BUCKET_NAME)
    song_files = list_song_embedding_files(s3)
    all_embeddings = []
    for key in song_files:
        try:
            emb = load_song_embedding_from_s3(s3, key)
            all_embeddings.append(emb)
        except Exception as e:
            print(f"Error loading {key}: {e}")

    # NaN이 없는 곡 임베딩만 사용
    valid_embeddings = []
    valid_keys = []
    for emb, key in zip(all_embeddings, song_files):
        if not np.isnan(emb).any():
            valid_embeddings.append(emb)
            valid_keys.append(key)
        else:
            print(f"제외: {key} (NaN 포함)")

    if not valid_embeddings:
        raise ValueError("유효한 곡 임베딩이 없습니다.")

    max_dist = estimate_max_distance(user_emb, valid_embeddings)

    song_scores = []
    for emb, key in zip(valid_embeddings, valid_keys):
        sim = combined_similarity(user_emb, emb, max_dist)
        song_scores.append((key, sim))

    top5_songs = sorted(song_scores, key=lambda x: x[1], reverse=True)[:5]
    song_names = [key.split('/')[-1].replace('_embedding.json', '').replace('_', ' ') for key, _ in top5_songs]

    # 2. 가수 추천 (BUCKET_NAME)
    summary_files = list_summary_files(s3)
    summary_embeddings = []
    summary_keys = []
    for key in summary_files:
        try:
            emb = load_summary_embedding_from_s3(s3, key)
            summary_embeddings.append(emb)
            summary_keys.append(key)
        except Exception as e:
            print(f"Error loading {key} (singer_unified_embedding): {e}")

    # NaN이 없는 summary 임베딩만 사용
    valid_summary_embeddings = []
    valid_summary_keys = []
    for emb, key in zip(summary_embeddings, summary_keys):
        if not np.isnan(emb).any():
            valid_summary_embeddings.append(emb)
            valid_summary_keys.append(key)
        else:
            print(f"제외: {key} (NaN 포함)")

    if not valid_summary_embeddings:
        raise ValueError("유효한 summary 임베딩이 없습니다.")

    max_dist_summary = estimate_max_distance(user_emb, valid_summary_embeddings)

    singer_scores = []
    for emb, key in zip(valid_summary_embeddings, valid_summary_keys):
        sim = combined_similarity(user_emb, emb, max_dist_summary)
        singer = key.split('/')[1]
        singer_scores.append((singer, sim))

    top3_singers = sorted(singer_scores, key=lambda x: x[1], reverse=True)[:3]
    singer_names = [singer for singer, _ in top3_singers]

    result = {"songs": song_names, "singers": singer_names}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    
    # 데이터베이스에 추천 결과 저장
    save_recommendations_to_db(user_id, song_names, singer_names)
    
    return result

if __name__ == "__main__":
    import sys
    user_id = sys.argv[1] if len(sys.argv) > 1 else None
    if not user_id:
        print("[ERROR] user_id를 인자로 전달해야 합니다.")
        exit(1)
    main(user_id)
