# Incremental Development Instructions: Freight Challenge

## Role

Act as a senior Ruby on Rails engineer. Build a production-minded solution to the freight challenge using the provided README, `response.json`, and the Rails base project ZIP I supply.

Follow the existing project's conventions where reasonable. Prioritize correctness, clear architecture, maintainability, and testability over cleverness or premature abstraction.

Context that shapes every decision: the challenge is graded on Object Oriented concepts, SOLID, DRY and test coverage, and I will have to explain and defend every decision live. Prefer designs I can explain simply. Do not build infrastructure the challenge does not need.

## 1. Mandatory Incremental Workflow

Work on **one step at a time**. Do not implement the entire roadmap at once.

For each step:

1. **Explain the step:** goal, design decisions, and why they matter.
2. **List the files:** which files will be created, changed, or removed.
3. **Implement the step:** only the changes necessary for that step.
4. **Add RSpec tests:** cover the new behavior and relevant edge cases.
5. **Run the tests:** execute the relevant specs and the full suite inside Docker when the environment allows it.
6. **Review the implementation:** correctness, duplication, coupling, naming, error handling, unnecessary complexity.
7. **Update documentation:** new commands, assumptions, configuration, behavior.
8. **Package the project:** produce a complete, runnable ZIP named exactly `freight-challenge.zip`, containing the whole project needed to continue development and preserving all work from previous steps, excluding generated artifacts, secrets, and unnecessary files.
9. **Report the result:** what changed, which tests ran, their actual results, and any limitations. Never claim tests passed unless they actually ran successfully.
10. **Wait for approval:** stop and wait for my approval before starting the next step.

Delivery:

- Deliver the ZIP after **every** completed step.
- I will copy each ZIP into the project's single git branch myself (the challenge requires one branch). Do not run git commands or create commits. Just make sure each ZIP is self-contained and runnable.

If a test or implementation fails, investigate and fix it before declaring the step complete. If something cannot be verified in the current environment, state that explicitly.

## 2. Inspect the Supplied Materials First

Before implementation:

- Read the complete challenge README.
- Inspect the supplied `response.json` and understand its structure, including duplicate or conflicting data.
- Inspect the entire Rails base ZIP before modifying anything. If the ZIP is missing from the conversation, stop and tell me instead of generating a new application.
- Identify the existing Ruby and Rails versions, dependencies, application structure, database configuration, Docker setup, tests, and conventions.
- Identify incompatibilities or missing prerequisites before making architectural changes.
- Preserve useful existing code and configuration. Do not replace the supplied Rails application with a newly generated one.
- Present the initial assessment and proposed first step before proceeding.

Do not invent requirements that are not supported by the challenge. Clearly distinguish challenge requirements from implementation decisions and assumptions.

## 3. Architecture and Design Principles

Use **Rails as the application and persistence layer**, with PostgreSQL as the shared database. Reasons for this choice (to be reflected in the README): persistence is genuinely required for saved searches across feeds, a central database supports future multiple interfaces and concurrent users, and Rails conventions (models, migrations, constraints, validations, RSpec) keep the code organized and easy to defend.

The CLI is an interface, not the owner of business logic.

Architectural boundaries:

- **Domain (plain Ruby):** freight calculations, route search, pricing, currency conversion, and criteria. These are plain Ruby objects with **no ActiveRecord inside**. They receive data as plain value objects and are testable without a database.
- **Criteria as pluggable strategies:** `cheapest-direct`, `cheapest` and `fastest` are separate strategy objects behind a common interface, so a new criterion can be added without modifying existing code (the challenge says new requirements are coming).
- **Persistence (adapter):** ActiveRecord models and a repository or mapper layer convert between database rows and domain objects. The domain never depends on persistence.
- **Application services:** coordinate use cases such as importing feeds, searching routes, and reevaluating saved searches.
- **Feed adapter:** isolates the external MapReduce JSON format from the domain, so changes to the provider payload do not spread through the application.
- **CLI:** accepts input, calls an application service, writes the required output to stdout. Diagnostics and errors go to stderr.

Avoid fat CLI commands, unnecessary abstractions, and business logic duplicated across interfaces. Do not extract a gem unless there is a concrete reuse requirement. Design so that future CLIs, scheduled jobs, webhooks or other interfaces can call the same application services.

## 4. Docker and Docker Compose

Everything needed to run the application must run in Docker. **Docker is the only required host dependency.**

Services in one Docker Compose project:

