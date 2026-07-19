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
