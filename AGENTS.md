# AGENTS.md - Inkbird ITC-308 Telemetry Server (Ruby on Rails)

## Project Overview
This project is a Ruby on Rails 8 web application and JSON ingestion server that receives, stores, and visualizes temperature telemetry from an **Inkbird ITC-308 Wi-Fi smart thermostat** ("cottage ITC-308").

Because the thermostat operates behind an Android Wi-Fi Hotspot with AP isolation, a dedicated Android bridge app polls the thermostat locally over Tuya v3.3 TCP (every ~60 seconds) and forwards normalized JSON payloads via HTTP `POST` over cellular to this Rails server.

---

## Architecture & Tech Stack
* **Framework:** Ruby on Rails 8.x (Full-stack with Hotwire / Turbo / Stimulus)
* **Styling:** Tailwind CSS (`tailwindcss-rails`)
* **Database:** SQLite3 (Rails 8 production-ready defaults with WAL mode enabled; single-file persistence)
* **Charts:** Chartkick + Chart.js (via `importmap-rails`) + `groupdate` for time-series aggregation
* **Authentication:**
  * **Ingestion API (`POST /api/v1/telemetry`):** Bearer token verified via `ActiveSupport::SecurityUtils.secure_compare` against `ENV["INGEST_BEARER_TOKEN"]`.
  * **Web Dashboard (`GET /`):** Public / read-only (no login required).
* **Testing:** Rails default Minitest (`bin/rails test`)

---

