from __future__ import annotations

import json
from datetime import date, datetime, timezone
from typing import Annotated, AsyncIterator, Optional

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import StreamingResponse
from google.cloud import firestore

from app.agents.orchestrator import GeminiClient, NightFlowOrchestrator
from app.auth import AuthUser, get_current_user
from app.config import Settings, get_settings
from app.firestore.repository import FirestoreRepository
from app.models import (
    ChatMessageRequest,
    FinalizeResponse,
    InterveneRequest,
    StartReflectionResponse,
    TomorrowPlanResponse,
)

router = APIRouter(prefix="/v1")


def get_repo(settings: Annotated[Settings, Depends(get_settings)]) -> FirestoreRepository:
    client = firestore.Client(project=settings.firebase_project_id)
    return FirestoreRepository(client, settings)


def get_orchestrator(
    settings: Annotated[Settings, Depends(get_settings)],
    repo: Annotated[FirestoreRepository, Depends(get_repo)],
) -> NightFlowOrchestrator:
    return NightFlowOrchestrator(GeminiClient(settings), repo, settings)


def _sse(data: dict) -> str:
    return f"data: {json.dumps(data, ensure_ascii=False, default=str)}\n\n"


async def _persist_discussion_stream(
    orch: NightFlowOrchestrator,
    uid: str,
    session_id: str,
    stream: AsyncIterator[dict],
) -> AsyncIterator[str]:
    review_placeholder = session_id
    async for event in stream:
        if event.get("type") == "agent_message" and event.get("agent_name"):
            try:
                orch._repo.save_discussion_turn(
                    uid,
                    session_id,
                    review_placeholder,
                    event["agent_name"],
                    event.get("message") or "",
                    reply_to=event.get("reply_to"),
                    confidence=event.get("confidence"),
                    accepted=False,
                )
            except Exception:
                pass
            # Also keep in session messages for finalize
            try:
                orch._repo.append_session_message(
                    uid,
                    session_id,
                    role="assistant",
                    content=event.get("message") or "",
                    agent_name=event.get("agent_name"),
                )
            except Exception:
                pass
        yield _sse(event)
    yield _sse({"type": "done", "agent_name": "Coordinator", "message": "", "done": True})


@router.post("/sessions/reflection", response_model=StartReflectionResponse)
async def start_reflection(
    user: Annotated[AuthUser, Depends(get_current_user)],
    orch: Annotated[NightFlowOrchestrator, Depends(get_orchestrator)],
) -> StartReflectionResponse:
    result = await orch.start_reflection(user.uid, user.email)
    return StartReflectionResponse(**result)


@router.post("/sessions/{session_id}/messages")
async def post_reflection_message(
    session_id: str,
    body: ChatMessageRequest,
    user: Annotated[AuthUser, Depends(get_current_user)],
    orch: Annotated[NightFlowOrchestrator, Depends(get_orchestrator)],
) -> StreamingResponse:
    try:
        orch._repo.get_session(user.uid, session_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    async def gen() -> AsyncIterator[str]:
        async for event in orch.reflection_reply(user.uid, session_id, body.message):
            yield _sse(event)
        yield _sse({"type": "done", "done": True, "agent_name": "Reflection", "message": ""})

    return StreamingResponse(gen(), media_type="text/event-stream")


@router.post("/sessions/{session_id}/discuss")
async def start_discussion(
    session_id: str,
    user: Annotated[AuthUser, Depends(get_current_user)],
    orch: Annotated[NightFlowOrchestrator, Depends(get_orchestrator)],
) -> StreamingResponse:
    try:
        orch._repo.get_session(user.uid, session_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    return StreamingResponse(
        _persist_discussion_stream(
            orch, user.uid, session_id, orch.run_discussion(user.uid, session_id)
        ),
        media_type="text/event-stream",
    )


@router.post("/sessions/{session_id}/discuss/intervene")
async def intervene_discussion(
    session_id: str,
    body: InterveneRequest,
    user: Annotated[AuthUser, Depends(get_current_user)],
    orch: Annotated[NightFlowOrchestrator, Depends(get_orchestrator)],
) -> StreamingResponse:
    try:
        orch._repo.get_session(user.uid, session_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    return StreamingResponse(
        _persist_discussion_stream(
            orch,
            user.uid,
            session_id,
            orch.run_discussion(user.uid, session_id, user_intervention=body.message),
        ),
        media_type="text/event-stream",
    )


@router.post("/sessions/{session_id}/finalize", response_model=FinalizeResponse)
async def finalize_session(
    session_id: str,
    user: Annotated[AuthUser, Depends(get_current_user)],
    orch: Annotated[NightFlowOrchestrator, Depends(get_orchestrator)],
) -> FinalizeResponse:
    try:
        result = await orch.finalize(user.uid, session_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return FinalizeResponse(**result)


def _to_plan_response(plan: dict, fallback_date: str) -> TomorrowPlanResponse:
    return TomorrowPlanResponse(
        plan_id=plan.get("id") or fallback_date,
        date=plan.get("date") or fallback_date,
        schedule=plan.get("schedule") or [],
        top_priority=plan.get("top_priority"),
        coach_message=plan.get("coach_message"),
        created_at=plan.get("created_at"),
    )


@router.get("/plans/today", response_model=TomorrowPlanResponse)
async def get_today_plan(
    user: Annotated[AuthUser, Depends(get_current_user)],
    repo: Annotated[FirestoreRepository, Depends(get_repo)],
) -> TomorrowPlanResponse:
    today = date.today().isoformat()
    plan = repo.get_plan_by_date(user.uid, today) or repo.get_latest_plan(user.uid)
    if plan is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="本日のプランがまだありません。昨夜の振り返りを完了してください。",
        )
    return _to_plan_response(plan, today)


@router.get("/plans/briefing", response_model=TomorrowPlanResponse)
async def get_morning_briefing(
    user: Annotated[AuthUser, Depends(get_current_user)],
    repo: Annotated[FirestoreRepository, Depends(get_repo)],
) -> TomorrowPlanResponse:
    """Morning briefing: prefer today's plan; fall back to latest for same-day demos."""
    today = date.today().isoformat()
    plan = repo.get_plan_by_date(user.uid, today) or repo.get_latest_plan(user.uid)
    if plan is None:
        raise HTTPException(status_code=404, detail="Morning plan not found")
    return _to_plan_response(plan, today)


@router.post("/scheduler/morning-ping")
async def morning_ping(request: Request) -> dict:
    """Cloud Scheduler stub — logs a morning ping. Push notifications are out of MVP scope."""
    return {
        "ok": True,
        "message": "morning-ping received",
        "at": datetime.now(timezone.utc).isoformat(),
        "path": str(request.url.path),
    }


@router.post("/demo/seed")
async def seed_demo(
    user: Annotated[AuthUser, Depends(get_current_user)],
    orch: Annotated[NightFlowOrchestrator, Depends(get_orchestrator)],
) -> dict:
    texts = [
        "試験前で疲れていた日。30分だけ数学をやると継続できた。",
        "睡眠不足の日は夜の重いタスクを避け、朝に回すと上手くいった。",
        "夕方は集中しやすい。19時前後の短時間ブロックが一番進む。",
    ]
    embeddings = orch._gemini.embed(texts)
    orch._repo.seed_demo_data(user.uid, embeddings)
    return {"ok": True, "memories": len(texts)}
