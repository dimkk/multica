# Self-Hosted Production Notes

Current production instance:

- app URL: `http://195.209.212.86:3000`
- API URL: `http://195.209.212.86:8080`
- server name: `multica-main-02`
- owner: `d-volkovsky@yandex.ru`

## Current deployment model

Production updates from `main` are currently **pull-based on the server**, not SSH-pushed from GitHub Actions.

The server was bootstrapped with:

- repo checkout in `/opt/multica`
- sync script: `/usr/local/bin/multica-sync.sh`
- timer: `multica-sync.timer`

Behavior:

1. changes land in `main`
2. the server polls `origin/main` every 2 minutes
3. if `HEAD` changed, it runs:

```bash
git reset --hard origin/main
docker compose -f docker-compose.selfhost.yml up -d --build --remove-orphans
```

This is the production update path in use today.

## GitHub workflow status

`.github/workflows/deploy-selfhost.yml` is kept as an **SSH fallback/manual workflow** for later use.

It is **not** the active production path right now, because inbound SSH to the running VM is not reliable enough for unattended GitHub Actions deploys.

## Production mode

`APP_ENV=production` is **not enabled yet on the live server**.

Reason:

- current access is plain HTTP by IP
- in production mode Multica sets `Secure` auth cookies
- with plain HTTP, browser login would stop working

Enable production mode only after the Yandex gateway / reverse proxy is in place and HTTPS is working.

Cutover checklist for later:

1. publish the app behind HTTPS
2. set `FRONTEND_ORIGIN`, `MULTICA_APP_URL`, `NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_WS_URL` to the final public URLs
3. configure `RESEND_*` for email auth
4. set `APP_ENV=production`
5. rebuild the stack

## Traefik + Let's Encrypt

For a real HTTPS edge, use the Traefik overlay instead of copying a manual certificate onto the VM.

Requirements:

- the public hostname must resolve to the VM IP
- ports `80` and `443` must be open
- use a hostname that actually points to the current prod VM

Today that means:

- `app.aiathome.ru` -> `195.209.212.86` is usable
- `aiathome.ru` is **not** usable yet because DNS still resolves to `195.209.214.122`

One-time setup on the server:

```bash
cd /opt/multica
cp deploy/selfhost.traefik.env.example .env.traefik
# edit PUBLIC_DOMAIN and LETSENCRYPT_EMAIL
docker compose -f docker-compose.selfhost.yml -f docker-compose.selfhost.traefik.yml --env-file .env --env-file .env.traefik up -d --build --remove-orphans
```

Recommended values for the current server:

```bash
PUBLIC_DOMAIN=app.aiathome.ru
LETSENCRYPT_EMAIL=d-volkovsky@yandex.ru
APP_ENV=production
FRONTEND_ORIGIN=https://app.aiathome.ru
MULTICA_APP_URL=https://app.aiathome.ru
MULTICA_SERVER_URL=wss://app.aiathome.ru/ws
LOCAL_UPLOAD_BASE_URL=https://app.aiathome.ru
ALLOWED_ORIGINS=https://app.aiathome.ru
CORS_ALLOWED_ORIGINS=https://app.aiathome.ru
```

Notes:

- the frontend can run behind the same host as the API; Traefik sends `/api`, `/auth`, `/ws`, `/health`, and `/uploads` to the backend and everything else to the frontend
- Let's Encrypt uses the HTTP challenge, so port `80` must stay reachable from the public internet
- after the HTTPS edge is live, point additional runtimes at `https://app.aiathome.ru` and `wss://app.aiathome.ru/ws`

## Add Another Runtime

Each additional runtime is installed on a separate machine and connects back to this server.

### macOS / Linux

Install prerequisites:

- `codex` on `PATH`
- `multica` CLI

CLI install:

```bash
brew tap multica-ai/tap
brew install multica
```

Point the CLI to this server:

```bash
multica config set app_url http://195.209.212.86:3000
multica config set server_url http://195.209.212.86:8080
```

Authenticate and register the runtime:

```bash
multica login
multica daemon start
```

Login details for the current non-production deployment:

- email: the operator's email
- verification code: `888888`

Verify:

```bash
multica daemon status
```

The runtime should appear in:

- `Settings -> Runtimes`

### Windows

There is no official Windows release artifact in this repo today.

Use one of these options:

1. run the runtime from WSL2 and follow the Linux steps
2. build `multica.exe` locally from source and then run the same `config set`, `login`, and `daemon start` commands

After the HTTPS cutover, use:

```bash
multica config set app_url https://app.aiathome.ru
multica config set server_url wss://app.aiathome.ru/ws
```

## Team Workflow

Current operating model:

1. developers open `http://195.209.212.86:3000`
2. create or join the workspace owned by `d-volkovsky@yandex.ru`
3. each machine that should execute agent work installs `codex` + `multica`
4. that machine runs `multica daemon start` and becomes a runtime
5. in the UI, create an agent and bind it to the runtime
6. create issues and assign them to the agent
7. the runtime daemon picks tasks up automatically
8. when code is merged to `main`, production updates automatically within about 2 minutes

## Notes

- current runtime owner was verified through the API: `d-volkovsky@yandex.ru` is already the workspace `owner`
- current production health check: `http://195.209.212.86:8080/health`
