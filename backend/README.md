# Tomorrow Planter Backend

FastAPI + ADK Multi-Agent + Vertex AI Gemini + Firestore.

## Local run

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env

# ADC (Vertex / Firestore)
gcloud auth application-default login
gcloud auth application-default set-quota-project tomorrow-planter

# Optional: skip Firebase token checks for API-only smoke tests
export AUTH_DISABLED=true

uvicorn app.main:app --reload --host 0.0.0.0 --port 8080
```

## Flutter

```bash
flutter run --dart-define=BACKEND_URL=http://localhost:8080
# Android emulator:
# flutter run --dart-define=BACKEND_URL=http://10.0.2.2:8080
```

Enable **Anonymous** (and Email) in Firebase Authentication console before signing in.

## Deploy Cloud Run

See [docs/setup-gcp.md](../docs/setup-gcp.md).
