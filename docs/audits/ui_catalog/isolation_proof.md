# Isolation proof before preflight

The gateway is the only exposed audit container. It publishes loopback-only
`127.0.0.1:18080 -> 80` for the web and `127.0.0.1:18002 -> 8000` for the API.
Backend, web and PostgreSQL have no published ports and remain only on the
`enactspace_ui_audit_network` Docker network, which remains `internal: true`.
The gateway alone joins the separate `enactspace_ui_audit_exposure` bridge. It
is read-only, drops all capabilities, adds only `NET_BIND_SERVICE`, uses
`no-new-privileges`, mounts only its Nginx configuration read-only, and has no
secret or data volume.

## Executed checks

| Check | Result |
| --- | --- |
| `curl http://127.0.0.1:18080/login` | HTTP 200 |
| `curl http://127.0.0.1:18002/health` | HTTP 200 and UI-audit health payload |
| Backend TCP to public `1.1.1.1:443` | blocked: network unreachable |
| Web request to `https://example.com` | blocked |
| Edge CDP navigation to `https://example.com/...` | blocked by `Fetch.failRequest` |

The CDP check produced no screenshot. Its blocked request is retained in
`external_requests.csv` with capture id `CDP_NETWORK_ISOLATION`.
