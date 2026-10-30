# AGENTS.md - Inkbird ITC-308 Telemetry Server (Ruby on Rails)

## Project Overview
This project is a Ruby on Rails 8 web application and JSON ingestion server that receives, stores, and visualizes temperature telemetry and periodic daytime camera photos from an **Inkbird ITC-308 Wi-Fi smart thermostat** ("cottage ITC-308").

Because the thermostat operates behind an Android Wi-Fi Hotspot with AP isolation, a dedicated Android bridge app polls the thermostat locally over Tuya v3.3 TCP (every ~60 seconds) and forwards normalized JSON payloads and periodic camera snapshots via HTTP `POST` over cellular to this Rails server.

---

## Architecture & Tech Stack
* **Ruby Version Management (Local Dev):** Uses **`mise`** (`.ruby-version`). Always run Rails/Bundler commands via `mise exec --` (e.g., `mise exec -- bin/rails test`, `mise exec -- bin/rails db:migrate`).
* **Framework:** Ruby on Rails 8.x (Full-stack with Hotwire / Turbo / Stimulus)
* **Styling:** Tailwind CSS (`tailwindcss-rails`)
* **Database:** SQLite3 (Rails 8 production-ready defaults with WAL mode enabled; single-file persistence)
* **Photo Storage:** Local filesystem under `/rails/storage/photos/` (`storage/photos/<device_id>/<YYYY-MM-DD>/<timestamp>_<lens>.jpg`), indexed by `device_photos` in SQLite.
* **Charts:** Chartkick + Chart.js (via `importmap-rails`) + `groupdate` for time-series aggregation
* **Authentication:**
  * **Ingestion APIs (`POST /api/v1/telemetry`, `POST /api/v1/photos`):** Bearer token verified via `ActiveSupport::SecurityUtils.secure_compare` against `ENV["INGEST_BEARER_TOKEN"]`.
  * **Web Dashboard (`GET /`, `GET /photos/:id`):** Public / read-only (no login required).
* **Testing:** Rails default Minitest (`mise exec -- bin/rails test`)

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
* **Backups & Archiving:** 3-2-1 backup via `/etc/cron.d/inkbird-backup` on `ubuntu-docker` (02:30 online SQLite `.backup`, 02:45 `rsync` to `/media/backups/inkbird/`) and weekly Sunday 05:00 `rclone` offsite sync on the Proxmox host. Photos older than 30 days can be archived via `bin/rails photos:archive`.

---

## Upstream JSON Payload Contracts (From Android Bridge)
The Android `WebhookUploader` sends `HTTP POST` requests with `Content-Type: application/json; charset=utf-8` and header `Authorization: Bearer <token>`.

