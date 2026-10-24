# Freight test pack

Files: `test-feed-1.json`, `test-feed-2.json` (snapshot that replaces feed 1), `test-feed-bad-structure.json` (no `rates` key).
The ports are disjoint from the sample feed, so the bundled `response.json` does not interfere.

## Run order

1. Clean start: `docker compose down -v`, then start with `FEED_PATH` pointing at `test-feed-1.json`.
2. Run the feed 1 queries below and compare stdout.
3. Run the error cases.
4. Run queries 9 to 12 twice. Saved searches must not duplicate (one row per origin, destination, criterion).
5. Import `test-feed-2.json`, run the feed 2 queries, then `notifications list`.
6. Import `test-feed-2.json` again: no new records, no new events.
7. Import `test-feed-bad-structure.json`: import fails, recorded as failed, data unchanged.

Stdin format for each query: three lines, for example `SGSIN`, `DEHAM`, `cheapest-direct`.

## What each feed 1 query proves

| # | Proves |
|---|---|
| 1 | Highest-rate wins (DIR3 has 500 and 2000 EUR; lowest would wrongly win). Departure-date rate: DIR1 is 904.76 EUR at the 03-01 rate, but would be 791.67 at the 03-02 rate and beat DIR2. Identical duplicate rate collapsed. Unpriced sailings DIR4 (precision), DIR5 (no exchange rate), DIR6 (no rate row) ignored |
| 2 | Three legs, same-day connection at AEJEA (arrive 03-06, depart 03-06). INDA + INDB (20 EUR) is time-infeasible and must lose |
| 3 | Fastest by elapsed time: 7 days via FST1 + FST2, even though it costs 900 EUR |
| 4 | Division, not multiplication: 129000.00 JPY at 129 is 1000 EUR and beats 1050 EUR. Rate printed exactly as received |
| 5 | Cheapest beats direct options with a two-leg route |
| 6 | Tie-break: three sailings at 200 EUR. TIEA and TIEB arrive first, then sailing code ascending gives TIEA |
| 7 | Fastest tie-break: TIEB takes 3 days, TIEA and TIEC take 4 |
| 8 | Dead-end port is reachable as a destination (DEAD), and the cycle sailing CYCL must not cause a loop |
| 9 | Conflict with an unconvertible candidate (CHF has no exchange rate): UNCV is unpriced, so the result is `[]` and the search is saved |
| 10 | Same sailing code with two different arrival dates in one feed: excluded, so `[]` and the search is saved |
| 11 | No outgoing sailings from USNYC: `[]`, saved |
| 12 | Well-formed unknown port: `[]`, exit 0, warning on stderr, saved |

## Error cases (feed 1 loaded)

| stdin | Expected |
|---|---|
| `SG1` / `DEHAM` / `cheapest` | exit 2, JSON error on stderr, nothing on stdout |
| `SGSIN` / `DEHAM` / `slowest` | exit 2 |
| two lines only | exit 2 |
| four lines (real extra content) | exit 2 |
| `sgsin` / `deham` / `fastest` with CRLF line endings and a trailing blank line | same result as query 3 |

## Import report for feed 1 (should be recorded with reasons)

- Rejected sailings: BADD (invalid date 2022-13-45), NODS (missing destination_port).
- Excluded for conflicting fields: CONF (two rows, different arrival).
- Rejected rates: BRAT (`abc`), DIR4 (`1500.005` USD would change by rounding), JPY2 (`129000.5` JPY would change by rounding), one row with no sailing_code.
- Orphan rates (no valid sailing): ZZZZ, BADD, NODS.
- Unpriced sailings: DIR4, DIR5 (no exchange rate for 2022-03-20), DIR6 (no rate row), JPY2, BRAT, UNCV (unconvertible conflict).
- Collapsed: duplicate identical DIR1 rate.

Exact counts depend on how the build counts them. Check the reasons, not the numbers.

## Feed 2 changes (full snapshot)

- FST1 removed: it must become inactive, not deleted, so the fastest SGSIN to DEHAM route changes.
- DIR2 rescheduled (arrival 03-30 to 03-28): the later feed wins, and the output shows 03-28. This is the Q9 behavior.
- USN2 added (GBLGP to USNYC, 300 EUR): the saved search from feed 1 query 9 becomes fulfillable.
- After import, `notifications list` shows exactly one fulfillment event (GBLGP / USNYC / cheapest). Queries 10, 11 and 12 stay unfulfilled.

## After importing test-feed-1.json

**1.** `SGSIN / DEHAM / cheapest-direct`

```json
[
  {
    "origin_port": "SGSIN",
    "destination_port": "DEHAM",
    "departure_date": "2022-03-02",
    "arrival_date": "2022-03-30",
    "sailing_code": "DIR2",
    "rate": "900.00",
    "rate_currency": "EUR"
  }
]
```

**2.** `SGSIN / DEHAM / cheapest`

```json
[
  {
    "origin_port": "SGSIN",
    "destination_port": "AEJEA",
    "departure_date": "2022-03-01",
    "arrival_date": "2022-03-06",
    "sailing_code": "LEG1",
    "rate": "100.00",
    "rate_currency": "EUR"
  },
  {
    "origin_port": "AEJEA",
    "destination_port": "GBLGP",
    "departure_date": "2022-03-06",
    "arrival_date": "2022-03-10",
    "sailing_code": "LEG2",
    "rate": "110.00",
    "rate_currency": "USD"
  },
  {
    "origin_port": "GBLGP",
    "destination_port": "DEHAM",
    "departure_date": "2022-03-11",
    "arrival_date": "2022-03-13",
    "sailing_code": "LEG3",
    "rate": "50.00",
    "rate_currency": "EUR"
  }
]
```

