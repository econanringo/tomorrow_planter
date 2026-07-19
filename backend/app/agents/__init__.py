"""ADK Multi-Agent definitions for Tomorrow Planter.

The live night flow is orchestrated in `orchestrator.py` (SSE-friendly).
These ADK agents document and mirror the same roles for ADK tooling / future
`SequentialAgent` deployment on Cloud Run.
"""

from __future__ import annotations

from google.adk.agents import LlmAgent, SequentialAgent

from app.config import get_settings

_settings = get_settings()
_MODEL = _settings.gemini_model

reflection_agent = LlmAgent(
    name="Reflection",
    model=_MODEL,
    description="今日の振り返り・気分・疲労の雑談パートナー",
    instruction=(
        "あなたは Tomorrow Planter の Reflection Agent です。"
        "日本語で短く温かく雑談し、今日の出来事・気分・疲労を引き出してください。"
    ),
    output_key="reflection_summary",
)

memory_agent = LlmAgent(
    name="Memory",
    model=_MODEL,
    description="過去の自分の記録を要約し RAG コンテキストを提示する",
    instruction=(
        "あなたは Memory Agent です。与えられた過去記録から、今回の議論に役立つ"
        "パターンを日本語で短くまとめてください。"
    ),
    output_key="memory_context",
)

priority_agent = LlmAgent(
    name="Priority",
    model=_MODEL,
    description="締切・疲労・目標から明日の最優先を決める",
    instruction=(
        "あなたは Priority Agent です。疲労と継続を考慮し、明日の最優先を1つ選んでください。"
    ),
    output_key="priority_decision",
)

planner_agent = LlmAgent(
    name="Planner",
    model=_MODEL,
    description="明日の現実的なスケジュールを作成する",
    instruction=(
        "あなたは Planner Agent です。詰め込みすぎず、明日のスケジュールを提案してください。"
    ),
    output_key="tomorrow_schedule",
)

coach_agent = LlmAgent(
    name="Coach",
    model=_MODEL,
    description="励ましと継続サポート",
    instruction=(
        "あなたは Coach Agent です。今日の頑張りを認め、明日への一言を伝えてください。"
    ),
    output_key="coach_message",
)

# Discussion pipeline used conceptually by the Coordinator.
discussion_pipeline = SequentialAgent(
    name="DiscussionPipeline",
    sub_agents=[memory_agent, priority_agent, planner_agent, coach_agent],
)

# Root agent for ADK CLI / get_fast_api_app compatibility.
root_agent = LlmAgent(
    name="Coordinator",
    model=_MODEL,
    description="Tomorrow Planter 夜フローのオーケストレータ",
    instruction=(
        "あなたは Coordinator です。Reflection のあと DiscussionPipeline の視点で"
        "ユーザーと一緒に明日を設計してください。AIだけで決めず、ユーザー参加を促してください。"
    ),
    sub_agents=[reflection_agent, discussion_pipeline],
)
