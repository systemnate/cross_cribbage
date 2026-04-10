# Docker Compose Dev Environment — Design Spec

**Date:** 2026-04-09
**Status:** Approved

## Goal

Enable contributors to clone the repo and run a full development environment — Rails server, Vite dev server, and PostgreSQL — using only Docker, with no local Ruby or Node installation required.

## New Files

| File | Purpose |
|---|---|
| `Dockerfile.dev` | Development image: Ruby 3.3.5 + Node 22.14.0, all gems, npm packages |
| `docker-compose.yml` | Orchestrates `db`, `web`, and `vite` services |
| `.env.example` | Documents required env vars with working defaults (committed) |
| `.env` | Developer's local env vars — copied from `.env.example` (gitignored) |

## Services

### `db`
- Image: `postgres:16`
- Named volume `postgres_data` for persistence across restarts
- `POSTGRES_PASSWORD` set from env
- Health check: `pg_isready -U postgres` so dependent services wait until Postgres is accepting connections

### `web`
- Built from `Dockerfile.dev`
- Source root mounted as volume for hot reload
- Runs: `bin/rails db:prepare && bin/rails s -b 0.0.0.0 -p 3000`
- Exposes port 3000
- `depends_on: { db: { condition: service_healthy } }` — waits for Postgres to be ready, not just started
- Env: `DATABASE_URL`, `RAILS_ENV=development`

### `vite`
- Same image as `web` (no separate build)
- Source root mounted as volume
- Runs: `bin/vite dev`
- Exposes port 3036
- `depends_on: web`

## `Dockerfile.dev`

- Base: `ruby:3.3.5-slim`
- Installs system deps: `build-essential`, `libpq-dev`, `curl`, `git`
- Installs Node 22.14.0 via `nodenv/node-build`
- `bundle install` with no `BUNDLE_WITHOUT` (includes dev/test gems)
- `npm install`
- Sets `RAILS_ENV=development`
- No asset precompilation — Vite handles this at runtime
- No entrypoint script — services define their own commands

## Environment Variables

`.env.example` (committed, with working defaults):
```
DATABASE_URL=postgres://postgres:password@db:5432/cross_cribbage_development
POSTGRES_PASSWORD=password
```

No `RAILS_MASTER_KEY` needed — the app does not read from `Rails.application.credentials` anywhere.

## Vite Host Binding

`config/vite.json` gains `"host": "0.0.0.0"` in the `development` block so Vite's dev server accepts connections from outside the container. Binding on all interfaces in development is harmless for non-Docker users.

## Developer Workflow

```bash
cp .env.example .env
docker compose build
docker compose up
```

- App: http://localhost:3000
- Vite HMR: port 3036 (consumed internally by Rails asset helpers)

Database is created and migrated automatically on first `web` start via `bin/rails db:prepare`.

## Out of Scope

- Production compose setup (handled by Kamal)
- Dev containers / VS Code remote container integration
- Redis or any additional services (app uses Solid Cable + Solid Queue, both on Postgres)
