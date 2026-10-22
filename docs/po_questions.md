# Questions for the PO (grows each step)

Policies marked "assumed" are implemented as written and change only if the PO answers otherwise.

1. **Q1 Conflicting rates.** `MNOP` has two rates (456.78 and 812.00 USD). Assumed: keep the highest, record the discarded one. Is there a precedence rule (source, timestamp)? Which is valid?
2. **Q2 README vs JSON dates.** README `ERXQ` arrives 2022-02-06; the JSON says 2022-02-12. Which is right? (Also: README `cheapest-direct` example is a placeholder with 2024 dates and code `XXXX`.)
3. **Q3 Definition of "fastest".** Assumed: first departure to last arrival, layovers included, so `QRST` (17 days) wins and differs from the README example `ERXQ + ETRG` (22 days). The alternative, sum of leg durations, only reproduces the README with the 02-06 date. Which one is intended, and should the README example be corrected?
4. **Q4 Same-day connections and minimum layover.** Assumed allowed (`next.departure >= previous.arrival`, zero layover). The data has dates only, so this may be physically impossible. Is a minimum layover required?
5. **Q5 Missing exchange rate or rate row.** Assumed: the sailing is left unpriced, logged, and not returned by any criterion (including `fastest`). Should we instead use the latest earlier rate, or let `fastest` return sailings that cannot be priced in EUR?
6. **Q6 Snapshot vs delta feed.** Assumed: each feed is a full snapshot; sailings absent from the latest feed become inactive (kept for history). If feeds are deltas, nothing should be deactivated. Saved-search fulfilment is designed to work under both.
7. **Q7 Unknown ports.** Assumed: a well-formed code not in current data is saved as an unfulfilled search with a stderr warning. Should such searches expire, or be limited?
8. **Q8 Fulfilment notification.** Who is told when a saved search is fulfilled, and how? Assumed: a CLI command lists pending fulfilments.
9. **Q9 Rate semantics.** Is a rate per container, per shipment, all-in? Assumed comparable across sailings.
10. **Q10 Expired sailings.** Should past-departure sailings be excluded? The sample is from 2022 and is searched as-is.
11. **Q11 Rounding.** Amounts that would change when rounded to the currency's minor units are rejected, not rounded. Acceptable?
