"""
ChatGPT API를 활용한 자연어 피드백 생성 API
사용자의 ScoreHistory를 분석하여 개인화된 피드백을 생성하고 Feedback 테이블에 저장합니다.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func, desc
from typing import List, Optional
from pydantic import BaseModel
import openai
import os
from datetime import datetime, timedelta

from src.DB.database import get_db
from src.DB.models import ScoreHistory, Feedback, Result, UsersSync, Song, UserProfile
from src.auth.dependencies import get_current_user

router = APIRouter(prefix="/api/feedback", tags=["feedback"])

# OpenAI 클라이언트 설정 (새로운 방식)
openai_client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

class FeedbackRequest(BaseModel):
    """피드백 생성 요청 모델"""
    song_id: Optional[int] = None  # 특정 곡에 대한 피드백을 원할 경우
    days_back: int = 30  # 분석할 기간 (일)
    include_vocal_range: bool = True  # 보컬 범위 정보 포함 여부
    include_genre_analysis: bool = True  # 장르 분석 포함 여부

class FeedbackResponse(BaseModel):
    """피드백 응답 모델"""
    feedback_id: int
    content: str
    created_at: datetime
    song_title: Optional[str] = None
    singer: Optional[str] = None
    analysis_summary: Optional[dict] = None

def analyze_score_trends(score_histories: List[ScoreHistory]) -> dict:
    """점수 히스토리를 분석하여 트렌드를 파악합니다."""
    if not score_histories:
        return {"trend": "no_data", "message": "분석할 데이터가 없습니다."}
    
    # 최근 10개 기록으로 트렌드 분석
    recent_scores = sorted(score_histories, key=lambda x: x.created_at, reverse=True)[:10]
    
    if len(recent_scores) < 2:
        return {"trend": "insufficient_data", "message": "트렌드 분석을 위한 충분한 데이터가 없습니다."}
    
    # 평균 점수 계산
    avg_pitch = sum(s.pitch_score or 0 for s in recent_scores) / len(recent_scores)
    avg_rhythm = sum(s.rhythm_score or 0 for s in recent_scores) / len(recent_scores)
    
    # 종합 점수 계산 (피치 + 리듬의 평균)
    combined_scores = []
    for s in recent_scores:
        if s.pitch_score is not None and s.rhythm_score is not None:
            combined_scores.append((s.pitch_score + s.rhythm_score) / 2)
    avg_combined = sum(combined_scores) / len(combined_scores) if combined_scores else 0
    
    # 트렌드 분석 (최근 vs 이전)
    mid_point = len(recent_scores) // 2
    recent_half = recent_scores[:mid_point]
    older_half = recent_scores[mid_point:]
    
    # 종합 점수로 트렌드 분석
    recent_combined = []
    for s in recent_half:
        if s.pitch_score is not None and s.rhythm_score is not None:
            recent_combined.append((s.pitch_score + s.rhythm_score) / 2)
    
    older_combined = []
    for s in older_half:
        if s.pitch_score is not None and s.rhythm_score is not None:
            older_combined.append((s.pitch_score + s.rhythm_score) / 2)
    
    recent_avg = sum(recent_combined) / len(recent_combined) if recent_combined else 0
    older_avg = sum(older_combined) / len(older_combined) if older_combined else 0
    
    if recent_avg > older_avg + 5:
        trend = "improving"
    elif recent_avg < older_avg - 5:
        trend = "declining"
    else:
        trend = "stable"
    
    return {
        "trend": trend,
        "avg_pitch": avg_pitch,
        "avg_rhythm": avg_rhythm,
        "avg_combined": avg_combined,
        "recent_avg": recent_avg,
        "older_avg": older_avg,
        "total_songs": len(score_histories)
    }

def analyze_genre_preferences(score_histories: List[ScoreHistory], db: Session) -> dict:
    """사용자의 장르 선호도를 분석합니다."""
    if not score_histories:
        return {"genres": [], "message": "분석할 데이터가 없습니다."}
    
    # 곡 정보와 함께 점수 데이터 조회
    song_scores = db.query(ScoreHistory, Song).join(
        Song, ScoreHistory.song_id == Song.song_id
    ).filter(
        ScoreHistory.song_id.in_([sh.song_id for sh in score_histories])
    ).all()
    
    # 장르별 평균 점수 계산 (간단한 예시 - 실제로는 더 정교한 장르 분류 필요)
    genre_scores = {}
    for score_history, song in song_scores:
        # 여기서는 간단히 가수명으로 장르를 추정 (실제로는 별도 장르 테이블 필요)
        genre = "팝"  # 기본값
        if song.singer:
            if any(keyword in song.singer for keyword in ["아이유", "태연", "윤하"]):
                genre = "팝/발라드"
            elif any(keyword in song.singer for keyword in ["BTS", "블랙핑크", "트와이스"]):
                genre = "K-POP"
            elif any(keyword in song.singer for keyword in ["김범수", "박효신", "성시경"]):
                genre = "발라드"
        
        if genre not in genre_scores:
            genre_scores[genre] = []
        
        # 종합 점수 계산 (피치 + 리듬의 평균)
        if score_history.pitch_score is not None and score_history.rhythm_score is not None:
            combined_score = (score_history.pitch_score + score_history.rhythm_score) / 2
            genre_scores[genre].append(combined_score)
        else:
            genre_scores[genre].append(0)
    
    # 장르별 평균 점수 계산
    genre_analysis = []
    for genre, scores in genre_scores.items():
        avg_score = sum(scores) / len(scores)
        genre_analysis.append({
            "genre": genre,
            "avg_score": avg_score,
            "song_count": len(scores)
        })
    
    # 점수순으로 정렬
    genre_analysis.sort(key=lambda x: x["avg_score"], reverse=True)
    
    return {
        "genres": genre_analysis,
        "favorite_genre": genre_analysis[0]["genre"] if genre_analysis else "알 수 없음"
    }

def get_vocal_range_analysis(user_profile: UserProfile, score_histories: List[ScoreHistory], db: Session) -> dict:
    """사용자의 보컬 범위를 분석합니다."""
    if not user_profile or not user_profile.vocal_range:
        return {"vocal_range": "알 수 없음", "recommendations": []}
    
    vocal_range = user_profile.vocal_range
    
    # 보컬 범위별 연습 곡 분석
    song_scores = db.query(ScoreHistory, Song).join(
        Song, ScoreHistory.song_id == Song.song_id
    ).filter(
        ScoreHistory.song_id.in_([sh.song_id for sh in score_histories])
    ).all()
    
    # 보컬 범위별 점수 분석
    range_scores = {}
    for score_history, song in song_scores:
        if song.vocal_range:
            if song.vocal_range not in range_scores:
                range_scores[song.vocal_range] = []
            
            # 종합 점수 계산 (피치 + 리듬의 평균)
            if score_history.pitch_score is not None and score_history.rhythm_score is not None:
                combined_score = (score_history.pitch_score + score_history.rhythm_score) / 2
                range_scores[song.vocal_range].append(combined_score)
            else:
                range_scores[song.vocal_range].append(0)
    
    # 보컬 범위별 평균 점수 계산
    range_analysis = []
    for song_range, scores in range_scores.items():
        avg_score = sum(scores) / len(scores)
        range_analysis.append({
            "range": song_range,
            "avg_score": avg_score,
            "song_count": len(scores)
        })
    
    # 점수순으로 정렬
    range_analysis.sort(key=lambda x: x["avg_score"], reverse=True)
    
    # 보컬 범위별 추천사항
    recommendations = []
    if vocal_range == "저음":
        recommendations = [
            "저음역에서 안정적인 발성을 위해 복식호흡 연습을 강화하세요",
            "저음에서도 명확한 발음을 위해 입 모양과 혀 위치에 주의하세요",
            "저음역 곡들을 더 많이 연습하여 자신감을 키우세요"
        ]
    elif vocal_range == "중음":
        recommendations = [
            "중음역은 가장 자연스러운 음역이므로 표현력에 집중하세요",
            "다양한 감정 표현을 연습하여 곡의 감정을 살리세요",
            "중음에서 고음으로의 전환 연습을 강화하세요"
        ]
    elif vocal_range == "고음":
        recommendations = [
            "고음역에서 무리하지 않도록 적절한 호흡 지지가 중요합니다",
            "고음에서도 음색을 유지하도록 연습하세요",
            "고음역 연습 전 충분한 워밍업을 하세요"
        ]
    
    return {
        "vocal_range": vocal_range,
        "range_analysis": range_analysis,
        "recommendations": recommendations
    }

def generate_ai_feedback(analysis: dict, user_name: str, song_info: Optional[dict] = None, 
                        genre_analysis: Optional[dict] = None, vocal_analysis: Optional[dict] = None) -> str:
    """ChatGPT API를 사용하여 개인화된 피드백을 생성합니다."""
    
    # 시스템 프롬프트
    system_prompt = """당신은 전문적인 보컬 트레이너입니다. 
