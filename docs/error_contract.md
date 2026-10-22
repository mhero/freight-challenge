# CLI error contract (proposed — awaiting approval)

The challenge README defines none. Input (stdin): origin, destination, criterion, one per line. Rules:

- **stdout** only ever contains the JSON result. Input is not echoed. Nothing is printed to stdout on errors.
- **stderr** gets diagnostics. Errors are one JSON object with an HTTP-style status: `{"status":422,"error":"invalid_criterion","message":"..."}`.
- Exit code: `0` success, `2` client error (4xx), `1` unexpected failure (5xx).
- Input is trimmed; port codes are upper-cased, criterion lower-cased.

| Situation | stdout | stderr | exit |
|-----------|--------|--------|------|
| Route found | JSON array of legs | empty | 0 |
| No route, search saved (or already saved) | `[]` | `{"status":202,"saved_search_id":N,...}` | 0 |
| Fewer or more than 3 non-empty lines | empty | 422 `invalid_input` | 2 |
| Malformed port code (not 5 letters/digits) | empty | 422 `invalid_port` | 2 |
| Port not in the catalogue | empty | 404 `unknown_port` | 2 |
| Origin equals destination | empty | 422 `invalid_route` | 2 |
| Unknown criterion | empty | 422 `invalid_criterion` | 2 |
| Database down, import failure, bug | empty | 500 `internal_error` | 1 |

Saved-search fulfilment is exposed by a separate command (Step 05) that lists and acknowledges pending events.
