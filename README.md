# ChargeTrail v2 â€” Open-Source EV Charging Discovery, Crowdsourced Consensus & Physics-Aware Highway Route Planner

[![Flutter](https://img.shields.io/badge/Flutter-3.x%20(Android%20%7C%20iOS%20%7C%20Web)-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-Python%203.12-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![SQLAlchemy](https://img.shields.io/badge/SQLAlchemy-2.0%20%2B%20PostGIS%20%2F%20aiosqlite-D71F00?logo=sqlalchemy&logoColor=white)](https://www.sqlalchemy.org)
[![Routing](https://img.shields.io/badge/Routing-Project%20OSRM%20%2B%20Keep--Left%20Scorer-4A90E2)](https://project-osrm.org)
[![Tests](https://img.shields.io/badge/Tests-90%2F90%20Passing%20(48%20Pytest%20%2B%2042%20Flutter)-success)](.github/workflows/ci.yml)
[![Commercial API Cost](https://img.shields.io/badge/Commercial%20API%20Cost-%240%2Fmonth%20(100%25%20Open--Source)-brightgreen)](#5-quantitative-engineering-benchmark-legacy-v1-vs-chargetrail-v2)

**ChargeTrail v2** is a ground-up Clean Architecture reconstruction of an academic Final Year Project (Universiti Kebangsaan Malaysia â€” UKM). It completely eliminates recurring commercial API dependencies (Google Maps JavaScript SDK, Google Places API, Directions API) and proprietary cloud lock-in (Firebase/Cloud Firestore) in favor of a **$0/month, 100% open-source geospatial stack** tailored specifically for Peninsular Malaysia's expressway network (PLUS E1/E2, Karak E8, LPT, SKVE).

Engineered to solve the real-world EV charging dilemma across Southeast Asia, ChargeTrail v2 combines live OpenStreetMap data harvesting, Malaysia keep-left directional expressway cross-track scoring, brand-aware Tesla Supercharger highway exit affinity, and server-validated crowdsourced governance into a unified, high-performance platform.

---

## 1. Mobile UI Showcase (Android Physical Device Live Hardware UAT)

Validated on physical hardware (**Android Physical Device**, Android 17, 120Hz Dynamic AMOLED) via ADB reverse tunneling against a local FastAPI asynchronous instance:

| Explore Map & Operator Pins | Station Details & Consensus | ABRP Unified Route Planner | EV Garage & Telemetry |
| :---: | :---: | :---: | :---: |
| <img src="docs/screenshots/01_explore_map.png" width="210" alt="Explore Map & Brand Pins"/><br/><sub>**IP-Safe Operator Pins**<br/>`TSLA`, `GTR`, `JOM`, `CEV`, `SHL`<br/>+ Live OSM Harvester</sub> | <img src="docs/screenshots/02_station_details.png" width="210" alt="Station Details & Survei Mikro"/><br/><sub>**Station Details & Access**<br/>Access Badges<br/>`Suggest Edit` + 3-Vote Consensus</sub> | <img src="docs/screenshots/03_route_planner.png" width="210" alt="ABRP Unified Route Planner"/><br/><sub>**ABRP Bottom-Sheet Planner**<br/>3 Stop Strategies, R-A-G Slider<br/>& Duration Callout Pins</sub> | <img src="docs/screenshots/04_ev_garage.png" width="210" alt="EV Garage & Taper Telemetry"/><br/><sub>**Malaysian EV Catalog**<br/>Proton e.MAS 7, BYD Seal/Atto 3<br/>Tesla Model 3/Y & Taper Curves</sub> |

---

## 2. System Architecture & Geospatial Data Pipeline

```mermaid
flowchart TB
    subgraph Frontend["Flutter Cross-Platform Client (Android / iOS / Web)"]
        UI_Map["Explore Map & IP-Safe Brand Pins"]
        UI_Route["ABRP Unified Bottom-Sheet Route Planner"]
        UI_Consensus["Community Consensus UI (Survei Mikro)"]
        UI_Garage["EV Garage & Profile (Malaysian Catalog)"]
        State["Riverpod State Layer + Offline SharedPreferences Cache"]
        
        UI_Map --> State
        UI_Route --> State
        UI_Consensus --> State
        UI_Garage --> State
    end

    subgraph Backend["FastAPI Async Microservice (Python 3.12)"]
        API["REST API + /metrics Observability"]
        Harvester["Dual-Source IPv4 OSM Harvester Service"]
        Scorer["Malaysia Keep-Left Directional R&R Scorer"]
        Governance["Dual-Path Governance Engine"]
        DB[("SQLite (aiosqlite) / PostGIS Spatial Store")]
        
        API --> Harvester
        API --> Scorer
        API --> Governance
        Harvester --> DB
        Governance --> DB
        Scorer --> DB
    end

    subgraph Providers["$0 Open-Data Geospatial Providers (IPv4)"]
        OSM["Nominatim + Photon Komoot API"]
        OSRM["Project OSRM Routing Engine"]
        DeepLinks["Google Maps / Waze 6-Decimal Deep-Links"]
    end

    State <-->|"REST / JSON (Sub-350ms)"| API
    Harvester <-->|"Forced IPv4 BBox Sweep"| OSM
    UI_Route <-->|"Polyline Road Geometry"| OSRM
    UI_Route -.->|"Turn-by-Turn Navigation"| DeepLinks
```

---

## 3. Core Engineering Innovations & Mathematical Formulations

### 3.1 Dual-Source IPv4 OpenStreetMap Harvester (`0.2sâ€“1.0s` Latency)
Commercial geospatial APIs impose steep per-query billing and proprietary constraints. ChargeTrail v2 implements an asynchronous, dual-source harvester:
- **IPv4 Transport Bypassing ISP Blackholes:** Many Southeast Asian consumer ISPs misroute IPv6 traffic to European open-data mirrors, leading to 30-second connection timeouts. The harvester forces IPv4 socket binding via `httpx.AsyncHTTPTransport(local_address="0.0.0.0")`.
- **Parallel Bounding-Box Harvesting:** Interrogates Nominatim (`viewbox` with `bounded=1` and `extratags=1`) and Photon Komoot (`osm_value == 'charging_station'`) simultaneously using `asyncio.gather()`.
- **On-Interaction Upsert Pipeline:** Stations discovered dynamically on the client map viewport are automatically normalized and upserted into the central SQLite/PostGIS database via `POST /api/v1/stations/upsert-external`, making user exploration self-enriching for the entire community.

### 3.2 Malaysia Keep-Left Directional Highway R&R Scorer (`directional_highway_scorer.py`)
A major failure mode of naive EV corridor planners on expressways (e.g., PLUS Highway E1/E2, Karak E8) is recommending an R&R charging station situated on the **opposite carriageway**, separated by a physical concrete divider with no exit for up to 30 km.

```
Carriageway Travel Vector (sx, sy) â”€â”€â–º
â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• [Impassable Center Divider]
      Station Vector (dx, dy)
         â–²
         â”‚   Cross-Product: cp = dx * sy - dy * sx
         â””â”€â–º Left Carriageway (cp > 0): Bonus (-3.0) âœ…
         â””â”€â–º Right Carriageway (cp < 0, dist > 80m): Penalty (+15.0) âŒ
```

1. **Polyline Segment Geodetic Bearing:**
   For any coordinate step $(lat_1, lon_1) \to (lat_2, lon_2)$, calculate forward bearing $\theta$:
   $$\theta = \text{atan2}\left(\sin(\Delta lon)\cos(lat_2), \cos(lat_1)\sin(lat_2) - \sin(lat_1)\cos(lat_2)\cos(\Delta lon)\right)$$
2. **Equirectangular 2D Cross-Track Vector Math:**
   Project the segment direction vector $\vec{s} = (sx, sy)$ and station offset vector $\vec{d} = (dx, dy)$:
   $$dx = (lon_{st} - lon_1) \cdot \cos\left(\frac{lat_1 + lat_2}{2}\right), \quad dy = lat_{st} - lat_1$$
   $$cp = dx \cdot sy - dy \cdot sx$$
   In Malaysia's **Keep-Left** traffic system:
   - $cp > 0$: Station lies to the **driver's left** (same carriageway) $\to$ rewarded with a **$-3.0$ score reduction**.
   - $cp < 0$ with lateral offset $> 80\text{m}$: Station lies across the impassable divider on the opposite carriageway $\to$ penalised with **$+15.0$ detour penalty**.
3. **Bilingual Directional Token Hard-Exclusion:**
   Prevents opposite-direction stops using exact-word regex matching for dual-language highway nomenclature:
   - Northbound: `Northbound`, `NB`, `Arah Utara`, `Utara`
   - Southbound: `Southbound`, `SB`, `Arah Selatan`, `Selatan`
   - Eastbound / Westbound: `Eastbound`, `Timur` vs. `Westbound`, `Barat`
   - Sanitizes general highway names like *Lebuhraya Utara-Selatan* to prevent false positive exclusions.

### 3.3 Brand-Aware Tesla Supercharger Highway-Exit Affinity & Access Scoring
High-speed charging networks in Malaysia feature dedicated hubs (e.g., Tesla V3/V4 250 kW Superchargers) situated in commercial retail parks adjacent to expressway toll exits (e.g., Gamuda Cove, Sunway Pyramid, Freeport A'Famosa, Gurney Plaza):
- **Corridor Expansion:** When a Tesla vehicle preset is active, the search corridor dynamically expands from $5.0\text{ km}$ to $12.0\text{ km}$ from the highway polyline.
- **Brand Affinity Bonus:** Tesla Superchargers receive an affinity bonus of **$-5.0$** in ranking calculations.
- **Carpark Barrier Exemption:** While generic destination chargers inside multistory parking lots incur a time penalty, high-power Superchargers are exempted, correctly prioritizing rapid highway top-ups.

### 3.4 Server-Enforced Crowdsourced Governance (`Survei Mikro` & `Suggest an Edit`)
Legacy community charging apps suffer from vandalized or stale data because writes bypass validation or depend on slow manual administrative reviews:
- **Dual-Path Mutation:** Drivers can submit corrections (`operator_name`, `max_power_kw`, `price_per_kwh`, `parking_level`, `access_notes`) via `Suggest an Edit`.
- **Survei Mikro Consensus:** Edits trigger an in-app community verification card (`3-Vote Survei Mikro`). When a proposal attains `votes_for >= 3` with `votes_for > votes_against`, the FastAPI service automatically mutates the live station record with ACID guarantees.
- **Admin Fast-Track Queue:** High-impact additions or contested edits can be audited and instantly approved via authenticated administrative endpoints.

---

## 4. Quantitative Engineering Benchmark (Legacy v1 vs. ChargeTrail v2)

| Metric | Legacy v1 (Academic FYP) | ChargeTrail v2 (Production Architecture) | Improvement |
| :--- | :--- | :--- | :--- |
| **Monthly Commercial API Cost** | $150 â€“ $400 / month (Google Maps / Firestore) | **$0.00 / month (100% Open-Source Geospatial Stack)** | **100% Cost Elimination ($0/mo)** |
| **Route Planning Latency** | 20 â€“ 45 seconds (50+ client HTTP queries) | **< 350 ms (Single OSRM call + vectorized corridor pass)** | **~98% Faster Response** |
| **Spatial Query Complexity** | $O(N)$ unindexed client-side radius filtering | **$O(\log N)$ Spatial Index (BBox / PostGIS / R-Tree)** | **Scalable to 100,000+ stations** |
| **Expressway Side Awareness** | None (Blind euclidean radius) | **Keep-Left 2D Cross-Track Scorer + Bilingual Token Filter** | **Zero opposite-carriageway traps** |
| **Max File Size & Modularity** | 3,341 lines in monolithic files | **< 500 lines per file (Enforced by CI ceiling)** | **Maintainable Clean Architecture** |
| **Security & Authorization** | Client-side consensus & hardcoded keys | **PBKDF2-HMAC Password Hashing + JWT + Server ACID Consensus** | **Production DevSecOps Standards** |
| **Automated Test Suite** | 0 tests (Legacy broken harness) | **90 / 90 Tests Passing (48 Pytest + 42 Flutter Tests)** | **100% Quality Gate Coverage** |

---

## 5. Repository Structure

```
chargetrail-v2/
â”œâ”€â”€ backend/
â”‚   â”œâ”€â”€ app/
â”‚   â”‚   â”œâ”€â”€ api/v1/          # FastAPI routers (auth, stations, routing, vehicles, reviews)
â”‚   â”‚   â”œâ”€â”€ core/            # App configuration, security (JWT/PBKDF2), logging
â”‚   â”‚   â”œâ”€â”€ db/              # Async database session & engine (SQLite / PostGIS)
â”‚   â”‚   â”œâ”€â”€ models/          # SQLAlchemy ORM declarative models
â”‚   â”‚   â”œâ”€â”€ schemas/         # Pydantic v2 validation contracts
â”‚   â”‚   â””â”€â”€ services/        # OSRM router, OSM harvester, directional highway scorer
â”‚   â”œâ”€â”€ tests/               # 48 pytest test cases (100% pass)
â”‚   â”œâ”€â”€ requirements.txt
â”‚   â””â”€â”€ chargetrail_local.db # Local persistent geospatial SQLite database
â”œâ”€â”€ frontend/
â”‚   â”œâ”€â”€ lib/
â”‚   â”‚   â”œâ”€â”€ data/            # Repositories, REST API client (Dio), local cache
â”‚   â”‚   â”œâ”€â”€ domain/          # Pure Dart domain entities & value objects
â”‚   â”‚   â””â”€â”€ presentation/    # Riverpod providers, screens (Map, Planner, Garage, Profile)
â”‚   â”œâ”€â”€ test/                # 42 Flutter unit, provider, and widget tests (100% pass)
â”‚   â””â”€â”€ pubspec.yaml
â”œâ”€â”€ docs/
â”‚   â”œâ”€â”€ screenshots/         # Verified hardware UAT captures
â”‚   â”œâ”€â”€ PROGRESS.md          # Compacted living SDLC milestone tracker
â”‚   â””â”€â”€ UAT_GUIDE.md         # Hardware UAT test run protocol
â”œâ”€â”€ scripts/
â”‚   â”œâ”€â”€ run_uat.ps1          # Automated ADB reverse tunnel & physical test runner
â”‚   â””â”€â”€ view_db.ps1          # CLI inspection script for local stations & consensus votes
â””â”€â”€ .github/workflows/
    â””â”€â”€ ci.yml               # GitHub Actions CI pipeline (Ruff, Pytest, Flutter Analyze & Test)
```

---

## 6. Quick Start & DevSecOps Quality Gates

### Prerequisites
- **Python 3.12+**
- **Flutter 3.22+**
- **Android SDK** with platform tools (`adb`) for physical device testing

### 6.1 Backend Setup (FastAPI)
```powershell
# Navigate to backend and create virtual environment
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1

# Install dependencies and launch async development server
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 6.2 Frontend Setup (Flutter)
```powershell
# Navigate to frontend and install dependencies
cd frontend
flutter pub get

# Launch on connected device or Chrome web
flutter run -d chrome
```

### 6.3 Real-Device Hardware UAT (Android via ADB Reverse)
To test on a physical Android device without encountering Windows Firewall barriers:
```powershell
# Establish ADB reverse proxy tunnel
adb reverse tcp:8000 tcp:8000

# Launch automated live UAT runner
powershell -ExecutionPolicy Bypass -File scripts/run_uat.ps1 -Device "<YOUR_DEVICE_ID>"

# Inspect local database anytime
powershell -ExecutionPolicy Bypass -File scripts/view_db.ps1
```

### 6.4 Automated Verification Gates (CI/CD Baseline)
Every commit to `main` executes the following automated pipeline:

```powershell
# 1. Backend Linting & Formatting Check
ruff check backend/
ruff format --check backend/

# 2. Backend Automated Test Suite
pytest backend/tests/ -q

# 3. Frontend Static Analysis (Zero Warnings/Errors)
cd frontend
flutter analyze

# 4. Frontend Automated Test Suite
flutter test --no-pub

# 5. Production Web Release Build
flutter build web --release
```

---

## 7. License & Attribution

ChargeTrail v2 is open-source software licensed under the **MIT License**. Map tiles courtesy of **Esri World Street Map**, geocoding by **Nominatim & Photon Komoot**, and road network routing powered by **Project OSRM**. Geospatial data Â© [OpenStreetMap contributors](https://www.openstreetmap.org/copyright).


