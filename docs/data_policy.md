# Data policy (Step 01: approved)

Decisions are written down before any code. "Sample" means `db/feeds/response.json`; every number below was computed from it.
Each policy lists the alternative that was considered.

## 1. Findings in the sample data

| # | Finding | Impact |
|---|---------|--------|
| F1 | `MNOP` has two rates: 456.78 USD and 812.00 USD (no timestamp, no source). | Decides the `cheapest-direct` answer (P1). |
| F2 | README says `ERXQ` arrives 2022-02-06; the JSON says 2022-02-12. | README examples cannot be reproduced from the JSON. |
| F3 | README `fastest` example is `ERXQ + ETRG`. With the JSON, the fastest first-departure-to-last-arrival is the direct `QRST`, 17 days; `ERXQ + ETRG` takes 22 days (01-29 to 02-20). Even with ERXQ arriving 02-06 it is still 22 days. | The README example only holds if "fastest" means the sum of leg durations and ERXQ arrives 02-06 (12 days). With JSON dates that sum is 18 days, still slower than QRST. |
| F4 | README `cheapest-direct` example uses 2024 dates, code `XXXX`, rate 232.30. | Placeholder, never asserted. |
| F5 | README `cheapest` example shows `ERXQ` arriving 02-06 (see F2). The route and rates match the JSON. | Tests assert route and totals, not the README's literal output. |
| F6 | `ETRB` (ESBCN to BRSSZ) leads nowhere for CNSHA to NLRTM. | Dead end, must not break search. |
| F7 | No sailing without a rate, no rate without a sailing, and every departure date has an exchange rate. | The missing-data policies never trigger on the sample; they are tested with fabricated data. |
| F8 | Dates only, no times. | Durations are whole days; a same-day connection may be physically impossible. |

Reference values (EUR = amount / EUR-based rate of the departure date): ABCD 523.3570, EFGH 890.3200, IJKL 742.7820, MNOP 410.1095 (456.78 USD, discarded) or 729.0357 (812.00 USD, kept), QRST 761.9600, ERXQ 261.9600, ETRF 61.7957, ETRG 60.9302, ETRB 383.1737.

## 2. Approved policies

**P1 Conflicting rates for one sailing (APPROVED: keep the highest).** Compared in EUR; the highest wins. Deterministic, independent of feed order, and never under-quotes. The discarded rate is **not dropped silently**: it is recorded in the import record as a rejected/conflicting row (reason `conflicting_rate`, with the kept rate). Ties in EUR: lowest currency code alphabetically.
- Sample effect: `MNOP` = 812.00 USD (729.0357 EUR), so `cheapest-direct` = `ABCD`.
- Alternatives: lowest (optimistic, may be unbookable); last or first in feed (depends on arbitrary order); exclude until the PO confirms.
- Tests: a unit test on the conflict resolver and a sample-data test for `cheapest-direct`. PO question Q1.

**P2 "Fastest" (APPROVED: first departure to last arrival, layovers included).** Calendar days from the first leg's departure to the last leg's arrival. Sample: `QRST` (17 days) beats `ERXQ + ETRG` (22 days), which differs from the README example; we do **not** force the README output and **no test asserts it**.
- Alternative: sum of leg durations (ignores waiting between legs).
- Every README vs JSON mismatch (F2 to F5) is a PO question (Q2, Q3).

**P3 Connections (APPROVED: same-day allowed, zero minimum layover).** A connection is valid if `next.departure_date >= previous.arrival_date`, because the data only has dates. A same-day connection may be physically impossible (PO question Q4). The sample contains no same-day connection, so it is tested with fabricated data. No maximum number of legs. A port is never visited twice (origin included).