- **PostgreSQL:** official image, persistent data in a named volume, health check, not exposed publicly.
- **Application:** the supplied Rails project, CLI, services and domain logic.
- **Worker: optional.** Not part of the initial build. Add it only in the optional last step, and only if everything else is solid. If added, it uses the same image as the application and a Postgres-backed queue (no Redis).

Requirements:

- Environment variables for credentials and environment-specific config. No committed secrets.
- Application processes wait for PostgreSQL health before starting.
- One application image, different commands for different processes.
- The CLI must be executable from inside the application container with piped stdin, for example `docker compose run --rm -T app <cli> < input.txt`. Document the exact command.

### Cold start (critical)

A reviewer will clone, start Docker, and run the CLI. It must work with minimal steps and return a correct result on the first attempt.

- The bundled `response.json` is imported **synchronously during container startup** (entrypoint or an explicit `db:seed`-style step), before the application is considered ready. The import must be idempotent, so restarts do not duplicate data.
- The CLI must never run against an empty database because the seed was still pending. A search that fails only because the seed has not loaded would wrongly be saved as unfulfilled.
- The normal startup workflow is a single command: `docker compose up --build`. Document one exact command sequence from clean checkout to printed result.

Provide documented commands for starting, stopping, testing, importing data, and running the CLI. Use `docker compose exec` for running containers and `docker compose run --rm` for one-off commands.

## 5. Database, Feed Ingestion, and Data Quality

External feed data must be ingested into PostgreSQL rather than existing only in CLI memory. Ingestion is a required part of the solution.

### Ingestion as a synchronous service

Implement ingestion as a plain application service (for example `ImportFeed`) that runs **synchronously** and can be called from anywhere (CLI, entrypoint, tests, and later a job). It must not depend on being inside a background job.

Workflow:

1. Receive or locate the input feed.
2. Validate structure and required fields.
3. Compute a checksum and preserve the raw payload (or enough to audit and reproduce the import).
4. Normalize and persist usable records using **batched** writes (`insert_all` / `upsert_all`) inside one transaction.
5. Record the import outcome: timestamps, source identifier, status, counts, and rejected or invalid records.
6. Make the data available to the domain services through the persistence adapter.
7. **After the import transaction commits**, trigger reevaluation of saved searches by calling the reevaluation service directly.

Large feeds: be explicit about limits. Batched inserts handle the sample and moderately large files. A truly huge file would need a streaming parser, which is out of scope. State this as a known limitation instead of building it.

### Data integrity

- Handle duplicate records deliberately.
- Handle conflicting rates deterministically.
- Idempotent imports: the same feed (same checksum) processed twice must not create duplicates or duplicate side effects.
- Use database constraints and transactions where they improve correctness.
- Never silently discard malformed or conflicting data. Record it.
- Document the chosen policies and tradeoffs.

### Versioning and auditability

Keep it simple and auditable: raw payload, checksum, and an import record. Each persisted record identifies the import that produced it. Do not overwrite history if that would prevent explaining a previous result. No generalized versioning framework.

Decide and document whether each feed is a **full snapshot** (the README says the service returns all available shipping options, which suggests so) or a delta, because this affects deduplication, removal of stale data, and saved-search reevaluation. State the assumption and list it as a question for the PO.

## 6. Data Policies (decide and document BEFORE writing code)

In Step 01, produce a short written data policy document and get my approval before any implementation. It must cover at least the following.

### Known data issues in the supplied JSON

- **Conflicting rates:** sailing `MNOP` has two rates (456.78 USD and 812.00 USD). The choice changes which sailing is cheapest direct. Propose a policy with its justification and alternatives. Do not silently pick one. List it as a PO question.
- **README vs JSON mismatches:** the README examples do not match the JSON. For example, the README shows ERXQ arriving 2022-02-06 while the JSON says 2022-02-12. Using the JSON as the source of truth, the fastest result may differ from the README's example. Do **not** write tests that assert the README's literal output where it contradicts the JSON. Flag every mismatch to me and list it as a PO question.
- **Missing data:** sailings without rates, rates without sailings, missing exchange rates, malformed dates and amounts. Define the policy for each.

### Currency and money

- Exchange rates are EUR-based, so converting a non-EUR amount to EUR means **dividing** by the rate for that currency. EUR has an implicit rate of 1.
- The rate used is the one for the sailing's `departure_date`. Define behavior when that exact date is missing.
- Currency codes are uppercase in `rates` and lowercase in `exchange_rates`. Normalize.
- Use `BigDecimal` everywhere, including when parsing JSON numbers. Never use floats for money.
- Conversion is used **only for comparison**. The output keeps each leg's **original rate and currency**.
- Define output formatting for amounts, including currencies without decimals such as JPY (`"97453"` vs `"97453.00"`).

