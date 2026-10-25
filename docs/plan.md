# Freight Challenge: Build Instructions

## Role

Act as a senior Ruby on Rails engineer. Build the freight challenge from the README, `response.json`, and the Rails base project I supply. Follow the base project's conventions. Prioritize correctness, clear architecture, and testability over cleverness. The solution is graded on OO concepts, SOLID, DRY and test coverage, and I must defend every decision live, so prefer designs that are simple to explain. Do not build infrastructure the challenge does not need.

## 1. Workflow

Build everything in one pass. There are no approval gates.

1. Read the README, the sample JSON, and inspect the whole Rails base. If the Rails base is missing, stop and tell me. Never generate a new app in its place.
2. Preserve useful existing code and configuration.
3. Implement, test, and fix until the full suite passes inside Docker.
4. Do not claim anything passed unless it actually ran. State what could not be verified (for example CI).
5. Keep chat output and code comments short. No long explanations.

### Git and delivery

- If the base is not a git repo, init one and commit the untouched base first.
- Use **one branch** (`freight-challenge`) with **small, clear commits**: imperative messages, one concern each. Each commit should leave the app working.
- **Ticket IDs:** the README defines four tickets: PLS-0001 (cheapest-direct), WRT-0002 (cheapest), TST-0003 (fastest), SLD-0004 (saved searches). Prefix the message of every commit that implements one of them with its ID, for example `PLS-0001: Add cheapest-direct strategy`. Commits that do not implement a ticket (Docker, persistence, ingestion, CLI plumbing, CI, docs) get no ticket ID. Never tag a commit with a ticket it does not deliver.
- Deliver only `freight-challenge.bundle` (`git bundle create`) and run `git bundle verify` on it. Do not produce a zip. I will create it myself.
- Final report, short: what was built, commands run with their real results, known limitations, and the Questions for the PO.

## 2. Architecture

Rails is the application and persistence layer, PostgreSQL the shared database. Why Rails: persistence is required for saved searches, a central DB supports future interfaces and users, and Rails conventions keep the code organized and defensible.

- **Domain (plain Ruby, no ActiveRecord):** money, exchange rates, sailings, routes, route search, pricing. Testable without a database.
- **Criteria as strategies:** `cheapest-direct`, `cheapest`, `fastest` behind one interface. A new criterion must not require modifying existing ones.
- **Repository boundary and data access (important):** a search must use a **constant number of database queries, independent of path length and of the number of ports visited**. Never query per port or per leg. The domain depends on a small interface, `reachable_from(origin)`, that returns every active, priced sailing reachable from the origin through time-feasible connections (next departure date >= previous arrival date), plus the exchange rates needed to compare them. ActiveRecord implements it with **one recursive CTE** (`WITH RECURSIVE ... UNION`, which deduplicates sailings so cycles terminate) and **one query** for the exchange rates of the dates involved: **at most 2 queries per search**. SQL decides which sailings are priced (an effective rate row exists and, for non-EUR currencies, an exchange rate exists for the departure date). All arithmetic stays in Ruby with BigDecimal, so currency conversion lives in one place. The route search then runs Dijkstra in memory over the loaded sailings (indexed by origin port, sorted by departure date). An in-memory repository implements the same interface for domain unit tests. `known_port?` checks both ports in one query and runs only for unfulfilled searches. The database is configured via `DATABASE_URL`. Another store means writing another adapter. Do not build a plugin system.
- **Application services:** `ImportFeed`, `SearchRoutes`, `ReevaluateSavedSearches`.
- **Feed adapter:** isolates the MapReduce JSON format from the domain.
- **CLI:** parses input, calls a service, prints the result. No business logic.

No controllers or HTTP endpoints unless required. No gem extraction.

## 3. Docker

Docker is the only host dependency.

