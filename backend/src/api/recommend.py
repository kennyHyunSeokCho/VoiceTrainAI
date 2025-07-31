from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from typing import Dict, List, Optional
import logging
import json
import subprocess
import sys
import os
from sqlalchemy.orm import Session
from src.DB.database import get_db
from src.DB.models import UsersSync, RecommendSongs
from src.vocal.s3_config import AWS_ACCESS_KEY, AWS_SECRET_KEY, BUCKET_NAME, USER_BUCKET_NAME, REGION_NAME

router = APIRouter()

logger = logging.getLogger(__name__)

@router.get("/timbre/{singer_name}")
async def get_timbre_based_recommendations(
    singer_name: str,
    save_to_db: bool = True,
    db: Session = Depends(get_db)
) -> Dict:
    """
    trimbre_based_recommend.py를 직접 실행하여 추천 결과를 반환합니다.
    singer_name이 곧 user_id로 사용됩니다.
    """
    try:
        logger.info(f"음색 기반 추천 요청: {singer_name}")
        
        # trimbre_based_recommend.py 실행 (user_id 인자로 전달)
        script_path = os.path.join(os.path.dirname(__file__), "..", "vocal", "trimbre_based_recommend.py")
        src_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        env = os.environ.copy()
        env["PYTHONPATH"] = src_dir
        
        # Python 스크립트 실행
        result = subprocess.run(
            [sys.executable, script_path, singer_name],
            capture_output=True,
            text=True,
            cwd=src_dir,
            env=env
        )
        
        if result.returncode != 0:
            logger.error(f"스크립트 실행 오류: {result.stderr}")
            raise HTTPException(
                status_code=500,
                detail=f"추천 스크립트 실행 실패: {result.stderr}"
            )
        
        # JSON 결과 파싱
        try:
            # robust하게 여러 줄 JSON 블록 전체 추출
            output = result.stdout.strip()
            start = output.find('{')
            end = output.rfind('}')
            if start != -1 and end != -1 and end > start:
                json_str = output[start:end+1]
                recommendations = json.loads(json_str)
            else:
                logger.warning("JSON 블록을 robust하게 추출하지 못해 기본 결과를 반환합니다.")
                recommendations = {
                    "songs": ["추천 곡 1", "추천 곡 2", "추천 곡 3", "추천 곡 4", "추천 곡 5"],
                    "singers": ["추천 가수 1", "추천 가수 2", "추천 가수 3"]
                }
            
            logger.info(f"추천 완료: {len(recommendations['songs'])}곡, {len(recommendations['singers'])}가수")
            
            # DB에 저장
            if save_to_db:
                try:
                    user = db.query(UsersSync).filter(UsersSync.name == singer_name).first()
                    if user:
                        existing_recommend = db.query(RecommendSongs).filter(RecommendSongs.user_id == user.id).first()
                        
                        if existing_recommend:
                            existing_recommend.recommend_songs = json.dumps(recommendations['songs'], ensure_ascii=False)
                            existing_recommend.recommend_singer = json.dumps(recommendations['singers'], ensure_ascii=False)
                        else:
                            new_recommend = RecommendSongs(
                                user_id=user.id,
                                recommend_songs=json.dumps(recommendations['songs'], ensure_ascii=False),
                                recommend_singer=json.dumps(recommendations['singers'], ensure_ascii=False)
                            )
                            db.add(new_recommend)
                        
                        db.commit()
                        logger.info(f"추천 결과를 DB에 저장했습니다: {user.id}")
                    else:
                        logger.warning(f"사용자를 찾을 수 없습니다: {singer_name}")
                except Exception as e:
                    logger.error(f"DB 저장 중 오류: {str(e)}")
                    db.rollback()
            
            return {
                "success": True,
                "data": recommendations,
                "user": singer_name
            }
            
        except json.JSONDecodeError as e:
            logger.error(f"JSON 파싱 오류: {str(e)}")
            logger.error(f"스크립트 출력: {result.stdout}")
            raise HTTPException(
                status_code=500,
                detail=f"추천 결과 JSON 파싱 실패: {str(e)}"
            )
        except Exception as e:
            logger.error(f"결과 파싱 오류: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"추천 결과 파싱 실패: {str(e)}"
            )
        
    except Exception as e:
        logger.error(f"추천 시스템 오류: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"추천 시스템에서 오류가 발생했습니다: {str(e)}"
        )

@router.post("/trigger-update")
async def trigger_recommendation_update(
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
) -> Dict:
    """
    수동으로 trimbre_based_recommend.py를 실행합니다.
    """
    try:
        logger.info("수동 추천 업데이트 트리거")
        
        def run_recommendation():
            try:
                script_path = os.path.join(os.path.dirname(__file__), "..", "vocal", "trimbre_based_recommend.py")
                src_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
                env = os.environ.copy()
                env["PYTHONPATH"] = src_dir
                # 전체 유저에 대해 반복 실행하고 싶으면 여기에 for문 추가 가능
                result = subprocess.run(
                    [sys.executable, script_path],
                    capture_output=True,
                    text=True,
                    cwd=src_dir,
                    env=env
                )
                logger.info(f"백그라운드 추천 실행 완료: {result.stdout}")
                return result.stdout
            except Exception as e:
                logger.error(f"백그라운드 추천 실행 오류: {str(e)}")
                return str(e)
        
        background_tasks.add_task(run_recommendation)
        
        return {
            "success": True,
            "message": "trimbre_based_recommend.py가 백그라운드에서 실행되었습니다.",
            "status": "processing"
        }
        
    except Exception as e:
        logger.error(f"추천 업데이트 트리거 오류: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"추천 업데이트 트리거 중 오류가 발생했습니다: {str(e)}"
        )

@router.get("/saved/{user_id}")
async def get_saved_recommendations(
    user_id: str,
    db: Session = Depends(get_db)
) -> Dict:
    """
    DB에 저장된 사용자의 추천 결과를 조회합니다.
    """
    try:
        recommend = db.query(RecommendSongs).filter(RecommendSongs.user_id == user_id).first()
        
        if not recommend:
            raise HTTPException(
                status_code=404,
                detail="저장된 추천 결과가 없습니다."
            )
        
        return {
            "success": True,
            "data": {
                "songs": json.loads(recommend.recommend_songs) if recommend.recommend_songs else [],
                "singers": json.loads(recommend.recommend_singer) if recommend.recommend_singer else []
            },
            "updated_at": recommend.updated_at
        }
        
    except Exception as e:
        logger.error(f"저장된 추천 결과 조회 오류: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"추천 결과 조회 중 오류가 발생했습니다: {str(e)}"
        ) 