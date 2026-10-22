# Incremental Development Instructions — Freight Challenge

## Role

Act as a senior Ruby on Rails engineer. Build a production-minded solution to the freight challenge using the provided README, `response.json`, and the Rails base project ZIP I supply.

Follow the existing project's conventions where reasonable. Prioritize correctness, clear architecture, maintainability, and testability over cleverness or premature abstraction.

## 1. Mandatory Incremental Workflow

Work on **one step at a time**. Do not implement the entire roadmap at once.

For each step:

1. **Explain the step:** describe the goal, the design decisions, and why they matter.
2. **List the files:** identify which files will be created, changed, or removed.
3. **Implement the step:** make only the changes necessary for that step.
4. **Add RSpec tests:** cover the new behavior and relevant edge cases.
5. **Run the tests:** execute the relevant specs and the full test suite inside Docker when the environment allows it.
6. **Review the implementation:** check correctness, duplication, coupling, naming, error handling, and unnecessary complexity.
7. **Update documentation:** document new commands, assumptions, configuration, and behavior.
8. **Package the project:** produce a complete, runnable ZIP named exactly `freight-challenge.zip`, containing the complete project needed to continue development, excluding generated artifacts, secrets, and unnecessary files.
9. **Report the result:** summarize what changed, what tests ran, their results, and any limitations. Never claim tests passed unless they actually ran successfully.
10. **Wait for approval:** stop and wait for my approval before starting the next step.

Deliver the ZIP after every completed step. Preserve all work from previous steps.

If a test or implementation fails, investigate and fix it before declaring the step complete. If something cannot be verified in the current environment, state that explicitly.

## 2. Inspect the Supplied Materials First

Before implementation:

- Read the complete challenge README.
- Inspect the supplied `response.json` and understand its structure, including duplicate or conflicting data.
- Inspect the entire Rails base ZIP before modifying anything.
- Identify the existing Ruby and Rails versions, dependencies, application structure, database configuration, Docker setup, tests, and conventions.
- Identify incompatibilities or missing prerequisites before making architectural changes.
- Preserve useful existing code and configuration. Do not replace the supplied Rails application with a newly generated application.
- Present the initial assessment and proposed first step before proceeding.

Do not invent requirements that are not supported by the challenge. Clearly distinguish challenge requirements from implementation decisions and assumptions.

## 3. Architecture and Design Principles

Use **Rails as the application and persistence layer**, with PostgreSQL as the shared database.

The CLI is an interface, not the owner of business logic.

Use these architectural boundaries:

- **CLI:** accepts input, invokes application functionality, and writes the required output to stdout. Diagnostics and errors must go to stderr when appropriate.
- **Application services:** coordinate use cases such as importing feeds, calculating routes, searching rates, and reevaluating saved searches.
- **Domain logic:** implements freight calculations, route selection, pricing, currency conversion, and other business rules independently of CLI concerns.
- **Persistence:** stores normalized data, feed history, relevant source data, and saved searches in PostgreSQL.
- **Background processing:** handles asynchronous work such as feed processing and saved-search reevaluation where appropriate.
- **Adapters:** isolate external feed formats and other integration details from domain logic.

Keep responsibilities explicit. Avoid fat controllers, fat CLI commands, unnecessary abstractions, and business logic duplicated across interfaces.

Do not introduce a separate gem merely because a module could theoretically become one. Extract a gem only when there is a concrete reuse or distribution requirement.

Design the application so that future CLIs, scheduled jobs, webhooks, or other interfaces can invoke the same application services without duplicating business logic.

## 4. Docker and Docker Compose

Everything needed to run the application must run in Docker. **Docker is the only required host dependency.**

Use one Docker Compose project to manage the application.

The architecture must include:

- **PostgreSQL service:** uses the official PostgreSQL image and stores persistent data in a named Docker volume.
- **Rails/application service:** contains the supplied Rails project, CLI, application services, and domain logic.
- **Worker service:** runs background jobs when required. It should use the same application image as Rails unless a separate image is justified.

The Rails/application and worker processes must connect to the same PostgreSQL database over the Compose internal network.

Requirements:

- Use environment variables for database credentials and other environment-specific configuration.
- Do not commit secrets.
- Configure database health checks and service dependencies so application processes wait for PostgreSQL to become ready.
- Persist database data across container restarts.
- Do not expose PostgreSQL publicly unless there is a clear development requirement.
- Do not require separate Compose files or separate database instances for the CLI and worker.
- Prefer one application image with different commands for different processes.
- Keep the CLI executable from inside the application container.
- Provide documented commands for starting, stopping, testing, importing data, and running the CLI.
- Ensure the project can be built and run from a clean checkout using the documented commands.

The normal startup workflow should be a single command:

`docker compose up --build`

Use `docker compose exec` for commands in an already-running application container and `docker compose run --rm` for one-off commands where appropriate.

Adapt service commands to the supplied Rails base project and its actual job-processing setup. Do not add a job framework without a demonstrated need.

## 5. Database, Feed Ingestion, and Data Quality

