# Freight challenge

Ruby on Rails (API-only, used as application and persistence layer) + PostgreSQL, run entirely with Docker.
Challenge spec: `docs/challenge/README.md`. Sample feed: `db/feeds/response.json`.

**Status: Step 01 (bootstrap + approved data policies).** The CLI and routing arrive in later steps.

## Requirements
Docker with Compose v2. Nothing else.

## Commands
```bash
docker compose up --build -d        # build, start PostgreSQL (healthy) and the app container, prepare the DB
docker compose run --rm test        # full RSpec suite + SimpleCov summary (separate test database)
docker compose down                 # stop (data kept in the pgdata volume)
docker compose down -v              # stop and wipe the database
```
Later steps add: `docker compose exec -T app bin/freight < input.txt` (or `run --rm -T app ...`).
Migration output goes to stderr, so stdout only carries the CLI result.

## Configuration
| Variable | Default | Use |
|----------|---------|-----|
| `POSTGRES_USER` | `freight` | DB user (db and app) |
| `POSTGRES_PASSWORD` | `freight` | DB password; local-only default, override via shell or `.env` |
| `DB_HOST` | `db` in Compose | DB host |
| `RAILS_ENV` | `development` (`test` for the test service) | Rails env |

The database is not published on a host port.

## Design docs (read before Step 02)
- `docs/data_policy.md`: findings in the data, approved conflict/missing-data/currency/routing policies and expected sample results
- `docs/error_contract.md`: CLI stdout/stderr/exit codes (unknown well-formed ports are saved, not errors)
- `docs/po_questions.md`: questions for the PO

## Base-project changes (Step 01)
Production-oriented Dockerfile now defaults to `development` and keeps test gems; removed `COPY vendor/*` (no `vendor/` dir, it breaks the build); `config/database.yml` reads host/user/password from env; entrypoint runs `db:prepare` for every command (to stderr); SimpleCov added; `compose.yaml` added.
Left untouched for now: Kamal files, Solid Cache/Queue/Cable gems (Queue is reserved for the optional Step 08 worker), existing `.github` workflow (Brakeman, bundler-audit, RuboCop). The Docker RSpec CI job comes in Step 07.
