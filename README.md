# Tomorrow Planter

> **Every day, you plant tomorrow.**
> 

---

# 概要

**Tomorrow Planter** は、AIと一緒に毎日を振り返り、未来の自分を育てるための **AIネイティブなライフプランニングアプリ**です。

毎晩、ユーザーはAI Agentとの対話を通じて一日を振り返ります。会話の内容をもとに、複数のAI Agentがそれぞれの専門的な視点から議論を行い、「今日の自分」と「過去の自分」の経験を踏まえながら、明日に向けた最適な行動計画を提案します。

Tomorrow Planterの特徴は、AIが答えを一方的に提示するのではなく、**AI Agent同士の議論をリアルタイムで可視化し、その議論にユーザー自身も参加できる**ことです。ユーザー・AI Agent・過去の記録が協力して意思決定を行うことで、毎日の小さな選択を積み重ね、未来の自分を育てていきます。

また、Cloud Firestore に蓄積された振り返りやタスク履歴を、ベクトル検索による RAG（Retrieval-Augmented Generation）の知識ベースとして活用することで、AIは「過去の自分」の経験を参考にしながら、一人ひとりに最適化されたアドバイスやスケジュールを生成します。

Tomorrow Planterは、Todoを管理するアプリではありません。
日中の **Task Seed（タスクの種）** は一覧管理が目的ではなく、大きな目標を分解して「いつ植えるか」を AI と一緒に決めるための機能です。分解中も AI の思考段階を可視化します。

**今日の行動という"種"を植え、AIとともに明日の自分を育てるためのプラットフォームです。**

---

# コンセプト

> **あなた専属のAIチームが、毎日を一緒に設計する。**
> 

毎晩寝る前に5〜10分だけアプリを開く。

AIと雑談をしながら

- 今日を振り返る
- 気持ちを整理する
- 明日やることを考える
- AI Agent同士が議論する
- ユーザーも議論へ参加する
- 明日の予定を決定する

という流れで一日を締めくくる。

---

# 解決したい課題

現在のタスク管理アプリでは

- Todoを書くだけ
- AIが整理するだけ
- 大きなタスクのまま放置され、締切逆算の分解と実行日提案が弱い
- 優先順位はユーザー任せ
- 「継続する仕組み」が弱い
- AIの待ち時間がぐるぐる表示だけで、思考過程が見えない

という課題がある。

Tomorrow Planter では

**「毎日の振り返り」→「AIとの対話」→「AI会議」→「明日の設計」**

という習慣を作り、日中は Task Seed で大きな目標を分解して「いつ植えるか」まで一緒に決める。

---

# ユーザーフロー

## 🌙 夜

```
アプリを開く

↓

Reflection Agentと会話

↓

今日を振り返る

↓

AI Agent同士が議論

↓

ユーザーも議論へ参加

↓

Tomorrow Plan生成

↓

保存して就寝
```

---

## 🌞 朝

```
Good Morning!

↓

昨日決めた予定を表示

↓

今日の最重要タスクを通知
```

---

## ☀️ 日中

```
タスク（種）を追加（タイトル + 期限）

↓

「AIでタスクを分解」 または 「タスクを直接追加」

↓

（分解を選んだ場合）AIが考えている演出（アニメーション）

↓

Gemini がサブタスク + 実行日を提案 → ユーザーが確認・調整して採用

↓

今日やる分は実行・完了 / 残りは夜の Tomorrow Plan に引き継ぎ
```

補足:

- タスク実行・完了
- AIへ相談
- 予定変更

---

# コア機能

## 1. Reflection

毎晩AIと会話しながら

- 今日の出来事
- 気分
- 疲労
- 良かったこと
- 悪かったこと

を振り返る。

雑談ベースで進むため入力負荷が少ない。

---

## 2. AI Multi-Agent Discussion

Reflection終了後

AI Agentが相談を始める。

例

```
Reflection Agent

今日は疲れてそう。

Priority Agent

でも課題の締切は明日。

Planner Agent

30分だけやろう。

Coach Agent

継続を優先したい。
```

通常のAIアプリでは見えない

**AIの思考プロセスを可視化する。**

---

## 3. Human in the Loop

ユーザーもAI会議へ参加できる。

例

```
Reflection

疲れてそうですね。

あなた

今日は意外と元気！

Planner

了解しました。

勉強時間を60分へ変更します。
```

AIだけで決めるのではなく

