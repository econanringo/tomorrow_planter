#!/usr/bin/env python3
"""Seed demo goals/memories for a user via the Backend API.

Usage:
  export ID_TOKEN=...   # Firebase ID token
  export BACKEND_URL=http://localhost:8080
  python scripts/seed_demo.py
"""

from __future__ import annotations

import os
import sys

import httpx

BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:8080").rstrip("/")
TOKEN = os.getenv("ID_TOKEN", "")


def main() -> int:
    if not TOKEN:
        print("Set ID_TOKEN to a Firebase ID token", file=sys.stderr)
        return 1
    headers = {"Authorization": f"Bearer {TOKEN}"}
    with httpx.Client(timeout=60.0) as client:
        res = client.post(f"{BACKEND_URL}/v1/demo/seed", headers=headers)
        print(res.status_code, res.text)
        return 0 if res.is_success else 1


if __name__ == "__main__":
    raise SystemExit(main())
