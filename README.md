# Freight Challenge

Shypple freight take-home in Ruby. A small Rails application (persistence and
conventions) with the business rules in plain Ruby, driven by a stdin/stdout CLI.
The original task is in [docs/CHALLENGE.md](docs/CHALLENGE.md).

**Docker is the only dependency.** PostgreSQL and the app run through Docker Compose.

## Quick start

```sh
printf 'CNSHA\nNLRTM\ncheapest-direct\n' > input.txt
docker compose run --rm -T app bin/freight < input.txt
```

The first run builds the image, starts PostgreSQL, runs migrations (`db:prepare`)
and imports the bundled `data/response.json` before the command runs. stdout carries
only the JSON result; setup logs go to stderr.

| Task | Command |
| --- | --- |
| Search | `docker compose run --rm -T app bin/freight < input.txt` |
| Import a feed | `docker compose run --rm -v "$PWD/my.json:/feeds/my.json" app bin/freight import /feeds/my.json` |
| List / ack notifications | `docker compose run --rm app bin/freight notifications list` and `... notifications ack 1 2` or `ack --through 5` |
| Run the tests | `bin/docker-test` (any rspec args are passed on) |
| Stop | `docker compose down` (add `-v` to delete the database) |
| Lint, security scans | `docker compose run --rm app bin/rubocop` / `bin/brakeman` |

Input is three lines (origin port, destination port, criterion: `cheapest-direct`,
`cheapest`, `fastest`). Output is a JSON array of legs, printed as in the challenge.
CRLF, whitespace, lowercase and trailing blank lines are accepted.

### Environment variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `DATABASE_URL` | set in `compose.yml` | PostgreSQL connection |
| `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | `freight` / `freight` / `freight_development` | Local defaults; override with a `.env` file (git-ignored) |
| `FEED_PATH` | `data/response.json` | Feed imported at container start |
| `SEED_ON_BOOT` | `true` | `false` skips the startup import (always skipped for `RAILS_ENV=test`) |

The seed import is synchronous and idempotent (checksum), and imports are
serialized with a PostgreSQL advisory lock, so two containers starting together are safe.

## Error contract

stdout only ever holds the result. Errors are one JSON line on stderr.

| Case | stdout | stderr | Exit |
| --- | --- | --- | --- |
| Result found | JSON array of legs | empty | 0 |
| No route or unknown port | `[]` | warning for unknown ports; the search is saved | 0 |
| Malformed port, invalid criterion, missing or extra lines, bad command | empty | `{"error":{"code":422 or 400,...}}` | 2 |
| Import file missing (404) or invalid feed (422) | empty | `{"error":{...}}` | 2 |
| Internal error | empty | `{"error":{"code":500,...}}` | 1 |

## Architecture

```
bin/freight -> FreightCli::Runner (lib/freight_cli)        thin: parse, call a service, print
                  |
   application services (app/services)   SearchRoutes, ImportFeed, ImportFeedFile, SeedFeed,
                  |                      ReevaluateSavedSearches, NotificationInbox, FeedMerge
   domain, plain Ruby (app/domain/freight)   Rate, ExchangeRates, RateResolver, Sailing, Route,
                  |                          RouteSearch, Criteria::{CheapestDirect,Cheapest,Fastest}
   Freight::SailingRepository  <-- ActiveRecordSailingRepository (app/repositories) -- PostgreSQL
   MapReduceFeed (app/feeds): the only code that knows the feed's JSON format
```

- **Criteria are strategies** behind one base class (`max_legs`, `sort_key`, `prunable?`).
  A new criterion is a new class plus one line in `Freight::Criteria.all`; existing ones are not modified.
- **Route search** is a depth-first search that expands one port at a time through
  `departures_from(port, on_or_after:)`, never loading the schedule. No port is visited
  twice (no cycles), dead ends return nothing, and there is no limit on the number of legs.
  Branch-and-bound pruning uses the criterion (cost and duration only grow with more legs).


## Data policies

- **Source of truth is the JSON.** Exchange rates are EUR-based: USD to EUR **divides** by the
  rate of the sailing's `departure_date` (exact date, no carry-forward). EUR is 1.
  All math uses `BigDecimal`, including parsed JSON numbers.
- **Conflicting rates** for one sailing (MNOP: 456.78 vs 812.00 USD): the **highest in EUR**
  wins, independent of feed order; the discarded rate is recorded in the import issues.
- **Unpriced sailings** (no rate, or no exchange rate for the date) are excluded from every
  criterion and recorded. A conflict containing an unconvertible candidate leaves the sailing unpriced.
- **Output keeps each leg's original rate and currency, exactly as received** (`"97453"` stays
  `"97453"`). Precision is checked by value (JPY 0 decimals, USD/EUR 2, default 2); a rate that rounding
  would change is rejected and recorded.
- **Connections:** next departure date >= previous arrival date. Same-day connections are allowed
  (dates only, so one may be physically impossible).
- **Fastest** = first departure to last arrival, layovers included.
- **Tie-breaks:** cheapest: total EUR, fewer legs, earlier arrival, sailing codes ascending.
  Fastest: duration, total EUR, fewer legs, sailing codes ascending.
- Sample results: cheapest-direct **ABCD** (~523.36 EUR); cheapest **ERXQ + ETRG** (~322.89 EUR);
  fastest **QRST** (17 days vs 22).

## Import, versioning and inspecting results

`ImportFeed` validates the structure, stores the raw payload and an import record
(`feed_imports`: status, checksum, counts), then upserts exchange rates and sailings and appends rates in batches in
one transaction. Nothing is deleted.

- Same checksum already imported: no-op. Structurally invalid feeds are recorded as `failed`.
- Each feed is a **full snapshot**: sailings missing from it become **inactive** (`active = false`),
  and are excluded from searches. They return if a later feed contains them.
- `rates` is append-only with `import_id`; the effective rate comes from the import that last saw the sailing.
- A sailing code with different route or dates inside one feed is a conflict: excluded and recorded.
  Identical duplicates collapse. Malformed records are rejected and recorded.
- Rejections, conflicts, unpriced sailings and orphan rates live in `import_issues`:

```sh
docker compose exec db psql -U freight freight_development \
  -c "select kind, reference, reason from import_issues order by id"
