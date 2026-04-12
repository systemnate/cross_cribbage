# Code Coverage Tooling — Design

## Goal

Add code-coverage reporting to both the Rails backend and the React/TypeScript frontend so contributors can measure test coverage locally. No new tests are written as part of this work — only the tooling to measure coverage when tests eventually exist. A minimum coverage threshold of **75%** is enforced on both sides so runs fail when coverage drops below the floor.

## Non-Goals

- Writing any unit, integration, or component tests.
- Wiring coverage into CI (there is no CI config in the repo today).
- Uploading coverage to external services (Codecov, Coveralls, etc.).
- Refactoring existing code to improve coverage.

## Backend — SimpleCov

**Gem**

Add to the `:test` group in `Gemfile`:

```ruby
group :test do
  gem "shoulda-matchers"
  gem "simplecov", require: false
end
```

**Initialization**

SimpleCov must start before any application code loads. Add to the very top of `spec/rails_helper.rb`, above the existing `require` lines:

```ruby
require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  coverage_dir "coverage/backend"
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/vendor/"
  add_filter "/db/"
  add_group "Models",      "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Channels",    "app/channels"
  add_group "Jobs",        "app/jobs"
  add_group "Lib",         "app/lib"
  minimum_coverage line: 75
end
```

Notes:

- The `"rails"` profile gives sensible Rails defaults; the block overrides where needed.
- `coverage_dir` is set to `coverage/backend` so it doesn't collide with the frontend report (see Collision Handling below).
- `minimum_coverage line: 75` causes `rspec` to exit non-zero if line coverage drops below 75%.
- Branch coverage is enabled for richer reporting but is not enforced as a threshold.

**Usage**

```bash
bundle exec rspec
open coverage/backend/index.html
```

## Frontend — Vitest + v8 Coverage

**Dependencies** (all `devDependencies`)

- `vitest` — test runner
- `@vitest/coverage-v8` — v8-based coverage provider
- `jsdom` — DOM environment so React components are renderable under Node
- `@testing-library/react` — React component testing utilities
- `@testing-library/jest-dom` — DOM matchers (`toBeInTheDocument`, etc.)

These are installed now so the framework is ready the moment anyone writes a test. No test files are created in this task.

**`vitest.config.ts`** (new file at repo root)

```ts
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    globals: true,
    include: ["app/frontend/**/*.{test,spec}.{ts,tsx}"],
    coverage: {
      provider: "v8",
      reporter: ["text", "html"],
      reportsDirectory: "coverage/frontend",
      include: ["app/frontend/**/*.{ts,tsx}"],
      exclude: [
        "app/frontend/**/*.d.ts",
        "app/frontend/entrypoints/**",
        "app/frontend/types/**",
      ],
      thresholds: {
        lines: 75,
        statements: 75,
        branches: 75,
        functions: 75,
      },
    },
  },
});
```

Notes:

- `include` targets source files under `app/frontend/`; entrypoints and pure type files are excluded because they contain little runnable logic worth measuring.
- Threshold applies to all four metrics; `vitest run --coverage` exits non-zero if any metric drops below 75%.
- Because there are no tests yet, `npm run test:coverage` will initially report 0% and fail the threshold. This is expected and intentional — the threshold is wired so that once tests are added, the gate already exists. Developers who want to run the tooling without failure today can run `npm test` (no coverage gate) instead.

**`package.json` scripts**

```json
"scripts": {
  "build": "vite build",
  "test": "vitest",
  "test:coverage": "vitest run --coverage"
}
```

**`tsconfig.json`**

The repo has a root `tsconfig.json`. Add `"types": ["vitest/globals", "@testing-library/jest-dom"]` under `compilerOptions` so `describe` / `it` / `expect` and the jest-dom matchers are type-visible when tests are eventually written.

## Collision Handling

SimpleCov and Vitest both default their output to `coverage/`. To let them coexist:

- SimpleCov writes to `coverage/backend/`.
- Vitest writes to `coverage/frontend/`.

Add `/coverage/` to `.gitignore` (the repo currently has no entry for it).

## Directory Layout (after this work)

```
coverage/              # gitignored
  backend/index.html
  frontend/index.html
docs/superpowers/specs/
  2026-04-11-code-coverage-design.md  # this file
vitest.config.ts       # new
Gemfile                # simplecov added to :test
spec/rails_helper.rb   # SimpleCov.start prepended
package.json           # new devDeps + scripts
.gitignore             # /coverage/ added
```

## Acceptance Criteria

1. `bundle exec rspec` still passes the existing specs and produces `coverage/backend/index.html`.
2. With existing specs, backend line coverage is reported; if it falls below 75%, the run exits non-zero. (Initial measurement may be above or below 75% — the gate is honest either way; the user is not asking us to chase the threshold.)
3. `npm run test:coverage` executes without crashing. It will exit non-zero today because there are zero frontend tests, and zero tests → 0% coverage → below the 75% floor. This is expected until tests are written.
4. `npm test` runs Vitest in watch mode without requiring any tests to exist (Vitest handles empty test suites gracefully).
5. `coverage/` is git-ignored.
6. No application code under `app/` is modified.
7. No test files are added.

## Risks / Open Questions

- **Initial backend threshold failure.** If existing specs don't cover 75% of backend code, `rspec` will start failing. Mitigation: during implementation, run coverage once to check the baseline. If it comes in below 75%, flag to the user before committing the threshold — options are (a) lower the threshold to the observed baseline, (b) leave the threshold at 75% and accept that `rspec` now fails until coverage improves, or (c) make the threshold advisory by omitting `minimum_coverage` on the backend. Default recommendation if the baseline is clearly below 75%: option (a), set the threshold to the observed floor rounded down to the nearest 5%.
- **Frontend threshold always fails today.** By design — see acceptance criterion #3. The user has been told and accepted this.
- **No CI.** Thresholds only fire when a developer runs the command locally. That's fine for this scope; CI wiring is a separate task.