사용자의 노래 연습 기록을 분석하여 격려적이고 구체적인 피드백을 제공해주세요.
피드백은 다음 요소들을 포함해야 합니다:
1. 전반적인 성과 평가
2. 강점과 개선점
3. 구체적인 연습 제안
4. 격려의 메시지

한국어로 친근하고 격려적인 톤으로 작성해주세요."""

    # 사용자 프롬프트 구성
    user_prompt = f"""
{user_name}님의 노래 연습 분석 결과입니다:

전체 연습 곡 수: {analysis['total_songs']}곡
평균 점수:
- 피치: {analysis['avg_pitch']:.1f}점
- 리듬: {analysis['avg_rhythm']:.1f}점  
- 종합: {analysis['avg_combined']:.1f}점

성과 트렌드: {analysis['trend']}
"""

    if song_info:
        user_prompt += f"""
특정 곡 분석:
- 곡명: {song_info['title']}
- 가수: {song_info['singer']}
- 피치 점수: {song_info['pitch_score']}점
- 리듬 점수: {song_info['rhythm_score']}점
- 종합 점수: {song_info['combined_score']}점
"""

    if genre_analysis and genre_analysis.get('genres'):
        user_prompt += f"""
장르별 성과:
- 선호 장르: {genre_analysis['favorite_genre']}
- 장르별 평균 점수:
"""
        for genre_info in genre_analysis['genres'][:3]:  # 상위 3개 장르만
            user_prompt += f"  * {genre_info['genre']}: {genre_info['avg_score']:.1f}점 ({genre_info['song_count']}곡)\n"

    if vocal_analysis:
        user_prompt += f"""