**AIチームと共同で意思決定する。**

---

## 4. Tomorrow Planner

議論終了後

AIが明日のスケジュールを生成。

例

```
7:00 起床

8:00 学校

18:30 ご飯

19:00 数学30分

20:00 洗濯

21:00 自由時間
```

---

## 5. Coach

最後に

Coach Agentが

- 今日の頑張り
- 明日への一言
- モチベーション

を伝える。

---

## 6. Task Seed（AIタスク分解）

日中フェーズの機能。大きなタスク（種）と期限を入力し、次のどちらかで進められる。

- **AIでタスクを分解** — Gemini（Decomposer Agent）が実行可能なサブタスクへ分解し、締切までの実行日を提案する
- **タスクを直接追加** — 分解せず、そのまま種としてリストに追加する（細かく分かれているタスク向け）

| 従来のTodo | Tomorrow Planter の Task Seed |
| --- | --- |
| 自分で細かく書く | 大きなタスクだけ書いて AI が分解（または直接追加） |
| 期限だけ持つ | 締切までの実行日を提案 |
| ぐるぐる待ちだけ | 分解の過程をアニメーションで見せる |
| 一覧管理が主目的 | 夜の議論・明日の設計に接続する種 |

UX要件:

- 入力は **タイトル + 期限** を最小とする（入力負荷を低く）
- **直接追加** と **AI分解** の両方の導線を用意する
- 分解結果は即確定せず、**採用 / 編集 / やり直し** を必須にする（Human in the Loop）
- 分解時は Memory RAG（過去の完了パターン・疲労傾向）を参照する
- 詰め込みすぎない（夜の Planner と同思想）
- **提案中は専用の thinking アニメーションを必ず出す**（`CircularProgressIndicator` 単体は不可）

例

```
ユーザー: 「レポート提出」期限 7/25

↓

AI分解中アニメーション（過去参照 → 分解 → 日付配分）

↓

AI分解:
  7/20 資料収集
  7/21 構成案
  7/22 下書き
  7/23 推敲
  7/24 提出準備

↓

ユーザー: 「7/22は予定があるから7/21と7/23に寄せて」

↓

再提案 → 採用
```

### 提案中UI（必須）

プロダクト原則「AIの思考プロセスを可視化する」「ブラックボックスにしない」を日中の分解にも適用する。

#### 画面状態

| 状態 | UI |
| --- | --- |
| idle | 入力フォーム +「AIでタスクを分解」+「タスクを直接追加」 |
| thinking | 専用パネル全表示。ボタンは disabled。キャンセル可 |
| revealing | サブタスクカードが上から順に出現 |
| review | 編集・日付変更・やり直し・採用 |
| error | 短いエラー + 再試行 |

#### 思考段階（植物メタファー）

1. **種を見つめています** — タスク内容の把握（`inspect`）
2. **過去の自分を参照しています** — Memory / RAG（`memory`）
3. **ステップに分解しています** — サブタスク生成（`breakdown`）
4. **カレンダーに植え付けています** — 実行日の配分（`schedule`）

各段階は縦リストで表示し、現在段階だけ強調（primary のパルス）。完了段階はチェックに切り替わる。

#### モーション（最低3つ）

テーマの primary（`#136b55` 系）を使う。

1. **SeedPulse** — 中央の種アイコンがゆっくり拡大・縮小（約 1.2s ループ）
2. **StageCrossfade** — 段階テキストのフェード切替（約 300ms）
3. **SubtaskReveal** — 結果カードが下から fade + slide（1枚あたり約 80–120ms、順次）

追加演出:

- 結果エリアにスケルトン行（3〜5本）をシマー表示し、reveal で実データに置換
- `MediaQuery.disableAnimations` 時はパルス停止し、段階テキストと LinearProgress のみ

#### バックエンド連動（SSE）

`POST /v1/tasks/decompose` は一括 JSON ではなく **SSE** で進捗を返す（夜の discussion と同様）。タイトルと期限を送り、Gemini（Decomposer）がサブタスクと実行日を洗い出す。

| イベント | 内容 |
| --- | --- |
| `decompose_started` | 分解開始 |
| `decompose_progress` | `stage`: `inspect` / `memory` / `breakdown` / `schedule` |
| `subtask_draft` | 部分結果（任意） |
| `decompose_complete` | サブタスク配列 |
| `error` | 失敗 |

