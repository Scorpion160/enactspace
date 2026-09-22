# Pilot findings - remaining UX gaps

## UX-FIN-001 - P1 major

`PaymentModel` exposes `proofUrl`, but the payment list has no consultation or
preview action for that proof. PF10 therefore audits the existing rejection
dialog and its safe `Retour` exit; it does not claim that a proof detail exists.

## UX-ARC-001 - P1 major

Hall of Fame entries are static and have no detail sheet. PF12 now validates
the separate, real historical-project detail sheet (DIMBALI), including its
problem, solution, impact, awards, lessons, and close action.

There is no remaining attendance product finding: PF09 now proves the real
Secretary detail surface and its required management markers at runtime.
