# GEMINI.md — ChargeTrail v2 Engineering Constitution

## 1. Project Identity & Core Problem Statement
- **Project:** `chargetrail-v2` — An open-source, community-driven EV charging station discovery and battery-aware journey planning platform for Malaysia (Android, iOS, Web).
- **Reference Docs:** Always consult `docs/THESIS_BLUEPRINT.md` (requirements & Mermaid diagrams) and `docs/LEGACY_AUDIT.md` (v1 pitfalls to avoid).
- **4 Core Pillars:**
  1. Unified Station Discovery (OpenChargeMap/OSM baseline + community-added hidden chargers with step-by-step access photo guides).
  2. Server-Enforced `Survei Mikro` (5-vote community consensus engine before untrusted edits go live).
  3. Battery-Aware Route Planner (OSRM polyline + PostGIS `ST_DWithin` spatial corridor filtering + 3 stop strategies).
  4. Offline-First & Server-Shutdown Resilience (Local device caching + primary/fallback API failover).

---

## 2. $0 Open-Source Tech Stack (Strict Zero-Paid-API Policy)
- **NEVER use paid Google Maps/Places/Directions SDKs or client-side Firebase.**
- **Frontend (`app/`):** Flutter 3.x (Android, iOS, Web)
  - Map Engine: `flutter_map` + OpenStreetMap / MapLibre tiles (100% pure Dart).
  - State Management & DI: `flutter_riverpod` (Riverpod 2.x).
  - Routing: `go_router`.
  - Models & Serialization: `freezed` + `json_serializable` (Strict typing; NO raw `Map<String, dynamic>` in domain/UI layers).
  - Offline Local Cache: `drift` (SQLite) for offline stations, saved trips, and queued edits.
  - HTTP Client: `dio` with Primary/Fallback URL failover interceptor.
- **Backend (`backend/`):** Python 3.12 + FastAPI
  - ORM & Spatial: Async `SQLAlchemy 2.0` + `asyncpg` + `GeoAlchemy2` + `Alembic` migrations.
  - Validation & Settings: `Pydantic v2` + `pydantic-settings`.
  - External Open Routing/Geocoding: `OSRM` (routing) + `Photon / Nominatim` (geocoding) + `OpenChargeMap` (seed data).
  - Testing & Linting: `pytest` + `ruff`.
- **Database & Infrastructure (`docker-compose.yml`):**
  - `postgis/postgis:16-3.4` (PostgreSQL 16 + PostGIS spatial indexing).

---

## 3. Mandatory Software Engineering Principles (Non-Negotiable)
1. **Module-by-Module Delivery (Build -> Test -> Verify):**
   - Never implement multiple modules at once. Build only the requested slice, write tests, run linters, and wait for user verification before moving to the next module.
2. **File Size Ceiling (150–400 Lines Target | 500 Lines Hard Max):**
   - No source file may exceed 500 lines. Keep files between 150 and 400 lines.
   - Proactively split screens, bottom sheets, modals, widgets, services, and repositories into separate, single-purpose files.
3. **The Big Three (DRY, KISS, YAGNI):**
   - **DRY:** Extract repeated UI patterns, validation, or SQL filters into reusable helpers/widgets.
   - **KISS:** Write straightforward, readable logic. Avoid over-abstracted meta-programming.
   - **YAGNI:** Only build what is required for the current module.
4. **SOLID & Separation of Concerns (SoC):**
   - **Flutter 3-Layer Feature Structure (`lib/features/<feature>/`):**
     - `presentation/` (Screens, Widgets, Riverpod Controllers — ZERO HTTP or SQL logic allowed here).
     - `domain/` (Immutable Freezed entities & repository interfaces).
     - `data/` (DTOs, Dio remote data sources, Drift local cache data sources, repository implementations).
   - **FastAPI 3-Layer Structure (`backend/app/`):**
     - `api/v1/` (Thin HTTP routers — request/response handling only).
     - `services/` (Pure business logic: route simulation, 5-vote consensus, spatial corridor math).
     - `repositories/` & `models/` (Database queries and PostGIS models).
5. **Coding Standards & Clean Code:**
   - **Python:** Strict PEP 8 (`snake_case` functions/vars, `PascalCase` classes, full type hints).
   - **Dart:** Strict Effective Dart (`camelCase` vars/methods, `PascalCase` types, `snake_case.dart` files).
   - Functions must do ONE thing well (15–40 lines max) with self-documenting names.

---

## 4. Verification Commands
- **Backend Lint & Format:** `cd backend && ruff check . && ruff format --check .`
- **Backend Tests:** `cd backend && pytest`
- **Frontend Analyze:** `cd app && flutter analyze`
- **Frontend Tests:** `cd app && flutter test`
