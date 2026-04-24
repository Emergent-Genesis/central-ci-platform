# Central CI Platform

A single **public** GitHub repository that hosts all GitHub Actions workflows and reusable composite actions for multiple private projects. Running workflows in a public repo gives unlimited free Actions minutes.

---

## Repository Layout

```
central-ci-platform/
├── .github/
│   ├── actions/
│   │   ├── ngrok-tunnel/        — composite: start ngrok, output public URL
│   │   └── ollama/              — composite: pull Ollama from GHCR, start container
│   └── workflows/
│       ├── finance-os-*.yml     — Finance OS scheduled + manual workflows
│       ├── build-ollama-image.yml
│       ├── comfyui-docker.yml
│       ├── run-comfyui.yml
│       └── run-comfyui-old.yml
└── docker/
    └── ollama-mistral/          — Dockerfile: Ollama + mistral:7b-instruct pre-baked
```

---

## Composite Actions

Reusable building blocks called from workflows via `uses: ./.github/actions/<name>`.

### `ngrok-tunnel`

Installs ngrok, authenticates, starts an HTTP tunnel, and outputs the public URL.

| Input | Required | Description |
|---|---|---|
| `port` | yes | Local port to expose |
| `ngrok_token` | yes | ngrok auth token |

| Output | Description |
|---|---|
| `ngrok_url` | Public HTTPS URL |

### `ollama`

Logs in to GHCR, pulls the pre-baked Ollama Docker image, starts it as a local container, and waits for the API to be ready.

| Input | Default | Description |
|---|---|---|
| `model_profile` | `mistral-7b` | Must match an image built via `build-ollama-image.yml` |
| `port` | `11434` | Port to expose the Ollama API on |

| Output | Description |
|---|---|
| `ollama_url` | Base URL, e.g. `http://localhost:11434` |

> Ollama and the calling Python script run on the same Actions runner — no ngrok tunnel needed.

---

## Finance OS Workflows

All Finance OS logic runs here. The private `finance-os` repo has **no workflows**.

### Scheduled (cron + manual)

| Workflow | Cron (IST) | What it does |
|---|---|---|
| `finance-os-daily-cache.yml` | 06:00 AM daily | Refreshes market data — stocks, MF NAV, gold/silver, macro rates |
| `finance-os-monthly-analysis.yml` | 08:00 PM on 1st | Full portfolio refresh → math scoring → Ollama AI analysis → Firestore |
| `finance-os-monthly-report.yml` | 07:00 AM on 1st | Gemini-generated PDF report → writes to data repo |
| `finance-os-firestore-cleanup.yml` | 00:30 AM on 1st | Deletes Firestore documents past their 6-month TTL |

### Manual (`workflow_dispatch`)

| Workflow | Input | What it does |
|---|---|---|
| `finance-os-deploy-live.yml` | `branch` | Builds Next.js static export → deploys to Firebase live channel |
| `finance-os-deploy-preview.yml` | `branch` | Builds Next.js static export → deploys Firebase preview URL |
| `finance-os-backup-sync.yml` | `branch` | Mirrors finance-os repo to backup repo |

### One-time setup

| Workflow | Input | What it does |
|---|---|---|
| `build-ollama-image.yml` | `model` (choice) | Builds Ollama + model Docker image → pushes to GHCR. Run once, then update when the model changes. |

**Ollama startup flow:** `build-ollama-image.yml` bakes the model weights into the image at build time. The monthly analysis workflow calls the `ollama` composite action to pull (~30 s) and start the container — no model download at runtime.

---

## ComfyUI Workflows

| Workflow | Trigger | What it does |
|---|---|---|
| `comfyui-docker.yml` | Manual — `model_profile` | Builds ComfyUI Docker image for the selected profile → pushes to GHCR |
| `run-comfyui.yml` | Manual — `model_profile`, `session_duration_hours` | Pulls GHCR image → starts ComfyUI → exposes via ngrok tunnel |

**Profiles:** `basic`, `fhdr`, `video-model`

Run `comfyui-docker.yml` once per profile before using `run-comfyui.yml`.

---

## Required Secrets

Set these in **Settings → Secrets → Actions** of this repo.

### Finance OS

| Secret | Description |
|---|---|
| `TOKEN_GITHUB` | PAT with `repo` scope — checks out private repos and used as `REPO_ACCESS_TOKEN` by Python |
| `PRIVATE_REPO_PATH` | `owner/finance-os` |
| `BACKUP_REPO_PATH` | `owner/finance-os-backup` |
| `GEMINI_API_KEY` | Google AI Studio key |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Base64-encoded Firebase service account JSON |
| `NEXT_PUBLIC_API_URL` | Render.com backend URL |
| `NEXT_PUBLIC_FIREBASE_API_KEY` | Firebase Web API Key |
| `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN` | e.g. `your-project.firebaseapp.com` |
| `NEXT_PUBLIC_FIREBASE_PROJECT_ID` | Firebase project ID |
| `NEXT_PUBLIC_FIREBASE_APP_ID` | Firebase App ID |

### ComfyUI

| Secret | Description |
|---|---|
| `PRIVATE_REPO_PAT` | PAT for `comfyui-source-private` repo |

### Shared

| Secret | Description |
|---|---|
| `NGROK_AUTH_TOKEN` | ngrok auth token — used by ComfyUI and any workflow that uses the `ngrok-tunnel` action |
| `GITHUB_TOKEN` | Auto-injected by GitHub Actions — used for GHCR login (no setup needed) |

---

## Adding a New Project

1. Add the project's workflow files under `.github/workflows/` (prefix with the project name, e.g. `myproject-*.yml`)
2. Add any required secrets to this repo's Actions secrets
3. If the project needs a Docker image, add a Dockerfile under `docker/<image-name>/` and a build workflow
4. If the project needs Ollama, call `uses: ./.github/actions/ollama` — no extra setup required
