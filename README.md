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
- 優先順位はユーザー任せ
- 「継続する仕組み」が弱い

という課題がある。

Tomorrow OSでは

**「毎日の振り返り」→「AIとの対話」→「AI会議」→「明日の設計」**

という習慣を作る。

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

- タスク実行
- タスク追加
- AIへ相談
- 予定変更
- タスク完了

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

## 6. Morning Briefing

朝

```
Good Morning!

今日一番重要なのは

✅ 数学30分

昨日一緒に決めた予定だよ！
```

---

## 7. Weekly Review

毎週

- タスク達成率
- 気分
- 集中時間
- 睡眠
- 継続率

を可視化。

---

## 8. Future Prediction

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
 ├── Task
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
- RAGの対象は「過去の自分」
- 毎日の振り返りを通じて、長期的な成長をサポートする

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
>