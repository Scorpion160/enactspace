# Runtime blockers - Phase 0B preparation

## Active

1. No active network blocker remains. The former direct-binding limitation is
   resolved by the hardened gateway: only it joins the local exposure bridge,
   while backend, web and PostgreSQL remain on the internal audit network.
2. The normal sandbox session cannot access the Docker named pipe or the local
   Docker config. Elevated local Docker commands work, so all container
   lifecycle actions require that local approval path.
3. No native PostgreSQL CLI or service was found. The audit database therefore
   depends on the isolated Docker PostgreSQL container.
4. No Node.js, Playwright CLI, Firefox executable, or Edge WebDriver was found
   on the PATH. The proposed capture runner must use the installed Edge binary
   through Flutter/CDP or a local browser automation dependency that is
   explicitly approved and installed later.
5. The runner-only dependency is pinned in `requirements.audit.txt`. The
   dedicated internal network deliberately cannot resolve a package index, so
   its local audit venv uses the already-installed matching `websockets 16.1.1`
   package without changing production backend requirements.

## Resolved safeguards

- Docker Desktop is local only and was started only to host the audit database.
- No existing local Docker containers, custom networks, or volumes were found.
- No production environment file, VPS, real email, or real account was read or
  used during preparation.
- The deterministic audit seed now validates all requested role, membership,
  chat and asset invariants successfully.
