# GEMINI.md — ChargeTrail v2 Fast-Execution Constitution

## 1. Fast-Execution Rules (CRITICAL — PREVENT CONTEXT BLOAT & HANGS)
- **DO NOT** read `docs/THESIS_BLUEPRINT.md` or `docs/LEGACY_AUDIT.md` unless explicitly asked.
- **Read ONLY** the specific files mentioned in the user's prompt (never read more than 4 files at once).
- **Run Single Test Files First:** Always run `flutter test test/<single_file>.dart --no-pub` instead of running the entire test suite in a loop.
- **Never Use `pumpAndSettle()` on `FlutterMap`:** Always use `await tester.pump(const Duration(milliseconds: 200));`.

## 2. $0 Open-Source Tech Stack
- **Frontend (`frontend/`):** Flutter 3.x, `flutter_riverpod`, `flutter_map` (Esri/OSM tiles), `dio`, `shared_preferences`, `geolocator`, `url_launcher`.
- **Backend (`backend/`):** Python 3.12, FastAPI, Async `SQLAlchemy 2.0`, `aiosqlite` (`chargetrail_local.db`) / PostGIS, `Pydantic v2`, `httpx`, `pytest`, `ruff`.

## 3. Core Guardrails
- **File Size Ceiling:** Target 150–350 lines per file (500 lines hard max).
- **3-Layer Separation of Concerns:** `presentation/` -> `domain/` -> `data/` (Flutter) and `api/v1/` -> `services/` -> `repositories/` & `models/` (FastAPI).
