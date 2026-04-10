# Docker Compose Dev Environment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `docker compose up` developer workflow so contributors can run the full stack (Rails + Vite + Postgres) without installing Ruby or Node locally.

**Architecture:** Three services — `db` (Postgres 16), `web` (Rails on :3000), `vite` (Vite dev server on :3036) — all built from a new `Dockerfile.dev`. Source is bind-mounted for hot reload; `node_modules` and the bundle cache live in named Docker volumes so they survive the bind mount overlay.

**Tech Stack:** Docker Compose v2, Ruby 3.3.5, Node 22.14.0, Postgres 16, vite-plugin-ruby

---

## Files

| Action | Path | Purpose |
|--------|------|---------|
| Modify | `config/vite.json` | Add `"host": "0.0.0.0"` so Vite accepts connections from outside the container |
| Create | `.env.example` | Documents required env vars with working defaults (committed) |
| Create | `Dockerfile.dev` | Development image — Ruby + Node + all gems, no asset precompile |
| Create | `docker-compose.yml` | Orchestrates db, web, and vite services |

`.gitignore` already ignores `/.env*` — no change needed.

---

## Task 1: Add Vite host binding

**Files:**
- Modify: `config/vite.json`

- [ ] **Step 1: Add `"host"` to the development block**

The current file:
```json
{
  "development": {
    "autoBuild": false,
    "publicOutputDir": "vite-dev",
    "port": 3036
  },
  "test": {
    "autoBuild": true,
    "publicOutputDir": "vite-test"
  }
}
```

Replace with:
```json
{
  "development": {
    "autoBuild": false,
    "publicOutputDir": "vite-dev",
    "port": 3036,
    "host": "0.0.0.0"
  },
  "test": {
    "autoBuild": true,
    "publicOutputDir": "vite-test"
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add config/vite.json
git commit -m "fix: bind Vite dev server to 0.0.0.0 for Docker compatibility"
```

---

## Task 2: Create `.env.example`

**Files:**
- Create: `.env.example`

- [ ] **Step 1: Create the file**

```
DATABASE_URL=postgres://postgres:password@db:5432/cross_cribbage_development
POSTGRES_PASSWORD=password
```

- [ ] **Step 2: Commit**

```bash
git add .env.example
git commit -m "chore: add .env.example for Docker dev setup"
```

---

## Task 3: Create `Dockerfile.dev`

**Files:**
- Create: `Dockerfile.dev`

- [ ] **Step 1: Create the file**

```dockerfile
# syntax=docker/dockerfile:1
# Development image — not for production (see Dockerfile)

ARG RUBY_VERSION=3.3.5
FROM docker.io/library/ruby:$RUBY_VERSION-slim

WORKDIR /rails

# System dependencies needed to build gems and native extensions
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential curl git libpq-dev libyaml-dev pkg-config \
      node-gyp python-is-python3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Node.js (same version as production Dockerfile)
ARG NODE_VERSION=22.14.0
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    rm -rf /tmp/node-build-master

ENV RAILS_ENV=development \
    BUNDLE_PATH="/usr/local/bundle"

# Install all gems (including dev/test groups)
COPY vendor/ ./vendor/
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Install node modules
# node_modules dir is created here so the named volume can seed from it
COPY package.json package-lock.json ./
RUN npm install

# Copy source — will be overridden by the bind mount volume at runtime,
# but copying here ensures the image is self-contained if run without compose.
COPY . .
```

- [ ] **Step 2: Commit**

```bash
git add Dockerfile.dev
git commit -m "feat: add Dockerfile.dev for local development"
```

---

## Task 4: Create `docker-compose.yml`

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: Create the file**

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  web:
    build:
      context: .
      dockerfile: Dockerfile.dev
    command: bash -c "bin/rails db:prepare && bin/rails s -b 0.0.0.0 -p 3000"
    volumes:
      - .:/rails
      - node_modules:/rails/node_modules
      - bundle:/usr/local/bundle
    ports:
      - "3000:3000"
    env_file: .env
    environment:
      RAILS_ENV: development
    depends_on:
      db:
        condition: service_healthy

  vite:
    build:
      context: .
      dockerfile: Dockerfile.dev
    command: bin/vite dev
    volumes:
      - .:/rails
      - node_modules:/rails/node_modules
      - bundle:/usr/local/bundle
    ports:
      - "3036:3036"
    env_file: .env
    environment:
      RAILS_ENV: development
    depends_on:
      - web

volumes:
  postgres_data:
  node_modules:
  bundle:
```

**Why named volumes for `node_modules` and `bundle`:**
- The bind mount (`. :/rails`) would hide any files the image built into `/rails`, including `node_modules`.
- Declaring `node_modules` and `bundle` as named volumes tells Docker to create separate volumes for those paths that take precedence over the bind mount. Docker seeds an empty named volume from the image on first start, so `npm install` and `bundle install` results are preserved.
- When `Gemfile` or `package.json` changes, run `docker compose build` to rebuild, then `docker compose up` — Docker replaces the volume contents with the new image contents on first start with an updated image.

- [ ] **Step 2: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: add docker-compose.yml for local development"
```

---

## Task 5: Smoke test

No automated tests apply to Docker infrastructure files. Verify manually.

- [ ] **Step 1: Copy env file**

```bash
cp .env.example .env
```

- [ ] **Step 2: Build the image**

```bash
docker compose build
```

Expected: build completes with no errors. Both `web` and `vite` services resolve to the same cached image after the first build.

- [ ] **Step 3: Start services**

```bash
docker compose up
```

Expected output (may be interleaved):
```
cross_cribbage-db-1   | database system is ready to accept connections
cross_cribbage-web-1  | == Puma ... listening on http://0.0.0.0:3000
cross_cribbage-vite-1 | VITE ... ready in ... ms
```

- [ ] **Step 4: Verify the app loads**

Open http://localhost:3000 in a browser. Expected: the Cross Cribbage home page renders.

- [ ] **Step 5: Verify database was prepared**

In a second terminal:
```bash
docker compose exec web bin/rails db:version
```

Expected: prints a migration version number (not an error), confirming `db:prepare` ran successfully.

- [ ] **Step 6: Verify Vite HMR is connected**

Open browser dev tools → Network tab. Reload http://localhost:3000. Expected: no asset 404s, Vite dev assets load from port 3036.

- [ ] **Step 7: Tear down**

```bash
docker compose down
```

Expected: all containers stop cleanly. Postgres data persists in the `postgres_data` named volume — restarting with `docker compose up` should not re-run migrations.