- Compose services: **PostgreSQL** (official image, named volume, health check, not exposed) and **app**. No worker service, no Redis, no cache.
- One image. Credentials and config come from environment variables. No committed secrets.
- **Migrations are part of the container startup.** The entrypoint waits for Postgres health, runs `db:prepare` (idempotent), then runs the seed import, then hands over to the command. No manual migration step on the host.
- **Cold start:** the bundled `response.json` is imported synchronously by the entrypoint, idempotent by checksum. The seed file path is configurable (env var such as `FEED_PATH`, default: the bundled file), so a reviewer can swap in their own feed, including a larger one, without code changes. `bin/freight import FILE` must also work inside the container. The import is safe if two containers start together (advisory lock or unique constraint). The CLI must never run against an empty database because a seed was pending, or a valid search would wrongly be saved as unfulfilled.
- One documented sequence from clean checkout to printed result, for example `docker compose run --rm -T app bin/freight < input.txt`.
- Document start, stop, test, import, and CLI commands.

## 4. Ingestion, merging and versioning

`ImportFeed` is a synchronous service callable from the CLI, the entrypoint, tests, or a future job.

1. Validate structure and required fields. Compute the file checksum. Same checksum already imported means no-op.
2. Store the raw payload and an **import record**: id, timestamps, source, status, counts, rejected and conflicting rows with reasons.
3. Normalize and persist in **batches** (`upsert_all`) inside one transaction.
4. After commit, call `ReevaluateSavedSearches`.

Merge and versioning rules:

- **Never wipe or hard-delete.** Every persisted row records the import that produced it.
- **Sailings** upsert by `sailing_code` and carry `last_seen_import_id`. Each feed is assumed to be a **full snapshot**: after a successful import, sailings not seen in it are marked **inactive**, not deleted. Inactive sailings are excluded from searches.
- **Rates are append-only** with `import_id`. The effective rate of a sailing is resolved from the latest import that contained it (policy in section 5), so any past result can be explained.
- Same `sailing_code` with different route or date fields: treat as a conflict, exclude the sailing, and record it.
- Identical duplicates collapse. Malformed records are rejected and recorded, never silently dropped.
- Use database constraints (unique keys, foreign keys, not null) and transactions.

## 5. Data policies (decided)

- **Conflicting rates for one sailing (for example MNOP: 456.78 vs 812.00 USD):** keep the **highest** (compared in EUR). Deterministic and independent of feed order. Record the discarded rate. Expected `cheapest-direct` for CNSHA to NLRTM: **ABCD** (about 523.36 EUR).
- **Unpriced sailings** (no rate row, or no exchange rate for the departure date) are **excluded from every criterion**. Every output leg needs a rate. Record the reason. PO question Q5.
- **Conflict with an unconvertible candidate:** the sailing stays unpriced. Record the conflict and the reason in the import record.
- **Currency:** exchange rates are EUR-based, so USD to EUR means **dividing**. EUR has an implicit rate of 1. Use the rate for the sailing's `departure_date`, no carry-forward from other dates. Normalize currency case (lowercase in `exchange_rates`, uppercase in `rates`). Use `BigDecimal` everywhere, including parsing JSON numbers.
- **Output:** each leg keeps its original rate and currency. Conversion is for comparison only.
- **Rate precision is checked by value.** `"97453.00"` JPY is accepted. A rate that would change by rounding is rejected and recorded, never silently rounded. Keep per-currency decimal places in a small config map (JPY 0, USD 2, EUR 2, default 2). **Output the rate string exactly as received.** The by-value check is validation only.
- **Connections:** next departure date >= previous arrival date. Same-day connections are allowed with zero layover. The data has dates only, so a same-day connection may be physically impossible. Document this.
- **No maximum number of legs.** Prevent cycles (no port revisited) and handle dead ends.
- **Fastest:** first departure to last arrival, layovers included. Alternative (sum of leg durations) is documented.
- **Tie-breaks (deterministic, tested):** cheapest: lower total EUR, then fewer legs, then earlier arrival, then sailing codes ascending. Fastest: shorter duration, then lower total EUR, then fewer legs, then sailing codes ascending.
- **README vs JSON mismatches:** the JSON is the source of truth. For example, the README shows ERXQ arriving 2022-02-06, the JSON says 2022-02-12. Do not force the README output and do not assert the README's literal output where it contradicts the JSON. List each mismatch as a PO question.