보컬 범위 분석:
- 현재 보컬 범위: {vocal_analysis['vocal_range']}
- 보컬 범위별 추천사항:
"""
        for rec in vocal_analysis['recommendations']:
            user_prompt += f"  * {rec}\n"

    if analysis['trend'] == "improving":
        user_prompt += "\n최근 점수가 향상되고 있어서 매우 좋습니다!"
    elif analysis['trend'] == "declining":
        user_prompt += "\n최근 점수가 다소 하락하고 있으니 연습 방법을 점검해보세요."
    else:
        user_prompt += "\n점수가 안정적으로 유지되고 있습니다."

    user_prompt += "\n\n위 정보를 바탕으로 개인화된 피드백을 작성해주세요."

    try:
        response = openai_client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            max_tokens=600,
            temperature=0.7
        )
        
        return response.choices[0].message.content.strip()
    
    except Exception as e:
        print(f"OpenAI API 호출 오류: {e}")
        # API 오류 시 기본 피드백 반환
        return f"{user_name}님, 노래 연습을 꾸준히 하고 계시네요! 현재 평균 {analysis['avg_total']:.1f}점을 기록하고 계시고, 총 {analysis['total_songs']}곡을 연습하셨습니다. 더 나은 성과를 위해 꾸준한 연습을 이어가세요!"

@router.post("/generate", response_model=FeedbackResponse)
async def generate_feedback(
    request: FeedbackRequest,
    current_user: UsersSync = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """사용자의 ScoreHistory를 분석하여 AI 피드백을 생성하고 저장합니다."""
    
    try:
        # 사용자의 ScoreHistory 조회
        query = db.query(ScoreHistory).filter(
            ScoreHistory.user_id == current_user.id
        )
        
        if request.song_id:
            # 특정 곡에 대한 피드백
            query = query.filter(ScoreHistory.song_id == request.song_id)
            song_info = db.query(Song).filter(Song.song_id == request.song_id).first()
            if not song_info:
                raise HTTPException(status_code=404, detail="해당 곡을 찾을 수 없습니다.")
        else:
            # 전체 기간 분석
            days_ago = datetime.now() - timedelta(days=request.days_back)
            query = query.filter(ScoreHistory.created_at >= days_ago)
            song_info = None
        
        score_histories = query.order_by(desc(ScoreHistory.created_at)).all()
        
        if not score_histories:
            raise HTTPException(status_code=404, detail="분석할 연습 기록이 없습니다.")
        
        # 점수 트렌드 분석
        analysis = analyze_score_trends(score_histories)
        
        # 사용자 프로필 조회
        user_profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        
        # 장르 분석 (요청된 경우)
        genre_analysis = None
        if request.include_genre_analysis:
            genre_analysis = analyze_genre_preferences(score_histories, db)
        
        # 보컬 범위 분석 (요청된 경우)
        vocal_analysis = None
        if request.include_vocal_range and user_profile:
            vocal_analysis = get_vocal_range_analysis(user_profile, score_histories, db)
        
        # 특정 곡 정보 준비
        song_data = None
        if song_info and score_histories:
            latest_score = score_histories[0]
            song_data = {
                "title": song_info.song_title,
                "singer": song_info.singer,
                "pitch_score": latest_score.pitch_score,
                "rhythm_score": latest_score.rhythm_score,
                "combined_score": (latest_score.pitch_score + latest_score.rhythm_score) / 2 if latest_score.pitch_score and latest_score.rhythm_score else 0
            }
        
        # AI 피드백 생성
        feedback_content = generate_ai_feedback(
            analysis, 
            current_user.name or "사용자", 
            song_data, 
            genre_analysis, 
            vocal_analysis
        )
        
        # 가장 최근 Result 찾기 (피드백 연결용)
        latest_result = None
        if request.song_id:
            latest_result = db.query(Result).filter(
                Result.user_id == current_user.id,
                Result.song_id == request.song_id
            ).order_by(desc(Result.created_at)).first()
        
        # Feedback 테이블에 저장
        new_feedback = Feedback(
            result_id=latest_result.result_id if latest_result else 1,  # 기본값 설정
            content=feedback_content
        )
        
        db.add(new_feedback)
        db.commit()
        db.refresh(new_feedback)
        
        # 분석 요약 정보
        analysis_summary = {
            "trend": analysis["trend"],
            "avg_combined_score": analysis["avg_combined"],
            "total_songs": analysis["total_songs"]
        }
        
        if genre_analysis:
            analysis_summary["favorite_genre"] = genre_analysis["favorite_genre"]
        
        if vocal_analysis:
            analysis_summary["vocal_range"] = vocal_analysis["vocal_range"]
        
        return FeedbackResponse(
            feedback_id=new_feedback.feedback_id,
            content=new_feedback.content,
            created_at=new_feedback.created_at,
            song_title=song_info.song_title if song_info else None,
            singer=song_info.singer if song_info else None,
            analysis_summary=analysis_summary
        )
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"피드백 생성 오류: {e}")
        raise HTTPException(status_code=500, detail="피드백 생성 중 오류가 발생했습니다.")

@router.get("/history", response_model=List[FeedbackResponse])
async def get_feedback_history(
    current_user: UsersSync = Depends(get_current_user),
    db: Session = Depends(get_db),
    limit: int = 10
):
    """사용자의 피드백 히스토리를 조회합니다."""
    
    try:
        # 사용자의 Result를 통해 Feedback 조회
        feedbacks = db.query(Feedback, Song.song_title, Song.singer).join(
            Result, Feedback.result_id == Result.result_id
        ).join(
            Song, Result.song_id == Song.song_id
        ).filter(
            Result.user_id == current_user.id
        ).order_by(
            desc(Feedback.created_at)
        ).limit(limit).all()
        
        return [
            FeedbackResponse(
                feedback_id=feedback.feedback_id,
                content=feedback.content,
                created_at=feedback.created_at,
                song_title=song_title,
                singer=singer
            )
            for feedback, song_title, singer in feedbacks
        ]
        
    except Exception as e:
        print(f"피드백 히스토리 조회 오류: {e}")
        raise HTTPException(status_code=500, detail="피드백 히스토리 조회 중 오류가 발생했습니다.")

@router.get("/analysis/{song_id}")
async def get_song_analysis(
    song_id: int,
    current_user: UsersSync = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """특정 곡에 대한 상세 분석 정보를 제공합니다."""
    
    try:
        # 해당 곡의 모든 연습 기록 조회
        score_histories = db.query(ScoreHistory).filter(
            ScoreHistory.user_id == current_user.id,
            ScoreHistory.song_id == song_id
        ).order_by(desc(ScoreHistory.created_at)).all()
        
        if not score_histories:
            raise HTTPException(status_code=404, detail="해당 곡의 연습 기록이 없습니다.")
        
        # 곡 정보 조회
        song = db.query(Song).filter(Song.song_id == song_id).first()
        if not song:
            raise HTTPException(status_code=404, detail="해당 곡을 찾을 수 없습니다.")
        
        # 분석 수행
        analysis = analyze_score_trends(score_histories)
        
        return {
            "song_title": song.song_title,
            "singer": song.singer,
            "total_practices": len(score_histories),
            "analysis": analysis,
            "recent_scores": [
                {
                    "pitch_score": sh.pitch_score,
                    "rhythm_score": sh.rhythm_score,
                    "combined_score": (sh.pitch_score + sh.rhythm_score) / 2 if sh.pitch_score and sh.rhythm_score else 0,
                    "created_at": sh.created_at
                }
                for sh in score_histories[:5]  # 최근 5개 기록
            ]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"곡 분석 오류: {e}")
        raise HTTPException(status_code=500, detail="곡 분석 중 오류가 발생했습니다.")

@router.get("/user-stats")
async def get_user_statistics(
    current_user: UsersSync = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """사용자의 전체 통계 정보를 제공합니다."""
    
    try:
        # 전체 연습 기록 조회
        score_histories = db.query(ScoreHistory).filter(
            ScoreHistory.user_id == current_user.id
        ).all()
        
        if not score_histories:
            return {
                "total_practices": 0,
                "message": "아직 연습 기록이 없습니다."
            }
        
        # 기본 통계
        total_practices = len(score_histories)
        
        # 종합 점수 계산 (피치 + 리듬의 평균)
        combined_scores = []
        for sh in score_histories:
            if sh.pitch_score is not None and sh.rhythm_score is not None:
                combined_scores.append((sh.pitch_score + sh.rhythm_score) / 2)
        
        avg_combined_score = sum(combined_scores) / len(combined_scores) if combined_scores else 0
        
        # 최근 30일 통계
        thirty_days_ago = datetime.now() - timedelta(days=30)
        recent_practices = [sh for sh in score_histories if sh.created_at >= thirty_days_ago]
        recent_combined_scores = []
        for sh in recent_practices:
            if sh.pitch_score is not None and sh.rhythm_score is not None:
                recent_combined_scores.append((sh.pitch_score + sh.rhythm_score) / 2)
        recent_avg_score = sum(recent_combined_scores) / len(recent_combined_scores) if recent_combined_scores else 0
        
        # 분석 수행
        analysis = analyze_score_trends(score_histories)
        genre_analysis = analyze_genre_preferences(score_histories, db)
        
        # 사용자 프로필 조회
        user_profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        vocal_analysis = None
        if user_profile:
            vocal_analysis = get_vocal_range_analysis(user_profile, score_histories, db)
        
        return {
            "total_practices": total_practices,
            "avg_combined_score": avg_combined_score,
            "recent_practices": len(recent_practices),
            "recent_avg_score": recent_avg_score,
            "trend": analysis["trend"],
            "favorite_genre": genre_analysis["favorite_genre"] if genre_analysis.get("genres") else "알 수 없음",
            "vocal_range": vocal_analysis["vocal_range"] if vocal_analysis else "알 수 없음",
            "genre_breakdown": genre_analysis.get("genres", [])
        }
        
    except Exception as e:
        print(f"사용자 통계 조회 오류: {e}")
        raise HTTPException(status_code=500, detail="사용자 통계 조회 중 오류가 발생했습니다.")

@router.get("/score-graph")
async def get_score_graph_data(
    current_user: UsersSync = Depends(get_current_user),
    db: Session = Depends(get_db),
    days: int = 30,  # 기본 30일
    limit: int = 50  # 최대 50개 데이터 포인트
):
    """사용자의 점수 변화 그래프 데이터를 제공합니다."""
    
    try:
        # 지정된 기간의 연습 기록 조회 (시간순 정렬)
        days_ago = datetime.now() - timedelta(days=days)
        score_histories = db.query(ScoreHistory).filter(
            ScoreHistory.user_id == current_user.id,
            ScoreHistory.created_at >= days_ago
        ).order_by(ScoreHistory.created_at.asc()).limit(limit).all()
        
        if not score_histories:
            return {
                "message": "해당 기간에 연습 기록이 없습니다.",
                "data": []
            }
        
        # 그래프 데이터 구성
        graph_data = []
        for i, history in enumerate(score_histories):
            # 곡 정보 조회
            song = db.query(Song).filter(Song.song_id == history.song_id).first()
            
            # 종합 점수 계산 (피치 + 리듬의 평균)
            if history.pitch_score is not None and history.rhythm_score is not None:
                combined_score = (history.pitch_score + history.rhythm_score) / 2
                graph_data.append({
                    "date": history.created_at.strftime("%Y-%m-%d"),
                    "score": round(combined_score, 2),
                    "song_title": song.song_title if song else "Unknown",
                    "practice_number": i + 1
                })
        
        if not graph_data:
            return {
                "message": "유효한 점수 데이터가 없습니다.",
                "data": []
            }
        
        # 통계 계산
        scores = [point["score"] for point in graph_data]
        max_score = max(scores)
        min_score = min(scores)
        avg_score = sum(scores) / len(scores)
        
        # 개선률 계산 (첫 번째 vs 마지막 점수)
        if len(graph_data) >= 2:
            first_score = graph_data[0]["score"]
            last_score = graph_data[-1]["score"]
            improvement_rate = ((last_score - first_score) / first_score * 100) if first_score > 0 else 0
        else:
            improvement_rate = 0
        
        return {
            "data": graph_data,
            "max_score": round(max_score, 2),
            "min_score": round(min_score, 2),
            "avg_score": round(avg_score, 2),
            "improvement_rate": round(improvement_rate, 2),
            "total_practices": len(graph_data)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"그래프 데이터 조회 중 오류 발생: {str(e)}")

@router.get("/test/score-graph")
async def get_score_graph_data_test(
    user_id: str,
    db: Session = Depends(get_db),
    days: int = 30,  # 기본 30일
    limit: int = 50  # 최대 50개 데이터 포인트
):
    """사용자의 점수 변화 그래프 데이터를 제공합니다 (테스트용)."""
    
    # 지정된 사용자의 점수 히스토리 조회
    cutoff_date = datetime.now() - timedelta(days=days)
    score_histories = db.query(ScoreHistory).filter(
        ScoreHistory.user_id == user_id,
        ScoreHistory.created_at >= cutoff_date
    ).order_by(ScoreHistory.created_at.desc()).limit(limit).all()
    
    if not score_histories:
        return {
            "data": [],
            "max_score": 0,
            "min_score": 0,
            "avg_score": 0,
            "improvement_rate": 0,
            "message": "해당 기간에 점수 기록이 없습니다."
        }
    
    # 데이터 포인트 생성
    data_points = []
    for score in score_histories:
        if score.pitch_score is not None and score.rhythm_score is not None:
            combined_score = (score.pitch_score + score.rhythm_score) / 2
            data_points.append({
                "date": score.created_at.strftime("%Y-%m-%d"),
                "score": round(combined_score, 2),
                "pitch_score": score.pitch_score,
                "rhythm_score": score.rhythm_score
            })
    
    if not data_points:
        return {
            "data": [],
            "max_score": 0,
            "min_score": 0,
            "avg_score": 0,
            "improvement_rate": 0,
            "message": "유효한 점수 데이터가 없습니다."
        }
    
    # 통계 계산
    scores = [point["score"] for point in data_points]
    max_score = max(scores)
    min_score = min(scores)
    avg_score = sum(scores) / len(scores)
    
    # 개선률 계산 (첫 번째 vs 마지막 점수)
    if len(data_points) >= 2:
        first_score = data_points[-1]["score"]  # 가장 오래된 점수
        last_score = data_points[0]["score"]    # 가장 최근 점수
        improvement_rate = ((last_score - first_score) / first_score * 100) if first_score > 0 else 0
    else:
        improvement_rate = 0
    
    return {
        "data": data_points,
        "max_score": round(max_score, 2),
        "min_score": round(min_score, 2),
        "avg_score": round(avg_score, 2),
        "improvement_rate": round(improvement_rate, 2),
        "total_practices": len(data_points)
    }
    """사용자의 점수 변화 그래프 데이터를 제공합니다."""
    
    try:
        # 지정된 기간의 연습 기록 조회 (시간순 정렬)
        days_ago = datetime.now() - timedelta(days=days)
        score_histories = db.query(ScoreHistory).filter(
            ScoreHistory.user_id == current_user.id,
            ScoreHistory.created_at >= days_ago
        ).order_by(ScoreHistory.created_at.asc()).limit(limit).all()
        
        if not score_histories:
            return {
                "message": "해당 기간에 연습 기록이 없습니다.",
                "data": []
            }
        
        # 그래프 데이터 구성
        graph_data = []
        for i, history in enumerate(score_histories):
            # 곡 정보 조회
            song = db.query(Song).filter(Song.song_id == history.song_id).first()
            
            graph_data.append({
                "index": i + 1,  # 연습 순서
                "date": history.created_at.strftime("%Y-%m-%d %H:%M"),
                "timestamp": history.created_at.isoformat(),
                "song_title": song.song_title if song else "알 수 없는 곡",
                "singer": song.singer if song else "알 수 없는 가수",
                "pitch_score": history.pitch_score,
                "rhythm_score": history.rhythm_score
            })
        
        # 통계 정보 계산
        pitch_scores = [data["pitch_score"] for data in graph_data if data["pitch_score"] is not None]
        rhythm_scores = [data["rhythm_score"] for data in graph_data if data["rhythm_score"] is not None]
        
        # 종합 점수 계산 (피치 + 리듬의 평균)
        combined_scores = []
        for data in graph_data:
            if data["pitch_score"] is not None and data["rhythm_score"] is not None:
                combined_scores.append((data["pitch_score"] + data["rhythm_score"]) / 2)
        
        stats = {
            "total_practices": len(graph_data),
            "avg_pitch_score": sum(pitch_scores) / len(pitch_scores) if pitch_scores else 0,
            "avg_rhythm_score": sum(rhythm_scores) / len(rhythm_scores) if rhythm_scores else 0,
            "avg_combined_score": sum(combined_scores) / len(combined_scores) if combined_scores else 0,
            "max_pitch_score": max(pitch_scores) if pitch_scores else 0,
            "min_pitch_score": min(pitch_scores) if pitch_scores else 0,
            "max_rhythm_score": max(rhythm_scores) if rhythm_scores else 0,
            "min_rhythm_score": min(rhythm_scores) if rhythm_scores else 0,
            "max_combined_score": max(combined_scores) if combined_scores else 0,
            "min_combined_score": min(combined_scores) if combined_scores else 0,
            "improvement_rate": 0  # 계산 로직 추가 필요
        }
        
        # 개선률 계산 (첫 10개 vs 마지막 10개)
        if len(combined_scores) >= 20:
            first_10_avg = sum(combined_scores[:10]) / 10
            last_10_avg = sum(combined_scores[-10:]) / 10
            if first_10_avg > 0:
                stats["improvement_rate"] = ((last_10_avg - first_10_avg) / first_10_avg) * 100
        
        return {
            "period_days": days,
            "data_points": len(graph_data),
            "stats": stats,
            "graph_data": graph_data
        }
        
    except Exception as e:
        print(f"점수 그래프 데이터 조회 오류: {e}")
        raise HTTPException(status_code=500, detail="점수 그래프 데이터 조회 중 오류가 발생했습니다.")

@router.get("/score-trend")
async def get_score_trend_analysis(
    current_user: UsersSync = Depends(get_current_user),
    db: Session = Depends(get_db),
    days: int = 30
):
    """사용자의 점수 트렌드 분석을 제공합니다."""
    
    try:
        # 지정된 기간의 연습 기록 조회
        days_ago = datetime.now() - timedelta(days=days)
        score_histories = db.query(ScoreHistory).filter(
            ScoreHistory.user_id == current_user.id,
            ScoreHistory.created_at >= days_ago
        ).order_by(ScoreHistory.created_at.asc()).all()
        
        if not score_histories:
            return {
                "message": "해당 기간에 연습 기록이 없습니다.",
                "trend": "no_data"
            }
        
        # 주별 평균 점수 계산
        weekly_data = {}
        for history in score_histories:
            week_start = history.created_at - timedelta(days=history.created_at.weekday())
            week_key = week_start.strftime("%Y-%m-%d")
            
            if week_key not in weekly_data:
                weekly_data[week_key] = []
            
            # 피치와 리듬 점수의 평균을 종합 점수로 사용
            if history.pitch_score is not None and history.rhythm_score is not None:
                combined_score = (history.pitch_score + history.rhythm_score) / 2
                weekly_data[week_key].append(combined_score)
            else:
                weekly_data[week_key].append(0)
        
        # 주별 평균 계산
        weekly_averages = []
        for week, scores in sorted(weekly_data.items()):
            weekly_averages.append({
                "week": week,
                "avg_score": sum(scores) / len(scores),
                "practice_count": len(scores)
            })
        
        # 트렌드 분석
        if len(weekly_averages) >= 2:
            first_week_avg = weekly_averages[0]["avg_score"]
            last_week_avg = weekly_averages[-1]["avg_score"]
            
            if last_week_avg > first_week_avg + 5:
                trend = "improving"
                trend_message = "점수가 꾸준히 향상되고 있습니다!"
            elif last_week_avg < first_week_avg - 5:
                trend = "declining"
                trend_message = "점수가 다소 하락하고 있습니다. 연습 방법을 점검해보세요."
            else:
                trend = "stable"
                trend_message = "점수가 안정적으로 유지되고 있습니다."
        else:
            trend = "insufficient_data"
            trend_message = "트렌드 분석을 위한 충분한 데이터가 없습니다."
        
        return {
            "trend": trend,
            "trend_message": trend_message,
            "weekly_data": weekly_averages,
            "total_weeks": len(weekly_averages),
            "total_practices": len(score_histories)
        }
        
    except Exception as e:
        print(f"점수 트렌드 분석 오류: {e}")
        raise HTTPException(status_code=500, detail="점수 트렌드 분석 중 오류가 발생했습니다.")

@router.get("/test/score-trend")
async def get_score_trend_analysis_test(
    user_id: str,
    db: Session = Depends(get_db),
    days: int = 30
):
    """사용자의 점수 트렌드 분석을 제공합니다 (테스트용)."""
    
    try:
        # 지정된 기간의 연습 기록 조회
        days_ago = datetime.now() - timedelta(days=days)
        score_histories = db.query(ScoreHistory).filter(
            ScoreHistory.user_id == user_id,
            ScoreHistory.created_at >= days_ago
        ).order_by(ScoreHistory.created_at.asc()).all()
        
        if not score_histories:
            return {
                "message": "해당 기간에 연습 기록이 없습니다.",
                "trend": "no_data"
            }
        
        # 주별 평균 점수 계산
        weekly_data = {}
        for history in score_histories:
            week_start = history.created_at - timedelta(days=history.created_at.weekday())
            week_key = week_start.strftime("%Y-%m-%d")
            
            if week_key not in weekly_data:
                weekly_data[week_key] = []
            
            # 피치와 리듬 점수의 평균을 종합 점수로 사용
            if history.pitch_score is not None and history.rhythm_score is not None:
                combined_score = (history.pitch_score + history.rhythm_score) / 2
                weekly_data[week_key].append(combined_score)
            else:
                weekly_data[week_key].append(0)
        
        # 주별 평균 계산
        weekly_averages = []
        for week, scores in sorted(weekly_data.items()):
            weekly_averages.append({
                "week": week,
                "avg_score": sum(scores) / len(scores),
                "practice_count": len(scores)
            })
        
        # 트렌드 분석
        if len(weekly_averages) >= 2:
            first_week_avg = weekly_averages[0]["avg_score"]
            last_week_avg = weekly_averages[-1]["avg_score"]
            
            if last_week_avg > first_week_avg + 5:
                trend = "improving"
                trend_message = "점수가 꾸준히 향상되고 있습니다!"
            elif last_week_avg < first_week_avg - 5:
                trend = "declining"
                trend_message = "점수가 다소 하락하고 있습니다. 연습 방법을 점검해보세요."
            else:
                trend = "stable"
                trend_message = "점수가 안정적으로 유지되고 있습니다."
        else:
            trend = "insufficient_data"
            trend_message = "트렌드 분석을 위한 충분한 데이터가 없습니다."
        
        return {
            "trend": trend,
            "trend_message": trend_message,
            "weekly_data": weekly_averages,
            "total_weeks": len(weekly_averages),
            "total_practices": len(score_histories)
        }
        
    except Exception as e:
        print(f"점수 트렌드 분석 오류: {e}")
        raise HTTPException(status_code=500, detail="점수 트렌드 분석 중 오류가 발생했습니다.")

@router.get("/test/user-stats")
async def get_user_statistics_test(
    user_id: str,
    db: Session = Depends(get_db)
):
    """사용자의 통계 정보를 제공합니다 (테스트용)."""
    
    try:
        # 사용자의 전체 점수 히스토리 조회
        score_histories = db.query(ScoreHistory).filter(
            ScoreHistory.user_id == user_id
        ).all()
        
        if not score_histories:
            return {
                "message": "점수 기록이 없습니다.",
                "total_practices": 0,
                "avg_pitch_score": 0,
                "avg_rhythm_score": 0,
                "avg_combined_score": 0,
                "best_score": 0,
                "recent_trend": "no_data"
            }
        
        # 통계 계산
        total_practices = len(score_histories)
        
        # 유효한 점수들만 필터링
        valid_scores = []
        for history in score_histories:
            if history.pitch_score is not None and history.rhythm_score is not None:
                combined_score = (history.pitch_score + history.rhythm_score) / 2
                valid_scores.append({
                    "pitch": history.pitch_score,
                    "rhythm": history.rhythm_score,
                    "combined": combined_score,
                    "date": history.created_at
                })
        
        if not valid_scores:
            return {
                "message": "유효한 점수 데이터가 없습니다.",
                "total_practices": total_practices,
                "avg_pitch_score": 0,
                "avg_rhythm_score": 0,
                "avg_combined_score": 0,
                "best_score": 0,
                "recent_trend": "no_data"
            }
        
        # 평균 점수 계산
        avg_pitch = sum(s["pitch"] for s in valid_scores) / len(valid_scores)
        avg_rhythm = sum(s["rhythm"] for s in valid_scores) / len(valid_scores)
        avg_combined = sum(s["combined"] for s in valid_scores) / len(valid_scores)
        
        # 최고 점수
        best_score = max(s["combined"] for s in valid_scores)
        
        # 최근 트렌드 분석 (최근 5개 vs 이전 5개)
        recent_trend = "stable"
        if len(valid_scores) >= 10:
            recent_scores = valid_scores[-5:]  # 최근 5개
            older_scores = valid_scores[-10:-5]  # 이전 5개
            
            recent_avg = sum(s["combined"] for s in recent_scores) / len(recent_scores)
            older_avg = sum(s["combined"] for s in older_scores) / len(older_scores)
            
            if recent_avg > older_avg + 3:
                recent_trend = "improving"
            elif recent_avg < older_avg - 3:
                recent_trend = "declining"
        
        return {
            "total_practices": total_practices,
            "avg_pitch_score": round(avg_pitch, 2),
            "avg_rhythm_score": round(avg_rhythm, 2),
            "avg_combined_score": round(avg_combined, 2),
            "best_score": round(best_score, 2),
            "recent_trend": recent_trend,
            "valid_scores_count": len(valid_scores)
        }
        
    except Exception as e:
        print(f"사용자 통계 분석 오류: {e}")
        raise HTTPException(status_code=500, detail="사용자 통계 분석 중 오류가 발생했습니다.") 

@router.get("/test/generate")
async def generate_feedback_test(
    user_id: str,
    song_id: Optional[int] = None,
    days_back: int = 30,
    include_vocal_range: bool = True,
    include_genre_analysis: bool = True,
    db: Session = Depends(get_db)
):
    """AI 피드백을 생성합니다 (테스트용)."""
    
    try:
        # 사용자의 점수 히스토리 조회
        days_ago = datetime.now() - timedelta(days=days_back)
        query = db.query(ScoreHistory).filter(
            ScoreHistory.user_id == user_id,
            ScoreHistory.created_at >= days_ago
        )
        
        if song_id:
            query = query.filter(ScoreHistory.song_id == song_id)
        
        score_histories = query.order_by(ScoreHistory.created_at.desc()).all()
        
        if not score_histories:
            return {"error": "해당 기간에 연습 기록이 없습니다."}
        
        # 점수 분석
        pitch_scores = [sh.pitch_score for sh in score_histories]
        rhythm_scores = [sh.rhythm_score for sh in score_histories]
        combined_scores = [(p + r) / 2 for p, r in zip(pitch_scores, rhythm_scores)]
        
        avg_pitch = sum(pitch_scores) / len(pitch_scores)
        avg_rhythm = sum(rhythm_scores) / len(rhythm_scores)
        avg_combined = sum(combined_scores) / len(combined_scores)
        
        # 트렌드 분석
        if len(combined_scores) >= 2:
            recent_avg = sum(combined_scores[:len(combined_scores)//2]) / (len(combined_scores)//2)
            older_avg = sum(combined_scores[len(combined_scores)//2:]) / (len(combined_scores)//2)
            trend = "improving" if recent_avg > older_avg else "declining" if recent_avg < older_avg else "stable"
        else:
            trend = "stable"
        
        # GPT 피드백 생성
        system_prompt = """당신은 전문적인 보컬 트레이너입니다. 
