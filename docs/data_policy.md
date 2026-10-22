# Data policy (Step 01 — awaiting approval)

Decisions are written down before any code. Each one lists the alternatives so it can be defended or changed.
"Sample" means `db/feeds/response.json`; all numbers below were computed from it.

## 1. Findings in the sample data

| # | Finding | Impact |
|---|---------|--------|
| F1 | `MNOP` has two rates: 456.78 USD and 812.00 USD (no timestamp, no source). | Changes the `cheapest-direct` answer (see P1). |
| F2 | README `ERXQ` arrives 2022-02-06; JSON says 2022-02-12. | README examples are not reproducible from the JSON. |
| F3 | README TST-0003 (`fastest`) answer is `ERXQ + ETRG`. With the JSON, the fastest door-to-door is the **direct `QRST`, 17 days**; `ERXQ + ETRG` is 22 days (01-29 to 02-20). Even with ERXQ arriving 02-06 it is still 22 days. | README example only holds if "fastest" = sum of leg durations AND ERXQ arrives 02-06 (12 days). With JSON dates the sum is 18 days, still slower than QRST. |
| F4 | README `cheapest-direct` example uses 2024 dates, code `XXXX`, rate 232.30. | Placeholder; not asserted anywhere. |
| F5 | `ETRB` (ESBCN to BRSSZ) leads nowhere for CNSHA to NLRTM. | Dead end, must not break search. |
| F6 | JSON has no sailing without a rate, no rate without a sailing, and an exchange rate exists for every departure date. | Policies below still defined for when feeds are dirty. |
| F7 | Dates are plain dates (no times). | Durations are whole days; connections cannot be compared by hour. |

Reference values (EUR = amount / EUR-based rate of the departure date): ABCD 523.3570, EFGH 890.3200, IJKL 742.7820, MNOP 410.1095 (456.78) or 729.0357 (812.00), QRST 761.9600, ERXQ 261.9600, ETRF 61.7957, ETRG 60.9302, ETRB 383.1737.
`cheapest` (CNSHA to NLRTM) = `ERXQ + ETRG` = 322.8902 EUR, whichever MNOP rate is used (ERXQ + ETRF = 323.7557 is second).

## 2. Policies

**P1 Conflicting rates for one sailing (MNOP).** Proposed: keep the sailing, use the **highest** rate (compared in EUR), record every candidate as a data issue. Why: a freight forwarder that under-quotes loses money, and "highest" does not depend on feed order, so it is deterministic. Effect on sample: `cheapest-direct` = `ABCD` (523.3570).
Alternatives: lowest rate (`cheapest-direct` = `MNOP` at 456.78 USD; optimistic, may be unbookable); last in feed wins (depends on arbitrary order); first wins (same); exclude the sailing until the PO confirms (safe but hides a real option). Ties in EUR: lowest currency code alphabetically, then input order of the string amount.

**P2 Duplicate sailings.** Identity is `sailing_code`. Same code with identical route and dates = duplicate, collapsed. Same code with different route or dates = conflict, **both rejected** and recorded (we cannot know which is true).

**P3 Missing data.**
- Sailing without rate: stored, never returned by a search, recorded as an issue.
- Rate without sailing: rejected and recorded.
- Missing exchange rate for the departure date: EUR sailings are unaffected (rate 1). Non-EUR sailings are stored but excluded from price comparison, recorded as an issue. **No carry-forward from nearby dates** (we do not invent money). Alternative: use the latest earlier date.
- Malformed dates (not ISO `YYYY-MM-DD`, arrival before departure), non-numeric or non-positive amounts, unknown currency shape, missing fields: the record is rejected and recorded. A structurally invalid file (missing top-level keys, wrong types) is rejected whole.
- Nothing is dropped silently: every rejected record goes in the import record with the reason.

**P4 Currency and money.** `BigDecimal` everywhere, JSON numbers parsed as BigDecimal. Exchange rates are EUR-based, so non-EUR to EUR means **divide**; EUR is 1. Currency codes normalized to upper case (`usd` to `USD`). Converted values are used **only to compare**, never rounded before comparing. Output keeps each leg's original amount and currency.

**P5 Output amount format.** Amounts printed with the currency's minor units: 2 decimals for EUR/USD (`"589.30"`), 0 for JPY (`"97453"`). Minor-unit table is a small explicit map (JPY 0, default 2). An amount with more decimals than the currency allows is rejected, not rounded.

**P6 Feed type.** Assumed a **full snapshot** (the README says it returns *all* options): the latest successful import is the active catalogue, sailings missing from it are marked withdrawn (kept for audit, not deleted). Alternative: delta (never withdraw). Same checksum twice = no-op. PO question Q6.

**P7 Routing.**
- Search is over sailings with time, not a port graph.
- Connection valid if `next.departure_date >= previous.arrival_date` (same-day allowed, zero minimum layover, because we only have dates).
- No maximum number of legs. A port is never visited twice (origin included).
- `cheapest-direct`: single-leg routes only.
- `cheapest`: lowest sum of EUR-converted legs.
- `fastest`: **first departure to last arrival, layovers included** (calendar days). Alternative: sum of leg durations (excludes waiting; this is what makes the README example fit).
- Tie-breaks (deterministic): cheapest = lower EUR total, then fewer legs, then earlier arrival, then lexicographic sailing codes in order. fastest = shorter duration, then lower EUR total, then fewer legs, then lexicographic codes. cheapest-direct = lower EUR, then earlier arrival, then sailing code.

**P8 Saved searches.** Identity = (origin, destination, criterion). Repeating a search never creates a second row. Fulfilment is one event per search (unique constraint) when a later import makes it answerable. Detail in Step 05.

## 3. Open decision for you

Unknown port code: the plan says reject with an error, but SLD-0004 says a route we do not have *yet* must be saved. A port that only appears in a future feed would be rejected under the plan. Proposed: well-formed code not in the catalogue = **error 404, not saved** (typo protection, as the plan says); malformed code = 422. Alternative: save any well-formed code as unfulfilled. Please choose.