Expected results on the sample, as a sanity check: cheapest = ERXQ + ETRG (about 322.89 EUR; ERXQ + ETRF is about 323.76); cheapest-direct = ABCD; fastest = QRST (17 days, versus 22 for ERXQ + ETRG).

## 6. CLI contract

Input on stdin, one per line: origin port, destination port, criterion. Output on stdout: a JSON array of legs (`origin_port`, `destination_port`, `departure_date`, `arrival_date`, `sailing_code`, `rate`, `rate_currency`). stdout carries only the result, printed with `JSON.pretty_generate` to match the README examples. Input lines are not echoed.

- **Tolerant stdin:** strip trailing newlines, CRLF line endings, surrounding whitespace, and trailing blank lines before counting lines. Valid input must never trigger the "extra input lines" error because of formatting. Only real extra content does.
- Normalize ports (trim, uppercase) and validate `[A-Z]{2}[A-Z0-9]{3}`.
- **Malformed port, invalid criterion, missing or extra input lines:** JSON error on stderr with an HTTP-style code, exit **2**.
- **Well-formed but unknown port, or no route:** print `[]`, exit **0**, save the search. Print a warning on stderr for unknown ports so typos do not pass silently.
- **Internal error, including a search statement timeout (resource limit):** JSON error on stderr, exit **1**. No route is printed.
- Other commands: `import FILE`, `notifications list`, `notifications ack`.

## 7. Saved searches and fulfillment (SLD-0004)

- An unfulfilled search is persisted, deduplicated by origin, destination and criterion.
- After a committed import, `ReevaluateSavedSearches` processes pending searches in batches, claiming rows with `FOR UPDATE SKIP LOCKED`. It is safe under retries and concurrent runs.
- **Group pending searches by origin:** one `reachable_from` load per distinct origin, then run each (destination, criterion) search in memory over the same loaded data. Never one load per saved search.
- A newly fulfillable search is marked fulfilled and a **fulfillment event** is written to an outbox table. A unique constraint guarantees one event per search.
- **Pull model:** `notifications list` (paginated, filterable) and `notifications ack` (several ids, or all up to an id). A CLI cannot subscribe, so the outbox is the mechanism.
- Bulk case: queries and notifications are separate. Each query answers immediately. Fulfillments arrive later and can be many, hence pagination and bulk ack. Client errors are per-query exit codes, not notifications.
- A push webhook is documented as the next step, not built. Document the tradeoffs.

## 8. Scale

Build the cheap parts:

- **Constant queries per search** (section 2) and **one load per origin** during reevaluation (section 7).
- Batched upserts, never row-by-row inserts.
- A partial index on active sailings, `(origin_port, departure_date, sailing_code)`, to support the recursive step.
- `last_seen_import_id` and append-only rates (section 4).
- **Statement timeout** on search queries (configurable). If it fires, fail with an explicit resource-limit error (JSON on stderr, exit 1). Never return a partial or best-so-far route as if it were optimal.
- **Benchmark script** `bin/benchmark`: generates a synthetic graph (configurable ports and sailings) and reports, per size: load time, search latency (p50 and max over a fixed set of queries), SQL query count per search, and peak memory if measurable. Run it at 10k, 100k and 1M sailings and put the real numbers in the README, with the gap to the 10M target stated plainly. Do not claim scale beyond what was measured.

**Results are exact.** The search is globally optimal. No cap on legs, no search horizon, no "bounded" mode, no best-so-far answers.

**Search design:** best-first search over **sailings**, not ports (a node is a sailing). Per-port labels would be wrong, because connections are time-dependent and a cheap but late arrival at a port can lose to a costlier but earlier one. A sailing fixes its own arrival date, so routes ending in the same sailing differ only in accumulated cost (or elapsed time), and the sort key must grow with each added leg and keep its order when the same legs are appended. State this argument in a code comment and prove it with the brute-force equivalence spec (section 9). Do not replace it with per-port Dijkstra.

**Do not build** a cache, a job queue, a worker, or Redis. Document them in a short "Scale path" README section, together with: a search horizon (as an opt-in, explicitly non-global mode), a frontier or database-assisted search for subgraphs too large for memory, a precomputed reachability table per port pair, a streaming parser, a staging table or `COPY`, parallel reevaluation, webhook delivery, and sharding. If a cache is ever added, its key must include origin, destination, criterion and the data version, and an import must invalidate it.