```

`db/schema.rb` is generated by the first `db:prepare`; commit it after the first run.

## Saved searches and notifications (SLD-0004)

1. A search without an answer (no route, or an unknown port) answers `[]`, exit 0, and is saved
   (`saved_searches`, deduplicated by origin, destination, criterion while pending).
2. After a committed import, `ReevaluateSavedSearches` processes pending searches in batches claimed with
   `FOR UPDATE SKIP LOCKED`, so retries and concurrent runs are safe.
3. A fulfilled search is marked fulfilled and one row is written to `fulfillment_events`
   (the outbox, unique per search) with the route.
4. The user pulls: `notifications list` (`--status`, `--limit`, `--after-id`, `--origin`, `--destination`,
   `--criterion`; the result has `next_after_id`) and `notifications ack IDS...` or `ack --through ID`.

**Trade-offs.** A CLI cannot subscribe, so a pull outbox is the simplest honest mechanism: nothing is lost if
nobody is listening, and bulk volumes are handled by pagination and bulk ack. Queries and notifications are separate:
each query answers immediately; client errors are exit codes, not notifications. A **push webhook** is the next step
(a sender reads the outbox and retries); it needs endpoint registration, signing, retries and dead-lettering, so it is documented, not built.

## Tests and CI

`bin/docker-test` runs the full RSpec suite against a separate PostgreSQL database with SimpleCov
(report in `coverage/`). Domain specs use an in-memory repository; service, persistence and CLI specs use PostgreSQL;
end-to-end specs cover the three README scenarios and a saved search fulfilled by a second feed; two specs use real
threads (same-checksum imports, `SKIP LOCKED`). GitHub Actions (`.github/workflows/ci.yml`) builds the image and runs
the same suite in Docker, next to the existing lint and security jobs.

## Scale path

Built: batched upserts, an index on `(origin_port, departure_date)`, per-port expansion, `last_seen_import_id`,
append-only rates. **Current limit:** the feed is parsed in memory (and stored as raw text), and route search is a
bounded depth-first search without a leg cap, which can be slow on dense schedules.
Not built: streaming parser, staging table or `COPY`, parallel reevaluation with a job queue and worker,
Redis cache for hot routes, webhook delivery, sharding.

## Assumptions

Ports are two letters plus three letters or digits. A port is "known" when an active sailing uses it.
Rates for conflicting or missing sailings are ignored and recorded. A later snapshot overwrites a sailing's fields.
A search from a port to itself finds nothing and is saved. Imports may take long on huge feeds (single transaction).

## Questions for the PO

1. **MNOP:** two rates for one sailing (456.78 and 812.00 USD). We keep the highest; should it be the lowest, the latest, or a hard error?
2. **README vs JSON:** the README shows ERXQ arriving 2022-02-06 (JSON: 2022-02-12), a cheapest-direct example dated 2024 with rate 232.30 that exists nowhere in the data, and the same two legs for `fastest` as for `cheapest` (the JSON gives QRST). We follow the JSON. Which is right?
3. **Fastest:** first departure to last arrival (layovers count), or the sum of leg durations?
4. **Connections:** are same-day connections allowed, and is there a minimum layover? We only have dates.
5. **Unpriced sailings (Q5):** sailings without a rate or exchange rate are excluded everywhere. Should they be shown or flagged?
6. **Snapshot or delta feeds:** do feeds replace everything (we deactivate missing sailings) or only add changes?
7. **Unknown ports:** save the search and warn (current), or reject it?
8. **Currencies without decimals:** should JPY be printed with decimals or as received (current)?
9. **Conflicting sailing fields:** a sailing code with different route or dates is excluded. Is that right, or should the latest win?
10. **Maximum legs:** is there a sensible cap (cost of unbounded search)?
