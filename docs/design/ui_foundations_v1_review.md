# UI Foundations V1 Review

## Scope

This implementation is limited to the visual foundations, login, global shell,
administrator dashboard and member dashboard. Services, APIs, routes, roles
and permissions are unchanged.

## Implemented visual changes

- The base system now defines semantic colors, a spacing scale, three radii,
  border-first surfaces and accessible control sizing.
- Shared UI primitives are available for headers, actions, badges, metrics,
  data cards, empty states, filter bars and responsive navigation.
- Login keeps its primary path in the first mobile viewport, with a 92 px
  mark, shorter branding, a wider tablet form and compact secondary access.
- Desktop navigation rail is reduced to 232 px. Inactive destinations are
  simple lines with hover and focus feedback; the active destination carries
  the yellow state and a discrete side marker.
- The dashboard uses a shorter contextual header with a role, greeting,
  context, priority and labelled actions, without repeating its page title.
- Metric cards no longer place every icon on a colored square; color is now a
  semantic accent rather than the component identity.

## Audit findings treated

- Confirmed blank dashboard hero actions are replaced by labelled actions.
- Oversized dark dashboard framing is removed from the V1 dashboard header.
- Empty card hierarchy is reduced through border-first data surfaces.
- Desktop content width increases to a useful 1480 px maximum with the more
  compact navigation rail.
- Mobile top-bar crowding is reduced by removing the logo and using `Accueil`
  for the dashboard title.
- Member metrics use a two-column 126 px compact mobile treatment while
  retaining 44 px or larger touch targets.

## Intended responsive behavior

| View | Mobile | Tablet | Desktop |
| --- | --- | --- | --- |
| Login | Primary fields, recovery and CTA lead the scroll | Wider focused form column | Simplified brand panel plus wider form panel |
| Shell | Compact title, drawer and daily bottom navigation | Hybrid compact shell below 1100 px | Labelled 232 px rail and wider content |
| Member dashboard | Personal actions and metrics lead | Adaptive grid | Side information joins the main work area |
| Admin dashboard | Alerts lead before metrics | Adaptive grid | Attention, activity and global metrics are separated |

## Captured build

- Build SHA-256, `main.dart.js`:
  `6D762BD2A8ACC7322C980DED08DAB8FE1B9D95958F4189EAAA80C0E3C4CB8778`.
- Web origin: `http://127.0.0.1:18080`.
- API origin: `http://127.0.0.1:18002`.
- Flutter URL strategy: `hash_strategy`.
- All captures use audit fixtures, local CanvasKit, and the Google font
  allowlist without credentials. Every capture reports loaded and verified text.

## Eight captures

1. `screenshots/ui_foundations_v1/01_login_mobile_390x844.png`
2. `screenshots/ui_foundations_v1/02_login_tablet_768x1024.png`
3. `screenshots/ui_foundations_v1/03_login_desktop_1440x900.png`
4. `screenshots/ui_foundations_v1/04_shell_member_mobile_390x844.png`
5. `screenshots/ui_foundations_v1/05_shell_admin_desktop_1440x900.png`
6. `screenshots/ui_foundations_v1/06_dashboard_member_mobile_390x844.png`
7. `screenshots/ui_foundations_v1/07_dashboard_admin_desktop_1440x900.png`
8. `screenshots/ui_foundations_v1/08_dashboard_admin_1920x1080.png`

## Comparison with the master catalogue

- The former repeated dark dashboard hero has become a compact white context
  header with a visible role, a priority signal and named actions.
- The blank white action capsules are removed in favour of `Voir les alertes`,
  `Mes taches` and `Actualiser`.
- The V1 rail preserves labels while reclaiming desktop content width and
  removes the repeated inactive dark capsules.
- Mobile content begins with the current role, the immediate priority, the
  next action and two compact metric columns.
- Metrics now use restrained icon accents instead of a colored square behind
  every icon.

## New observations

- The first mobile login viewport shows the identity, email, password,
  recovery action and sign-in CTA without requiring a scroll.
- The desktop rail still needs a dedicated information-architecture pass for
  long club navigation, outside this phase.
- The responsive canvas and visual text are validated at the eight requested
  viewports. No additional module was opened or redesigned.

## Remaining limits

- `flutter analyze --no-pub` completes with no issues and the release web build
  succeeds. `flutter test --no-pub --reporter expanded -j 1 --timeout 45s -v`
  completes in 17.6 seconds: `test/widget_test.dart` is the only test file;
  its first test fails on line 12 because it expects the obsolete `Connexion`
  label while the login now renders `Connexion des comptes validés`. The second
  compact candidate-tracking test passes. `flutter doctor -v` is healthy except
  for the expected missing Chrome executable; Edge is available for web.
- No other module was redesigned in this phase.
