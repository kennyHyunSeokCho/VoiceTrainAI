import json
import os
import tempfile
import boto3
import numpy as np
import librosa
import torch
import logging
from urllib.parse import unquote

# librosa 캐싱 문제 해결을 위한 환경 변수 설정
os.environ['LIBROSA_CACHE_DIR'] = '/tmp/librosa_cache'
os.environ['JOBLIB_TEMP_FOLDER'] = '/tmp/joblib_cache'
# librosa 캐싱 완전 비활성화
os.environ['LIBROSA_CACHE_LEVEL'] = '0'
os.environ['LIBROSA_DISABLE_CACHE'] = '1'

# 로깅 설정
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS S3 클라이언트
s3_client = boto3.client('s3')

# 환경 변수
BUCKET_NAME = os.environ.get('S3_BUCKET_NAME', 'ai-vocal-training-user')
MODEL_PATH = os.environ.get('MODEL_PATH', '/tmp/singer_identity')

# 전역 모델 인스턴스 (cold start 방지)
_analyzer = None

def get_analyzer():
    """싱글톤 패턴으로 analyzer 인스턴스 반환"""
    global _analyzer
    if _analyzer is None:
        _analyzer = LambdaVocalAnalyzer()
    return _analyzer


class LambdaVocalAnalyzer:
    def __init__(self):
        """singer-identity 모델 초기화"""
        try:
            # /tmp 디렉토리 확인 및 생성
            import os
            tmp_dir = '/tmp/singer_identity'
            os.makedirs(tmp_dir, exist_ok=True)
            logger.info(f"Ensured tmp directory exists: {tmp_dir}")
            
            from singer_identity.model import load_model
            # /var/task에서 모델 파일을 /tmp로 복사하도록 source 파라미터 지정
            logger.info(f"Loading model from {MODEL_PATH} with source /var/task/singer_identity")
            self.model = load_model(MODEL_PATH, source='/var/task/singer_identity')
            logger.info("Singer identity model loaded successfully")
        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            raise

    def extract_embedding(self, audio: np.ndarray, sr: int = 44100) -> np.ndarray:
        try:
            if len(audio.shape) > 1:
                audio = np.mean(audio, axis=1)

            if sr != 44100:
                audio = librosa.resample(audio, orig_sr=sr, target_sr=44100)

            segment_length = 44100 * 4
            segments = []
            for i in range(0, len(audio), segment_length):
                segment = audio[i:i + segment_length]
                if len(segment) == segment_length:
                    segments.append(segment)

            if not segments:
                audio = np.pad(audio, (0, segment_length - len(audio)), 'constant')
                segments = [audio]

            embeddings = []
            for seg in segments:
                seg_tensor = torch.from_numpy(seg).float().unsqueeze(0)
                with torch.no_grad():
                    embedding = self.model(seg_tensor)
                    embeddings.append(embedding.cpu().numpy())

            return np.mean(embeddings, axis=0).flatten()
        except Exception as e:
            logger.error(f"Error extracting embedding: {e}")
            raise

    def analyze_vocal(self, audio_path: str, user_id: str):
        try:
            # soundfile을 사용하여 오디오 로드 (librosa 캐싱 문제 우회)
            import soundfile as sf
            from scipy import signal
            
            # soundfile로 오디오 로드
            audio, sr = sf.read(audio_path)
            
            # 스테레오를 모노로 변환 (필요한 경우)
            if len(audio.shape) > 1:
                audio = np.mean(audio, axis=1)
            
            # scipy.signal을 사용하여 리샘플링 (librosa 대신)
            if sr != 44100:
                # 리샘플링 비율 계산
                ratio = 44100 / sr
                # scipy.signal.resample 사용
                audio = signal.resample(audio, int(len(audio) * ratio))
                sr = 44100
            
            embedding = self.extract_embedding(audio, sr)
            
            return {
                "user_id": user_id,
                "embedding": embedding.tolist(),
                "embedding_dim": len(embedding),
                "audio_duration": len(audio) / sr,
                "sample_rate": sr,
                "analysis_timestamp": str(np.datetime64('now')),
                "model_version": "singer-identity-byol"
            }
        except Exception as e:
            logger.error(f"Error analyzing vocal: {e}")
            raise

    def save_to_s3(self, result, user_id: str, filename: str):
        try:
            base_name = os.path.splitext(filename)[0]
            analysis_id = f"{base_name}_{int(np.datetime64('now').astype(np.int64) / 1e9)}"
            s3_key = f"{user_id}/timbre/{analysis_id}.json"
            json_data = json.dumps(result, ensure_ascii=False, indent=2)
            s3_client.put_object(
                Bucket=BUCKET_NAME,
                Key=s3_key,
                Body=json_data.encode('utf-8'),
                ContentType='application/json'
            )
            logger.info(f"Analysis result saved to S3: {s3_key}")
            return analysis_id
        except Exception as e:
            logger.error(f"Error saving to S3: {e}")
            raise


def get_latest_vocal_file(bucket: str, user_id: str) -> str:
    prefix = f"{user_id}/vocal/"
    response = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix)
    if "Contents" not in response:
        raise FileNotFoundError(f"No .wav files found under {prefix}")

    wav_files = [obj for obj in response["Contents"] if obj["Key"].endswith(".wav")]
    if not wav_files:
        raise FileNotFoundError(f"No .wav files found under {prefix}")

    latest_file = max(wav_files, key=lambda x: x["LastModified"])
    logger.info(f"Found latest file: {latest_file['Key']} for user: {user_id}")
    return latest_file["Key"]


def lambda_handler(event, context):
    try:
        logger.info(f"Event received: {json.dumps(event, ensure_ascii=False)}")

        s3_event = event['Records'][0]['s3']
        bucket = s3_event['bucket']['name']

        raw_key = s3_event['object']['key']
        key = unquote(raw_key).encode('utf-8').decode('utf-8')
        logger.info(f"Decoded S3 key: {key}")

        path_parts = key.split('/')
        if len(path_parts) < 2:
            raise ValueError(f"Invalid S3 key format: {key}")
        user_id = path_parts[0]

        latest_key = get_latest_vocal_file(bucket, user_id)
        filename = os.path.basename(latest_key)

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_file:
            s3_client.download_file(bucket, latest_key, temp_file.name)
            temp_path = temp_file.name

        try:
            analyzer = get_analyzer()
            result = analyzer.analyze_vocal(temp_path, user_id)
            analysis_id = analyzer.save_to_s3(result, user_id, filename)

            return {
                "statusCode": 200,
                "body": json.dumps({
                    "message": "Vocal analysis completed successfully",
                    "analysis_id": analysis_id,
                    "user_id": user_id,
                    "latest_file": filename,
                    "result_s3_key": f"{user_id}/timbre/{analysis_id}.json"
                }, ensure_ascii=False)
            }
        finally:
            os.unlink(temp_path)

    except Exception as e:
        logger.error(f"Lambda execution failed: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": "Vocal analysis failed",
                "message": str(e)
            }, ensure_ascii=False)
        }
