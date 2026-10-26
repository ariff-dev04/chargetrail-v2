# ChargeTrail v2 — Living SDLC Progress Tracker

> **Agent Rule:** Both the Web Orchestrator Agent and Local Gemini CLI must read this file to determine current project state, and update this file whenever a module passes verification.

## 📊 Current Project State
- **Last Completed Gate:** `Module 2 — Authentication, User Profiles & Saved Station Bookmarks` ✅
- **Current Active Target:** `Module 3 — Community Contributions & Survei Mikro Consensus Engine (Backend + Flutter)` ⏳
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
  - `backend/app/services/station_service.py` & `station_seed_data.py`: Haversine distance calculator, 404 enforcement, and realistic 6-station Malaysian dataset (KLCC, IOI City Mall, Sunway Pyramid, Tapah RSA, Mid Valley Southkey, Gurney Plaza).
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

### [x] Module 2: Authentication, User Profiles & Saved Station Bookmarks (COMPLETED)
- **Status:** Verified (17/17 `pytest` passed in 2.35s, 0 `ruff` warnings, 13/13 `flutter test` passed, 0 `flutter analyze` issues, all files 80–330 lines).
- **Delivered Artifacts (`KF01`, `KF02`, `KF08`):**
  - `backend/app/core/security.py`: Salted PBKDF2-HMAC-SHA256 password hashing/verification, signed JWT token issuance/decoding, and `get_current_user` HTTPBearer dependency.
  - `backend/app/models/user.py`: SQLAlchemy 2.0 `User` and `SavedStation` entities with cascading relationships, preferred connector field, and uniqueness constraints.
  - `backend/app/schemas/user.py`: Pydantic v2 schemas (`UserRegister`, `UserLogin`, `UserProfileUpdate`, `UserProfileRead`, `TokenResponse`, `BookmarkToggleResponse`) with regex email validation.
  - `backend/app/repositories/user_repository.py`: Async user CRUD, case-insensitive email lookup, bookmark toggling, and saved stations relational queries.
  - `backend/app/services/auth_service.py`: Registration with conflict checks, login validation, profile management, and bookmark toggling.
  - `backend/app/services/station_seed_data.py`: Extracted Malaysian dataset seeder to enforce strict file modularity (<350 lines).
  - `backend/app/api/v1/auth.py` & `router.py`: REST endpoints `/auth/register`, `/auth/login`, `/users/me`, `/users/me/bookmarks/{id}`, `/users/me/bookmarks`.
  - `backend/tests/test_auth.py`: 4 comprehensive test suites verifying registration, duplicate email rejection (409), authentication failures (401), profile edits, and bookmark toggle lifecycle.
  - `frontend/lib/features/auth/domain/user_model.dart`: Immutable `UserProfile` model with JSON roundtrip and bookmark query helpers.
  - `frontend/lib/features/auth/data/auth_repository.dart`: Dio authentication repository with offline local demo session failover in SharedPreferences.
  - `frontend/lib/features/auth/presentation/auth_controller.dart`: Riverpod `AuthNotifier` managing session restoration, login/register, demo login, profile updates, and bookmark toggling.
  - `frontend/lib/features/auth/presentation/profile_screen.dart`: Complete profile screen with Sign In/Register toggle, demo driver shortcut, profile details card, connector choice chips, and saved station bookmarks list.
  - `frontend/lib/features/stations/presentation/widgets/station_detail_sheet.dart`: Added interactive bookmark button wired to `authControllerProvider`.
  - `frontend/lib/main.dart`: Integrated `ProfileScreen` as the 3rd destination in the `NavigationBar`.
  - `frontend/test/auth_profile_test.dart`: Unit and widget tests for models, auth notifier, and profile screen.

### [ ] Module 3: Community Contributions & `Survei Mikro` Consensus Engine (NEXT UP)
- **Scope (`KF06`, `KF07`, `KF09`):** Add hidden station, propose field edits, report charger issues, and 5-vote server-enforced consensus engine.

### [ ] Module 4: Live Charging Session, Queue Timer & Verified Reviews
- **Scope (`KF12`, `KF13`):** 4 live actions (*Charging*, *Finish*, *Could Not Charge*, *Waiting*), local countdown timer, visit-verified reviews, and gamification stats.

### [ ] Module 5: Battery-Aware Route Planner (`OSRM` + `PostGIS Corridor`)
- **Scope (`KF10`, `KF11`):** Backend OSRM polyline fetch + PostGIS `ST_DWithin` corridor query + 3 stop strategies + Flutter route timeline & charger swapping.

### [ ] Module 6: CI/CD Pipeline, Observability & Deployment Readiness
- **Scope:** GitHub Actions (`ruff`, `pytest`, `flutter analyze`, `flutter test`, Flutter Web build) + structured logging & Docker Compose production profile.