**3.** `SGSIN / DEHAM / fastest`

```json
[
  {
    "origin_port": "SGSIN",
    "destination_port": "BEANR",
    "departure_date": "2022-03-02",
    "arrival_date": "2022-03-07",
    "sailing_code": "FST1",
    "rate": "600.00",
    "rate_currency": "EUR"
  },
  {
    "origin_port": "BEANR",
    "destination_port": "DEHAM",
    "departure_date": "2022-03-08",
    "arrival_date": "2022-03-09",
    "sailing_code": "FST2",
    "rate": "300.00",
    "rate_currency": "EUR"
  }
]
```

**4.** `AEJEA / DEHAM / cheapest-direct`

```json
[
  {
    "origin_port": "AEJEA",
    "destination_port": "DEHAM",
    "departure_date": "2022-03-05",
    "arrival_date": "2022-03-15",
    "sailing_code": "JPY1",
    "rate": "129000.00",
    "rate_currency": "JPY"
  }
]
```

**5.** `AEJEA / DEHAM / cheapest`

```json
[
  {
    "origin_port": "AEJEA",
    "destination_port": "GBLGP",
    "departure_date": "2022-03-06",
    "arrival_date": "2022-03-10",
    "sailing_code": "LEG2",
    "rate": "110.00",
    "rate_currency": "USD"
  },
  {
    "origin_port": "GBLGP",
    "destination_port": "DEHAM",
    "departure_date": "2022-03-11",
    "arrival_date": "2022-03-13",
    "sailing_code": "LEG3",
    "rate": "50.00",
    "rate_currency": "EUR"
  }
]
```

**6.** `BEANR / GBLGP / cheapest-direct`

```json
[
  {
    "origin_port": "BEANR",
    "destination_port": "GBLGP",
    "departure_date": "2022-03-04",
    "arrival_date": "2022-03-08",
    "sailing_code": "TIEA",
    "rate": "200.00",
    "rate_currency": "EUR"
  }
]
```

**7.** `BEANR / GBLGP / fastest`

```json
[
  {
    "origin_port": "BEANR",
    "destination_port": "GBLGP",
    "departure_date": "2022-03-05",
    "arrival_date": "2022-03-08",
    "sailing_code": "TIEB",
    "rate": "200.00",
    "rate_currency": "EUR"
  }
]
```

**8.** `SGSIN / USNYC / cheapest`

```json
[
  {
    "origin_port": "SGSIN",
    "destination_port": "USNYC",
    "departure_date": "2022-03-02",
    "arrival_date": "2022-03-12",
    "sailing_code": "DEAD",
    "rate": "50.00",
    "rate_currency": "EUR"
  }
]
```

**9.** `GBLGP / USNYC / cheapest`

```json
[]
```

**10.** `AEJEA / USNYC / cheapest-direct`

```json
[]
```

**11.** `USNYC / DEHAM / fastest`

```json
[]
```

**12.** `QQQQQ / DEHAM / cheapest`

```json
[]
```

## After importing test-feed-2.json (snapshot, replaces feed 1)

**1.** `SGSIN / DEHAM / cheapest-direct`

```json
[
  {
    "origin_port": "SGSIN",
    "destination_port": "DEHAM",
    "departure_date": "2022-03-02",
    "arrival_date": "2022-03-28",
    "sailing_code": "DIR2",
    "rate": "900.00",
    "rate_currency": "EUR"
  }
]
```

**2.** `SGSIN / DEHAM / cheapest`

```json
[
  {
    "origin_port": "SGSIN",
    "destination_port": "AEJEA",
    "departure_date": "2022-03-01",
    "arrival_date": "2022-03-06",
    "sailing_code": "LEG1",
    "rate": "100.00",
    "rate_currency": "EUR"
  },
  {
    "origin_port": "AEJEA",
    "destination_port": "GBLGP",
    "departure_date": "2022-03-06",
    "arrival_date": "2022-03-10",
    "sailing_code": "LEG2",
    "rate": "110.00",
    "rate_currency": "USD"
  },
  {
    "origin_port": "GBLGP",
    "destination_port": "DEHAM",
    "departure_date": "2022-03-11",
    "arrival_date": "2022-03-13",
    "sailing_code": "LEG3",
    "rate": "50.00",
    "rate_currency": "EUR"
  }
]
```

**3.** `SGSIN / DEHAM / fastest`

```json
[
  {
    "origin_port": "SGSIN",
    "destination_port": "AEJEA",
    "departure_date": "2022-03-01",
    "arrival_date": "2022-03-06",
    "sailing_code": "LEG1",
    "rate": "100.00",
    "rate_currency": "EUR"
  },
  {
    "origin_port": "AEJEA",
    "destination_port": "GBLGP",
    "departure_date": "2022-03-06",
    "arrival_date": "2022-03-10",
    "sailing_code": "LEG2",
    "rate": "110.00",
    "rate_currency": "USD"
  },
  {
    "origin_port": "GBLGP",
    "destination_port": "DEHAM",
    "departure_date": "2022-03-11",
    "arrival_date": "2022-03-13",
    "sailing_code": "LEG3",
    "rate": "50.00",
    "rate_currency": "EUR"
  }
]
```

**4.** `GBLGP / USNYC / cheapest`

```json
[
  {
    "origin_port": "GBLGP",
    "destination_port": "USNYC",
    "departure_date": "2022-03-12",
    "arrival_date": "2022-03-20",
    "sailing_code": "USN2",
    "rate": "300.00",
    "rate_currency": "EUR"
  }
]
```

**5.** `AEJEA / USNYC / cheapest-direct`

```json
[]
```
