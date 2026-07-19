from __future__ import annotations

import json
import re
from typing import Any, AsyncIterator, Dict, List, Optional

import vertexai
from vertexai.generative_models import GenerativeModel
from vertexai.language_models import TextEmbeddingInput, TextEmbeddingModel

from app.config import Settings
from app.firestore.repository import FirestoreRepository
from app.models import ScheduleItem


def _extract_json(text: str) -> Any:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    return json.loads(text)


class GeminiClient:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        vertexai.init(project=settings.gcp_project_id, location=settings.gcp_location)
        self._model = GenerativeModel(settings.gemini_model)
        self._embedder = TextEmbeddingModel.from_pretrained(settings.embedding_model)

    async def generate(self, system: str, user: str) -> str:
        prompt = f"{system}\n\n---\n\n{user}"
        # generate_content is sync in vertexai; run in thread via asyncio if needed later
        response = self._model.generate_content(prompt)
        return (response.text or "").strip()

    def embed(self, texts: List[str]) -> List[List[float]]:
        inputs = [TextEmbeddingInput(text=t, task_type="RETRIEVAL_DOCUMENT") for t in texts]
        embeddings = self._embedder.get_embeddings(inputs)
        return [list(e.values) for e in embeddings]

    def embed_query(self, text: str) -> List[float]:
        inputs = [TextEmbeddingInput(text=text, task_type="RETRIEVAL_QUERY")]
        embeddings = self._embedder.get_embeddings(inputs)
        return list(embeddings[0].values)


