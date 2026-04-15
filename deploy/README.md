# Self-Hosted Production Notes

Current production target:

- public URL: `https://app.aiathome.ru`
- current VM: `multica-main-03`
- current VM IP: `195.209.219.118`
- owner: `d-volkovsky@yandex.ru`

## Deployment Model

Production is updated from `main` by a pull-based sync on the VM.

Server-side components:

- repo checkout: `/opt/multica`
- sync script: `/usr/local/bin/multica-sync.sh`
- systemd timer: `multica-sync.timer`

Behavior:

1. changes land in `main`
2. the VM polls `origin/main` every 2 minutes
3. if `HEAD` changed, it runs:

```bash
git fetch origin main
git reset --hard origin/main
docker compose -f docker-compose.selfhost.yml -f docker-compose.selfhost.caddy.yml --env-file .env --env-file .env.caddy up -d --build --remove-orphans
```

This is the active production rollout path.

## GitHub Workflow

`.github/workflows/deploy-selfhost.yml` is kept as a manual SSH fallback.

It is not the active production path because inbound SSH on this cloud is unreliable. Use it only after SSH access to the VM is confirmed stable.

## HTTPS Edge

The recommended edge is `Caddy + Let's Encrypt + wstunnel`, not a static certificate and not the earlier Traefik label-based overlay.

Files:

- `docker-compose.selfhost.caddy.yml`
- `deploy/Caddyfile`
- `deploy/selfhost.caddy.env.example`

One-time server setup:

```bash
cd /opt/multica
cp deploy/selfhost.caddy.env.example .env.caddy
# edit PUBLIC_DOMAIN, LETSENCRYPT_EMAIL, and MASTER_LOGIN_CODE if desired
docker compose -f docker-compose.selfhost.yml -f docker-compose.selfhost.caddy.yml --env-file .env --env-file .env.caddy up -d --build --remove-orphans
```

Recommended `.env.caddy` values for the live host:

```bash
PUBLIC_DOMAIN=app.aiathome.ru
LETSENCRYPT_EMAIL=d-volkovsky@yandex.ru
APP_ENV=production
MASTER_LOGIN_CODE=
FRONTEND_ORIGIN=https://app.aiathome.ru
MULTICA_APP_URL=https://app.aiathome.ru
MULTICA_SERVER_URL=wss://app.aiathome.ru/ws
LOCAL_UPLOAD_BASE_URL=https://app.aiathome.ru
ALLOWED_ORIGINS=https://app.aiathome.ru
CORS_ALLOWED_ORIGINS=https://app.aiathome.ru
NEXT_PUBLIC_API_URL=
NEXT_PUBLIC_WS_URL=
```

Notes:

- Caddy terminates TLS for `app.aiathome.ru` and routes `/api`, `/auth`, `/health`, `/ws`, and `/uploads` to the backend
- Caddy also terminates TLS for `ssh.aiathome.ru` and proxies websocket upgrades to `wstunnel`
- `ssh.aiathome.ru` is reserved for the operator SSH-over-TLS tunnel when `wstunnel` is enabled
- everything else goes to the frontend
- leave `NEXT_PUBLIC_API_URL` and `NEXT_PUBLIC_WS_URL` empty so the browser stays same-origin under the current host
- Let's Encrypt uses the HTTP challenge, so port `80` must remain publicly reachable

## Production Login

With `APP_ENV=production`, the built-in `888888` dev code is disabled.

For self-hosted recovery, the backend now supports an optional `MASTER_LOGIN_CODE` env var:

- set `MASTER_LOGIN_CODE` in `.env.caddy` if you need operator login without external email delivery
- the user must still request `/auth/send-code` first for the same email
- then the configured master code can be entered in the UI

If you configure `RESEND_API_KEY`, normal email delivery works and `MASTER_LOGIN_CODE` can be left empty.

## Add Another Runtime

Each additional runtime is installed on a separate machine and connects back to `https://app.aiathome.ru`.

### macOS / Linux

Prerequisites:

- `codex` on `PATH`
- `multica` CLI

Install the CLI:

```bash
brew tap multica-ai/tap
brew install multica
```

Point the CLI at production:

```bash
multica config set app_url https://app.aiathome.ru
multica config set server_url wss://app.aiathome.ru/ws
```

Authenticate and register:

```bash
multica login
multica daemon start
multica daemon status
```

The runtime should appear in `Settings -> Runtimes`.

### Windows

Use one of these options:

1. run the runtime from WSL2 and follow the Linux steps
2. build `multica.exe` locally from source, then run the same `config set`, `login`, and `daemon start` commands

## Operator SSH Access

Because inbound raw SSH is unreliable on this cloud, operator access is exposed through `wstunnel` over the existing HTTPS endpoint.

Server-side:

- `Dockerfile.admin-ssh` builds a dedicated operator SSH container
- `docker-compose.selfhost.caddy.yml` starts `ghcr.io/erebe/wstunnel:latest`
- Caddy routes `ssh.aiathome.ru` to `wstunnel`
- `wstunnel` is restricted to `admin-ssh:2222`
- the SSH shell lands in the `admin-ssh` container with `/workspace` mounted from `/opt/multica`
- Docker socket is mounted, so `docker`, `docker compose`, and repo operations are available from that shell

Client-side requirements:

- `wstunnel` installed locally
- the same SSH private key you would normally use for `ubuntu@...`

Example OpenSSH config:

```sshconfig
Host multica-prod
  HostName 127.0.0.1
  Port 22
  User ubuntu
  IdentityFile ~/.ssh/multica-prod.pem
  ProxyCommand wstunnel client --log-lvl=off -L stdio://%h:%p wss://ssh.aiathome.ru
```

Then connect with:

```bash
ssh multica-prod
```

One-shot command without `~/.ssh/config`:

```bash
ssh -o "ProxyCommand=wstunnel client --log-lvl=off -L stdio://127.0.0.1:22 wss://ssh.aiathome.ru" -i /path/to/key.pem ubuntu@dummy
```

## Team Workflow

Operating model:

1. open `https://app.aiathome.ru`
2. log in as a workspace member of `d-volkovsky@yandex.ru`
3. each execution machine installs `codex` and `multica`
4. each execution machine runs `multica daemon start`
5. create agents in the UI and bind them to the available runtimes
6. create issues and assign them to the agents
7. runtime daemons execute the tasks automatically
8. updates merged to `main` reach production through the VM sync timer

## Notes

- `d-volkovsky@yandex.ru` is the verified workspace owner on the current production instance
- direct health check on the active VM remains `http://195.209.219.118:8080/health`
- `docker-compose.selfhost.traefik.yml` is left in the repo only as an experimental fallback overlay
