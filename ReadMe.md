# Central CI Platform

A centralised GitHub Actions hub for building, signing, and deploying multi-platform apps (web, Android, iOS) to Firebase, plus on-demand interactive sessions for ComfyUI and n8n.

---

## About

This repository contains no application code. It is a collection of reusable composite actions and workflow files that other private project repositories consume. A single workflow dispatch triggers checkout, build, sign, and deploy across web, Android, and iOS targets — all coordinated from one place.

**Smart framework detection:** Build commands are automatically selected based on each project's `package.json`, supporting Next.js, Angular, React/Vite, and other frameworks without manual configuration.

Supported projects are registered in `prepare-deployment.yml`. Each project maps to a GitHub Environment of the same name, isolating its secrets from other projects.

---

## Secrets & Variables

### Repository-level secrets

Set these under **Settings → Secrets and variables → Actions → Repository secrets**.

| Secret | What it is | Where to get it |
|--------|------------|-----------------|
| `GH_TOKEN` | Personal Access Token used to checkout private project repos | GitHub → **Settings → Developer settings → Personal access tokens (classic)** → generate with `repo` scope and `read:packages` |
| `NGROK_AUTH_TOKEN` | Auth token for ngrok tunnels (ComfyUI, n8n sessions) | [dashboard.ngrok.com](https://dashboard.ngrok.com) → **Your Authtoken** |
| `CLOUDFLARE_API_TOKEN` | Deploys web builds to Cloudflare Pages (default web provider) | Cloudflare dashboard → **My Profile → API Tokens** → create with the "Edit Cloudflare Pages" template |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account the Pages project lives in | Cloudflare dashboard → right sidebar of any domain, or **Workers & Pages** overview page |

---

### Environment-level secrets

Create one GitHub Environment per project (`astroaugur`, `finance-os`, `family-tree`) under **Settings → Environments**, then add the secrets below to each.

#### Firebase — service account JSON + app ID secrets

`FIREBASE_SERVICE_ACCOUNT` is a JSON blob containing service account credentials plus web app configuration. **App IDs for Android and iOS are passed as separate secrets**, not in the JSON.

Build the JSON like this:

1. Firebase console → **Project Settings → Service accounts** → **Generate new private key** — download the JSON
2. Firebase console → **Project Settings → Your apps → (Web app)** → copy the config fields
3. Merge into one object:

```jsonc
{
  // From the downloaded service account JSON (all standard IAM fields)
  "type": "service_account",
  "project_id": "my-project-12345",
  "private_key_id": "...",
  "private_key": "-----BEGIN RSA PRIVATE KEY-----\n...",
  "client_email": "firebase-adminsdk-xxx@my-project-12345.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",

  // Add manually from Firebase console → Project Settings → Your apps → (Web app) → Config
  "web_api_key":              "AIzaSy...",
  "web_app_id":               "1:123:web:abc",
  "web_messaging_sender_id":  "123456789",
  "web_storage_bucket":       "my-project-12345.appspot.com"
}
```

The service account must have the **Firebase App Distribution Admin** role (Firebase console → Project Settings → Service accounts, or Google Cloud IAM).

> `auth_domain` is derived automatically as `{project_id}.firebaseapp.com` — no need to store it.

#### All environment secrets

| Secret | Used by | Where to get it |
|--------|---------|-----------------|
| `FIREBASE_SERVICE_ACCOUNT` | Web, Android, iOS | See above |
| `FIREBASE_ANDROID_APP_ID` | Android | Firebase console → **Project Settings → Your apps → (Android app) → App ID** (format: `1:NNN:android:xxx`) |
| `FIREBASE_IOS_APP_ID` | iOS | Firebase console → **Project Settings → Your apps → (iOS app) → App ID** (format: `1:NNN:ios:xxx`) |
| `FIREBASE_MEASUREMENT_ID` | Android, iOS | Firebase console → **Project Settings → Your apps → (Web app) → Measurement ID** (format: `G-XXXXXXXXXX`) |
| `API_URL` | Android, iOS | Your backend — e.g. `https://api.myapp.com` |
| `ADMIN_CODE` | Web (family-tree only) | Arbitrary string you define |
| `ANDROID_SIGNING_KEY_BASE64` | Android | Run `scripts/generate-android-keystore.sh` — output printed at end |
| `ANDROID_KEY_ALIAS` | Android | Same script output |
| `ANDROID_KEYSTORE_PASSWORD` | Android | Same script output |
| `ANDROID_KEY_PASSWORD` | Android | Same script output |
| `IOS_P12_BASE64` | iOS | Run `scripts/generate-ios-certs.sh p12 …` — output printed at end |
| `IOS_P12_PASSWORD` | iOS | Same script output |
| `IOS_CODE_SIGN_IDENTITY` | iOS | Keychain Access → find the imported certificate → copy the full string, e.g. `Apple Distribution: Your Name (ABCDE12345)` |
| `IOS_PROVISIONING_PROFILE` | iOS | Apple Developer → **Profiles** → download `.mobileprovision` → use the exact profile name |

> **Android signing is optional for personal/testing use.** When none of the `ANDROID_*` secrets are set the build action auto-generates a self-signed keystore. For production builds, generate a persistent one with `scripts/generate-android-keystore.sh`.

> **iOS signing requires an Apple Developer account.** Use `scripts/generate-ios-certs.sh` to generate the CSR and .p12; follow Apple's certificate portal to get the signed distribution certificate.

---

## Workflows & Required Secrets

### `multi-project-deploy.yml` (main workflow)

Dispatches a build and deploy to web, Android, iOS, or all targets. Requires **environment secrets** from one of the project environments (`astroaugur`, `finance-os`, `family-tree`, `personal-3d-portfolio`).

**Inputs:**
- `project` (required) — which project to deploy: `astroaugur`, `finance-os`, `family-tree`, or `personal-3d-portfolio`
- `deploy` (required) — which target(s): `web`, `android`, `ios`, or `all`
- `deploy_channel` (optional) — Hosting channel: `preview` or `production` (default: `production`)
- `deploy_provider` (optional) — web hosting target: `cloudflare` or `firebase` (default: `cloudflare`). Only used when `deploy` is `web` or `all`.
- `web_output_directory` (optional) — build output directory, relative to the project root, that gets uploaded to Cloudflare Pages, e.g. `dist`, `build`, `out` (default: `dist`). Not used for Firebase.
- `tester_groups` (optional) — comma-separated Firebase App Distribution tester groups (default: `qa-team`)

**Required secrets (all from the project environment, unless noted):**
- `FIREBASE_SERVICE_ACCOUNT` (required unless deploying web-only with `deploy_provider: cloudflare`; still required for android/ios)
- `FIREBASE_ANDROID_APP_ID` (if deploying android or all)
- `FIREBASE_IOS_APP_ID` (if deploying ios or all)
- `FIREBASE_MEASUREMENT_ID` (if deploying android or ios)
- `API_URL` (if deploying android or ios)
- `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` (repository-level; required if deploying web with `deploy_provider: cloudflare`, the default)
- `GH_TOKEN` (repository-level or environment-level)
- Android signing secrets if deploying android (optional — auto-generated if absent)
- iOS signing secrets if deploying ios (required)
- `ADMIN_CODE` (if project is family-tree and deploying web)

**Cloudflare Pages project naming:** the Cloudflare Pages project name is expected to match the `project` input exactly (e.g. project `astroaugur` deploys to a Cloudflare Pages project named `astroaugur`). Create the Pages project with that name beforehand.

**Note:** `personal-3d-portfolio` only supports **web** deployment. Other projects support `web`, `android`, `ios`, or `all`.

---

### `version-bump-release.yml`

Bumps version, tags, and pushes to a project repo.

**Inputs:**
- `project` (required) — `astroaugur` or `finance-os`
- `bump_type` (optional) — `major`, `minor`, `patch`, or `build` (default: `patch`)

**Required secrets:**
- `GH_TOKEN` (repository-level)

---

### `run-comfyui.yml`

Spawns a ComfyUI session with ngrok tunnel.

**Inputs:**
- `model_profile` (optional) — `basic`, `fhdr`, or `video-model` (default: `basic`)
- `image_tag` (optional) — ComfyUI Docker image tag (default: latest)
- `session_duration_hours` (required) — `1`, `2`, `3`, `4`, `5`, or `6`

**Required secrets:**
- `NGROK_AUTH_TOKEN` (repository-level)

---

### `run-n8n.yml`

Spawns an n8n session with ngrok tunnel and basic auth.

**Inputs:**
- `session_duration_hours` (required) — `1`, `2`, `3`, `4`, `5`, or `6`

**Required secrets:**
- `N8N_BASIC_AUTH_USER` (environment-level, any environment)
- `N8N_BASIC_AUTH_PASSWORD` (environment-level, any environment)
- `NGROK_AUTH_TOKEN` (repository-level)

---

### `build-comfyui-image.yml`

Builds and pushes ComfyUI Docker image to GHCR.

**Inputs:**
- `model_profile` (required) — `basic` or `video-model`

**Required secrets:**
- `PRIVATE_REPO_PAT` (repository-level) — GitHub PAT with access to `Emergent-Genesis/comfyui-source-private`

---

### `build-ollama-image.yml`

Builds and pushes Ollama Docker image to GHCR.

**Inputs:**
- `model` (required) — `mistral-7b` (only option currently)

**Required secrets:**
- None (uses built-in `GITHUB_TOKEN`)

---

### `content-analytics.yml`

Runs content analytics against a YouTube channel.

**Inputs:**
- `sessions` (optional) — number of sessions (default: `5`)
- `headless` (optional) — run headless (default: `true`)

**Required secrets:**
- `GH_TOKEN` (repository-level)
- `VIDEO_BASE_URL` (repository-level) — base URL for video content

---

### `bbt-web.yml`

Checks out `bug-bounty-analyzer`, starts its FastAPI web interface, and exposes it via a Cloudflare `trycloudflare.com` tunnel for the duration of the session.

**Inputs:**
- `duration_hours` (required) — `1`, `2`, `3`, `4`, `5`, or `6`

**Required secrets:**
- `GH_TOKEN` (repository-level) — to checkout the private `bug-bounty-analyzer` repo

**Note:** No ngrok token needed — uses Cloudflare's anonymous quick tunnels. Scan results (`results/`) are uploaded as a workflow artifact when the session ends.

---

### `bbt-scan.yml`

Checks out `bug-bounty-analyzer` and runs a one-shot CLI security scan against a target URL, uploading the report as a workflow artifact.

**Inputs:**
- `target_url` (required) — e.g. `https://example.com`
- `profile` (optional) — `fast`, `balanced`, or `thorough` (default: `balanced`)
- `formats` (optional) — comma-separated output formats, e.g. `html,json` (default: `html,json`)
- `auth_header` (optional) — auth header for authenticated scans
- `auth_cookie` (optional) — session cookie for authenticated scans

**Required secrets:**
- `GH_TOKEN` (repository-level) — to checkout the private `bug-bounty-analyzer` repo