사용자의 노래 연습 기록을 분석하여 격려적이고 구체적인 피드백을 제공해주세요.
피드백은 다음 요소들을 포함해야 합니다:
1. 전반적인 성과 평가
2. 강점과 개선점
3. 구체적인 연습 제안
4. 격려의 메시지

한국어로 친근하고 격려적인 톤으로 작성해주세요."""

        user_prompt = f"""
사용자님의 노래 연습 분석 결과입니다:

연습 기간: 최근 {days_back}일
총 연습 횟수: {len(score_histories)}회
평균 점수:
- 피치: {avg_pitch:.1f}점
- 리듬: {avg_rhythm:.1f}점
- 종합: {avg_combined:.1f}점

성과 트렌드: {trend}

위 정보를 바탕으로 개인화된 피드백을 작성해주세요.
"""

        response = openai_client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            max_tokens=600,
            temperature=0.7
        )
        
        feedback_content = response.choices[0].message.content.strip()
        
        # 피드백을 데이터베이스에 저장
        feedback = Feedback(
            user_id=user_id,
            content=feedback_content,
            song_id=song_id,
            created_at=datetime.now()
        )
        db.add(feedback)
        db.commit()
        db.refresh(feedback)
        
        return {
            "feedback_id": feedback.feedback_id,
            "content": feedback_content,
            "created_at": feedback.created_at.isoformat(),
            "analysis": {
                "total_practices": len(score_histories),
                "avg_pitch": avg_pitch,
                "avg_rhythm": avg_rhythm,
                "avg_combined": avg_combined,
                "trend": trend
            }
        }
        
    except Exception as e:
        db.rollback()
        return {"error": f"피드백 생성 중 오류가 발생했습니다: {str(e)}"}

@router.get("/test/history")
async def get_feedback_history_test(
    user_id: str,
    limit: int = 10,
    db: Session = Depends(get_db)
):
    """사용자의 피드백 히스토리를 조회합니다 (테스트용)."""
    
    try:
        feedbacks = db.query(Feedback).filter(
            Feedback.user_id == user_id
        ).order_by(Feedback.created_at.desc()).limit(limit).all()
        
        return [
            {
                "feedback_id": f.feedback_id,
                "content": f.content,
                "song_id": f.song_id,
                "created_at": f.created_at.isoformat()
            }
            for f in feedbacks
        ]
        
    except Exception as e:
        return {"error": f"피드백 히스토리 조회 중 오류가 발생했습니다: {str(e)}"}

@router.get("/test/analysis/{song_id}")
async def get_song_analysis_test(
    song_id: int,
    user_id: str,
    db: Session = Depends(get_db)
):
    """특정 곡에 대한 분석을 제공합니다 (테스트용)."""
    
    try:
        # 곡 정보 조회
        song = db.query(Song).filter(Song.song_id == song_id).first()
        if not song:
            return {"error": "곡을 찾을 수 없습니다."}
        
        # 사용자의 해당 곡 연습 기록 조회
        score_histories = db.query(ScoreHistory).filter(
            ScoreHistory.user_id == user_id,
            ScoreHistory.song_id == song_id
        ).all()
        
        if not score_histories:
            return {"error": "해당 곡의 연습 기록이 없습니다."}
        
        # 점수 분석
        pitch_scores = [sh.pitch_score for sh in score_histories]
        rhythm_scores = [sh.rhythm_score for sh in score_histories]
        combined_scores = [(p + r) / 2 for p, r in zip(pitch_scores, rhythm_scores)]
        
        avg_pitch = sum(pitch_scores) / len(pitch_scores)
        avg_rhythm = sum(rhythm_scores) / len(rhythm_scores)
        avg_combined = sum(combined_scores) / len(combined_scores)
        
        return {
            "song_id": song.song_id,
            "song_title": song.song_title,
            "singer": song.singer,
            "practice_count": len(score_histories),
            "avg_pitch": avg_pitch,
            "avg_rhythm": avg_rhythm,
            "avg_score": avg_combined,
            "best_score": max(combined_scores),
            "recent_score": combined_scores[0] if combined_scores else 0
        }
        
    except Exception as e:
        return {"error": f"곡 분석 중 오류가 발생했습니다: {str(e)}"} 