Flutter 側は `stage` を見て thinking UI を進め、complete で reveal に遷移する。ネットワークが速くても各段階を最低約 400ms 表示し、チラつきを防ぐ。

実装の置き場所:

- `lib/features/tasks/widgets/decompose_thinking_panel.dart`
- `lib/features/tasks/task_seed_screen.dart`

---

## 7. Morning Briefing

朝

```
Good Morning!

今日一番重要なのは

✅ 数学30分

昨日一緒に決めた予定だよ！
```

---

## 8. Weekly Review

毎週

- タスク達成率
- 気分
- 集中時間
- 睡眠
- 継続率

を可視化。

---

## 9. Future Prediction

現在の状況から

```
資格取得まで

達成確率

87%
```

などを予測。

---

# AI Agent構成

```
                 Coordinator Agent
                         │
 ┌──────────┼──────────┼──────────┐
 │          │          │          │
Reflection Priority  Planner  Decomposer
Agent      Agent     Agent    Agent
 │          │          │          │
 └──────┬───┴──────────┴──────────┘
        │
  Memory Agent
        │
   Coach Agent
```

---

## Reflection Agent

役割

- 今日を振り返る
- 気分分析
- 疲労分析
- 会話

使用モデル

- Gemini

---

## Memory Agent

役割

- 会話要約
- 長期記憶
- RAG検索

例

```
最近

・数学を避けている

・睡眠不足

・夕方が一番集中できる
```

---

## Priority Agent

役割

優先順位決定

考慮

- 締切
- 疲労
- 長期目標
- 過去の成功パターン

---

## Planner Agent

役割

スケジュール作成

RAGで取得した過去のデータも参考にする。

採用済みかつ実行日が明日の SubTask も入力コンテキストに含める。

---

## Decomposer Agent

役割

- 親タスク（種）を実行可能なサブタスクへ分解する
- 締切までの実行日を提案する
- 分解中は SSE の progress イベントを流し、UI の思考段階と同期する

参照

- Memory / RAG（過去の完了パターン）
- Priority（締切・負荷）

採用後は Planner が夜の Tomorrow Plan に織り込む。

使用モデル

- Gemini

---

## Coach Agent

役割

励ます。

継続できるようサポートする。

---

# RAG（長期記憶）

このアプリのRAGは

**「自分自身」**

が知識ベースになる。

例

```
去年

試験前

疲れていた日
```

を検索して

```
去年も

30分だけ勉強すると

継続できていたよ。
```

というアドバイスを行う。

つまり

**「過去の自分」を参照するAIコーチ**を実現する。

---

# データベース設計（Cloud Firestore）

```
User
 │
 ├── Goal
 │
 ├── Task（ParentTask / 種）
 │    └── SubTask[]
 │
 ├── DailyReview
 │
 ├── TomorrowPlan
 │
 ├── AgentDiscussion
 │
 ├── Memory
 │
 └── Embedding（Firestore ベクトル検索）
```

---

## Task（ParentTask / 種）

| Column | 内容 |
| --- | --- |
| id | タスクID |
| title | タイトル |
| deadline | 期限（YYYY-MM-DD） |
| status | `open` / `decomposed` / `done` / `archived` |
| notes | メモ（任意） |
| created_at | 作成時刻 |
| updated_at | 更新時刻 |

---

## SubTask

| Column | 内容 |
| --- | --- |
| id | サブタスクID |
| parent_task_id | 親タスクID |
| title | タイトル |
| suggested_date | AI提案の実行日 |
| scheduled_date | ユーザー確定の実行日 |
| status | `suggested` / `accepted` / `done` / `skipped` |
| order | 並び順 |
| estimate_minutes | 見積もり分（任意） |
| source | `ai` / `user` |
| accepted | 採用フラグ |

夜フローとの接続:

- 採用済みかつ `scheduled_date == 明日` の SubTask を、夜の Planner 入力コンテキストに含める
- 完了した SubTask は Memory に要約保存し、次回の分解・優先度判断の RAG に使う

---

## Agent Discussion

AI会議も保存する。

| Column | 内容 |
| --- | --- |
| id | 発言ID |
| review_id | 振り返りID |
| agent_name | Reflection / Planner / Coach |
| message | 発言内容 |
| reply_to | 返信先 |
| confidence | 確信度 |
| accepted | 採用されたか |
| created_at | 時刻 |

これにより

過去のAI会議も再生できる。

---

# 技術スタック

## Frontend

- Flutter

