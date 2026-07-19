# Tomorrow Planter — GCP / Firebase セットアップ

デモ MVP を既存プロジェクト `tomorrow-planter`（リージョン既定: `asia-northeast1`）へ接続するための手順。

## 前提

- `gcloud` / `firebase` / FlutterFire CLI がインストール済み
- 課金（Blaze）が有効であること（Vertex AI / Cloud Run に必要）

## 1. プロジェクト選択

```bash
gcloud config set project tomorrow-planter
firebase use tomorrow-planter
```

## 2. 必要 API の有効化

```bash
gcloud services enable \
  aiplatform.googleapis.com \
  run.googleapis.com \
  firestore.googleapis.com \
  cloudtasks.googleapis.com \
  cloudscheduler.googleapis.com \
  secretmanager.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  identitytoolkit.googleapis.com \
  --project=tomorrow-planter
```

## 3. Firebase コンソール設定

1. [Firebase Console](https://console.firebase.google.com/project/tomorrow-planter) を開く
2. **Authentication** を初めて開いて Get started → Sign-in method で次を有効化:
   - **Email/Password**
   - **Google**
3. **Firestore Database** を Native モードで作成（ロケーション: `asia-northeast1` 推奨）— 既に作成済みならスキップ

### Google ログイン用の構成ファイル（重要）

Firebase に古いアプリ（`com.example.*` / `com.tomorrowplanter.app`）が残っている場合がある。
**使うのは `com.econanringo.*` のアプリだけ。**

| 用途 | 使うアプリ | 識別子 | 置き場所 |
| --- | --- | --- | --- |
| Android | 表示名が `Tomorrow Planter Android` かつ package が `com.econanringo.tomorrow_planter` | `com.econanringo.tomorrow_planter` | [`android/app/google-services.json`](../android/app/google-services.json) |
| iOS | 表示名が `Tomorrow Planter iOS` かつ Bundle ID が `com.econanringo.tomorrowPlanter` | `com.econanringo.tomorrowPlanter` | [`ios/Runner/GoogleService-Info.plist`](../ios/Runner/GoogleService-Info.plist) |
| macOS | 同上 Bundle ID | `com.econanringo.tomorrowPlanter` | [`macos/Runner/GoogleService-Info.plist`](../macos/Runner/GoogleService-Info.plist) |

使わないもの: `tomorrow_planter (android/ios)`（`com.example.*`）、`com.tomorrowplanter.app`。Firebase コンソールから削除してよい。

**Android の SHA-1** は `com.econanringo.tomorrow_planter` のアプリにだけ登録する:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
# SHA1 をコピー → Firebase コンソール → プロジェクト設定 → 該当 Android アプリ → SHA 証明書フィンガープリント
```

登録後、そのアプリの `google-services.json` を再ダウンロードして置き換える。iOS は該当アプリの `GoogleService-Info.plist` を再ダウンロードして置き換える。

その後:

```bash
flutterfire configure --project=tomorrow-planter \
  --android-package-name=com.econanringo.tomorrow_planter \
  --ios-bundle-id=com.econanringo.tomorrowPlanter \
  --macos-bundle-id=com.econanringo.tomorrowPlanter \
  --out=lib/firebase_options.dart
```

4. ルールと索引をデプロイ:

```bash
firebase deploy --only firestore --project=tomorrow-planter
```

## 4. FlutterFire 設定

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=tomorrow-planter \
  --out=lib/firebase_options.dart
```

`lib/firebase_options.dart` と各プラットフォームの設定ファイルが生成される。

## 5. Backend 用サービスアカウント

```bash
PROJECT_ID=tomorrow-planter
SA_NAME=tomorrow-planter-backend
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create "${SA_NAME}" \
  --display-name="Tomorrow Planter Backend" \
  --project="${PROJECT_ID}"

for ROLE in \
  roles/datastore.user \
  roles/aiplatform.user \
  roles/secretmanager.secretAccessor \
  roles/logging.logWriter \
  roles/run.invoker
do
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="${ROLE}"
done
```

ローカル開発時のみ（コミット禁止）:

```bash
gcloud iam service-accounts keys create ./secrets/backend-sa.json \
  --iam-account="${SA_EMAIL}"
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/secrets/backend-sa.json"
```

## 6. 環境変数

`backend/.env.example` をコピーして `backend/.env` を作成する。

| 変数 | 例 | 説明 |
| --- | --- | --- |
| `GCP_PROJECT_ID` | `tomorrow-planter` | GCP プロジェクト |
| `GCP_LOCATION` | `asia-northeast1` | Vertex AI（Gemini / Embedding）リージョン。`gemini-3.5-flash` は `us-central1` 非対応のため `asia-northeast1` または `global` を指定する |
| `FIREBASE_PROJECT_ID` | `tomorrow-planter` | Firebase プロジェクト |
| `GEMINI_MODEL` | `gemini-3.5-flash` | Agent 用モデル |
| `EMBEDDING_MODEL` | `text-embedding-004` | RAG Embedding |
| `BACKEND_URL` | `http://localhost:8080` | Flutter が叩く API 基点 |
| `CORS_ORIGINS` | `*` | 開発時は `*` 可 |

Flutter 側:

```bash
flutter run --dart-define=BACKEND_URL=http://localhost:8080
```

## 7. Cloud Run デプロイ（任意）

```bash
cd backend
gcloud run deploy tomorrow-planter-api \
  --source=. \
  --region=asia-northeast1 \
  --project=tomorrow-planter \
  --service-account="${SA_EMAIL}" \
  --allow-unauthenticated \
  --set-env-vars="GCP_PROJECT_ID=tomorrow-planter,GCP_LOCATION=asia-northeast1,FIREBASE_PROJECT_ID=tomorrow-planter,GEMINI_MODEL=gemini-3.5-flash"
```

本番では `--allow-unauthenticated` を外し、Firebase Auth トークン検証のみにする。

## 8. Cloud Scheduler（朝リマインド・スタブ）

```bash
gcloud scheduler jobs create http morning-briefing-ping \
  --location=asia-northeast1 \
  --schedule="0 7 * * *" \
  --time-zone="Asia/Tokyo" \
  --uri="https://YOUR_CLOUD_RUN_URL/v1/scheduler/morning-ping" \
  --http-method=POST \
  --oidc-service-account-email="${SA_EMAIL}"
```

## 9. ベクトル検索索引

Firestore コンソールまたは `gcloud firestore indexes composite create` で
`users/{uid}/memories` の `embedding` フィールドにベクトル索引を作成する。
次元は Embedding モデルに合わせる（`text-embedding-004` は 768）。

詳細は [`firebase/firestore.indexes.json`](../firebase/firestore.indexes.json) を参照。
