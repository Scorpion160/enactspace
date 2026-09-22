# Fixture assertions

`tools/seed_ui_audit.py` resets only the guarded `postgres/enactspace_ui_audit`
database and aborts before changing data if the audit environment guard fails.
After the seed commit it asserts the following invariants:

| Assertion | Expected |
| --- | --- |
| Candidate memberships in poles | 0 |
| Candidate memberships in projects | 0 |
| Multi-role member in Technique | 1 active membership |
| Technique lead | `audit.polelead@example.test` with `chef` |
| Technique deputy | `audit.poledeputy@example.test` with `adjoint` |
| Audit Horizon lead | `audit.projectlead@example.test` with `chef` |
| Chat threads | 10 |
| Chat messages | 100 across the first 9 threads |
| Empty chat threads | 1, the tenth thread |
| Stored fixture assets | actual local files, not URL-only records |

The audit seed creates PNG/JPEG profile and media placeholders, PDF, TXT,
DOCX, XLSX and payment-proof payloads under the isolated upload volume. Only
the explicit `missing`/`broken` scenarios may reference a path which is absent.

## Deterministic profiles

| Profile | Activation / restore action | Expected fixture state |
| --- | --- | --- |
| `nominal` | reset seed | standard records and valid local assets |
| `empty` | select empty thread or data-free view | no records in the scoped view |
| `partial` | open designated incomplete profile/project | intentional missing optional fields |
| `dense` | reset seed then use standard scope | 50 tasks, 30 posts/documents, 100 messages |
| `long_content` | open long post/story | deliberately long copy and name |
| `permission_denied` | role-scoped route/action | backend permission response expected |
| `invalid_media` | designated invalid file only | invalid local payload, never a normal media path |
| `payment_pending` | finance payment filter | pending proof data |
| `payment_rejected` | finance payment filter | rejected proof data |
| `attendance_open` | open attendance session | check-in available |
| `attendance_closed` | closed attendance session | check-in refused |
| `chat_empty` | tenth thread | no messages |

Profile switching is a documented audit driver action. The runner must restore
the deterministic baseline with a guarded reseed before a profile that changes
database state; it must never reuse state from another scenario.

## Last validated seed result

The guarded local seed completed successfully before preflight preparation:

```text
candidate_pole_memberships=0
candidate_project_memberships=0
multirole_technique_memberships=1
technique_lead=1
technique_deputy=1
horizon_project_lead=1
threads=10
messages=100
empty_threads=1
stored_assets=8
physical_assets=14
```