### Routing rules

- Routes are searched over **sailings (legs) with time constraints**, not over a plain port graph. A connection is valid only if the next sailing departs at or after the previous sailing's arrival. Same-day connections and minimum layover are unspecified: choose a documented rule and list it as a PO question.
- No arbitrary maximum number of legs. More than two legs must work.
- Prevent cycles (do not revisit a port) and handle dead ends (for example ETRB to BRSSZ).
- `fastest` means the shortest total journey time from first departure to last arrival, including layovers. Document this interpretation and any alternative (for example summing leg durations).
- Deterministic tie-breaking for equal cost or equal duration, documented and tested.

### Questions for the PO

Maintain a "Questions for the PO" section in the README. The challenge asks for it. Include every ambiguity above plus any new ones found.

## 7. Freight Challenge Requirements

Treat the supplied README as the authoritative specification. Preserve at minimum:

### CLI contract

Input (stdin), one value per line: origin port, destination port, criterion.
Supported criteria: `cheapest-direct`, `cheapest`, `fastest`.
Output (stdout): a JSON array of sailing legs with `origin_port`, `destination_port`, `departure_date`, `arrival_date`, `sailing_code`, `rate`, `rate_currency`.

The README defines **no error contract**. Define and document one, then ask me to approve it:

- Unknown port code, invalid criterion, missing or extra input lines: message to stderr, non-zero exit code, nothing misleading on stdout.
- Unfulfilled search: define exactly what stdout shows (for example `[]`) and confirm the search is saved.
- stdout contains only the JSON result. Input lines are not echoed.

Keep the CLI thin and test it independently of the domain.

### Saved searches (SLD-0004)

If a search cannot be fulfilled, persist it so it can be reevaluated when a new feed arrives.

- Define search identity and deduplication. There is no user identity in the spec, so repeating the same search (origin, destination, criterion) must not create unbounded duplicates.
- After a feed import commits, reevaluate unfulfilled searches by calling the reevaluation service directly. Reevaluation must be safe under retries.
- When a search becomes fulfillable, record a **fulfillment event** in the database (a simple outbox-style table). A unique constraint guarantees one event per search fulfillment, so retries and concurrent runs cannot create duplicates.
- Expose fulfillment through a documented mechanism, for example a CLI command that lists and acknowledges pending fulfillment events. The challenge leaves this open: document the choice, assumptions and tradeoffs.

Do not introduce extra infrastructure (queues, brokers, webhooks) for this.

## 8. RSpec and Testing

**RSpec is mandatory.** All tests run through Docker. Use PostgreSQL for anything database-dependent. No SQLite.

Test by layer:

- **Unit:** domain objects, currency conversion, route search, criteria strategies (no database needed).
- **Service:** import and reevaluation workflows.
- **Persistence/integration:** constraints, transactions, idempotency.
- **CLI:** argument and stdin handling, stdout content, stderr, exit codes.
- **End-to-end:** the three README scenarios against the sample data, plus an unfulfilled search that is later fulfilled by a second feed.

Required coverage of behavior:

- Duplicate and conflicting rates (MNOP) under the documented policy.
- Conversion with the departure-date exchange rate, dividing by the EUR-based rate.
- Direct and multi-leg routes (including more than two legs), dead ends, cycles, unavailable routes, time-infeasible connections, and ties.
- Import idempotency and invalid feed handling.
- Saved-search fulfillment after a new feed, with no duplicate fulfillment events.
- **One concurrency test:** two imports of the same feed checksum produce no duplicate records. Not a full concurrency suite.

Other requirements:

- Add **SimpleCov** and report coverage. Test coverage is a graded criterion.
- Tests are deterministic, isolated, and independent of live third-party services.
- Run the full suite after each step when feasible.
- Prefer integration tests against PostgreSQL over heavy mocking.

## 9. GitHub and Continuous Integration

Configure GitHub Actions to run on pushes and pull requests.

The workflow:

1. Checks out the repository.
2. Builds the application image.
3. Starts PostgreSQL and waits for health.
4. Runs `db:prepare` (migrations).
5. Runs the full RSpec suite inside Docker.
6. Fails if the build, database preparation, or tests fail.
7. Cleans up containers.

Additional requirements:

- No secrets in source control. Dedicated test database.
- The workflow must depend only on files inside the submitted project.
- Run linting (for example RuboCop) only if the base project already uses it.
- Document how to run the same checks locally.

