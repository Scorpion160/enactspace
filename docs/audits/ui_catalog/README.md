# EnactSpace - Catalogue UI/UX

Reference code: `7f0a9fd5ade92c1fbe88e9316016fab299c0005a`
Branch: `audit/ui-visual-catalog-phase0`
Status: static inventory completed; isolated runtime capture completed; 42 corrected master captures retained.

## Purpose

This catalogue documents the EnactSpace Flutter user interface from both
source-level inventory and isolated runtime observation.

The work began as a phase 0A static inventory of `frontend/lib`, route
configuration, role visibility, dialogs, sheets, controls and local subviews.
It was later extended with an isolated local/test runtime environment,
synthetic fixtures and a corrected master visual capture set.

No production environment, VPS, real email account or real user account was
required for the audit workflow.

## Method

The static inventory follows direct and indirect user-visible surfaces:
routes, dialogs, mobile sheets, pickers, form panels, detail panels,
menu/select controls, empty/error/loading states and role-gated views.

A class count is not treated as a visual-view count. Local widgets are grouped
into meaningful capture-relevant views in `views_inventory.csv`.

Runtime captures were performed against isolated audit fixtures. The final
master review supersedes earlier captures affected by incomplete font loading.

## Phase 0A static inventory totals

| Measure | Total | Notes |
| --- | ---: | --- |
| Declared `GoRoute` entries | 23 | One transient splash route, two public routes and 20 shell routes |
| User-facing routes under review | 22 | Excludes the transient `/splash` bootstrap route |
| Screen source files | 25 | All `*screen.dart` files under `frontend/lib/features` |
| Direct dialog call sites | 44 | `showDialog`, including generic invocations |
| Sheet mechanisms | 21 | `showModalBottomSheet` and `DraggableScrollableSheet` |
| Date/time/file picker mechanisms | 20 | 9 date, 4 time and 7 file picker references |
| Popup menu controls | 8 | `PopupMenuButton` |
| Select controls | 303 | `DropdownButton` + `DropdownMenu`; control count, not view count |
| Explicit tab bars | 1 | Alumni |
| Direct route/navigation calls | 22 | Router declarations and direct navigation calls; excludes back/pop |
| Local widget classes in screen files | 546 | Structural complexity signal only |
| Primary view groups in `views_inventory.csv` | 66 | Capture-relevant user-visible view groups |
| Full static view/subview/state inventory | 118 | Includes named subviews and state panels |
| Interaction entries catalogued | 60 | Grouped user intents/openings |
| Test-data families | 21 | See `test_data_requirements.csv` |

## Runtime master capture status

The canonical runtime visual set is stored in:

`docs/audits/ui_catalog/screenshots/master/`

The current master set contains exactly 42 PNG captures.

Final typography correction and visual review established:

- 42/42 master captures report `font_loaded=true`.
- 42/42 report `text_render_verified=true`.
- 35/42 reached their requested state without an unexpected runtime signal.
- Captures 16, 18, 26, 28 and 30 correspond to unavailable actions or subviews.
- Capture 20 retains an unexpected network signal.
- Capture 27 retains an unexpected console signal.
- No false application state was fabricated to make an unavailable flow appear successful.

The detailed corrected reading of all 42 captures is maintained in
`master_visual_review.md`.

## Historical capture forecast

Before runtime execution, the static catalogue produced a conservative
non-deduplicated planning forecast.

The original forecast was:

| Scope | Mandatory capture estimate |
| --- | ---: |
| Public access and candidate | 154 |
| Shell/navigation by role | 176 |
| Operational core (dashboard, members, attendance, tasks, finance) | 528 |
| Community/resources (posts, chat, notifications, documents) | 402 |
| Governance and lifecycle (recruitment, poles, projects, events, alumni) | 476 |
| Learning, impact and memory | 238 |
| Accessibility/zoom/orientation exceptions | 190 |
| **Total before approved deduplication** | **2,164** |
| Provisional deduplication candidates | 612 |
| **Conditional forecast after deduplication** | **1,552** |

These values are planning data from the pre-capture phase. They are not the
number of final master screenshots delivered by the runtime audit.

## Isolated test environment and accounts

The audit environment is local/test only.

The fixture model covers the operational roles required by the catalogue,
including Admin, Team Leader, Secretary, Finance, Pole Lead, Pole Deputy,
Project Lead, Member, Alumni and Candidate, together with synthetic
multi-role scenarios where required.

Synthetic audit identities are used instead of real Enactus ESP accounts.

Environment setup, isolation rules and runtime constraints are documented in:

- `runtime_environment.md`
- `runtime_blockers.md`
- `isolation_proof.md`
- `tools/README.md`

## Screenshot organization

The canonical screenshots are the numbered PNG files under:

`docs/audits/ui_catalog/screenshots/master/`

Their filenames identify the audited domain/view, role and viewport.

Temporary or superseded visual material under
`screenshots/ui_foundations_v1_temp/` is not part of the canonical master set.

## Visual review status

The corrected master review identifies confirmed visual issues as well as
earlier findings invalidated after proper typography loading.

Among the recurrent areas requiring further product work are:

- dashboard hero and quick-action treatment;
- mobile member filtering and list density;
- responsive navigation density;
- chat attachments and participant truncation;
- finance empty states and payment context;
- recruitment actions and candidate detail;
- attendance QR/NFC runtime states;
- Mobile Money and document-deposit flows;
- archive detail density and media presentation.

See `master_visual_review.md` for the complete evidence-based review.

## Known limitations

- Some requested actions or subviews were unavailable in the audited product
  state and are documented rather than simulated.
- NFC, camera and other hardware-dependent behavior cannot be fully validated
  by browser-only visual capture.
- Runtime network or console anomalies retained in captures 20 and 27 remain
  documented signals rather than hidden failures.
- Historical preflight runs are retained separately and are not part of the
  canonical master result set.
- The audit corpus is evidence for the audited reference commit and should not
  be treated as proof that later product revisions are visually identical.

## Main catalogue files

- `routes_inventory.csv`: declared routes and user-facing route control set.
- `views_inventory.csv`: primary static audit views grouped by user-visible intent.
- `interactions_inventory.csv`: openings, transitions and destructive flows.
- `test_data_requirements.csv`: isolated fixture requirements.
- `capture_plan.csv`: role/state/viewport capture planning.
- `pre_capture_inventory.md`: detailed static reconciliation.
- `master_capture_results.csv`: results associated with the canonical master set.
- `master_visual_review.md`: corrected visual findings for the 42 master captures.
- `font_control_results.csv`: typography-loading controls.
- `isolation_proof.md`: evidence of the isolated audit environment.
- `runtime_environment.md`: runtime environment description.
- `runtime_blockers.md`: resolved and remaining runtime constraints.
- `tools/`: deterministic local audit and capture tooling.
- `screenshots/master/`: canonical 42-image visual evidence set.

## Historical material

The following material is preserved separately from the canonical master set:

- `archive/run_ancien/`: historical preflight/runtime runs.
- `screenshots/ui_foundations_v1_temp/`: superseded temporary captures.

They can remain useful for audit traceability but should not be interpreted as
the current canonical visual result.

## Current conclusion

The catalogue has progressed beyond the initial static-only phase.

The canonical state consists of:

- a reconciled static UI inventory;
- an isolated deterministic audit environment;
- runtime evidence and control artifacts;
- 42 corrected master screenshots;
- a corrected visual review distinguishing confirmed issues from findings
  invalidated by typography-loading problems.

Further product redesign or regression testing should use this master corpus as
the audit reference rather than the earlier temporary capture material.