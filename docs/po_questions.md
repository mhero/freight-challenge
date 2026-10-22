# Questions for the PO (grows each step)

1. Q1 Rates: `MNOP` has two rates (456.78 and 812.00 USD). Which is valid, and is there a precedence rule (source, timestamp)?
2. Q2 README `ERXQ` arrives 2022-02-06, the JSON says 2022-02-12. Which is right?
3. Q3 Is "fastest" first departure to last arrival (layovers included) or the sum of leg durations? The README `fastest` example only holds under the second reading plus the 02-06 date. With the JSON, `QRST` (direct, 17 days) wins under either.
4. Q4 Same-day connections and minimum layover: is arrival date = next departure date allowed? Any minimum hours? (Data has dates only.)
5. Q5 Missing exchange rate for a departure date: skip the sailing, or use the latest earlier rate?
6. Q6 Is each feed a full snapshot or a delta? Should sailings missing from a new feed be withdrawn?
7. Q7 Should a search for a port we have never seen be saved or rejected?
8. Q8 Who is notified when a saved search is fulfilled, and how (CLI listing is the assumption)?
9. Q9 Rate semantics: is a rate per container, per shipment, all-in? Does it include fees? (Assumed comparable across sailings.)
10. Q10 Should expired sailings (past departure) be excluded? The sample is from 2022 and is searched as-is.
11. Q11 Rounding: amounts rejected if more decimals than the currency allows. Acceptable?