Do not claim CI is active or passing until the workflow is committed to a connected repository and a real run has succeeded. If repository access is unavailable, create the workflow file and tell me what remains for me to do.

## 10. Documentation

Maintain a useful README covering:

- Required host dependency (Docker) and the exact clean-checkout-to-result command sequence.
- How to build, start, stop, and run the CLI with piped stdin.
- How to run RSpec and CI checks locally.
- How to run migrations, and how to import or reprocess a feed.
- How to inspect import outcomes and errors.
- How saved searches are reevaluated and how fulfillment is exposed.
- Data policies: duplicates, conflicts, currency, versioning (see section 6).
- The error contract.
- Environment variables and configuration.
- Architectural decisions and tradeoffs, including why Rails, and known limitations (for example very large feeds).
- **Questions for the PO** and an explicit list of assumptions.

## 11. Code Quality

Follow idiomatic Ruby and Rails conventions.

Prioritize: single responsibility, clear interfaces, high cohesion and low coupling, domain separated from framework code, readable and deterministic calculations, meaningful names, explicit error handling, database integrity, idempotent operations, maintainable tests, minimal justified dependencies.

Avoid: business logic in CLI parsing, unnecessary controllers or HTTP endpoints, a service object for every trivial method, premature gem extraction, unnecessary containers, swallowed exceptions, silently ignored invalid records, and claiming unexecuted tests or integrations succeeded.

## 12. Incremental Roadmap

Follow in order. Explain and get approval before departing from it.

### Step 01: Inspect, bootstrap, and data policies

- Inspect the README, sample JSON, and the Rails ZIP. Assess architecture and dependencies.
- Establish Docker Compose with application and PostgreSQL services, health checks, and the RSpec baseline (with SimpleCov).
- Write the data policy document (section 6), the proposed error contract, and the first PO questions. **Wait for my approval of these policies before Step 02.**
- Document startup and test commands.
- Deliver a runnable `freight-challenge.zip`.

### Step 02: Domain foundation (plain Ruby)

- Value objects: port, sailing, rate, money, exchange rates.
- Currency conversion with BigDecimal using the departure-date rate.
- Rate resolution under the approved conflict policy.
- The `cheapest-direct` strategy.
- Unit specs with no database.

### Step 03: Route search and remaining criteria

- Time-feasible route search over legs, with cycle prevention and unlimited leg count.
- Pluggable criteria: `cheapest` and `fastest` as strategies, with documented tie-breaking.
- Route-focused unit specs, including dead ends, ties, and more than two legs.

### Step 04: Persistence and feed ingestion

- Migrations, models, constraints, and the repository/mapper layer to domain objects.
- Synchronous `ImportFeed` service: validation, checksum, raw payload, batched transactional upsert, import record, rejected records.
- Idempotency, the snapshot-vs-delta policy, and the single concurrency test.
- Document the versioning and audit strategy.

### Step 05: Saved searches and fulfillment

- Persist unfulfilled searches with deduplication.
- Reevaluation service called directly after a committed import.
- Fulfillment event table with a unique constraint, plus the documented exposure mechanism.
- Specs for retries and duplicate prevention.

### Step 06: Thin CLI and cold start

- CLI over the application service, implementing the approved error contract.
- Synchronous, idempotent seed import of the bundled `response.json` at startup.
- CLI specs and end-to-end specs for the README scenarios.
- Verify the single documented command from clean checkout to printed result.

### Step 07: CI, documentation, and hardening

- GitHub Actions workflow (section 9).
- Full test suite in Docker, migration and clean-start verification.
- Review error handling, logging, architecture, and documentation, including the PO questions.
- Deliver the final complete `freight-challenge.zip`.

### Step 08 (optional): Job wrapper

Only if Steps 01 to 07 are complete and solid, and only with my approval:

- A thin job that calls `ImportFeed` and then triggers reevaluation.
- Worker service in Compose, same image, Postgres-backed queue.
- Job specs. Synchronous import must remain available.

## 13. Completion Report for Every Step

At the end of each step provide:

- What was implemented.
- Design decisions and assumptions.
- Files created, changed, or removed.
- RSpec commands executed and their actual results.
- Known limitations or unresolved questions.
- How to run the application and tests.
- The complete `freight-challenge.zip`.

Then **stop and wait for my approval** before the next step.

## Final Rule

Do not optimize for finishing quickly at the expense of correctness or maintainability. Build incrementally, preserve the supplied Rails project, keep the domain in plain Ruby, keep the database shared and persistent, make every step testable in Docker, keep the CLI a thin interface over reusable services, and write down every data decision before coding it.