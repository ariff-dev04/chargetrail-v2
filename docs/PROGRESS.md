# ChargeTrail v2 — Living SDLC Progress Tracker

> **Agent Rule:** Both the Web Orchestrator Agent and Local Gemini CLI must read this file to determine current project state, and update this file whenever a module passes verification.

## 📊 Current Project State
- **Last Completed Gate:** `Module 5 — Backend Route Planner, OSRM Polyline & Range Anxiety Engine` ✅
- **Current Active Target:** `Module 6 — Flutter Route Planner UI, Interactive Polyline & Final Thesis Hardening` ⏳
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

### [x] Module 3: Community Contributions, Admin Moderation & Survei Mikro Consensus Engine (COMPLETED)
- **Status:** Verified (20/20 `pytest` passed in 3.78s, 0 `ruff` warnings, 17/17 `flutter test` passed, 0 `flutter analyze` issues, all files 80–335 lines).
- **Delivered Artifacts (`KF06`, `KF07`, `KF09`, `KF16`):**
  - `backend/app/models/community.py`: SQLAlchemy 2.0 `StationReview` and `MicroSurveyVote` models for check-in reviews and 1-tap telemetry dimensions.
  - `backend/app/schemas/community.py`: Pydantic v2 schemas (`ReviewCreate`, `ReviewRead`, `MicroSurveyCreate`, `MicroSurveyConsensusRead`, `StationModerationUpdate`).
  - `backend/app/repositories/community_repository.py`: Async community station creation with `is_verified=False`, moderation queue queries, review rating recomputations, and micro-survey vote tallies.
  - `backend/app/services/community_service.py`: 3-vote consensus engine evaluating plug status (`out_of_order` triggers `is_available = False`), parking fee (`free` triggers `parking_fee_myr = 0.0`), and access difficulty.
  - `backend/app/api/v1/community.py` & `router.py`: REST endpoints `/community/stations`, `/community/stations/pending`, `/community/stations/{id}/moderate`, `/community/stations/{id}/reviews`, and `/community/stations/{id}/micro-survey`.
  - `backend/tests/test_community.py`: Comprehensive tests for station submission and approval, review rating recalculation, and 3-vote consensus auto-updates.
  - `frontend/lib/features/community/domain/community_models.dart`: Immutable `StationReview` and `MicroSurveyConsensus` models with summary badge text logic.
  - `frontend/lib/features/community/data/community_repository.dart`: Dio client with SharedPreferences offline failover for offline review and consensus testing.
  - `frontend/lib/features/community/presentation/community_controller.dart`: Riverpod `CommunityNotifier` managing reviews, votes, pending stations, and moderation actions.
  - `frontend/lib/features/community/presentation/widgets/micro_survey_card.dart`: Embedded widget in `StationDetailSheet` with 1-tap voting chips, consensus badge, and check-in review form.
  - `frontend/lib/features/community/presentation/submit_station_sheet.dart`: 2-tab modal sheet for Submit Charger (`KF06`) and Admin Moderation Queue (`KF09`) with 1-tap Approve & Publish.
  - `frontend/lib/features/stations/presentation/map_discovery_screen.dart`: Added `+ Add Charger` floating action button opening the submission sheet.
  - `frontend/test/community_survey_test.dart`: 4 comprehensive tests for consensus models, micro survey card, and submission sheet.

