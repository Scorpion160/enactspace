# EnactSpace UI Foundations V1

## Direction

EnactSpace - L'impact en mouvement uses a calm institutional base, direct
community language, and data-first layouts. The visual anchor is Enactus
yellow on soft black, supported by white elevated surfaces on an ivory canvas.
Poppins remains the application typeface.

## Tokens

- Canvas: `AppTheme.background` ivory.
- Surfaces: white and `surfaceElevated`.
- Text: `darkText` and `secondaryText`.
- Border: `border`, used before shadows.
- Semantic colors: yellow action, success, warning, error and information.
- Spacing: 4, 8, 12, 16, 20, 24, 32, 40 and 48 px.
- Radius: 10 px controls, 16 px data surfaces, 24 px large contextual regions.

## Shared components

`AppPageHeader`, `AppSectionHeader`, primary/secondary/icon buttons, status
badges, metrics, data cards, empty states, filter bars and responsive
navigation are defined in `frontend/lib/shared/ui/app_components.dart`.

## Responsive rules

- Mobile keeps a labelled five-destination daily navigation and prioritizes the
  next task over decorative framing.
- Tablet uses a compact contextual shell instead of a squeezed desktop rail.
- Desktop uses a 232 px labelled rail, up to 1480 px of useful content width and information-dense
  grids. Shadows are reserved for hierarchy, not applied to every surface.

## Accessibility

Controls have a minimum 44 px target; icon buttons expose tooltips; semantic
states use labels in addition to color; focus uses the yellow outline supplied
by the application theme.