---

## Backend

- Python
- FastAPI
- Agent Development Kit (ADK)

---

## AI

- Gemini（Vertex AI）
- ADK Multi-Agent

---

## Database

- Cloud Firestore
- Firestore ベクトル検索（RAG・Embedding）

---

## Infrastructure

- Firebase Authentication
- Firebase Storage
- Cloud Run
- Cloud Tasks
- Cloud Scheduler
- Secret Manager
- Cloud Logging
- Cloud Monitoring

---

# Google Cloud / Firebase 構成

| サービス | 用途 |
| --- | --- |
| ADK | Multi-Agent構築 |
| Gemini | 各Agentの思考・会話・計画生成 |
| Cloud Run | Backend・Agent実行環境 |
| Cloud Firestore | データ保存 |
| Firestore ベクトル検索 | RAG・Embedding検索 |
| Firebase Storage | 添付ファイル保存 |
| Cloud Tasks | 非同期Agent処理 |
| Cloud Scheduler | 朝・夜の定期処理 |
| Firebase Authentication | 認証 |
| Secret Manager | APIキー管理 |
| Cloud Logging | Agentログ |
| Cloud Monitoring | モニタリング |

---

# デモシナリオ（Google Cloud Next）

1. 夜にアプリを開く
2. Reflection Agentと会話
3. Geminiが内容を要約
4. Memory AgentがFirestoreから過去の似た日をRAG検索
5. Reflection / Priority / Planner / Coachが議論
6. ユーザーも議論へ参加
7. Planner Agentが明日の予定を生成
8. Firestoreへ保存
9. 翌朝、通知とともに今日の予定を表示

---

# このプロジェクトの独自性

- AIがタスクを管理するのではなく、**AIチームがユーザーと一緒に明日を設計する**
- AI同士の議論をリアルタイムで可視化
- ユーザーもAI会議へ参加できる
- 日中の Task Seed では、大きな目標の分解過程もアニメーションで可視化する
- RAGの対象は「過去の自分」
- 毎日の振り返りを通じて、長期的な成長をサポートする

---

# Task Seed 実装メモ（今後）

- Backend: `POST /v1/tasks`（直接追加 / 分解結果の一括保存）、`GET /v1/tasks`、`DELETE /v1/tasks/{id}`、`POST /v1/tasks/decompose`（**Gemini SSE + stage**）は実装済み。`PATCH` は今後
- Agent: Decomposer + progress yield（既存 Gemini クライアント再利用）— 実装済み
- Frontend: Home に日中導線、`/tasks`、**thinking パネル必須**（`DecomposeThinkingPanel`）、分解結果の確認・保存 UI
- Planner 連携: finalize / discuss 時に翌日分の accepted SubTask をコンテキスト投入
- 提案中UIは `CircularProgressIndicator` 単体にせず、SeedPulse / StageCrossfade / SubtaskReveal を実装する

---

# キャッチコピー

> **AIと一緒に一日を終え、明日を始める。**
> 

または

> **あなた専属のAIチームが、毎日をデザインする。**
> 

または

> **Tomorrow isn't planned by you alone.**
> 
> 
> **AIと一緒に、明日をつくろう。**

---

# デモ MVP の起動

詳細は [docs/setup-gcp.md](docs/setup-gcp.md) と [backend/README.md](backend/README.md)。

```bash
# Backend
cd backend && source .venv/bin/activate
export AUTH_DISABLED=true   # API単体確認時のみ。アプリ連携時は false + Firebase Auth
uvicorn app.main:app --reload --host 0.0.0.0 --port 8080

# Flutter（別ターミナル）
flutter run --dart-define=BACKEND_URL=http://localhost:8080
```

Cursor / VS Code では **Run and Debug（F5）** で起動できる。構成は [`.vscode/launch.json`](.vscode/launch.json)。

- `Tomorrow Planter (macOS)` / `(Chrome)` / `(iOS simulator)` … Backend も自動起動し `BACKEND_URL=http://localhost:8080`
- `Tomorrow Planter (Android emulator)` … `http://10.0.2.2:8080`
- `Tomorrow Planter (Flutter only)` … Backend は手動起動済みのとき用

Firebase Console で Authentication の **Email/Password** と **Google** を有効化してからサインインする（Anonymous は使わない）。
Google ログイン用の構成ファイルの置き場所は [docs/setup-gcp.md](docs/setup-gcp.md) を参照。
