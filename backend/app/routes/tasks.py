from __future__ import annotations

import json
import re
from typing import Annotated, AsyncIterator, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from google.cloud import firestore

from app.agents.orchestrator import GeminiClient, NightFlowOrchestrator
from app.auth import AuthUser, get_current_user
from app.config import Settings, get_settings
from app.firestore.repository import FirestoreRepository
from app.models import (
    CreateTaskRequest,
    DecomposeTaskRequest,
    SubTaskResponse,
    TaskListResponse,
    TaskResponse,
    TaskStatus,
    UpdateSubTaskRequest,
    UpdateTaskRequest,
)

router = APIRouter(prefix="/v1/tasks", tags=["tasks"])

_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def get_repo(settings: Annotated[Settings, Depends(get_settings)]) -> FirestoreRepository:
    client = firestore.Client(project=settings.firebase_project_id)
    return FirestoreRepository(client, settings)


def get_orchestrator(
    settings: Annotated[Settings, Depends(get_settings)],
    repo: Annotated[FirestoreRepository, Depends(get_repo)],
) -> NightFlowOrchestrator:
    return NightFlowOrchestrator(GeminiClient(settings), repo, settings)


def _validate_date(value: str, field: str) -> None:
    if not _DATE_RE.match(value):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{field} must be YYYY-MM-DD",
        )


def _sse(data: dict) -> str:
    return f"data: {json.dumps(data, ensure_ascii=False, default=str)}\n\n"


def _to_subtask(raw: dict) -> SubTaskResponse:
    return SubTaskResponse(
        id=raw.get("id") or "",
        parent_task_id=raw.get("parent_task_id") or "",
        title=raw.get("title") or "",
        suggested_date=raw.get("suggested_date") or "",
        scheduled_date=raw.get("scheduled_date"),
        status=raw.get("status") or "accepted",
        order=int(raw.get("order") or 0),
        estimate_minutes=raw.get("estimate_minutes"),
        source=raw.get("source") or "ai",
        accepted=bool(raw.get("accepted", True)),
        created_at=raw.get("created_at"),
    )


def _to_task(raw: dict) -> TaskResponse:
    subtasks = [_to_subtask(s) for s in (raw.get("subtasks") or [])]
    return TaskResponse(
        id=raw.get("id") or "",
        title=raw.get("title") or "",
        deadline=raw.get("deadline") or "",
        status=raw.get("status") or TaskStatus.OPEN,
        notes=raw.get("notes"),
        subtasks=subtasks,
        created_at=raw.get("created_at"),
        updated_at=raw.get("updated_at"),
    )


@router.post("", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
async def create_task(
    body: CreateTaskRequest,
    user: Annotated[AuthUser, Depends(get_current_user)],
    repo: Annotated[FirestoreRepository, Depends(get_repo)],
) -> TaskResponse:
    _validate_date(body.deadline, "deadline")
    for sub in body.subtasks or []:
        _validate_date(sub.suggested_date, "suggested_date")
        if sub.scheduled_date:
            _validate_date(sub.scheduled_date, "scheduled_date")

    repo.ensure_user(user.uid, user.email)

    has_subtasks = bool(body.subtasks)
    task_status = TaskStatus.DECOMPOSED if has_subtasks else TaskStatus.OPEN
    subtask_payload = None
    if body.subtasks:
        subtask_payload = [
            {
                "title": s.title,
                "suggested_date": s.suggested_date,
                "scheduled_date": s.scheduled_date or s.suggested_date,
                "estimate_minutes": s.estimate_minutes,
                "order": s.order,
                "source": s.source,
                "accepted": s.accepted,
                "status": s.status.value if hasattr(s.status, "value") else s.status,
            }
            for s in body.subtasks
        ]

    created = repo.create_task(
        user.uid,
        title=body.title,
        deadline=body.deadline,
        notes=body.notes,
        status=task_status.value,
        subtasks=subtask_payload,
    )
    return _to_task(created)


@router.post("/decompose")
async def decompose_task(
    body: DecomposeTaskRequest,
    user: Annotated[AuthUser, Depends(get_current_user)],
    orch: Annotated[NightFlowOrchestrator, Depends(get_orchestrator)],
) -> StreamingResponse:
    """Gemini Decomposer でサブタスク＋実行日を SSE で返す。"""
    _validate_date(body.deadline, "deadline")

    async def gen() -> AsyncIterator[str]:
        try:
            async for event in orch.decompose_task(
                user.uid,
                title=body.title,
                deadline=body.deadline,
                notes=body.notes,
            ):
                yield _sse(event)
        except Exception as exc:  # noqa: BLE001
            yield _sse(
                {
                    "type": "error",
                    "agent_name": "Decomposer",
                    "message": str(exc),
                    "done": True,
                }
            )
        yield _sse(
            {
                "type": "done",
                "agent_name": "Decomposer",
                "message": "",
                "done": True,
            }
        )

    return StreamingResponse(gen(), media_type="text/event-stream")


@router.get("", response_model=TaskListResponse)
async def list_tasks(
    user: Annotated[AuthUser, Depends(get_current_user)],
    repo: Annotated[FirestoreRepository, Depends(get_repo)],
    status_filter: Annotated[
        Optional[str], Query(alias="status", description="open|decomposed|done|archived")
    ] = None,
) -> TaskListResponse:
    if status_filter and status_filter not in {s.value for s in TaskStatus}:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="invalid status filter",
        )
    repo.ensure_user(user.uid, user.email)
    tasks = repo.list_tasks(user.uid, status=status_filter)
    return TaskListResponse(tasks=[_to_task(t) for t in tasks])