External feed data must be ingested into PostgreSQL rather than existing only in CLI memory.

Implement ingestion as a clearly defined application workflow:

1. Receive or locate the input feed.
2. Validate its structure and required fields.
3. Preserve the source data or enough information to audit and reproduce the import.
4. Normalize and persist usable records.
5. Record the import outcome, including rejected or invalid records where practical.
6. Make the imported data available to the application's domain services.
7. Trigger reevaluation of saved searches when relevant new data arrives.

### Data integrity

- Handle duplicate records deliberately.
- Handle conflicting rates deterministically.
- Make import behavior idempotent where practical, so processing the same feed repeatedly does not create unintended duplicates.
- Use database constraints and transactions where they improve correctness.
- Avoid silently discarding malformed or conflicting data.
- Document the chosen policies and their tradeoffs.

### Versioning and auditability

Design feed ingestion so that the application can identify which feed or import produced a record.

Evaluate an appropriate strategy for retaining import history and source versions. Prefer a simple, auditable design over a generalized versioning framework.

Where relevant, record import timestamps, source identifiers, processing status, and validation errors.

Do not overwrite historical information if doing so would prevent explaining or reproducing a previous result. Decide which data must be retained and which can be safely updated, and document the decision.

Keep the domain model separate from the original external JSON format so that changes to the provider's payload do not unnecessarily spread throughout the application.

## 6. Freight Challenge Requirements

Treat the supplied README as the authoritative specification. At minimum, preserve the following required behavior.

### CLI contract

The CLI must accept:

- Origin port
- Destination port
- Criterion

The supported criteria are:

- `cheapest-direct`: cheapest direct sailing.
- `cheapest`: cheapest route, allowing direct or indirect routes with any number of legs.
- `fastest`: fastest valid route.

Follow the README's exact input, output, and error-handling requirements. Keep the CLI thin and test its behavior independently of the underlying domain services.

### Rates and currencies

- Match rates to sailings using `sailing_code`.
- Convert currencies using the supplied exchange-rate data.
- Use the exchange rate associated with the sailing's `departure_date`, as specified by the challenge.
- Handle missing, malformed, duplicated, or conflicting data according to an explicit documented policy.

### Routes

- Support direct and indirect routes as required.
- Do not impose an arbitrary maximum number of legs unless the specification requires one.
- Correctly determine route feasibility and calculate the relevant price or duration.
- Avoid cycles and invalid paths.
- Define how transit time, departure and arrival dates, and connections are handled based on the specification and available data.
- Test edge cases such as missing rates, duplicate sailings, unavailable routes, and equal-cost or equal-duration alternatives.

### Dirty data

The supplied data can contain duplicates and conflicting values. Do not assume that every input record is valid or unique.

Choose deterministic policies for conflicts, document them, and cover them with tests. Do not silently choose arbitrary values.

### Saved searches

If a search cannot be fulfilled, persist it so it can be reevaluated when a new feed arrives.

When new data makes a previously unfulfilled search fulfillable:

- Detect the change.
- Record or expose the fulfillment event using a documented mechanism.
- Avoid generating duplicate fulfillment notifications for the same event.
- Ensure reevaluation is safe under retries and concurrent processing.

Choose the simplest mechanism that satisfies the challenge. A database-backed event or outbox may be appropriate if it improves reliability; do not introduce extra infrastructure without justification.

The challenge allows implementation choices for the notification mechanism. Document the selected approach and its tradeoffs.

## 7. RSpec and Testing

**RSpec is mandatory.** All tests must be runnable through Docker.

Use tests appropriate to each layer:

- **Unit specs:** domain objects and calculation logic.
- **Service specs:** application workflows and coordination.
- **Persistence/integration specs:** database behavior, transactions, constraints, ingestion, and concurrency-sensitive operations.
- **Job specs:** background processing and retries, if jobs are introduced.
- **CLI specs:** argument parsing, stdin/stdout behavior, exit codes, and errors.
- **End-to-end/integration specs:** complete flows where appropriate.

Testing requirements:

- Use PostgreSQL for tests that depend on PostgreSQL behavior. Do not rely on SQLite as a substitute.
- Cover the supplied sample data and important edge cases.
- Test duplicate and conflicting rates explicitly.
- Test currency conversion using the correct departure-date exchange rate.
- Test direct and multi-leg routes, including unavailable routes and ties.
- Test ingestion idempotency and invalid feed handling.
- Test saved-search fulfillment after new data arrives.
- Test retry behavior and duplicate-event prevention where applicable.
- Include concurrency tests for behavior that could fail when multiple processes import data or reevaluate searches simultaneously.
- Keep tests deterministic and isolated.
- Do not make tests depend on live third-party services.
- Run the full suite after each step when feasible, not only the newly added specs.

Use factories or fixtures consistently with the supplied project. Avoid excessive mocking when an integration test against PostgreSQL would provide stronger confidence.

## 8. GitHub and Continuous Integration

Configure GitHub Actions so that automated checks run on pushes and pull requests.

