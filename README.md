# Freight Challenge

Finds the best shipping route between two ports from a MapReduce feed: the cheapest direct sailing,
the cheapest route (any number of legs), or the fastest one. Searches that have no answer yet are
saved and answered when a later feed makes them possible.

Ruby on Rails app with the business rules in plain Ruby, used through a small stdin/stdout command line.
The original task is in [docs/CHALLENGE.md](docs/CHALLENGE.md).

**Docker is the only thing you need installed.**

## Contents

[Quick start](#quick-start) · [Everyday commands](#everyday-commands) · [Searching](#searching) ·
[Loading data](#loading-data) · [Saved searches](#saved-searches-and-notifications) · [Errors](#errors-and-exit-codes) ·
[Configuration](#configuration) · [Tests](#tests) · [How it is built](#how-it-is-built) · [Rules](#business-rules) ·
[Scale](#scale-path) · [Assumptions and questions](#assumptionsquestions)

## Quick start

```sh
# 1. Start the app once. It builds the image, starts PostgreSQL, creates the tables and imports data/response.json.
docker compose run -d --name freight-app app sleep infinity
until docker logs freight-app 2>&1 | grep -q "Seed feed"; do sleep 1; done    # wait until setup is done

# 2. Ask as many questions as you want.
printf 'CNSHA\nNLRTM\ncheapest-direct\n' > input.txt
docker exec -i freight-app bin/freight < input.txt

# 3. When you are done.
docker rm -f freight-app && docker compose down
```

You do not load any data by hand: the bundled `data/response.json` is imported during step 1, before the first
answer. Setup runs once, so each query boots Rails once instead of three times. Result:

```json
[
  {
    "origin_port": "CNSHA",
    "destination_port": "NLRTM",
    "departure_date": "2022-02-01",
    "arrival_date": "2022-03-01",
    "sailing_code": "ABCD",
    "rate": "589.30",
    "rate_currency": "USD"
  }
]
```

Only the result goes to stdout. Setup messages and errors go to stderr. If `freight-app` already exists
(`docker: Error response ... name is already in use`), remove it first with `docker rm -f freight-app`.

## Everyday commands

These assume the container from the quick start is running.

| I want to... | Command |
| --- | --- |
| Search | `docker exec -i freight-app bin/freight < input.txt` |
| Import a feed file | `docker cp my.json freight-app:/tmp/my.json` then `docker exec freight-app bin/freight import /tmp/my.json` |
| See fulfilled saved searches | `docker exec freight-app bin/freight notifications list` |
| Mark them as read | `docker exec freight-app bin/freight notifications ack 1 2` (or `ack --through 5`) |
| See setup logs | `docker logs freight-app` |
| Run the tests | `bin/docker-test` |
| Run the scenario test pack | `bin/test-pack` (wipes the local database) |
| Stop | `docker rm -f freight-app` then `docker compose down` (add `-v` to delete the database too) |
| Style and security checks | `docker compose run --rm app bin/rubocop` and `bin/brakeman` |

After changing code, rebuild the image (`docker compose build app`) and start the container again.

### Alternative: one container per command

If you prefer not to keep a container around, every command also works as a one-off. Each one starts a fresh container,
boots Rails three times (migrations check, seed check, the command) and removes the container; the data is safe in
the PostgreSQL volume.

```sh
docker compose run --rm -T app bin/freight < input.txt
docker compose run --rm -v "$PWD/my.json:/feeds/my.json" app bin/freight import /feeds/my.json
docker compose run --rm app bin/freight notifications list
```

## Searching

Input is three lines: origin port, destination port, criterion.

| Criterion | Returns |
| --- | --- |
| `cheapest-direct` | the cheapest single sailing |
| `cheapest` | the cheapest route, direct or with any number of legs (all legs are listed) |
| `fastest` | the route with the shortest time from first departure to last arrival |

Ports are two letters plus three letters or digits (`CNSHA`). Lowercase, extra spaces, Windows line endings
and trailing blank lines are accepted. Each leg is printed with its original rate and currency, exactly as
received. If there is no route the output is `[]` (see [Errors](#errors-and-exit-codes)).

## Loading data

**At startup.** The entrypoint imports `data/response.json` (or the file named by `FEED_PATH`) before any
command runs, so a search never meets an empty database. Importing the same file twice does nothing.

**Later.** `bin/freight import FILE` loads another feed. It does not erase the old data. Each feed is treated as a
**full snapshot**:

- Sailings in the new feed are added, or updated if the code already exists (the new route and dates win).
- Sailings missing from the new feed become **inactive**: they are no longer searched but stay in the database,
  and they come back if a later feed contains them.
- Rates are never overwritten. Every import adds its own rate rows, and a sailing uses the rate from the
  import that last saw it.
- Exchange rates are updated per date and currency; dates absent from the new feed keep their old rates.
- Everything is recorded: the raw file, a checksum, counts, and every rejected, conflicting or unpriced row
  with its reason.

Look at what an import rejected:

```sh
docker compose exec db psql -U freight freight_development \
  -c "select kind, reference, reason from import_issues order by id"
```

## Saved searches and notifications

1. A search with no answer (no route, or an unknown port) prints `[]`, exits 0 and is **saved**. The same
   question is saved only once while it is pending.
2. After every import, pending searches are checked again. Those that now have a route are marked fulfilled and
   a notification is written for each, once.
3. You read them with `notifications list` and clear them with `notifications ack`.
   `list` accepts `--status unacknowledged|acknowledged|all`, `--limit`, `--after-id` (paging), `--origin`,
   `--destination` and `--criterion`.

There are no user accounts: saved searches and notifications are shared by everyone using the database.

A command line cannot be subscribed to, so notifications are pulled from an outbox table. Nothing is lost if
nobody is listening, and large volumes are handled by paging and bulk acknowledgement. A push webhook is the natural
next step; it needs endpoint registration, signing and retries, so it is documented here and not built.

## Errors and exit codes

| Situation | stdout | stderr | Exit |
| --- | --- | --- | --- |
| Route found | JSON array of legs | empty | 0 |
| No route, or a well-formed unknown port | `[]` | warning for unknown ports; the search is saved | 0 |
| Malformed port, invalid criterion, missing or extra input lines, bad command | empty | `{"error":{"code":422 or 400,...}}` | 2 |
| Import file missing (404) or invalid feed (422) | empty | `{"error":{...}}` | 2 |
| Internal error | empty | `{"error":{"code":500,...}}` | 1 |

## Configuration

| Variable | Default | Meaning |
| --- | --- | --- |
| `DATABASE_URL` | set in `compose.yml` | PostgreSQL connection |
| `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | `freight` / `freight` / `freight_development` | Local defaults; override in a git-ignored `.env` file |
| `FEED_PATH` | `data/response.json` | Feed imported at container start |
| `SEED_ON_BOOT` | `true` | `false` skips the startup import (always skipped in tests) |

Imports are serialized with a PostgreSQL advisory lock, so two containers starting together are safe.
`db/schema.rb` is generated by the first `db:prepare`; commit it after the first run.

## Tests

- **`bin/docker-test`** runs the RSpec suite in Docker against a separate test database, with SimpleCov
  coverage in `coverage/`. Domain specs use an in-memory repository; the rest use PostgreSQL. It covers the
  three challenge scenarios, saved searches fulfilled by a second feed, and two real-thread specs
  (same-feed imports, row locking).
- **`bin/test-pack`** replays [test-pack/PLAN.md](test-pack/PLAN.md) end to end through the CLI (feeds, queries,
  error cases, a snapshot import) and compares the output with the expected results.
- **CI:** `.github/workflows/ci.yml` builds the image and runs the same suite on every push and pull request,
  next to the lint and security jobs.

## How it is built

```
bin/freight -> FreightCli::Runner (lib/freight_cli)        thin: parse input, call a service, print
                  |
   services (app/services)   SearchRoutes, ImportFeed, ImportFeedFile, SeedFeed,
                  |          ReevaluateSavedSearches, NotificationInbox, FeedMerge
   domain, plain Ruby (app/domain/freight)   Rate, ExchangeRates, RateResolver, Sailing, Route,
                  |                          RouteSearch, Criteria::{CheapestDirect, Cheapest, Fastest}
   Freight::SailingRepository  <-- ActiveRecordSailingRepository (app/repositories) -- PostgreSQL
   MapReduceFeed (app/feeds): the only code that knows the feed's JSON format
```

- **Criteria are strategies** behind one base class. A new criterion is a new class plus one line in
  `Freight::Criteria.all`; existing ones are not touched.
- **Route search** is a Dijkstra search over sailings that asks the repository for one port at a time, so the whole
  schedule is never loaded. Each port is read from the earliest arrival date seen (the date filter runs in SQL, on a
  partial index of active sailings), a port is read again only when a route reaches it sooner, and a route is queued
  only if it beats the best one already queued for its last sailing. There is no limit on the number of legs.
- **Why Rails:** saved searches need persistence, a central database serves future interfaces and users, and Rails
  conventions keep the code easy to navigate. The domain does not depend on ActiveRecord: a different store means a
  different repository adapter.
- **Left out on purpose:** controllers, a worker service, a plugin system, gem extraction.

## Business rules

- **The JSON is the source of truth.** Exchange rates are EUR-based, so converting USD to EUR **divides** by the rate
  of the sailing's departure date (exact date, no carry-forward). EUR counts as 1. All math uses `BigDecimal`.
- **Conflicting rates** for one sailing (MNOP: 456.78 vs 812.00 USD): the **highest in EUR** wins, whatever the order in
  the file. The discarded rate is recorded.
- **Unpriced sailings** (no rate, or no exchange rate for the date) are ignored by every criterion and recorded.
  A conflict containing a rate that cannot be converted also leaves the sailing unpriced.
- **Precision** is checked by value (JPY 0 decimals, USD and EUR 2, others 2). A rate that rounding would change is
  rejected and recorded, never rounded.
- **Connections:** the next departure date must be on or after the previous arrival date. Same-day connections are
  allowed (the data only has dates, so one may be physically impossible).
- **Fastest** is first departure to last arrival, layovers included.
- **Tie-breaks.** Cheapest: total EUR, fewer legs, earlier arrival, sailing codes ascending. Fastest: duration,
  total EUR, fewer legs, sailing codes ascending.
- **Bad data is never dropped silently.** Malformed records are rejected, identical duplicates collapse, and a sailing
  code with different route or dates inside one feed is excluded; all of it is recorded with a reason.
- **Expected on the sample feed:** cheapest-direct is **ABCD** (about 523.36 EUR); cheapest is **ERXQ + ETRG**
  (about 322.89 EUR); fastest is **QRST** (17 days, against 22 for ERXQ + ETRG).

## Scale path

Built: batched upserts, a partial index on active sailings `(origin_port, departure_date, sailing_code)`, per-port expansion read from the arrival date in SQL, one queue entry per improvement, a `last_seen_import_id`
on sailings, and append-only rates.

Current limits: a feed is parsed in memory (and stored as raw text), imports run in one transaction, every loaded
sailing is converted to EUR in Ruby on each search (storing the EUR price at import would remove this, but it must be
recomputed whenever exchange rates change), and the route search has no leg cap, so it can be slow on very dense
schedules.

Not built, next steps: a long-running Rails served over HTTP (boot once, many queries; the services are already
separate from the CLI, so a controller would only call them), streaming parser, staging table or `COPY`, parallel re-checking through a job queue and worker,
Redis cache for hot routes, webhook delivery, sharding.

## Assumptions/Questions

### Search

**Assumptions**
1. A port is "known" when an active sailing uses it. Unknown ports answer `[]` with a warning on stderr and the search is saved.
2. A search from a port to itself finds nothing and is saved.
3. Saved searches and notifications are shared by everyone; there are no users.

**Open Questions**
1. **README vs JSON:** the README shows ERXQ arriving 2022-02-06 (JSON: 2022-02-12), a cheapest-direct example dated 2024 with rate 232.30 that exists nowhere in the data, and the same two legs for `fastest` as for `cheapest` (the JSON gives QRST). We follow the JSON. Which is right?
2. **Fastest:** first departure to last arrival (layovers count), or the sum of leg durations?
3. **Connections:** are same-day connections allowed, and is there a minimum layover? We only have dates.
4. **Unknown ports:** save the search and warn (current), or reject it?
5. **Currencies without decimals:** should JPY be printed with decimals or as received (current)?
6. **Maximum legs:** is there a sensible cap, given the cost of an unbounded search?
7. **Users:** is one shared set of saved searches fine, or should searches and notifications belong to a user?

**Possible improvement: a cache.** Every search reads the database (one query per port visited). Repeated queries could
be answered from a cache keyed by origin, destination and criterion, which would avoid hitting the database over and
over. It is not built because the data is small and each CLI call is a separate process, so the cache would have to live
outside it (PostgreSQL table or Redis). The hard part is consistency when the source of truth changes: the cache must be
invalidated by every import that changes data, even one that only adds exchange rates or deactivates sailings. A simple
and safe rule is to store, with each entry, the id of the last completed import it was computed against, and to ignore
entries from older imports. Without such a rule, a cached answer could outlive the data it came from and show a sailing
that has been deactivated or a rate that has changed.

### Import

**Assumptions**
1. Each feed is a full snapshot and is meant to **override** the current view. New and changed sailings are written, and
   sailings missing from the feed become inactive. A later snapshot overwrites a sailing's fields.
2. History is kept, not deleted: every import is recorded, rates are appended per import, and inactive sailings stay in
   the table.
3. Rates for conflicting or missing sailings are ignored and recorded in `import_issues`.

**Open Questions**
1. **MNOP:** two rates for one sailing (456.78 and 812.00 USD). We keep the highest; should it be the lowest, the latest, or a hard error?
2. **Snapshot or delta feeds:** do feeds replace everything (we deactivate missing sailings) or only add changes?
3. **Unpriced sailings:** sailings without a rate or exchange rate are excluded everywhere. Should they be shown or flagged?
4. **Conflicting sailing fields:** a sailing code with different route or dates is excluded. Is that right, or should the latest win?

**Possible improvement: smarter updates.** Imports are deliberately simple: a feed replaces the current state. If MapReduce
sends frequent or partial updates, a smarter merge could use versioning, for example a version or timestamp per sailing
and rate so that older data never overwrites newer data, plus delta feeds that add or remove only what changed. We kept
it simple for this challenge.