@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(
    task_id: str,
    user: Annotated[AuthUser, Depends(get_current_user)],
    repo: Annotated[FirestoreRepository, Depends(get_repo)],
) -> TaskResponse:
    try:
        task = repo.get_task(user.uid, task_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return _to_task(task)


@router.patch("/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: str,
    body: UpdateTaskRequest,
    user: Annotated[AuthUser, Depends(get_current_user)],
    repo: Annotated[FirestoreRepository, Depends(get_repo)],
) -> TaskResponse:
    if body.deadline:
        _validate_date(body.deadline, "deadline")
    fields: dict = {}
    if body.title is not None:
        fields["title"] = body.title
    if body.deadline is not None:
        fields["deadline"] = body.deadline
    if body.notes is not None:
        fields["notes"] = body.notes
    if body.status is not None:
        fields["status"] = body.status.value
    if not fields:
        raise HTTPException(status_code=422, detail="no fields to update")
    try:
        updated = repo.update_task(user.uid, task_id, **fields)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return _to_task(updated)


@router.patch("/{task_id}/subtasks/{subtask_id}", response_model=SubTaskResponse)
async def update_subtask(
    task_id: str,
    subtask_id: str,
    body: UpdateSubTaskRequest,
    user: Annotated[AuthUser, Depends(get_current_user)],
    repo: Annotated[FirestoreRepository, Depends(get_repo)],
) -> SubTaskResponse:
    if body.suggested_date:
        _validate_date(body.suggested_date, "suggested_date")
    if body.scheduled_date:
        _validate_date(body.scheduled_date, "scheduled_date")

    fields: dict = {}
    if body.title is not None:
        fields["title"] = body.title
    if body.suggested_date is not None:
        fields["suggested_date"] = body.suggested_date
    if body.scheduled_date is not None:
        fields["scheduled_date"] = body.scheduled_date
    if body.estimate_minutes is not None:
        fields["estimate_minutes"] = body.estimate_minutes
    if body.status is not None:
        fields["status"] = body.status.value
    if body.order is not None:
        fields["order"] = body.order
    if body.accepted is not None:
        fields["accepted"] = body.accepted
    if not fields:
        raise HTTPException(status_code=422, detail="no fields to update")

    try:
        updated = repo.update_subtask(user.uid, task_id, subtask_id, **fields)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return _to_subtask(updated)


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_task(
    task_id: str,
    user: Annotated[AuthUser, Depends(get_current_user)],
    repo: Annotated[FirestoreRepository, Depends(get_repo)],
) -> None:
    try:
        repo.delete_task(user.uid, task_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