class NightFlowOrchestrator:
    """Coordinator for Reflection → Multi-Agent Discussion → Plan → Coach."""

    def __init__(
        self,
        gemini: GeminiClient,
        repo: FirestoreRepository,
        settings: Settings,
    ) -> None:
        self._gemini = gemini
        self._repo = repo
        self._settings = settings

    async def start_reflection(self, uid: str, email: Optional[str]) -> Dict[str, str]:
        self._repo.ensure_user(uid, email)
        # Seed demo memories (RAG) once per user.
        try:
            seed_texts = [
                "試験前で疲れていた日。30分だけ数学をやると継続できた。",
                "睡眠不足の日は夜の重いタスクを避け、朝に回すと上手くいった。",
                "夕方は集中しやすい。19時前後の短時間ブロックが一番進む。",
            ]
            embeddings = self._gemini.embed(seed_texts)
            self._repo.seed_demo_data(uid, embeddings)
        except Exception:
            # Seeding must not block reflection start.
            pass

        session_id = self._repo.create_session(uid)
        greeting = (
            "こんばんは。今日一日、お疲れさまです。\n"
            "うまくいったことでも、ちょっと大変だったことでも、雑談するように話してくれれば大丈夫です。"
        )
        self._repo.append_session_message(
            uid, session_id, role="assistant", content=greeting, agent_name="Reflection"
        )
        return {"session_id": session_id, "greeting": greeting}

    async def reflection_reply(
        self, uid: str, session_id: str, user_message: str
    ) -> AsyncIterator[Dict[str, Any]]:
        self._repo.append_session_message(uid, session_id, role="user", content=user_message)
        session = self._repo.get_session(uid, session_id)
        history = session.get("messages") or []
        transcript = "\n".join(
            f"{m.get('agent_name') or m.get('role')}: {m.get('content')}" for m in history[-12:]
        )

        system = (
            "あなたは Tomorrow Planter の Reflection Agent です。"
            "日本語で、短く温かく雑談しながら今日の振り返りを進めます。"
            "入力負荷を下げ、1回の返答は2〜4文程度。"
            "気分・疲労・良かったこと・悪かったことに自然に触れてください。"
            "最後に短い質問を1つだけ添えてください。"
        )
        reply = await self._gemini.generate(system, transcript)
        self._repo.append_session_message(
            uid, session_id, role="assistant", content=reply, agent_name="Reflection"
        )

        # Lightweight mood/fatigue extraction (best-effort).
        try:
            analysis = await self._gemini.generate(
                "次の会話から mood と fatigue を JSON で返してください。"
                '形式: {"mood":"...","fatigue":"low|medium|high","summary":"..."}',
                transcript + f"\nReflection: {reply}",
            )
            parsed = _extract_json(analysis)
            self._repo.update_session(
                uid,
                session_id,
                mood=parsed.get("mood"),
                fatigue=parsed.get("fatigue"),
                summary=parsed.get("summary"),
            )
        except Exception:
            pass

        yield {
            "type": "agent_message",
            "agent_name": "Reflection",
            "message": reply,
            "done": True,
        }

    async def run_discussion(
        self, uid: str, session_id: str, user_intervention: Optional[str] = None
    ) -> AsyncIterator[Dict[str, Any]]:
        session = self._repo.get_session(uid, session_id)
        summary = session.get("summary") or "今日の振り返り会話"
        mood = session.get("mood")
        fatigue = session.get("fatigue")
        goals = self._repo.list_goals(uid)

        # Memory / RAG
        yield {
            "type": "agent_message",
            "agent_name": "Memory",
            "message": "過去の自分に似た日を探しています…",
            "confidence": 0.5,
            "done": False,
        }
        rag_context: List[Dict[str, Any]] = []
        try:
            query_emb = self._gemini.embed_query(summary)
            rag_context = self._repo.search_similar_memories(uid, query_emb, limit=3)
        except Exception:
            rag_context = []

        rag_text = "\n".join(f"- {m.get('text')}" for m in rag_context) or "- （まだ十分な記憶がありません）"
        memory_msg = await self._gemini.generate(
            "あなたは Memory Agent です。過去の自分の記録を短く要約し、今回の議論に役立つポイントを日本語で2〜3文で述べてください。",
            f"今日の要約: {summary}\n気分: {mood}\n疲労: {fatigue}\n過去の記録:\n{rag_text}",
        )
        self._repo.update_session(uid, session_id, rag_context=rag_context, phase="discussion")
        yield {
            "type": "agent_message",
            "agent_name": "Memory",
            "message": memory_msg,
            "confidence": 0.8,
            "done": True,
        }

        intervention_block = ""
        if user_intervention:
            intervention_block = f"\nユーザーからの介入: {user_intervention}\n必ずこの意見を計画に反映してください。"
            self._repo.append_session_message(
                uid, session_id, role="user", content=user_intervention, agent_name="User"
            )

        goals_text = "\n".join(
            f"- {g.get('title')}: {g.get('description', '')}" for g in goals
        ) or "- 資格試験に合格する（継続重視）"

        priority_msg = await self._gemini.generate(
            "あなたは Priority Agent です。締切・疲労・長期目標・過去パターンから、明日の最優先を1つ決め、理由を日本語で2文以内で述べてください。",
            f"要約: {summary}\n気分: {mood}\n疲労: {fatigue}\n目標:\n{goals_text}\nMemory:\n{memory_msg}{intervention_block}",
        )
        yield {
            "type": "agent_message",
            "agent_name": "Priority",
            "message": priority_msg,
            "reply_to": "Memory",
            "confidence": 0.85,
            "done": True,
        }

        planner_raw = await self._gemini.generate(
            "あなたは Planner Agent です。明日の現実的なスケジュールを JSON のみで返してください。"
            '形式: {"items":[{"time":"19:00","title":"...","duration_minutes":30,"is_priority":true,"notes":"..."}],'
            '"top_priority":"...","comment":"議論用の短い一言"}'
            "夜の自由時間も含め、詰め込みすぎないこと。",
            f"要約: {summary}\n疲労: {fatigue}\nPriority: {priority_msg}\nMemory: {memory_msg}{intervention_block}",
        )
        schedule: List[Dict[str, Any]] = []
        top_priority = None
        planner_comment = "明日のたたき台を作りました。"
        try:
            parsed = _extract_json(planner_raw)
            schedule = parsed.get("items") or []
            top_priority = parsed.get("top_priority")
            planner_comment = parsed.get("comment") or planner_comment
        except Exception:
            schedule = [
                {"time": "7:00", "title": "起床", "duration_minutes": 0, "is_priority": False},
                {
                    "time": "19:00",
                    "title": "最重要タスク 30分",
                    "duration_minutes": 30,
                    "is_priority": True,
                    "notes": priority_msg[:80],
                },
                {"time": "21:00", "title": "自由時間", "duration_minutes": 60, "is_priority": False},
            ]
            top_priority = schedule[1]["title"]

        self._repo.update_session(
            uid,
            session_id,
            schedule=schedule,
            coach_message=None,
        )
        yield {
            "type": "agent_message",
            "agent_name": "Planner",
            "message": planner_comment
            + "\n"
            + "\n".join(f"{i.get('time')} {i.get('title')}" for i in schedule),
            "reply_to": "Priority",
            "confidence": 0.9,
            "done": True,
            "meta": {"schedule": schedule, "top_priority": top_priority},
        }

        coach_msg = await self._gemini.generate(
            "あなたは Coach Agent です。今日の頑張りを認め、明日への一言を日本語で2〜3文、励ますように伝えてください。継続を優先してください。",
            f"要約: {summary}\nPriority: {priority_msg}\nPlan top: {top_priority}\nMemory: {memory_msg}",
        )
        self._repo.update_session(uid, session_id, coach_message=coach_msg)
        yield {
            "type": "agent_message",
            "agent_name": "Coach",
            "message": coach_msg,
            "reply_to": "Planner",
            "confidence": 0.88,
            "done": True,
        }

        yield {
            "type": "discussion_complete",
            "agent_name": "Coordinator",
            "message": "議論が一段落しました。予定を確認するか、意見を追加できます。",
            "done": True,
            "meta": {"schedule": schedule, "top_priority": top_priority, "coach_message": coach_msg},
        }

    async def finalize(self, uid: str, session_id: str) -> Dict[str, Any]:
        from datetime import datetime, timedelta, timezone

        session = self._repo.get_session(uid, session_id)
        summary = session.get("summary") or "今日の振り返り"
        mood = session.get("mood")
        fatigue = session.get("fatigue")
        schedule = session.get("schedule") or []
        coach_message = session.get("coach_message") or "また明日、一緒に育てていきましょう。"

        review_id = self._repo.save_daily_review(uid, session_id, summary, mood, fatigue)

        # Persist discussion turns
        for turn in session.get("discussion") or []:
            # already saved if via save_discussion_turn; skip duplicates by rewriting from final schedule phase
            pass

        # Save discussion from last run if stored only in session messages meta — persist explicit turns
        # Re-save key agent outputs from messages for replay
        for msg in session.get("messages") or []:
            agent = msg.get("agent_name")
            if agent in {"Memory", "Priority", "Planner", "Coach", "Reflection"}:
                self._repo.save_discussion_turn(
                    uid,
                    session_id,
                    review_id,
                    agent,
                    msg.get("content") or "",
                    accepted=agent in {"Planner", "Coach"},
                )

        # Also persist latest discussion array entries
        for turn in session.get("discussion") or []:
            if turn.get("id"):
                continue

        tomorrow = (datetime.now(timezone.utc) + timedelta(days=1)).date().isoformat()
        top_priority = None
        for item in schedule:
            if item.get("is_priority"):
                top_priority = item.get("title")
                break
        if not top_priority and schedule:
            top_priority = schedule[0].get("title")

        plan_id = self._repo.save_tomorrow_plan(
            uid,
            tomorrow,
            schedule,
            top_priority,
            coach_message,
            review_id,
            session_id,
        )

        # Store memory for future RAG
        try:
            emb = self._gemini.embed([summary])[0]
            self._repo.save_memory(
                uid,
                summary,
                emb,
                tags=["daily_review"],
                metadata={"review_id": review_id, "mood": mood, "fatigue": fatigue},
            )
        except Exception:
            pass

        self._repo.update_session(uid, session_id, phase="finalized", review_id=review_id)

        return {
            "review_id": review_id,
            "plan_id": plan_id,
            "plan_date": tomorrow,
            "schedule": [ScheduleItem.model_validate(i) for i in schedule],
            "coach_message": coach_message,
        }
