# ChargeTrail v2 — Living SDLC Progress Tracker

> **Agent Rule:** Both the Web Orchestrator Agent and Local Gemini CLI must read this file to determine current project state, and update this file whenever a module passes verification.

## 📊 Current Project State
- **Last Completed Gate:** `Module 1B — Flutter App Shell, Offline Cache & OpenStreetMap Discovery` ✅
- **Current Active Target:** `Module 2 — Authentication, Community Moderation & Micro-Surveys (Backend + Flutter)` ⏳
- **Repository:** `https://github.com/ariff-dev04/chargetrail-v2.git` (`main` branch)

---

## 🗺️ Modular SDLC Roadmap & Status

### [x] Module 0: Workspace & Infrastructure Base (COMPLETED)
- **Status:** Verified & Pushed to `main` (4/4 `pytest` passed, 0 `ruff` warnings, all files < 100 lines).
- **Delivered Artifacts:**
  - Root `.gitignore`, `.env.example`, `docker-compose.yml` (`postgis/postgis:16-3.4`), `GEMINI.md`.
  - `backend/app/core/config.py`, `backend/app/core/database.py`.
  - `backend/app/api/v1/health.py`, `backend/app/api/v1/router.py`, `backend/app/main.py`.
  - `backend/tests/test_health.py`, `backend/tests/conftest.py`, `backend/ruff.toml`.

### [x] Module 1A: Backend Station Spatial Core, Filtering & Seeder (COMPLETED)
- **Status:** Verified (13/13 `pytest` passed in 0.98s, 0 `ruff` warnings, all files 64–372 lines).
- **Delivered Artifacts (`KF03`, `KF04`, `KF05`):**
  - `backend/app/models/station.py`: SQLAlchemy 2.0 `ChargingStation` entity with GeoAlchemy2 SRID 4326 Point, PostgreSQL GiST spatial index, graceful SQLite test compatibility, and Malaysian metadata (parking level, fee, 24h, verified status).
  - `backend/app/schemas/station.py`: Pydantic v2 schemas (`PlugInfo`, `AccessStep`, `StationBase`, `StationCreate`, `StationRead`, `StationFilterParams`, `SeedResponse`).
  - `backend/app/repositories/station_repository.py`: Viewport bounding box filter (`min_lat`, `min_lng`, `max_lat`, `max_lng`), radial envelope, technical/amenity filters, and idempotent seed batch upsert.
  - `backend/app/services/station_service.py`: Haversine distance calculator, 404 enforcement, and realistic 6-station Malaysian dataset (KLCC, IOI City Mall, Sunway Pyramid, Tapah RSA, Mid Valley Southkey, Gurney Plaza).
  - `backend/app/api/v1/stations.py` & `backend/app/api/v1/router.py`: REST endpoints `GET /api/v1/stations`, `GET /api/v1/stations/{id}`, `POST /api/v1/stations/seed-sample`.
  - `backend/tests/test_stations.py`: Comprehensive test suite verifying seeding idempotency, bounding box queries, proximity searches, connector/power/amenity/24h filters, access steps, and 404 handling.

### [x] Module 1B: Flutter App Shell, Offline Cache & OpenStreetMap Discovery (COMPLETED)
- **Status:** Verified (9/9 `flutter test` passed, 0 `flutter analyze` issues, all files < 350 lines).
- **Delivered Artifacts (`KF03`, `KF04`, `KF05`):**
  - `frontend/lib/core/theme/app_theme.dart`: Emerald/teal Material 3 eco-mobility light & dark themes.
  - `frontend/lib/features/stations/domain/station_model.dart`: Immutable `ChargingStation`, `PlugInfo`, `AccessStep`, and `StationFilter` domain models with JSON serialization and pure filter matching.
  - `frontend/lib/features/stations/data/station_local_cache.dart`: SharedPreferences async non-blocking offline cache with 6 realistic Malaysian baseline stations.
  - `frontend/lib/features/stations/data/station_repository.dart`: Dio repository fetching `/api/v1/stations` with automatic failover to offline cache.
  - `frontend/lib/features/stations/presentation/station_controller.dart`: Riverpod `StationNotifier` managing station search, multi-criterion filter toggles, selection, and offline mode.
  - `frontend/lib/features/stations/presentation/widgets/station_filter_bar.dart`: Modular search input and horizontal filter chips (`CCS2`, `Type 2`, `CHAdeMO`, `120kW+ Fast`, `24 Hours`, `Dining`, and `Reset`).
  - `frontend/lib/features/stations/presentation/widgets/station_detail_sheet.dart`: Modular bottom sheet displaying tariff card, parking level badge ("Basement B1, Pillar B12"), plug breakdown, and step-by-step "How to Access Charger" guide.
  - `frontend/lib/features/stations/presentation/map_discovery_screen.dart`: `flutter_map` OpenStreetMap discovery view with custom speed-coded pins, filter bar overlay, offline banner, and quick preview card.
  - `frontend/lib/main.dart`: Root `ChargeTrailApp` with `ProviderScope`, Material 3 theme, and 3-tab `AppShell`.
  - `frontend/test/stations_discovery_test.dart` & `frontend/test/widget_test.dart`: 9 comprehensive unit and widget tests covering models, filtering, cache, filter bar, detail sheet, and navigation shell.

### [ ] Module 2: Station Details UI, Filter Sheet & Step-by-Step Access Guide
- **Scope (`KF04`, `KF05`):** Modular detail screen, plug availability badges, parking level/fee cards, "How to Access" visual steps, and filter modal sheet.

### [ ] Module 3: Authentication & User/EV Garage Profile
- **Scope (`KF01`, `KF02`, `KF14`):** FastAPI JWT + Google OAuth2, user profile, vehicle battery/range specs, saved stations, and saved trips.

### [ ] Module 4: Community Contributions & `Survei Mikro` Consensus Engine
- **Scope (`KF06`, `KF07`, `KF08`, `KF09`):** Add hidden station, propose field edits, report charger issues, and 5-vote server-enforced consensus engine.

### [ ] Module 5: Live Charging Session, Queue Timer & Verified Reviews
- **Scope (`KF12`, `KF13`):** 4 live actions (*Charging*, *Finish*, *Could Not Charge*, *Waiting*), local countdown timer, visit-verified reviews, and gamification stats.

### [ ] Module 6: Battery-Aware Route Planner (`OSRM` + `PostGIS Corridor`)
- **Scope (`KF10`, `KF11`):** Backend OSRM polyline fetch + PostGIS `ST_DWithin` corridor query + 3 stop strategies + Flutter route timeline & charger swapping.

### [ ] Module 7: CI/CD Pipeline, Observability & Deployment Readiness
- **Scope:** GitHub Actions (`ruff`, `pytest`, `flutter analyze`, `flutter test`, Flutter Web build) + structured logging & Docker Compose production profile.
