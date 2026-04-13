# Self-Hosted Server Deploy

This repository now includes an IP-based self-hosted deployment path for:

- host: `195.209.219.177`
- user: `ubuntu`
- app path: `/opt/multica`
- deploy trigger: every push to `main`

## First server bootstrap

Run on the server after SSH access is working:

```bash
cd /tmp
git clone https://github.com/dimkk/multica.git
cd multica
bash scripts/deploy/bootstrap-ubuntu.sh
```

The bootstrap script:

- installs Docker and Docker Compose if missing
- clones the repo into `/opt/multica`
- creates `/opt/multica/.env` from `deploy/selfhost.server.env.example`
- generates a random `JWT_SECRET`
- starts `docker-compose.selfhost.yml`

Before exposing the instance publicly, update `/opt/multica/.env`:

- set a strong `POSTGRES_PASSWORD`
- configure `RESEND_*` or keep the server in non-production mode
- move to HTTPS + domain before setting `APP_ENV=production`

## GitHub Actions secret

The workflow `.github/workflows/deploy-selfhost.yml` expects one repository secret:

- `DEPLOY_SSH_KEY`: private SSH key allowed to log into `ubuntu@195.209.219.177`

The public key for that secret must be present in `~ubuntu/.ssh/authorized_keys` on the server.

## Deploy flow

On every push to `main`, GitHub Actions:

1. connects to `195.209.219.177`
2. uploads `scripts/deploy/remote-deploy.sh`
3. fetches the latest `main`
4. resets the server checkout to the pushed commit
5. runs `docker compose -f docker-compose.selfhost.yml up -d --build --remove-orphans`
6. verifies `http://127.0.0.1:8080/health`