State the current limits plainly: the feed is parsed in memory, and a search loads the whole reachable subgraph of its origin, so memory grows with it. Report where the benchmark shows this becoming a problem.

## 9. Testing

RSpec is mandatory, run through Docker, with PostgreSQL for anything database-dependent (no SQLite). Add **SimpleCov** and report coverage.

- Unit: domain, conversion, route search, strategies (no DB).
- Service and persistence: import, constraints, idempotency, reevaluation.
- CLI: stdin and stdout, stderr, exit codes.
- End to end: the three README scenarios on the sample data (with the JSON as source of truth), plus an unfulfilled search fulfilled by a second feed.
- Explicit cases: MNOP conflict, unconvertible conflict, missing exchange rate and missing rate (fabricated data), precision rejection, JPY output string, departure-date conversion, more than two legs, dead end (ETRB), cycle, same-day connection (fabricated), time-infeasible connection, ties, inactive sailings after a snapshot import, import idempotency, invalid feed.
- Concurrency, two tests only: (1) two imports of the same checksum create no duplicates; (2) several simultaneous searches run while an import commits, and each returns a result consistent with either the old or the new data, never a mix, with no errors.
- **Query budget spec:** count SQL queries (`sql.active_record`) during one search over a chain of seven single-sailing hops (A to H) and assert at most 2. A shorter chain must give the same count. Also assert that reevaluation runs one load per distinct origin, not per saved search.
- **Equivalence spec:** compare the route search against a brute-force reference (exhaustive enumeration of simple paths) on small randomized graphs, for all three criteria.
- Deterministic, isolated, no live services. Run the full suite before delivering.

## 10. CI

GitHub Actions on push and pull request: check out, build the image, start Postgres and wait for health, `db:prepare`, run the full RSpec suite in Docker, fail on any error, clean up. Depends only on files in the repo. No secrets. Run linting only if the base already uses it. Do not claim CI is passing unless a real run succeeded. If it cannot be run, say so.

## 11. README

Cover: Docker as the only dependency, clean-checkout-to-result commands, running the CLI with piped stdin, running tests and CI checks locally, migrations (run at startup), importing or reprocessing a feed, inspecting import outcomes and errors, saved search and notification flow, data policies, error contract, environment variables, architecture and tradeoffs (including why Rails), scale path and limits, assumptions, and **Questions for the PO**.

PO questions to include at minimum: MNOP policy, highest vs lowest; README vs JSON mismatches; fastest definition; same-day connections and minimum layover; unpriced sailings (Q5); snapshot vs delta feeds; unknown ports; output formatting for currencies without decimals; conflicting sailing fields.

## 12. Code quality

Idiomatic Ruby and Rails. Single responsibility, high cohesion, low coupling, domain separated from framework code, explicit error handling, no swallowed exceptions, no silently ignored records, minimal dependencies. No service object for every trivial method.

## 13. Suggested commit sequence

Specs are committed with the code they cover. Only commits that deliver a README ticket carry its ID.

1. Base project as supplied.
2. Docker, Compose, entrypoint with `db:prepare`, RSpec and SimpleCov baseline.
3. Domain: money, exchange rates, sailing, rate resolution.
4. `PLS-0001:` Cheapest-direct strategy.
5. Route search with time-feasible connections over the in-memory graph loaded by `reachable_from` (recursive CTE, at most 2 queries).
6. `WRT-0002:` Cheapest strategy. `TST-0003:` Fastest strategy (separate commits).
7. Migrations, models, constraints, repository.
8. `ImportFeed`: validation, checksum, batching, versioning, inactive marking.
9. Seed import at startup.
10. CLI and error contract.
11. `SLD-0004:` Saved searches, reevaluation, outbox and notifications commands.
12. GitHub Actions.
13. README, PO questions, scale path.

## Final rule

Correctness and maintainability over speed. Keep the supplied Rails project, the domain in plain Ruby, the database shared and persistent, every test runnable in Docker, and the CLI a thin interface over reusable services.