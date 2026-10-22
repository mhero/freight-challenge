# Freight challenge

Ruby on Rails (API-only, used as application and persistence layer) + PostgreSQL, run entirely with Docker.
Challenge spec: `docs/challenge/README.md`. Sample feed: `db/feeds/response.json`.

**Status: Step 02 (domain foundation).** Persistence, feed import, route search for `cheapest`/`fastest`, saved searches and the CLI arrive in later steps.

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

## Domain layer (Step 02)
Plain Ruby under `app/domain/freight/` (no ActiveRecord, testable without records). Rails only autoloads it.

| Class | Responsibility |
|-------|----------------|
| `PortCode`, `Currency`, `Money` | Immutable value objects. `Money` is BigDecimal only; `Money.parse` is the strict feed boundary (P8). |
| `ExchangeRates` | EUR-based rates by exact date; converts to EUR by dividing (P7). |
| `Sailing`, `Rate`, `PricedSailing`, `Route` | Leg, offered price, leg with resolved price, ordered legs (duration first departure to last arrival, total EUR). |
| `RateResolver` | Chooses one price per sailing: highest EUR wins, discarded rates and missing data become `DataIssue`s (P1, P4). |
| `CatalogueBuilder`, `Catalogue` | Builds the searchable set of priced sailings plus the issues found. |
| `Criteria`, `Criteria::Base`, `Criteria::CheapestDirect` | Pluggable strategies: a criterion picks candidate routes and a sort key (ties are part of the key). New criterion = new class listed in `Criteria.all`. |
| `RouteSerializer` | README output format (original rate and currency, minor-unit formatting). |
| `Errors` | Domain errors, mapped to CLI error codes later. |

Test helpers live in `spec/support` (`DomainHelpers`, and `SampleFeed`, a test-only loader replaced by the real feed adapter in Step 04).
Run just the domain specs: `docker compose run --rm test bundle exec rspec spec/domain`.

## Design docs
- `docs/data_policy.md`: findings in the data, approved conflict/missing-data/currency/routing policies and expected sample results
- `docs/error_contract.md`: CLI stdout/stderr/exit codes (unknown well-formed ports are saved, not errors)
- `docs/po_questions.md`: questions for the PO

## Base-project changes (Step 01)
Production-oriented Dockerfile now defaults to `development` and keeps test gems; removed `COPY vendor/*` (no `vendor/` dir, it breaks the build); `config/database.yml` reads host/user/password from env; entrypoint runs `db:prepare` for every command (to stderr); SimpleCov added; `compose.yaml` added.
Left untouched for now: Kamal files, Solid Cache/Queue/Cable gems (Queue is reserved for the optional Step 08 worker), existing `.github` workflow (Brakeman, bundler-audit, RuboCop). The Docker RSpec CI job comes in Step 07.
