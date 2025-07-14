#!/usr/bin/env python3
"""
모든 가수의 곡별 임베딩 JSON 파일 생성
S3에서 모든 가수 데이터를 다운로드하여 각 곡별로 개별 JSON 파일 생성 및 업로드
"""

import os
import sys
import numpy as np
import torch
import soundfile as sf
import json
from singer_identity import load_model
from s3_utils import (
    get_s3_client, get_singer_list_from_s3, list_s3_files, download_from_s3, upload_file_to_s3
)

def extract_embedding(audio, model, target_sr=44100):
    if len(audio.shape) > 1:
        audio = np.mean(audio, axis=1)
    if target_sr is not None:
        import librosa
        audio = librosa.resample(audio, orig_sr=target_sr, target_sr=target_sr)
    segment_length = 4 * 44100
    segments = []
    for i in range(0, len(audio), segment_length):
        segment = audio[i:i + segment_length]
        if len(segment) == segment_length:
            segments.append(segment)
    if not segments:
        segments.append(np.pad(audio, (0, segment_length - len(audio)), 'constant'))
    embeddings = []
    for segment in segments:
        audio_tensor = torch.tensor(segment).unsqueeze(0).float()
        with torch.no_grad():
            embedding = model(audio_tensor)
            embeddings.append(embedding.numpy()[0])
    final_embedding = np.mean(embeddings, axis=0)
    return final_embedding

def main():
    print("🎵 모든 가수 곡별 임베딩 JSON 파일 생성 시작")
    print("=" * 60)
    bucket_name = "ai-vocal-training"
    vocal_prefix = "vocal/"
    embedding_prefix = "timbre_embeddings/"
    region_name = "ap-northeast-2"
    aws_access_key_id = " aws_access_key_id"
    aws_secret_access_key = "aws_secret_access_key"
    s3 = get_s3_client(aws_access_key_id, aws_secret_access_key, bucket_name, region_name)
    if s3 is None:
        print("S3 클라이언트 초기화 실패")
        return
    model = load_model('byol')
    model.eval()
    singers = get_singer_list_from_s3(s3, bucket_name, vocal_prefix)
    print(f"발견된 가수: {singers}")
    for singer in singers:
        print(f"\n🎤 가수: {singer}")
        song_files = list_s3_files(s3, bucket_name, prefix=f"{vocal_prefix}{singer}/")
        singer_embeddings = []
        for song in song_files:
            if not song['key'].endswith('.wav'):
                continue
            try:
                print(f"  🎵 곡: {song['key']}")
                local_wav = download_from_s3(s3, bucket_name, song['key'])
                if not local_wav or not os.path.exists(local_wav):
                    print(f"    ⚠️ 다운로드 실패: {song['key']}")
                    continue
                print(f"    ==> 임베딩 중: {os.path.basename(local_wav)}")
                audio, sr = sf.read(local_wav)
                if sr != 44100:
                    import librosa
                    audio = librosa.resample(audio, orig_sr=sr, target_sr=44100)
                embedding = extract_embedding(audio, model, target_sr=44100)
                singer_embeddings.append(embedding)
                embedding_json = {
                    "singer": singer,
                    "song_key": song['key'],
                    "embedding": embedding.tolist(),
                    "shape": list(embedding.shape)
                }
                local_embedding_path = local_wav.replace('.wav', '_embedding.json')
                with open(local_embedding_path, 'w', encoding='utf-8') as f:
                    json.dump(embedding_json, f, ensure_ascii=False, indent=2)
                embedding_s3_key = f"{embedding_prefix}{singer}/{os.path.basename(local_embedding_path)}"
                upload_file_to_s3(s3, local_embedding_path, bucket_name, embedding_s3_key)
                print(f"    ✅ 임베딩 완료 및 업로드: {embedding_s3_key}")
                os.remove(local_wav)
                os.remove(local_embedding_path)
            except Exception as e:
                print(f"    ❌ 오류 발생: {e}")
                continue
        # 가수별 summary 임베딩 저장
        if singer_embeddings:
            summary_embedding = np.mean(singer_embeddings, axis=0)
            summary_json = {
                "singer": singer,
                "summary_embedding": summary_embedding.tolist(),
                "shape": list(summary_embedding.shape),
                "num_songs": len(singer_embeddings)
            }
            os.makedirs("summary", exist_ok=True)
            local_summary_path = f"summary/{singer}_summary.json"
            with open(local_summary_path, 'w', encoding='utf-8') as f:
                json.dump(summary_json, f, ensure_ascii=False, indent=2)
            summary_s3_key = f"summary/{singer}_summary.json"
            upload_file_to_s3(s3, local_summary_path, bucket_name, summary_s3_key)
            print(f"  📄 가수 summary 임베딩 저장 및 업로드: {summary_s3_key}")
            os.remove(local_summary_path)
    print("\n🎉 전체 작업 완료!")

if __name__ == "__main__":
    main() 