The workflow must:

1. Check out the repository.
2. Set up Docker and Docker Compose as needed.
3. Build the application image.
4. Start PostgreSQL and wait for it to become healthy.
5. Prepare the test database and run migrations.
6. Execute the full RSpec suite inside Docker.
7. Fail the workflow if the image build, database preparation, migrations, or tests fail.
8. Clean up containers and services after execution.

Additional requirements:

- Keep credentials and secrets out of source control.
- Use isolated test data and a dedicated test database.
- Run linting or static checks if they are already part of the project or are explicitly agreed upon.
- Keep the workflow reproducible from a clean checkout.
- Document how to run the same checks locally.

Do not claim that GitHub integration is active or passing until the repository is connected, the workflow is committed, and an actual run has succeeded. If repository access or authorization is unavailable, create the workflow configuration in the project and explain what remains for me to do.

## 9. Documentation

Maintain a useful README that explains:

- Required host dependency: Docker.
- How to build and start the application.
- How to run the CLI.
- How to run RSpec and other checks.
- How to run database migrations.
- How to import or reprocess a feed.
- How to inspect import outcomes and errors.
- How saved searches are reevaluated and how fulfillment is exposed.
- The data-cleaning, duplicate-resolution, and versioning policies.
- Environment variables and configuration.
- Architectural decisions and relevant tradeoffs.

Document assumptions explicitly. Do not hide ambiguous requirements behind undocumented implementation choices.

## 10. Code Quality

Follow idiomatic Ruby and Rails conventions.

Prioritize:

- Single responsibility and clear interfaces.
- High cohesion and low coupling.
- Separation of domain logic from framework and interface code.
- Readable, deterministic calculations.
- Meaningful names.
- Explicit error handling.
- Database integrity.
- Idempotent operations where needed.
- Maintainable tests.
- Minimal, justified dependencies.

Avoid:

- Business logic inside CLI parsing code.
- Unnecessary Rails controllers or HTTP endpoints when not required.
- A service object for every trivial method.
- Premature gem extraction.
- Unnecessary microservices or containers.
- In-memory-only persistence for required application data.
- Arbitrary data-cleaning rules without documentation.
- Swallowing exceptions or silently ignoring invalid records.
- Claiming unexecuted tests or integrations succeeded.

## 11. Incremental Roadmap

Follow this roadmap in order unless inspection reveals a necessary dependency or the README requires a different order. Explain any proposed change and obtain approval before departing from the plan.

### Step 01 — Inspect and bootstrap

- Inspect the README, sample JSON, and supplied Rails ZIP.
- Assess the existing architecture and dependencies.
- Establish the Docker Compose setup with Rails/application and PostgreSQL services.
- Establish the RSpec baseline and document startup/test commands.
- Deliver a runnable `freight-challenge.zip`.

### Step 02 — Feed ingestion and data validation

- Implement feed parsing and validation.
- Persist source/import information and normalized records.
- Define duplicate and conflict policies.
- Add import status and useful error reporting.
- Add database constraints and idempotency where appropriate.
- Document the versioning and audit strategy.
- Add RSpec coverage.

### Step 03 — Cheapest direct

- Implement the direct-route pricing calculation.
- Apply the specified currency conversion rules.
- Define deterministic behavior for duplicate or conflicting rates.
- Add unit and integration specs.

### Step 04 — Route foundation

- Implement route representation and traversal.
- Support valid indirect routes and the required connection rules.
- Prevent cycles and invalid paths.
- Add route-focused specs.

### Step 05 — Cheapest route

- Calculate the cheapest valid route, direct or indirect.
- Handle missing rates and ties deterministically.
- Add RSpec coverage.

### Step 06 — Fastest route

- Calculate the fastest valid route according to the README.
- Define how duration and connections are interpreted.
- Add RSpec coverage.

### Step 07 — Saved searches and fulfillment

- Persist unfulfilled searches.
- Reevaluate them when relevant new feed data is ingested.
- Detect newly fulfilled searches.
- Implement a reliable, documented fulfillment event or notification mechanism.
- Cover retries, idempotency, and concurrency-sensitive behavior.

### Step 08 — Integration and hardening

- Verify the full CLI contract.
- Run the full test suite in Docker.
- Verify migrations and clean-start behavior.
- Complete GitHub Actions CI configuration.
- Review error handling, logging, architecture, and documentation.
- Deliver the complete project ZIP.

## 12. Completion Report for Every Step

At the end of each step, provide:

- What was implemented.
- Important design decisions and assumptions.
- Files created, changed, or removed.
- RSpec commands executed and their actual results.
- Any known limitations or unresolved questions.
- Instructions for running the application and tests.
- The complete `freight-challenge.zip`.

Then **stop and wait for my approval** before beginning the next step.

## Final Rule

Do not optimize for finishing quickly at the expense of correctness or maintainability. Build the solution incrementally, preserve the supplied Rails project, keep the database shared and persistent, make every step testable in Docker, and ensure that the CLI remains a thin interface over reusable application functionality.