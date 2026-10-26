# ChargeTrail v2 — Live User Acceptance Testing (UAT) Guide

This guide enables one-click visual verification of **Module 1A, Module 1B, and Module 2** on real devices, emulators, or web before moving to Module 3.

---

## 🚀 One-Click Launch

Open PowerShell in the project root:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_uat.ps1
```
*The launcher automatically boots FastAPI in the background (port 8000), seeds the 6 Malaysian EV stations, resolves host IPs, and starts Flutter.*

---

## 📱 Device Testing Options

### Option A: Android Studio Virtual Device (AVD)
1. Start your Android Emulator in Android Studio (e.g., Pixel 8 API 34).
2. Run `powershell -ExecutionPolicy Bypass -File scripts/run_uat.ps1`.
3. **Auto-resolution:** Connects to `http://10.0.2.2:8000` automatically.

### Option B: Physical Android Phone via Wi-Fi (Wireless Debugging)
1. Ensure PC and Phone are on the **same Wi-Fi network**.
2. Enable Developer Options -> **Wireless Debugging** -> `adb connect <phone_ip>:<port>`.
3. Run `powershell -ExecutionPolicy Bypass -File scripts/run_uat.ps1`.
4. **Auto-resolution:** Connects to your PC's Wi-Fi IPv4 (e.g., `http://192.168.1.x:8000`).

### Option C: Chrome Web or Windows Desktop
```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_uat.ps1 -Device chrome
# or:
powershell -ExecutionPolicy Bypass -File scripts/run_uat.ps1 -Device windows
```

---

## 📋 Human UAT Verification Checklist

### Feature Set 1: Map Discovery, Filters & Access Guide (Modules 1A & 1B)
- [ ] **OSM Pure Dart Map:** Map renders cleanly centered on Kuala Lumpur (`3.1578, 101.7118`) without paid Google SDKs.
- [ ] **Speed-Coded Markers:** Ultra-fast stations (≥120kW, e.g., Suria KLCC, Tapah RSA) show orange lightning pins; standard chargers show teal pins.
- [ ] **Horizontal Filter Bar:**
  - Tap `120kW+ Fast`: Map isolates high-speed chargers and updates counter pill.
  - Tap `CHAdeMO`: Isolates Mid Valley Southkey JB imported bay.
  - Tap `Reset`: Restores all 6 verified Malaysian stations.
- [ ] **Hidden Mall Charger Guide (`KF05`):**
  - Tap **Suria KLCC Gentari Charging Hub**.
  - Modal sheet opens: verify **"Basement B1, Pillar B12"** badge and numbered step-by-step directions (*Enter via Jalan Ampang ramp -> Follow green EV Hub markings*).

### Feature Set 2: Authentication, Profile & Bookmarks (Module 2)
- [ ] **Navigation Shell:** Tap 3rd bottom navigation tab: **"Profile & Saved"**.
- [ ] **Instant Demo Login:** Tap **"⚡ Continue as Malaysian Demo Driver"**. Profile instantly hydrates with Ahmad Faiz demo session.
- [ ] **Connector Preferences:** Tap `CHAdeMO` or `Type 2` choice chips — badge immediately updates.
- [ ] **Interactive Bookmark (`KF08`):**
  1. Switch back to **Explore** map tab.
  2. Tap **Sunway Pyramid chargEV Station**.
  3. In top-right of sheet, tap the bookmark icon (icon turns active teal).
  4. Return to **Profile & Saved** tab: verify Sunway Pyramid appears in **Saved Stations** list.
  5. Tap Sunway Pyramid in the saved list: re-opens the station detail sheet seamlessly.
