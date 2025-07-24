"""
가수 임베딩 기반 노래 추천 시스템
HuBERT 모델을 사용한 음성 임베딩 추출 및 유사도 계산
"""

import os
import json
import numpy as np
from datetime import datetime
from typing import Dict, List, Tuple, Optional
import pickle
from .user_embedding_extractor import UserEmbeddingExtractor
from .s3_utils import get_s3_client, download_s3_folder, upload_file_to_s3, get_singer_list_from_s3
from .s3_utils import get_s3_client_from_env, download_s3_folder, upload_file_to_s3, get_singer_list_from_s3

class SingerEmbeddingSystem:
    """가수 임베딩 기반 추천 시스템"""
    
    def __init__(self, model_name="superb/hubert-large-superb-sid"):
        self.model_name = model_name
        self.model = None
        self.feature_extractor = None
        self.singer_embeddings = {}  # {singer_name: embedding}
        self.song_database = {}      # {singer_name: [song_list]}
        self.song_embeddings = {}    # {singer_name: {song_path: embedding}}
        
    def load_model(self):
        """HuBERT 모델 로드"""
        try:
            import torch
            from transformers import HubertForSequenceClassification, Wav2Vec2FeatureExtractor
            
            print(f"모델 로딩 중: {self.model_name}")
            self.model = HubertForSequenceClassification.from_pretrained(self.model_name)
            self.feature_extractor = Wav2Vec2FeatureExtractor.from_pretrained(self.model_name)
            self.model.eval()
            self.user_extractor = UserEmbeddingExtractor(self.model, self.feature_extractor)
            print("✓ 모델 로딩 완료")
            return True
        except Exception as e:
            print(f"✗ 모델 로딩 실패: {e}")
            return False
    
    def extract_user_embedding(self, audio_path: str):
        if not hasattr(self, 'user_extractor') or self.user_extractor is None:
            print("UserEmbeddingExtractor가 초기화되지 않았습니다. load_model()을 먼저 호출하세요.")
            return None
        return self.user_extractor.extract_user_embedding(audio_path)
    
    def build_singer_embedding(self, singer_name: str, song_paths: List[str]) -> bool:
        print(f"\n가수 '{singer_name}' 임베딩 구축 중...")

        song_embeddings = {}
        valid_songs = []

        for song_path in song_paths:
            print(f"  처리 중: {os.path.basename(song_path)}")
            embedding = self.extract_user_embedding(song_path)
            if embedding is not None:
                song_embeddings[song_path] = embedding
                valid_songs.append(song_path)

        if len(song_embeddings) == 0:
            print(f"✗ 가수 '{singer_name}': 유효한 곡이 없습니다.")
            return False

        # 곡별 임베딩 캐싱
        self.song_embeddings[singer_name] = song_embeddings
        self.song_database[singer_name] = valid_songs

        # 가수 임베딩 = 곡별 임베딩의 평균
        singer_embedding = np.mean(list(song_embeddings.values()), axis=0)
        self.singer_embeddings[singer_name] = singer_embedding

        print(f"✓ 가수 '{singer_name}': {len(valid_songs)}곡으로 임베딩 생성 완료")
        return True
    
    def add_new_song_to_singer(self, singer_name: str, new_song_path: str) -> bool:
        """
        기존 가수의 임베딩 데이터셋에 신곡을 추가하고, 임베딩을 갱신한다.
        """
        print(f"신곡 추가: {singer_name} - {os.path.basename(new_song_path)}")
        new_embedding = self.extract_user_embedding(new_song_path)
        if new_embedding is None:
            print("임베딩 추출 실패")
            return False

        # 곡별 임베딩 캐시 추가
        if singer_name not in self.song_embeddings:
            self.song_embeddings[singer_name] = {}
        self.song_embeddings[singer_name][new_song_path] = new_embedding

        # 곡 리스트 추가
        if singer_name not in self.song_database:
            self.song_database[singer_name] = []
        self.song_database[singer_name].append(new_song_path)

        # 가수 임베딩(평균) 갱신
        embeddings = list(self.song_embeddings[singer_name].values())
        self.singer_embeddings[singer_name] = np.mean(embeddings, axis=0)
        print(f"✓ {singer_name} 임베딩 갱신 완료 (총 {len(embeddings)}곡)")
        return True
    
    def build_database_from_structure(self, dataset_root: str) -> int:
        """
        폴더 구조에서 가수 데이터베이스 구축
        dataset_root/
        ├── 가수1/
        │   ├── 곡1.wav
        │   └── 곡2.wav
        └── 가수2/
            ├── 곡3.wav
            └── 곡4.wav
        """
        if not os.path.exists(dataset_root):
            print(f"데이터셋 경로가 존재하지 않습니다: {dataset_root}")
            return 0
        
        count = 0
        for singer_name in os.listdir(dataset_root):
            singer_path = os.path.join(dataset_root, singer_name)
            if not os.path.isdir(singer_path):
                continue
            
            # 해당 가수의 모든 음성 파일 찾기
            song_paths = []
            for file_name in os.listdir(singer_path):
                if file_name.lower().endswith(('.wav', '.mp3', '.m4a', '.flac')):
                    song_paths.append(os.path.join(singer_path, file_name))
            
            if song_paths:
                if self.build_singer_embedding(singer_name, song_paths):
                    count += 1
        
        print(f"\n✓ 총 {count}명의 가수 임베딩 구축 완료")
        return count
    
    def calculate_similarity(self, user_embedding: np.ndarray, singer_name: str) -> float:
        """사용자 임베딩과 가수 임베딩의 코사인 유사도 계산"""
        if singer_name not in self.singer_embeddings:
            return 0.0
        
        singer_embedding = self.singer_embeddings[singer_name]
        
        # 코사인 유사도 계산
        dot_product = np.dot(user_embedding, singer_embedding)
        norm_user = np.linalg.norm(user_embedding)
        norm_singer = np.linalg.norm(singer_embedding)
        
        if norm_user == 0 or norm_singer == 0:
            return 0.0
        
        similarity = dot_product / (norm_user * norm_singer)
        return float(similarity)
    
    def recommend_songs(self, user_audio_path: str, top_k: int = 5) -> List[Dict]:
        """사용자 노래를 기반으로 유사한 가수의 곡 추천"""
        # 사용자 임베딩 추출
        user_embedding = self.extract_user_embedding(user_audio_path)
        if user_embedding is None:
            return []
        
        # 모든 가수와의 유사도 계산
        similarities = []
        for singer_name in self.singer_embeddings.keys():
            similarity = self.calculate_similarity(user_embedding, singer_name)
            similarities.append((singer_name, similarity))
        
        # 유사도 순으로 정렬
        similarities.sort(key=lambda x: x[1], reverse=True)
        
        # 상위 가수들의 곡 추천
        recommendations = []
        for singer_name, similarity in similarities[:top_k]:
            if singer_name in self.song_database:
                for song_path in self.song_database[singer_name]:
                    recommendations.append({
                        'singer': singer_name,
                        'song': os.path.basename(song_path),
                        'song_path': song_path,
                        'similarity': similarity
                    })
        
        return recommendations
    
    def save_database(self, file_path: str) -> bool:
        """임베딩 데이터베이스 저장"""
        try:
            data = {
                'timestamp': datetime.now().isoformat(),
                'model_name': self.model_name,
                'singer_embeddings': {k: v.tolist() for k, v in self.singer_embeddings.items()},
                'song_database': self.song_database,
                'song_embeddings': {
                    singer: {song: emb.tolist() for song, emb in song_dict.items()}
                    for singer, song_dict in self.song_embeddings.items()
                }
            }
            
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            
            print(f"✓ 데이터베이스 저장: {file_path}")
            return True
        except Exception as e:
            print(f"✗ 데이터베이스 저장 실패: {e}")
            return False
    
    def load_database(self, file_path: str) -> bool:
        """임베딩 데이터베이스 로드"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            self.singer_embeddings = {k: np.array(v) for k, v in data['singer_embeddings'].items()}
            self.song_database = data['song_database']
            self.song_embeddings = {
                singer: {song: np.array(emb) for song, emb in song_dict.items()}
                for singer, song_dict in data.get('song_embeddings', {}).items()
            }
            
            print(f"✓ 데이터베이스 로드: {file_path}")
            print(f"  가수 수: {len(self.singer_embeddings)}")
            print(f"  총 곡 수: {sum(len(songs) for songs in self.song_database.values())}")
            return True
        except Exception as e:
            print(f"✗ 데이터베이스 로드 실패: {e}")
            return False
    
    def get_statistics(self) -> Dict:
        """시스템 통계 정보"""
        total_songs = sum(len(songs) for songs in self.song_database.values())
        
        return {
            'total_singers': len(self.singer_embeddings),
            'total_songs': total_songs,
            'model_name': self.model_name,
            'embedding_dimension': list(self.singer_embeddings.values())[0].shape[0] if self.singer_embeddings else 0
        }

    def build_and_upload_singer_embeddings_from_s3(
        self,
        bucket_name: str = "ai-vocal-training",
        vocal_prefix: str = "vocal/",
        embedding_prefix: str = "embeddings/",
        local_temp_dir: str = "./temp_singer_dataset/",
        region_name: str = "ap-northeast-2"
    ) -> Dict:
        """
        S3에서 가수별 노래 데이터셋을 다운로드하여 임베딩을 생성하고,
        가수별로 S3에 저장하는 전체 파이프라인
        
        환경변수에서 AWS 자격증명을 자동으로 읽어옵니다:
        - AWS_ACCESS_KEY_ID
        - AWS_SECRET_ACCESS_KEY
        
        Args:
            aws_access_key_id: AWS Access Key ID
            aws_secret_access_key: AWS Secret Access Key
            bucket_name: S3 버킷명 (기본: ai-vocal-training)
            vocal_prefix: 가수 보컬 파일들이 있는 S3 경로 (기본: vocal/)
            embedding_prefix: 임베딩 결과를 저장할 S3 경로 (기본: embeddings/)
            local_temp_dir: 로컬 임시 폴더
            region_name: AWS 리전 (기본: ap-northeast-2)
            
        Returns:
            처리 결과 딕셔너리
        """
        print("=== S3 기반 가수 임베딩 생성 파이프라인 시작 ===\n")
        
        # S3 클라이언트 초기화
        s3_client = get_s3_client_from_env(bucket_name, region_name)
        if s3_client is None:
            return {"success": False, "error": "S3 클라이언트 초기화 실패"}
        
        # 가수 목록 조회
        print(f"S3에서 가수 목록 조회: s3://{bucket_name}/{vocal_prefix}")
        singers = get_singer_list_from_s3(s3_client, bucket_name, vocal_prefix)
        if not singers:
            return {"success": False, "error": "가수 목록이 비어있습니다"}
        
        results = {
            "success": True,
            "total_singers": len(singers),
            "processed_singers": [],
            "failed_singers": [],
            "embedding_files": []
        }
        
        for singer_name in singers:
            try:
                print(f"\n--- 가수 '{singer_name}' 처리 중 ---")
                
                # 1. 해당 가수의 S3 폴더 다운로드
                singer_s3_prefix = f"{vocal_prefix}{singer_name}/"
                singer_local_dir = os.path.join(local_temp_dir, singer_name)
                
                print(f"다운로드: s3://{bucket_name}/{singer_s3_prefix} → {singer_local_dir}")
                if not download_s3_folder(s3_client, bucket_name, singer_s3_prefix, singer_local_dir):
                    print(f"✗ {singer_name}: 다운로드 실패")
                    results["failed_singers"].append({"name": singer_name, "error": "다운로드 실패"})
                    continue
                
                # 2. 로컬에서 해당 가수의 모든 음성 파일 찾기
                song_paths = []
                for root, dirs, files in os.walk(singer_local_dir):
                    for file in files:
                        if file.lower().endswith(('.wav', '.mp3', '.m4a', '.flac')):
                            song_paths.append(os.path.join(root, file))
                
                if not song_paths:
                    print(f"✗ {singer_name}: 음성 파일이 없습니다")
                    results["failed_singers"].append({"name": singer_name, "error": "음성 파일 없음"})
                    continue
                
                print(f"발견된 곡: {len(song_paths)}개")
                
                # 3. 가수 임베딩 생성
                if not self.build_singer_embedding(singer_name, song_paths):
                    print(f"✗ {singer_name}: 임베딩 생성 실패")
                    results["failed_singers"].append({"name": singer_name, "error": "임베딩 생성 실패"})
                    continue
                
                # 4. 곡별 임베딩 파일 저장 및 S3 업로드
                for song_path in song_paths:
                    song_filename = os.path.basename(song_path)
                    song_name = os.path.splitext(song_filename)[0]
                    
                    # 곡별 JSON 파일명 생성
                    song_embedding_file = f"{song_name}_embedding.json"
                    local_song_embedding_path = os.path.join(local_temp_dir, song_embedding_file)
                    
                    # 곡별 데이터 구성
                    song_data = {
                        'timestamp': datetime.now().isoformat(),
                        'singer_name': singer_name,
                        'song_name': song_name,
                        'song_filename': song_filename,
                        'model_name': self.model_name,
                        'song_embedding': self.song_embeddings[singer_name][song_path].tolist(),
                        'singer_unified_embedding': self.singer_embeddings[singer_name].tolist(),
                        'song_metadata': {
                            'file_path': song_path,
                            'processing_time': datetime.now().isoformat()
                        }
                    }
                    
                    # 로컬에 곡별 JSON 파일 저장
                    with open(local_song_embedding_path, 'w', encoding='utf-8') as f:
                        json.dump(song_data, f, ensure_ascii=False, indent=2)
                    
                    # S3에 곡별 파일 업로드 (가수별 폴더 내)
                    s3_song_key = f"{embedding_prefix}{singer_name}/{song_embedding_file}"
                    
                    print(f"  업로드: {song_name} → s3://{bucket_name}/{s3_song_key}")
                    if upload_file_to_s3(s3_client, local_song_embedding_path, bucket_name, s3_song_key):
                        results["embedding_files"].append(s3_song_key)
                    else:
                        print(f"    ✗ {song_name}: S3 업로드 실패")
                    
                    # 로컬 임시 파일 삭제
                    if os.path.exists(local_song_embedding_path):
                        os.remove(local_song_embedding_path)

                # 가수별 요약 정보 파일도 추가로 생성 (선택사항)
                singer_summary_file = f"{singer_name}_summary.json"
                local_summary_path = os.path.join(local_temp_dir, singer_summary_file)
                
                summary_data = {
                    'timestamp': datetime.now().isoformat(),
                    'singer_name': singer_name,
                    'model_name': self.model_name,
                    'total_songs': len(self.song_database[singer_name]),
                    'songs_list': [os.path.basename(song) for song in song_paths],
                    'singer_unified_embedding': self.singer_embeddings[singer_name].tolist()
                }
                
                with open(local_summary_path, 'w', encoding='utf-8') as f:
                    json.dump(summary_data, f, ensure_ascii=False, indent=2)
                
                # 요약 파일도 S3에 업로드
                s3_summary_key = f"{embedding_prefix}{singer_name}/{singer_summary_file}"
                print(f"  요약 파일 업로드: {singer_summary_file} → s3://{bucket_name}/{s3_summary_key}")
                if upload_file_to_s3(s3_client, local_summary_path, bucket_name, s3_summary_key):
                    results["embedding_files"].append(s3_summary_key)
                
                # 요약 파일 로컬 삭제
                if os.path.exists(local_summary_path):
                    os.remove(local_summary_path)

                print(f"✓ {singer_name}: {len(song_paths)}개 곡별 임베딩 저장 완료")
                results["processed_singers"].append(singer_name)

            except Exception as e:
                print(f"✗ {singer_name}: 예외 발생 - {e}")
                results["failed_singers"].append({"name": singer_name, "error": str(e)})
        
        # 전체 임시 폴더 정리
        if os.path.exists(local_temp_dir):
            import shutil
            shutil.rmtree(local_temp_dir)
        
        print(f"\n=== 파이프라인 완료 ===")
        print(f"성공: {len(results['processed_singers'])}명")
        print(f"실패: {len(results['failed_singers'])}명")
        print(f"생성된 임베딩 파일: {len(results['embedding_files'])}개")
        
        return results

    def load_singer_embedding_from_s3(
        self,
        singer_name: str,
        bucket_name: str = "ai-vocal-training",
        embedding_prefix: str = "timbre_embeddings/",
        region_name: str = "ap-northeast-2"
    ) -> bool:
        """
        S3에서 특정 가수의 곡별 임베딩 데이터를 로드
        
        환경변수에서 AWS 자격증명을 자동으로 읽어옵니다:
        - AWS_ACCESS_KEY_ID
        - AWS_SECRET_ACCESS_KEY
        """
        s3_client = get_s3_client_from_env(bucket_name, region_name)
        if s3_client is None:
            print("S3 클라이언트 초기화 실패")
            return False
        
        try:
            # S3에서 가수 폴더의 모든 파일 목록 가져오기
            folder_prefix = f"{embedding_prefix}{singer_name}/"
            
            response = s3_client.list_objects_v2(
                Bucket=bucket_name,
                Prefix=folder_prefix
            )
            
            if 'Contents' not in response:
                print(f"✗ {singer_name}: S3에 임베딩 파일이 없습니다")
                return False
            
            # 가수 데이터 초기화
            self.song_database[singer_name] = []
            self.song_embeddings[singer_name] = {}
            singer_embedding_loaded = False
            
            song_count = 0
            summary_loaded = False
            
            # 각 파일 처리
            for obj in response['Contents']:
                s3_key = obj['Key']
                filename = os.path.basename(s3_key)
                
                # 요약 파일인지 곡별 파일인지 구분
                if filename.endswith('_summary.json'):
                    # 요약 파일 로드 (가수 통합 임베딩 포함)
                    local_temp_file = f"temp_{singer_name}_summary.json"
                    s3_client.download_file(bucket_name, s3_key, local_temp_file)
                    
                    with open(local_temp_file, 'r', encoding='utf-8') as f:
                        summary_data = json.load(f)
                    
                    # 가수 통합 임베딩 복원
                    self.singer_embeddings[singer_name] = np.array(summary_data['singer_unified_embedding'])
                    summary_loaded = True
                    
                    os.remove(local_temp_file)
                    
                elif filename.endswith('_embedding.json') and not filename.endswith('_summary.json'):
                    # 곡별 임베딩 파일 로드
                    local_temp_file = f"temp_{filename}"
                    s3_client.download_file(bucket_name, s3_key, local_temp_file)
                    
                    with open(local_temp_file, 'r', encoding='utf-8') as f:
                        song_data = json.load(f)
                    
                    # 곡 정보 복원
                    song_name = song_data['song_name']
                    song_filename = song_data['song_filename']
                    
                    # 곡 데이터베이스에 추가
                    self.song_database[singer_name].append({
                        'song_name': song_name,
                        'file_name': song_filename,
                        'file_path': song_data['song_metadata']['file_path']
                    })
                    
                    # 곡별 임베딩 복원
                    self.song_embeddings[singer_name][song_data['song_metadata']['file_path']] = np.array(song_data['song_embedding'])
                    
                    # 가수 통합 임베딩이 아직 로드되지 않았다면 곡 파일에서 가져오기
                    if not summary_loaded and not singer_embedding_loaded:
                        self.singer_embeddings[singer_name] = np.array(song_data['singer_unified_embedding'])
                        singer_embedding_loaded = True
                    
                    song_count += 1
                    os.remove(local_temp_file)
            
            print(f"✓ {singer_name} 임베딩 로드 완료 ({song_count}곡)")
            return True
            
        except Exception as e:
            print(f"✗ {singer_name} 임베딩 로드 실패: {e}")
            return False

    def load_single_song_embedding_from_s3(
        self,
        singer_name: str,
        song_name: str,
        bucket_name: str = "ai-vocal-training",
        embedding_prefix: str = "timbre_embeddings/",
        region_name: str = "ap-northeast-2"
    ) -> bool:
        """
        S3에서 특정 가수의 특정 곡 임베딩만 로드
        """
        s3_client = get_s3_client_from_env(bucket_name, region_name)
        if s3_client is None:
            print("S3 클라이언트 초기화 실패")
            return False
        
        try:
            # 곡별 임베딩 파일 다운로드
            s3_key = f"{embedding_prefix}{singer_name}/{song_name}_embedding.json"
            local_temp_file = f"temp_{song_name}_embedding.json"
            
            print(f"S3에서 곡 로드: s3://{bucket_name}/{s3_key}")
            s3_client.download_file(bucket_name, s3_key, local_temp_file)
            
            # JSON 파일 읽기
            with open(local_temp_file, 'r', encoding='utf-8') as f:
                song_data = json.load(f)
            
            # 가수 데이터 초기화 (필요시)
            if singer_name not in self.singer_embeddings:
                self.singer_embeddings[singer_name] = np.array(song_data['singer_unified_embedding'])
                self.song_database[singer_name] = []
                self.song_embeddings[singer_name] = {}
            
            # 곡 정보 추가
            song_info = {
                'song_name': song_data['song_name'],
                'file_name': song_data['song_filename'],
                'file_path': song_data['song_metadata']['file_path']
            }
            
            if song_info not in self.song_database[singer_name]:
                self.song_database[singer_name].append(song_info)
            
            # 곡 임베딩 추가
            self.song_embeddings[singer_name][song_data['song_metadata']['file_path']] = np.array(song_data['song_embedding'])
            
            # 임시 파일 삭제
            os.remove(local_temp_file)
            
            print(f"✓ {singer_name}의 {song_name} 임베딩 로드 완료")
            return True
            
        except Exception as e:
            print(f"✗ {singer_name}의 {song_name} 임베딩 로드 실패: {e}")
            return False

# 테스트 함수들
def test_user_recommendation():
    """사용자 노래 기반 추천 테스트"""
    system = SingerEmbeddingSystem()
    
    if not system.load_model():
        return
    
    # 테스트 데이터 - 실제 환경에서는 가수별 폴더 구조 사용
    print("=== 가수 임베딩 시스템 테스트 ===\n")
    
    # 가상의 데이터베이스 구축 (실제로는 dataset_root 사용)
    # system.build_database_from_structure("path/to/singer/dataset")
    
    # 사용자 노래로 추천 받기
    user_audio = "test_audio/가요1_vocal.wav"
    
    if os.path.exists(user_audio):
        print(f"사용자 노래: {user_audio}")
        print("임베딩 추출 중...")
        
        user_embedding = system.extract_user_embedding(user_audio)
        if user_embedding is not None:
            print(f"✓ 사용자 임베딩 추출 완료: shape {user_embedding.shape}")
            
            # 실제 추천은 데이터베이스가 구축된 후에 가능
            # recommendations = system.recommend_songs(user_audio, top_k=5)
            print("\n추천 시스템 준비 완료!")
            print("다음 단계: 가수별 곡 데이터를 준비하여 데이터베이스 구축")
        else:
            print("✗ 사용자 임베딩 추출 실패")
    else:
        print(f"테스트 파일이 없습니다: {user_audio}")

def test_s3_pipeline():
    """S3 파이프라인 테스트"""
    print("=== S3 기반 가수 임베딩 파이프라인 테스트 ===\n")
    
    print("환경변수에서 AWS 자격증명을 읽어옵니다.")
    print("다음 환경변수가 설정되어 있는지 확인하세요:")
    print("  export AWS_ACCESS_KEY_ID=your_access_key")
    print("  export AWS_SECRET_ACCESS_KEY=your_secret_key")
    print()
    
    system = SingerEmbeddingSystem()
    
    # 모델 로드
    if not system.load_model():
        print("✗ 모델 로딩 실패")
        return
    
    # S3 파이프라인 실행
    results = system.build_and_upload_singer_embeddings_from_s3(
        bucket_name="ai-vocal-training",
        vocal_prefix="vocal/",
        embedding_prefix="embeddings/",
        local_temp_dir="./temp_singer_dataset/"
    )
    
    print(f"\n=== 최종 결과 ===")
    print(f"성공 여부: {results['success']}")
    if results['success']:
        print(f"처리된 가수: {len(results['processed_singers'])}명")
        print(f"실패한 가수: {len(results['failed_singers'])}명")
        print(f"생성된 임베딩 파일: {len(results['embedding_files'])}개")
        
        if results['processed_singers']:
            print(f"성공한 가수들: {results['processed_singers']}")
        
        if results['failed_singers']:
            print(f"실패한 가수들:")
            for failed in results['failed_singers']:
                print(f"  - {failed['name']}: {failed['error']}")
    else:
        print(f"오류: {results.get('error', '알 수 없는 오류')}")

if __name__ == "__main__":
    # 기본 테스트 실행
    test_user_recommendation()
    
    # S3 파이프라인 테스트 (주석 해제하여 사용)
    # test_s3_pipeline() 