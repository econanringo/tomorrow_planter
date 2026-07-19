from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, List, Optional

from pydantic import BaseModel, Field


class AgentName(str, Enum):
    REFLECTION = "Reflection"
    MEMORY = "Memory"
    PRIORITY = "Priority"
    PLANNER = "Planner"
    DECOMPOSER = "Decomposer"
    COACH = "Coach"
    USER = "User"
    COORDINATOR = "Coordinator"


class ScheduleItem(BaseModel):
    time: str
    title: str
    duration_minutes: Optional[int] = None
    is_priority: bool = False
    notes: Optional[str] = None


class StartReflectionResponse(BaseModel):
    session_id: str
    greeting: str


class ChatMessageRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)


class InterveneRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)


class FinalizeResponse(BaseModel):
    review_id: str
    plan_id: str
    plan_date: str
    schedule: List[ScheduleItem]
    coach_message: str


class TomorrowPlanResponse(BaseModel):
    plan_id: str
    date: str
    schedule: List[ScheduleItem]
    top_priority: Optional[str] = None
    coach_message: Optional[str] = None
    created_at: Optional[datetime] = None


class SseAgentEvent(BaseModel):
    type: str = "agent_message"
    agent_name: str
    message: str
    reply_to: Optional[str] = None
    confidence: Optional[float] = None
    done: bool = False
    meta: Optional[dict[str, Any]] = None


class TaskStatus(str, Enum):
    OPEN = "open"
    DECOMPOSED = "decomposed"
    DONE = "done"
    ARCHIVED = "archived"


class SubTaskStatus(str, Enum):
    SUGGESTED = "suggested"
    ACCEPTED = "accepted"
    DONE = "done"
    SKIPPED = "skipped"


class SubTaskInput(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    suggested_date: str = Field(description="YYYY-MM-DD")
    scheduled_date: Optional[str] = None
    estimate_minutes: Optional[int] = Field(default=None, ge=1, le=24 * 60)
    order: int = 0
    source: str = "ai"
    accepted: bool = True
    status: SubTaskStatus = SubTaskStatus.ACCEPTED


class CreateTaskRequest(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    deadline: str = Field(description="YYYY-MM-DD")
    notes: Optional[str] = Field(default=None, max_length=2000)
    subtasks: Optional[List[SubTaskInput]] = None


class DecomposeTaskRequest(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    deadline: str = Field(description="YYYY-MM-DD")
    notes: Optional[str] = Field(default=None, max_length=2000)


class UpdateTaskRequest(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=500)
    deadline: Optional[str] = None
    notes: Optional[str] = Field(default=None, max_length=2000)
    status: Optional[TaskStatus] = None


class UpdateSubTaskRequest(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=500)
    suggested_date: Optional[str] = None
    scheduled_date: Optional[str] = None
    estimate_minutes: Optional[int] = Field(default=None, ge=1, le=24 * 60)
    status: Optional[SubTaskStatus] = None
    order: Optional[int] = None
    accepted: Optional[bool] = None


class SubTaskResponse(BaseModel):
    id: str
    parent_task_id: str
    title: str
    suggested_date: str
    scheduled_date: Optional[str] = None
    status: SubTaskStatus = SubTaskStatus.ACCEPTED
    order: int = 0
    estimate_minutes: Optional[int] = None
    source: str = "ai"
    accepted: bool = True
    created_at: Optional[datetime] = None


class TaskResponse(BaseModel):
    id: str
    title: str
    deadline: str
    status: TaskStatus
    notes: Optional[str] = None
    subtasks: List[SubTaskResponse] = Field(default_factory=list)
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class TaskListResponse(BaseModel):
    tasks: List[TaskResponse]