### 1. Temperature Telemetry (`POST /api/v1/telemetry`)
```json
{
  "device_id": "02720007bcddc234ce20",
  "timestamp_utc": "2026-10-29T16:15:00Z",
  "next_poll_utc": "2026-10-29T17:15:00Z",
  "next_photo_utc": "2026-10-29T18:15:00Z",
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

#### Telemetry Field Notes
* `device_id` (String, required): Tuya hardware ID (default cottage device: `02720007bcddc234ce20`).
* `timestamp_utc` (ISO-8601 String, required): UTC timestamp when the thermostat was polled.
* `next_poll_utc` (ISO-8601 String, optional / nullable): UTC timestamp when the Android gateway service is next scheduled to poll the thermostat.
* `next_photo_utc` (ISO-8601 String, optional / nullable): UTC timestamp when the Android gateway service is next scheduled to capture and upload a solar daytime photo.
* `unit` (String): `"C"` or `"F"`, default `"C"`.
* `current_temp_c` / `current_temp_f` (Float, nullable): Measured temperature in Celsius and Fahrenheit.
* `target_temp_c` (Float, nullable): Thermostat setpoint (stored in DB for completeness, **not** plotted on the UI chart).
* `relay_state` (String): `"cooling"`, `"heating"`, `"idle"`, or `"unknown"`.
* `compressor_delay_min` (Integer, nullable), `high_alarm_limit` (Float, nullable), `low_alarm_limit` (Float, nullable).
* `alarms` (JSON Object): Map of Tuya alarm DP keys (`"111"`, `"112"`, `"113"`) to boolean flags.
* `raw_dps` (JSON Object): Raw unscaled Tuya data points returned by the thermostat.
* **Retry Behavior:** The Android client retries once after 1.5s on network/HTTP failure. The ingestion endpoint handles duplicate `(device_id, timestamp_utc)` submissions idempotently (`200 OK` / `201 Created` without duplicating rows).

### 2. Periodic Daytime Photo Upload (`POST /api/v1/photos`)
```json
{
  "device_id": "02720007bcddc234ce20",
  "timestamp_utc": "2026-10-29T16:15:00Z",
  "next_photo_utc": "2026-10-29T18:15:00Z",
  "lens": "REAR_WIDE",
  "width": 1280,
  "height": 960,
  "current_temp_c": 29.0,
  "image_base64": "/9j/4AAQSkZJRgABAQAAAQABAAD..."
}
```

#### Photo Field Notes
* `device_id` (String, required): Tuya hardware ID.
* `timestamp_utc` (ISO-8601 String, required): UTC timestamp when the photo was captured.
* `next_photo_utc` (ISO-8601 String, optional / nullable): UTC timestamp when the Android gateway service is next scheduled to capture and upload a solar daytime photo.
* `lens` (String): Camera lens identifier, default `"REAR_WIDE"`.
* `width` / `height` (Integer, nullable): Image dimensions in pixels.
* `current_temp_c` (Float, nullable): Temperature in Celsius at capture time.
* `image_base64` (String, required): Base64-encoded JPEG binary (verified by JPEG magic bytes `\xFF\xD8\xFF`).

---

## Database Schema

### 1. `devices` Table
Tracks known thermostats and caches their latest state for fast dashboard lookups.
* `tuya_device_id` (`string`, `null: false`, unique index) — maps to payload `device_id`
* `name` (`string`, default: `"Cottage ITC-308"`)
* `last_seen_at` (`datetime`, indexed) — updated on every ingested reading (`[last_seen_at, recorded_at].compact.max`)
* `next_poll_at` (`datetime`, indexed) — expected time of next scheduled poll
* `next_photo_at` (`datetime`, indexed) — expected time of next scheduled photo capture
* `last_temp_c` (`float`)
* `last_temp_f` (`float`)
* `last_unit` (`string`, default: `"C"`)
* `last_relay_state` (`string`)
* `timestamps`

### 2. `telemetry_readings` Table
Stores the historical time-series data.
* `device_id` (`references :device`, `null: false`, foreign key)
* `recorded_at` (`datetime`, `null: false`) — parsed from `timestamp_utc`
* `next_poll_at` (`datetime`) — parsed from `next_poll_utc`
* `next_photo_at` (`datetime`) — parsed from `next_photo_utc`
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

### 3. `device_photos` Table
Stores metadata for periodic daytime JPEG snapshots saved under `/rails/storage/photos/`.
* `device_id` (`references :device`, `null: false`, foreign key)
* `recorded_at` (`datetime`, `null: false`) — parsed from `timestamp_utc`
* `next_photo_at` (`datetime`) — parsed from `next_photo_utc`
* `lens` (`string`, `null: false`, default: `"REAR_WIDE"`)
* `width` (`integer`)
* `height` (`integer`)
* `current_temp_c` (`float`)
* `file_path` (`string`, `null: false`) — relative path under `storage/photos/`
* `byte_size` (`integer`, `null: false`)
* `timestamps`

**Indexes on `device_photos`:**
* Composite unique index on `[:device_id, :recorded_at, :lens]`.
* Index on `:recorded_at`.

---

## Core Functional Requirements

### 1. Telemetry Ingestion Endpoint (`POST /api/v1/telemetry`)
* Inherit from `Api::V1::BaseController` (`ActionController::API`).
* **Authentication:** Extract the Bearer token via `authenticate_with_http_token` and compare against `ENV["INGEST_BEARER_TOKEN"]` using `ActiveSupport::SecurityUtils.secure_compare`. Return `401 Unauthorized` if missing or invalid, or `500` if `INGEST_BEARER_TOKEN` is not configured.
* **Persistence:**
  1. Find or create `Device` by `tuya_device_id: params[:device_id]`.
  2. Upsert or find-or-create the `TelemetryReading` for `(device, recorded_at)` so retries are idempotent.
  3. Update the parent `Device` attributes (`last_seen_at`, `last_temp_c`, `last_temp_f`, `last_unit`, `last_relay_state`).
* **Response:** Return `201 Created` (or `200 OK` if already recorded) with `{ "status": "ok", "reading_id": reading.id }`, or `422 Unprocessable Entity` with validation errors if required fields (`device_id`, `timestamp_utc`) are missing/invalid.

### 2. Photo Ingestion Endpoint (`POST /api/v1/photos`)
* Inherit from `Api::V1::BaseController` (`ActionController::API`) using the same Bearer token authentication.
* **Persistence:**
  1. Validate `device_id`, `timestamp_utc` (ISO-8601), and `image_base64` (valid Base64-encoded JPEG).
  2. Find or create `Device` by `tuya_device_id: params[:device_id]`.
  3. Write decoded JPEG bytes to `storage/photos/<device_id>/<YYYY-MM-DD>/<timestamp>_<lens>.jpg`.
  4. Upsert `DevicePhoto` for `(device, recorded_at, lens)` and update `device.last_seen_at`.
* **Response:** Return `201 Created` (or `200 OK` on retry) with `{ "status": "ok", "photo_id": photo.id }`, or `422 Unprocessable Entity` if invalid.

### 3. Web Dashboard (`GET /`) & Photo Serving (`GET /photos/:id`)
* Public read-only view showing telemetry and daytime photos for the primary device (or a device selector if multiple exist).
* **Header / Status Summary:**
  * Displays current temperature prominently (`last_temp_c` / `last_temp_f`), `last_seen_at` relative time (e.g., "2 minutes ago"), and an **Online / Stale** badge (e.g., Online if `last_seen_at` within the last 5 minutes, Offline/Stale otherwise).
* **Interactive Time-Series Chart:**
  * Renders a single line chart for **Current Temperature** (`current_temp_c`) over time.
  * **Important:** Do **not** plot `target_temp_c` (Target Setpoint) on the chart, as that function on the thermostat is not used.
  * Provide time-range filter controls: `24h`, `7d`, `30d`.
* **Latest Cottage Photo & Recent Captures:**
  * Displays the latest daytime photo with capture timestamp, lens, dimensions, and temperature badge, plus a strip of recent captures below.