**P4 Missing exchange rate or rate row (APPROVED: exclude and record).**
- Non-EUR sailing with no exchange rate for its departure date: stored, left **unpriced**, recorded in the import data-quality log (`missing_exchange_rate`). No carry-forward from nearby dates.
- EUR needs no exchange rate (implicit rate 1).
- Sailing with no rate row at all: same treatment (`missing_rate`).
- Implementation detail (Step 02): an unpriced sailing is not in the searchable catalogue, so **no criterion can return it** (not only price comparison). Reason: it cannot be ranked or tie-broken by EUR price, and the README output needs a rate on every leg. Alternative: let `fastest` use it. PO question Q5.
- A conflict that cannot be compared because one candidate lacks an exchange rate leaves the sailing unpriced too (we cannot know which rate is highest).
- Fabricated-data tests only; the sample never triggers this.

**P5 Unknown ports (APPROVED: CHANGED, save any well-formed code).** Input is trimmed and upper-cased, then validated against `[A-Z]{2}[A-Z0-9]{3}`.
- Malformed: client error, exit 2.
- Well-formed but not in the current data: handled like any unfulfilled search: `[]` on stdout, exit 0, the search is saved, plus a warning on stderr (`port not in current data`) so typos do not fail silently.
- Saved searches are deduplicated by (origin, destination, criterion).
- Reason: SLD-0004 covers routes we cannot fulfil yet, and a port may only appear in a future feed.

**P6 Feed type (APPROVED: full snapshot).** The README says the service returns *all* shipping options, so the latest successful import is the active catalogue. Sailings absent from it are marked **inactive, not deleted**, so history stays explainable. Re-importing identical content (same checksum) is a no-op.
- Alternative: delta feed (never deactivate anything). PO question Q6.
- Saved-search fulfilment must behave the same under either assumption: after each import, pending searches are re-evaluated against the active catalogue and each is fulfilled at most once. Under a delta feed nothing is deactivated, but the same code path runs.

**P7 Currency and money.** `BigDecimal` everywhere; JSON numbers parsed as BigDecimal. Exchange rates are EUR-based, so non-EUR to EUR means **divide**. Currency codes upper-cased. Converted values are used only to compare and are never rounded before comparing. Output keeps each leg's original amount and currency.

**P8 Output amount format.** Minor units per currency: 2 decimals for EUR/USD (`"589.30"`), 0 for JPY (`"97453"`), via a small explicit map (JPY 0, default 2). An amount whose value would be changed by rounding to the currency's minor units is rejected, not rounded (`"10.123"` USD, `"97453.5"` JPY). Trailing zeros lose nothing and are accepted (`"97453.00"` JPY prints as `"97453"`). Amounts must be plain decimals greater than zero (no signs, exponents, thousands separators).

**P9 Data validation.** Duplicate sailing: identity is `sailing_code`; identical duplicates collapse; same code with different route or dates = conflict, both rejected and recorded. Rate without sailing, malformed or non-ISO dates, arrival before departure, non-positive or non-numeric amounts, missing fields: the record is rejected and recorded. A structurally invalid file (missing top-level keys, wrong types) is rejected whole. Nothing is dropped silently.

**P10 Routing and tie-breaks.** `cheapest-direct`: single-leg routes only. `cheapest`: lowest sum of EUR-converted legs. Deterministic tie-breaks: cheapest = lower EUR total, then fewer legs, then earlier arrival, then lexicographic sailing codes in order. fastest = shorter duration, then lower EUR total, then fewer legs, then codes. cheapest-direct = lower EUR, then earlier arrival, then sailing code.

**P11 Saved searches.** Identity = (origin, destination, criterion); repeating a search never creates a second row; fulfilment is one event per search (unique constraint). Detail in Step 05.

## 3. Expected results on the sample (CNSHA to NLRTM)

| Criterion | Result | Check |
|-----------|--------|-------|
| `cheapest-direct` | `ABCD` | 523.3570 EUR (MNOP is 729.0357 under P1) |
| `cheapest` | `ERXQ + ETRG` | 322.8902 EUR. `ERXQ + ETRF` = 323.7557 EUR is the near-tie test (ETRF departs 02-15, after ERXQ arrives 02-12) |
| `fastest` | `QRST` | 17 days (vs 22 for `ERXQ + ETRG`) |

These three are asserted in the Step 02 to 03 specs; the README's literal outputs are not.
