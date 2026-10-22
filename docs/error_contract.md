# CLI error contract (approved)

The challenge README defines none. Input (stdin): origin, destination, criterion, one per line.

- **stdout** only ever contains the JSON result. Input is not echoed. Nothing is printed to stdout on errors.
- **stderr** gets diagnostics, one JSON object per line with an HTTP-style status: `{"status":422,"error":"invalid_criterion","message":"..."}`.
- Exit code: `0` success, `2` client error (4xx), `1` unexpected failure (5xx).
- Input is trimmed; port codes are upper-cased and validated against `[A-Z]{2}[A-Z0-9]{3}`; criterion is lower-cased.

| Situation | stdout | stderr | exit |
|-----------|--------|--------|------|
| Route found | JSON array of legs | empty | 0 |
| No route (known ports), search saved or already saved | `[]` | `{"status":202,"saved_search_id":N}` | 0 |
| Well-formed port not in current data (origin and/or destination) | `[]` | the 202 line above plus `{"status":202,"warning":"port_not_in_current_data","ports":["XXXXX"]}`; search is saved | 0 |
| Fewer or more than 3 non-empty input lines | empty | 422 `invalid_input` | 2 |
| Malformed port code | empty | 422 `invalid_port` | 2 |
| Origin equals destination | empty | 422 `invalid_route` | 2 |
| Unknown criterion | empty | 422 `invalid_criterion` | 2 |
| Database down, import failure, bug | empty | 500 `internal_error` | 1 |

An unknown well-formed port is **not** an error (decision P5): the search is saved so it can be fulfilled when a later feed adds the port.
Saved-search fulfilment is exposed by a separate command (Step 05) that lists and acknowledges pending events.
