# GEMINI.md — ChargeTrail v2 Fast-Execution Constitution

## 1. Fast-Execution Rules (CRITICAL — PREVENT CONTEXT BLOAT & HANGS)
- **DO NOT** read docs/THESIS_BLUEPRINT.md or docs/LEGACY_AUDIT.md unless explicitly asked.
- **Read ONLY** the specific files mentioned in the user's prompt (never read more than 4 files at once).
- **Run Single Test Files First:** Always run lutter test test/<single_file>.dart --no-pub instead of running the entire test suite in a loop.
- **Never Use pumpAndSettle() on FlutterMap:** Always use wait tester.pump(const Duration(milliseconds: 200));.

## 2.  Open-Source Tech Stack
- **Frontend (rontend/):** Flutter 3.x, lutter_riverpod, lutter_map (Esri/OSM tiles), dio, shared_preferences, geolocator, url_launcher.
- **Backend (ackend/):** Python 3.12, FastAPI, Async SQLAlchemy 2.0, iosqlite (chargetrail_local.db) / PostGIS, Pydantic v2, httpx, pytest, uff.

## 3. Core Guardrails & UI Iconography Mandate
- **STRICT ZERO-EMOJI UI MANDATE:** NEVER use hardcoded text emojis (e.g., ?, ??, ??, ??, ??, ??, ??, ??) in any Dart UI widget, SnackBar, or label. ALWAYS use native Flutter Material Icon(Icons.<name>_rounded) widgets (or vector icon packages).
- **File Size Ceiling:** Target 150–350 lines per file (500 lines hard max).
- **3-Layer Separation of Concerns:** presentation/ -> domain/ -> data/ (Flutter) and pi/v1/ -> services/ -> epositories/ & models/ (FastAPI).