### [x] Module 4: EV Vehicle Profiles & Garage Management (COMPLETED)
- **Status:** Verified (24/24 `pytest` passed in 4.04s, 0 `ruff` warnings, 22/22 `flutter test` passed, 0 `flutter analyze` issues, all files 80–335 lines).
- **Delivered Artifacts (`KF11`, `KF12`):**
  - `backend/app/models/vehicle.py`: SQLAlchemy 2.0 `VehicleProfile` model supporting battery capacity, range, consumption rate, peak DC charge speed, reserve SoC buffer, and primary EV selection.
  - `backend/app/schemas/vehicle.py`: Pydantic v2 schemas (`VehiclePresetRead`, `VehicleCreate`, `VehicleUpdate`, `VehicleRead`) with computed effective safe range.
  - `backend/app/services/vehicle_presets.py`: Curated factory specifications for 6 popular Malaysian EVs (`Proton e.MAS 7 Prime`, `BYD Atto 3 Extended Range`, `Tesla Model 3 Long Range`, `BYD Dolphin`, `Hyundai IONIQ 5`, `Nissan Leaf e+`).
  - `backend/app/repositories/vehicle_repository.py`: Multi-vehicle garage operations, automatic single-primary enforcement, and deletion with primary auto-promotion.
  - `backend/app/services/vehicle_service.py`: Business logic for garage profiles, reserve buffer range math, and presets catalog.
  - `backend/app/api/v1/vehicles.py` & `router.py`: REST endpoints `/vehicles/presets`, `/vehicles`, `/vehicles/{id}`, `/vehicles/{id}/select`, and `/vehicles/{id}` (delete).
  - `backend/tests/test_vehicles.py`: Async tests verifying preset catalog retrieval, primary EV toggling, reserve SoC effective range calculation, and deletion.
  - `frontend/lib/features/vehicles/domain/vehicle_model.dart`: Immutable `VehicleProfile` model with physics methods for range at SoC, safe usable range after reserve buffer, and 20%->80% charge duration estimation.
  - `frontend/lib/features/vehicles/data/vehicle_repository.dart`: Dio client with SharedPreferences offline cache pre-seeded with Malaysian presets and default garage.
  - `frontend/lib/features/vehicles/presentation/vehicle_controller.dart`: Riverpod `VehicleNotifier` managing multi-car garage, active EV selection, and SoC slider.
  - `frontend/lib/features/vehicles/presentation/garage_screen.dart`: Complete garage screen with active vehicle hero card, battery SoC slider (10%-100%), real-time safe range telemetry, garage vehicles list, and 1-tap Malaysian preset addition sheet.
  - `frontend/lib/features/stations/presentation/widgets/station_detail_sheet.dart`: Integrated real-time active EV charging estimate badge (`Est. 20%->80% for <Active EV>: ~XX mins`).
  - `frontend/lib/main.dart`: Wired `GarageScreen` as the 3rd destination (`EV Garage`) in the app shell `NavigationBar`.
  - `frontend/test/vehicle_garage_test.dart`: 4 comprehensive unit and widget tests for physics math, controller state, and garage UI.

### [x] Module 5: Backend Route Planner, OSRM Polyline & Range Anxiety Engine (COMPLETED)
- **Status:** Verified (28/28 `pytest` passed in 12.56s, 0 `ruff` warnings, 22/22 `flutter test` passed, 0 `flutter analyze` issues, all files 50–325 lines).
- **Delivered Artifacts (`KF10`, `KF13`, `KF14`, `KF15`):**
  - `backend/app/schemas/routing.py`: Pydantic v2 schemas (`LatLngPoint`, `PlaceSuggestion`, `RoutePlanRequest`, `ChargingStopRecommendation`, `RoutePlanResponse`).
  - `backend/app/services/geocoding_service.py`: Malaysian place geocoder curated with 13 major transit hubs and landmarks (KLCC, IOI City Mall, Sunway Pyramid, Tapah RSA, Gurney Plaza, Southkey JB, etc.) with Photon fallback.
  - `backend/app/services/osrm_client.py`: Highway routing client producing realistic multi-point North-South PLUS Expressway polylines with node interpolation, detour distances, and drive times.
  - `backend/app/services/route_planner_service.py`: Physics-aware trip simulator:
    - Dynamic vehicle spec overrides from garage `vehicle_id`.
    - Total energy expenditure and uncharged arrival SoC calculation (`KF14`).
    - Range anxiety classification: `"safe"`, `"warning"`, and `"critical_charging_required"`.
    - Spatial corridor filtering and stop optimizer (`KF15`) recommending reachable highway chargers (e.g. Tapah RSA) and computing charge minutes, costs, and safe final arrival battery.
  - `backend/app/api/v1/routing.py` & `router.py`: REST endpoints `GET /api/v1/routing/places` and `POST /api/v1/routing/plan`.
  - `backend/tests/test_routing.py`: 4 comprehensive test suites covering place search, short safe urban route, long highway trip requiring charging at Tapah RSA, and garage vehicle overrides.

### [ ] Module 6: Flutter Route Planner UI, Interactive Polyline & Final Thesis Hardening (NEXT UP)
- **Scope (`KF10`, `KF13`, `KF14`, `KF15`):** Interactive Route Planner screen in `frontend/` with origin/destination search inputs, battery SoC starting slider, polyline overlay on `flutter_map`, route timeline cards with charging stops, and charger replacement sheet.

### [ ] Module 7: CI/CD Pipeline, Observability & Deployment Readiness
- **Scope:** GitHub Actions (`ruff`, `pytest`, `flutter analyze`, `flutter test`, Flutter Web build) + structured logging & Docker Compose production profile.
