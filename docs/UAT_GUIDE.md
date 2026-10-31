# ChargeTrail v2 â€” End-to-End Live User Acceptance Testing (UAT) Guide

This guide provides a comprehensive visual testing checklist for evaluating ChargeTrail v2 on real physical devices (e.g., Samsung Galaxy via Wireless Debugging), Android emulators, and Chrome/Windows desktop across all 4 navigation tabs and thesis requirements (`KF01` through `KF16`).

---

## ðŸš€ 1. One-Click Automated Launch

Run the following command from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_uat.ps1
```

### What this script does automatically:
1. Detects host IPv4 address on your local Wi-Fi network.
2. Spawns the FastAPI backend server on `http://0.0.0.0:8000`.
3. Seeds all 12 verified Peninsular Malaysia charging hubs via `POST /api/v1/stations/seed-sample`.
4. Scans for connected physical devices (`Android-Device`), Android AVD emulators, or web browsers.
5. Injects `--dart-define=API_BASE_URL=http://<YOUR_IP>:8000` and launches the Flutter application.

> **Wi-Fi Firewall Note:** If running on a physical Android phone over Wi-Fi and the app shows `Offline Mode`, open PowerShell as Administrator and run:
> ```powershell
> New-NetFirewallRule -DisplayName "ChargeTrail API 8000" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
> ```
> Then tap **"Offline Mode â€¢ Tap to Reconnect"** on the top banner in the app.

---

## ðŸ“± 2. Interactive Feature Verification Checklists

### Checklist 1: Map Discovery, 12 Malaysian Hubs, Map Switcher & GPS (Tabs: Explore Map)
- [ ] **Street / Satellite / Dark Layer Switcher:** Tap the map layer button on the bottom right. Switch to **Satellite** (Esri World Imagery) and **Dark** (CartoDB Dark Matter). Verify tiles load cleanly with **zero console warnings**.
- [ ] **My Location GPS Marker:** Tap the `My Location` FAB. Verify camera animates to your coordinates at zoom 14.5, a SnackBar shows `Located GPS: 3.1343, 101.6865`, and a blue pulsing radar marker appears.
- [ ] **Filter Chips:** Tap `120kW+ Fast`, `24 Hours`, `CHAdeMO`, or `Dining`. Verify station pins immediately filter on the map and the counter badge updates (e.g. `6 stations`). Tap `Reset`.
- [ ] **Underground Mall Access Guide:** Tap `Suria KLCC Gentari Charging Hub` pin. Verify the sheet displays `Basement B1, Pillar B12`, tariff (RM 1.50/kWh), and the step-by-step parking ramp photos/instructions.

### Checklist 2: Community Submissions, Moderation Queue & Survei Mikro
- [ ] **Submit New Charger (`KF06`):** Tap `+ Add` on the map. Fill in station name, select `CCS2`, and tap `Submit Charger for Review`. Verify confirmation SnackBar.
- [ ] **Admin Moderation Queue (`KF09`):** In the same sheet, switch to the `Moderation Queue` tab. Tap `Approve & Publish` on the submitted station. Verify it appears live on the map.
- [ ] **Survei Mikro 1-Tap Consensus (`KF16`):** Open any station sheet. In the `Survei Mikro` card, tap `All Working` and `Free Parking`. Verify the badge updates to `Consensus: Verified Working`.
- [ ] **Check-In Review (`KF07`):** In the station sheet, select 5 stars, choose wait time (`0-5 mins`), enter a comment (`"Fast charging at 175kW!"`), and tap `Post Review`. Verify rating re-computes.

### Checklist 3: EV Garage & Malaysian EV Catalog (Tabs: EV Garage)
- [ ] **Battery SoC% Slider (`KF12`):** Switch to `EV Garage`. Drag the battery slider from `10%` to `100%`. Verify `Total Usable Range` and `Safe Route Range` update in real time.
- [ ] **Malaysian EV Catalog (`KF11`):** Tap `+ Add Vehicle`. Choose `Proton e.MAS 7 Prime`, `BYD Atto 3`, or `Tesla Model 3 Long Range`. Verify specs auto-populate and save to your garage.
- [ ] **Active EV Selection:** Tap `Select Active Vehicle`. Switch back to `Explore Map` and open any station detail sheet; verify the badge displays: `Est. 20%->80% for <Active EV>: ~XX mins`.

### Checklist 4: Battery-Aware Route Planner & Range Anxiety (Tabs: Route Planner)
- [ ] **Safe Urban Route (`KF14`):** Switch to `Route Planner`. Tap preset `KL -> Putrajaya (Safe)` with 80% SoC. Verify green `SAFE RANGE` banner, 0 charging stops, and direct arrival battery > 65%.
- [ ] **Interstate Long Route with Charging Stop (`KF15`):** Tap preset `KL -> Penang (Needs Stop)` with 55% SoC. Verify:
  1. Crimson `CRITICAL â€¢ HIGHWAY CHARGING STOP MANDATORY` banner appears.
  2. Blue/teal highway polyline renders along the North-South PLUS Expressway.
  3. Recommends **Stop 1: Shell Recharge Tapah RSA Northbound** (+152 km, arrive 20% -> charge to 80%, ~22 mins, RM 54.00).
  4. Final arrival battery at Penang is safely above 20%.
  5. Tapping the recommended stop opens the station details and access guide.

### Checklist 5: Driver Authentication, Profiles & Bookmarks (Tabs: Profile & Saved)
- [ ] **1-Tap Demo Driver Login (`KF01`):** Switch to `Profile & Saved`. Tap `âš¡ Continue as Malaysian Demo Driver`. Verify instant authentication and driver badge.
- [ ] **Preferred Connector Setting (`KF02`):** Select `CCS2` or `Type 2` under preferred connectors. Verify preference is saved.
- [ ] **Bookmark Favorite Station (`KF08`):** Open any station sheet on the map and tap the bookmark heart icon. Return to `Profile & Saved` and verify the station appears in `Saved Stations`.
- [ ] **Sign Out:** Tap `Sign Out`. Verify app cleanly resets to guest mode with local cache intact.


