# AGENTS.md — Tomorrow Planter

コーディングエージェント向けのプロジェクトガイド。詳細なプロダクト説明・デモシナリオは [README.md](README.md) を参照すること。

## プロダクト要約

**Tomorrow Planter** は、AIと一緒に毎日を振り返り、未来の自分を育てる **AIネイティブなライフプランニングアプリ**である。

- Todoを管理するアプリではない
- 今日の行動という「種」を植え、AIとともに明日の自分を育てるプラットフォーム
- キャッチコピー: *Every day, you plant tomorrow.*

## コアUX原則

実装・設計時に必ず守ること。

1. **雑談ベースの Reflection** — 入力負荷を低く保ち、毎晩5〜10分で一日を締めくくれること
2. **AI議論の可視化** — Agent同士の思考プロセスをリアルタイムで見せる。ブラックボックスにしない
3. **Human in the Loop** — AIだけで決めず、ユーザーが議論に参加して共同意思決定する
4. **RAGは「過去の自分」** — 外部知識ではなく、ユーザー自身の振り返り・タスク履歴を知識ベースにする

## ユーザーフロー（実装の軸）

| フェーズ | 主な体験 |
| --- | --- |
| 夜 | Reflection → AI Multi-Agent議論 → ユーザー参加 → Tomorrow Plan生成 → 保存 |
| 朝 | Morning Briefing（昨日決めた予定・最重要タスクの通知） |
| 日中 | タスク実行・追加・AI相談・予定変更・完了 |

画面・API・Agent設計はこの3フェーズに沿って組み立てる。

## コア機能（実装優先度の指針）

1. Reflection（今日の振り返り会話）
2. AI Multi-Agent Discussion（議論の可視化）
3. Human in the Loop（ユーザー発言の反映）
4. Tomorrow Planner（明日のスケジュール生成）
5. Coach（励まし・継続サポート）
6. Morning Briefing
7. Weekly Review
8. Future Prediction

## AI Agent 構成

```
                 Coordinator Agent
                         │
 ┌──────────────┼──────────────┐
 │              │              │
Reflection   Priority      Planner
Agent        Agent         Agent
 │              │              │
 └───────┬──────┴──────────────┘
         │
   Memory Agent
         │
    Coach Agent
```

| Agent | 役割 |
| --- | --- |
| Coordinator | 全体のオーケストレーション |
| Reflection | 今日の振り返り、気分・疲労分析、会話（Gemini） |
| Memory | 会話要約、長期記憶、RAG検索 |
| Priority | 締切・疲労・長期目標・過去の成功パターンから優先順位決定 |
| Planner | スケジュール作成（RAGの過去データも参照） |
| Coach | 励まし、継続サポート |

使用モデル: **Gemini（Vertex AI）** / 構築: **ADK Multi-Agent**

## 技術スタック

| 層 | 技術 |
| --- | --- |
| Frontend | Flutter（既存 `lib/`） |
| Backend | Python, FastAPI, Agent Development Kit (ADK) |
| AI | Gemini（Vertex AI）, ADK Multi-Agent |
| Database | Cloud SQL (PostgreSQL) + pgvector |
| Infra | Cloud Run, Cloud Storage, Cloud Tasks, Cloud Scheduler, Secret Manager, Cloud Logging, Cloud Monitoring, Identity Platform |

現状のリポジトリは Flutter スキャフォールド中心。Backend（FastAPI / ADK）は今後追加する想定。

## データモデル（概要）

```
User
 ├── Goal
 ├── Task
 ├── DailyReview
 ├── TomorrowPlan
 ├── AgentDiscussion
 ├── Memory
 └── Embedding(pgvector)
```

`AgentDiscussion` は AI会議の発言を保存し、過去の議論を再生可能にする（`agent_name`, `message`, `reply_to`, `confidence`, `accepted` 等）。

## 実装ガイドライン

- **Todoアプリ化しない** — 一覧・CRUD中心の設計に寄せず、「振り返り → 議論 → 明日の設計」を主軸にする
- **議論ログを永続化する** — Agent発言は `AgentDiscussion` として保存し、再生・分析できること
- **計画生成時は Memory / RAG を参照する** — Planner / Priority / Coach は過去の自分のパターンを踏まえる
- **ユーザー参加を前提にする** — Agent出力を最終決定とせず、ユーザー発言で計画を更新できること
- **機密をリポジトリに載せない** — APIキー等は Secret Manager 前提。`.env` や資格情報をコミットしない
- **非同期処理は Cloud Tasks / Scheduler を想定** — 長時間の Agent 実行や朝・夜の定期処理に使う

## 参照

- プロダクト詳細・デモシナリオ: [README.md](README.md)
