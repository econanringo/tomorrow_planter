from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from uuid import uuid4

from google.cloud import firestore
from google.cloud.firestore_v1.base_vector_query import DistanceMeasure
from google.cloud.firestore_v1.vector import Vector

from app.config import Settings


def _now() -> datetime:
    return datetime.now(timezone.utc)


class FirestoreRepository:
    def __init__(self, client: firestore.Client, settings: Settings) -> None:
        self._db = client
        self._settings = settings

    def user_ref(self, uid: str) -> firestore.DocumentReference:
        return self._db.collection("users").document(uid)

    def ensure_user(self, uid: str, email: Optional[str] = None) -> None:
        ref = self.user_ref(uid)
        if not ref.get().exists:
            ref.set(
                {
                    "email": email,
                    "created_at": _now(),
                    "updated_at": _now(),
                }
            )

    def create_session(self, uid: str) -> str:
        session_id = str(uuid4())
        self.user_ref(uid).collection("sessions").document(session_id).set(
            {
                "phase": "reflection",
                "messages": [],
                "mood": None,
                "fatigue": None,
                "summary": None,
                "rag_context": [],
                "discussion": [],
                "schedule": [],
                "coach_message": None,
                "created_at": _now(),
                "updated_at": _now(),
            }
        )
        return session_id

    def get_session(self, uid: str, session_id: str) -> Dict[str, Any]:
        snap = self.user_ref(uid).collection("sessions").document(session_id).get()
        if not snap.exists:
            raise KeyError(f"session not found: {session_id}")
        data = snap.to_dict() or {}
        data["id"] = session_id
        return data

    def update_session(self, uid: str, session_id: str, **fields: Any) -> None:
        fields["updated_at"] = _now()
        self.user_ref(uid).collection("sessions").document(session_id).update(fields)

    def append_session_message(
        self,
        uid: str,
        session_id: str,
        role: str,
        content: str,
        agent_name: Optional[str] = None,
    ) -> None:
        session = self.get_session(uid, session_id)
        messages = list(session.get("messages") or [])
        messages.append(
            {
                "role": role,
                "content": content,
                "agent_name": agent_name,
                "created_at": _now().isoformat(),
            }
        )
        self.update_session(uid, session_id, messages=messages)

    def save_discussion_turn(
        self,
        uid: str,
        session_id: str,
        review_id: str,
        agent_name: str,
        message: str,
        reply_to: Optional[str] = None,
        confidence: Optional[float] = None,
        accepted: bool = False,
    ) -> str:
        message_id = str(uuid4())
        doc = {
            "id": message_id,
            "review_id": review_id,
            "session_id": session_id,
            "agent_name": agent_name,
            "message": message,
            "reply_to": reply_to,
            "confidence": confidence,
            "accepted": accepted,
            "created_at": _now(),
        }
        self.user_ref(uid).collection("agent_discussions").document(message_id).set(doc)

        session = self.get_session(uid, session_id)
        discussion = list(session.get("discussion") or [])
        discussion.append(doc)
        self.update_session(uid, session_id, discussion=discussion)
        return message_id

    def save_daily_review(
        self,
        uid: str,
        session_id: str,
        summary: str,
        mood: Optional[str],
        fatigue: Optional[str],
    ) -> str:
        review_id = str(uuid4())
        self.user_ref(uid).collection("daily_reviews").document(review_id).set(
            {
                "id": review_id,
                "session_id": session_id,
                "summary": summary,
                "mood": mood,
                "fatigue": fatigue,
                "created_at": _now(),
            }
        )
        return review_id

    def save_tomorrow_plan(
        self,
        uid: str,
        plan_date: str,
        schedule: List[Dict[str, Any]],
        top_priority: Optional[str],
        coach_message: Optional[str],
        review_id: str,
        session_id: str,
    ) -> str:
        plan_id = plan_date
        self.user_ref(uid).collection("tomorrow_plans").document(plan_id).set(
            {
                "id": plan_id,
                "date": plan_date,
                "schedule": schedule,
                "top_priority": top_priority,
                "coach_message": coach_message,
                "review_id": review_id,
                "session_id": session_id,
                "created_at": _now(),
            }
        )
        return plan_id

    def get_plan_by_date(self, uid: str, plan_date: str) -> Optional[Dict[str, Any]]:
        snap = self.user_ref(uid).collection("tomorrow_plans").document(plan_date).get()
        if not snap.exists:
            return None
        return snap.to_dict()

    def get_latest_plan(self, uid: str) -> Optional[Dict[str, Any]]:
        snaps = (
            self.user_ref(uid)
            .collection("tomorrow_plans")
            .order_by("created_at", direction=firestore.Query.DESCENDING)
            .limit(1)
            .stream()
        )
        for snap in snaps:
            data = snap.to_dict() or {}
            data["id"] = snap.id
            return data
        return None

    def save_memory(
        self,
        uid: str,
        text: str,
        embedding: List[float],
        tags: Optional[List[str]] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> str:
        memory_id = str(uuid4())
        self.user_ref(uid).collection("memories").document(memory_id).set(
            {
                "id": memory_id,
                "text": text,
                "embedding": Vector(embedding),
                "tags": tags or [],
                "metadata": metadata or {},
                "created_at": _now(),
            }
        )
        return memory_id

    def search_similar_memories(
        self,
        uid: str,
        query_embedding: List[float],
        limit: int = 3,
    ) -> List[Dict[str, Any]]:
        collection = self.user_ref(uid).collection("memories")
        try:
            results = (
                collection.find_nearest(
                    vector_field="embedding",
                    query_vector=Vector(query_embedding),
                    distance_measure=DistanceMeasure.COSINE,
                    limit=limit,
                )
                .stream()
            )
            out: List[Dict[str, Any]] = []
            for doc in results:
                data = doc.to_dict() or {}
                data["id"] = doc.id
                # Vector is not JSON-serializable for SSE/session state.
                data.pop("embedding", None)
                out.append(data)
            return out
        except Exception:
            # Fallback when vector index is not ready: return recent memories.
            snaps = (
                collection.order_by("created_at", direction=firestore.Query.DESCENDING)
                .limit(limit)
                .stream()
            )
            out = []
            for doc in snaps:
                data = doc.to_dict() or {}
                data["id"] = doc.id
                data.pop("embedding", None)
                out.append(data)
            return out

    def list_goals(self, uid: str, limit: int = 5) -> List[Dict[str, Any]]:
        snaps = self.user_ref(uid).collection("goals").limit(limit).stream()
        return [{"id": s.id, **(s.to_dict() or {})} for s in snaps]

    def seed_demo_data(self, uid: str, embeddings: List[List[float]]) -> None:
        goals = self.user_ref(uid).collection("goals")
        if not list(goals.limit(1).stream()):
            goals.document("goal-exam").set(
                {
                    "title": "資格試験に合格する",
                    "description": "毎日少しでも勉強を継続する",
                    "target_date": "2026-12-01",
                    "created_at": _now(),
                }
            )

        memories = [
            (
                "試験前で疲れていた日。30分だけ数学をやると継続できた。",
                ["fatigue", "study", "math"],
            ),
            (
                "睡眠不足の日は夜の重いタスクを避け、朝に回すと上手くいった。",
                ["sleep", "schedule"],
            ),
            (
                "夕方は集中しやすい。19時前後の短時間ブロックが一番進む。",
                ["focus", "evening"],
            ),
        ]
        existing = list(self.user_ref(uid).collection("memories").limit(1).stream())
        if existing:
            return
        for (text, tags), emb in zip(memories, embeddings):
            self.save_memory(uid, text, emb, tags=tags)

    def tasks_ref(self, uid: str) -> firestore.CollectionReference:
        return self.user_ref(uid).collection("tasks")

    def create_task(
        self,
        uid: str,
        title: str,
        deadline: str,
        notes: Optional[str] = None,
        status: str = "open",
        subtasks: Optional[List[Dict[str, Any]]] = None,
    ) -> Dict[str, Any]:
        task_id = str(uuid4())
        now = _now()
        doc: Dict[str, Any] = {
            "id": task_id,
            "title": title,
            "deadline": deadline,
            "status": status,
            "notes": notes,
            "created_at": now,
            "updated_at": now,
        }
        task_ref = self.tasks_ref(uid).document(task_id)
        task_ref.set(doc)

        saved_subtasks: List[Dict[str, Any]] = []
        for raw in subtasks or []:
            sub_id = str(uuid4())
            suggested = raw.get("suggested_date") or deadline
            scheduled = raw.get("scheduled_date") or suggested
            sub_doc = {
                "id": sub_id,
                "parent_task_id": task_id,
                "title": raw["title"],
                "suggested_date": suggested,
                "scheduled_date": scheduled,
                "status": raw.get("status") or "accepted",
                "order": int(raw.get("order") or 0),
                "estimate_minutes": raw.get("estimate_minutes"),
                "source": raw.get("source") or "ai",
                "accepted": bool(raw.get("accepted", True)),
                "created_at": now,
            }
            task_ref.collection("subtasks").document(sub_id).set(sub_doc)
            saved_subtasks.append(sub_doc)

        doc["subtasks"] = saved_subtasks
        return doc

    def list_subtasks(self, uid: str, task_id: str) -> List[Dict[str, Any]]:
        snaps = (
            self.tasks_ref(uid)
            .document(task_id)
            .collection("subtasks")
            .order_by("order")
            .stream()
        )
        out: List[Dict[str, Any]] = []
        for snap in snaps:
            data = snap.to_dict() or {}
            data["id"] = snap.id
            out.append(data)
        return out

    def get_task(self, uid: str, task_id: str) -> Dict[str, Any]:
        snap = self.tasks_ref(uid).document(task_id).get()
        if not snap.exists:
            raise KeyError(f"task not found: {task_id}")
        data = snap.to_dict() or {}
        data["id"] = task_id
        data["subtasks"] = self.list_subtasks(uid, task_id)
        return data

    def list_tasks(
        self,
        uid: str,
        status: Optional[str] = None,
        limit: int = 50,
    ) -> List[Dict[str, Any]]:
        # Avoid composite-index requirement: order then filter in memory.
        snaps = (
            self.tasks_ref(uid)
            .order_by("created_at", direction=firestore.Query.DESCENDING)
            .limit(max(limit, 100))
            .stream()
        )
        out: List[Dict[str, Any]] = []
        for snap in snaps:
            data = snap.to_dict() or {}
            if status and data.get("status") != status:
                continue
            data["id"] = snap.id
            data["subtasks"] = self.list_subtasks(uid, snap.id)
            out.append(data)
            if len(out) >= limit:
                break
        return out

    def delete_task(self, uid: str, task_id: str) -> None:
        task_ref = self.tasks_ref(uid).document(task_id)
        if not task_ref.get().exists:
            raise KeyError(f"task not found: {task_id}")
        for sub in task_ref.collection("subtasks").stream():
            sub.reference.delete()
        task_ref.delete()

    def update_task(self, uid: str, task_id: str, **fields: Any) -> Dict[str, Any]:
        task_ref = self.tasks_ref(uid).document(task_id)
        if not task_ref.get().exists:
            raise KeyError(f"task not found: {task_id}")
        payload = {k: v for k, v in fields.items() if v is not None}
        payload["updated_at"] = _now()
        task_ref.update(payload)
        return self.get_task(uid, task_id)

    def update_subtask(
        self,
        uid: str,
        task_id: str,
        subtask_id: str,
        **fields: Any,
    ) -> Dict[str, Any]:
        task_ref = self.tasks_ref(uid).document(task_id)
        if not task_ref.get().exists:
            raise KeyError(f"task not found: {task_id}")
        sub_ref = task_ref.collection("subtasks").document(subtask_id)
        snap = sub_ref.get()
        if not snap.exists:
            raise KeyError(f"subtask not found: {subtask_id}")
        payload = {k: v for k, v in fields.items() if v is not None}
        if payload:
            sub_ref.update(payload)
        data = sub_ref.get().to_dict() or {}
        data["id"] = subtask_id
        return data