## Deployment & Hosting Notes
* **Domain:** `https://inkbird.squall.ca` (via Cloudflare Tunnel `squall-ingress` for WAN and Nginx Proxy Manager `192.168.10.251` + AdGuard split-horizon DNS for LAN).
* **Host:** Squall Lab Proxmox (`192.168.10.250`) → `ubuntu-docker` LXC (`192.168.10.251`, CTID `105`).
* **Orchestration:** Portainer GitOps (`https://portainer.squall.ca`) deploying [docker-compose.yml](file:///Users/charles/projects/inkbird-server/docker-compose.yml) (container name `inkbird`, network `proxy_network`, internal Thruster HTTP port `80`, healthcheck `GET /up`).
* **Persistent Volume:** `/srv/inkbird/storage:/rails/storage` owned by `1000:1000` on LXC NVMe rootfs.
* **Environment Variables (Portainer Stack):**
  * `RAILS_MASTER_KEY`
  * `INGEST_BEARER_TOKEN`
  * `SOLID_QUEUE_IN_PUMA=true`
  * `RAILS_MAX_THREADS=3`
* **Backups:** 3-2-1 backup via `/etc/cron.d/inkbird-backup` on `ubuntu-docker` (02:30 online SQLite `.backup`, 02:45 `rsync` to `/media/backups/inkbird/`) and weekly Sunday 05:00 `rclone` offsite sync on the Proxmox host.

---

## Upstream JSON Payload Contract (From Android Bridge)
The Android `WebhookUploader` sends an `HTTP POST` request with `Content-Type: application/json; charset=utf-8` and header `Authorization: Bearer <token>`.

### Example Request Body
```json
{
  "device_id": "02720007bcddc234ce20",
  "timestamp_utc": "2026-10-29T16:15:00Z",
  "unit": "C",
  "current_temp_c": 29.0,
  "current_temp_f": 84.2,
  "target_temp_c": 8.0,
  "relay_state": "cooling",
  "compressor_delay_min": 3,
  "high_alarm_limit": 35.0,
  "low_alarm_limit": 0.0,
  "alarms": {
    "111": false,
    "112": false,
    "113": false
  },
  "raw_dps": {
    "101": "C",
    "104": 290,
    "106": 80,
    "108": 3,
    "109": 350,
    "110": 0,
    "111": false,
    "112": false,
    "113": false,
    "115": "1",
    "116": 842
  }
}
```

### Field Notes
* `device_id` (String, required): Tuya hardware ID (default cottage device: `02720007bcddc234ce20`).
* `timestamp_utc` (ISO-8601 String, required): UTC timestamp when the thermostat was polled.
* `unit` (String): `"C"` or `"F"`, default `"C"`.
* `current_temp_c` / `current_temp_f` (Float, nullable): Measured temperature in Celsius and Fahrenheit.
* `target_temp_c` (Float, nullable): Thermostat setpoint (stored in DB for completeness, **not** plotted on the UI chart).
* `relay_state` (String): `"cooling"`, `"heating"`, `"idle"`, or `"unknown"`.
* `compressor_delay_min` (Integer, nullable), `high_alarm_limit` (Float, nullable), `low_alarm_limit` (Float, nullable).
* `alarms` (JSON Object): Map of Tuya alarm DP keys (`"111"`, `"112"`, `"113"`) to boolean flags.
* `raw_dps` (JSON Object): Raw unscaled Tuya data points returned by the thermostat.
* **Retry Behavior:** The Android client retries once after 1.5s on network/HTTP failure. The ingestion endpoint should handle duplicate `(device_id, timestamp_utc)` submissions gracefully (either idempotently returning `200 OK` / `201 Created` without duplicating rows).

---

## Database Schema

### 1. `devices` Table
Tracks known thermostats and caches their latest state for fast dashboard lookups.
* `tuya_device_id` (`string`, `null: false`, unique index) — maps to payload `device_id`
* `name` (`string`, default: `"Cottage ITC-308"`)
* `last_seen_at` (`datetime`, indexed) — updated on every ingested reading (`[last_seen_at, recorded_at].compact.max`)
* `last_temp_c` (`float`)
* `last_temp_f` (`float`)
* `last_unit` (`string`, default: `"C"`)
* `last_relay_state` (`string`)
* `timestamps`

### 2. `telemetry_readings` Table
Stores the historical time-series data.
* `device_id` (`references :device`, `null: false`, foreign key)
* `recorded_at` (`datetime`, `null: false`) — parsed from `timestamp_utc`
* `unit` (`string`, `null: false`, default: `"C"`)
* `current_temp_c` (`float`)
* `current_temp_f` (`float`)
* `target_temp_c` (`float`)
* `relay_state` (`string`, default: `"unknown"`)
* `compressor_delay_min` (`integer`)
* `high_alarm_limit` (`float`)
* `low_alarm_limit` (`float`)
* `alarms` (`json`, default: `{}`)
* `raw_dps` (`json`, default: `{}`)
* `timestamps`

**Indexes on `telemetry_readings`:**
* Composite unique index on `[:device_id, :recorded_at]` (prevents duplicate rows on Android client retries and speeds up time-range queries).
* Index on `:recorded_at`.

---

## Core Functional Requirements

### 1. Ingestion Endpoint (`POST /api/v1/telemetry`)
* Inherit from `ActionController::API` (or skip CSRF verification for JSON API requests).
* **Authentication:** Extract the Bearer token via `authenticate_or_request_with_http_token` and compare against `ENV["INGEST_BEARER_TOKEN"]` using `ActiveSupport::SecurityUtils.secure_compare`. Return `401 Unauthorized` if missing or invalid, or `500` if `INGEST_BEARER_TOKEN` is not configured.
* **Persistence:**
  1. Find or create `Device` by `tuya_device_id: params[:device_id]`.
  2. Upsert or find-or-create the `TelemetryReading` for `(device, recorded_at)` so retries are idempotent.
  3. Update the parent `Device` attributes (`last_seen_at`, `last_temp_c`, `last_temp_f`, `last_unit`, `last_relay_state`).
* **Response:** Return `201 Created` (or `200 OK` if already recorded) with `{ "status": "ok", "reading_id": reading.id }`, or `422 Unprocessable Entity` with validation errors if required fields (`device_id`, `timestamp_utc`) are missing/invalid.

### 2. Web Dashboard (`GET /`)
* Public read-only view showing telemetry for the primary device (or a device selector if multiple exist).
* **Header / Status Summary:**
  * Displays current temperature prominently (`last_temp_c` / `last_temp_f`), `last_seen_at` relative time (e.g., "2 minutes ago"), and an **Online / Stale** badge (e.g., Online if `last_seen_at` within the last 5 minutes, Offline/Stale otherwise).
* **Interactive Time-Series Chart:**
  * Renders a single line chart for **Current Temperature** (`current_temp_c`) over time.
  * **Important:** Do **not** plot `target_temp_c` (Target Setpoint) on the chart, as that function on the thermostat is not used.
  * Provide time-range filter controls:
    * `24h` (last 24 hours, raw or 5-minute buckets)
    * `7d` (last 7 days, hourly average/min/max or hourly buckets)
    * `30d` (last 30 days, hourly or daily buckets)
