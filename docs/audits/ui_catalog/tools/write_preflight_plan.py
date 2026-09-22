"""Write the Phase 0B.3A preflight plan with a strict CSV schema."""
from __future__ import annotations

import csv
from pathlib import Path


CATALOG = Path(__file__).resolve().parents[1]
PLAN = CATALOG / "preflight_plan.csv"
COLUMNS = [
    "preflight_id", "scenario_driver", "role", "test_account_alias", "viewport",
    "orientation", "data_profile", "network_profile", "initial_route",
    "expected_final_route", "setup_action", "interaction_steps", "expected_markers",
    "forbidden_markers", "teardown_action", "status",
]


def row(
    preflight_id: str, scenario_driver: str, role: str, test_account_alias: str,
    viewport: str, orientation: str, data_profile: str, initial_route: str,
    expected_final_route: str, setup_action: str, interaction_steps: str,
    expected_markers: str, forbidden_markers: str,
) -> dict[str, str]:
    return {
        "preflight_id": preflight_id,
        "scenario_driver": scenario_driver,
        "role": role,
        "test_account_alias": test_account_alias,
        "viewport": viewport,
        "orientation": orientation,
        "data_profile": data_profile,
        "network_profile": "localhost_only",
        "initial_route": initial_route,
        "expected_final_route": expected_final_route,
        "setup_action": setup_action,
        "interaction_steps": interaction_steps,
        "expected_markers": expected_markers,
        "forbidden_markers": forbidden_markers,
        "teardown_action": "clear storage; close target; restore network",
        "status": "pending_final_validation",
    }


ROWS = [
    row("PF01", "preflight_login_public_mobile", "public", "public", "390x844", "portrait", "nominal", "/login", "/login", "clear browser storage; open login", "none", "route:/login; text:Connexion; input:email; input:password", "redirect:/dashboard; text:Accès refusé"),
    row("PF02", "preflight_login_public_desktop", "public", "public", "1440x900", "landscape", "nominal", "/login", "/login", "clear browser storage; open login", "none", "route:/login; text:Connexion; input:email; input:password", "redirect:/dashboard; text:Accès refusé"),
    row("PF03", "preflight_invalid_login", "public", "public", "390x844", "portrait", "invalid_credentials", "/login", "/login", "clear browser storage; open login", "find Email; fill invalid@example.test; find Mot de passe; fill wrong-password; press Enter once; await POST /api/auth/token 401", "route:/login; text:Email ou mot de passe incorrect; input:email; input:password; action:retry_login", "redirect:/dashboard; text:Accès refusé"),
    row("PF04", "preflight_member_shell_mobile", "member", "audit.member", "390x844", "portrait", "nominal", "/dashboard", "/dashboard", "inject local audit.member token; navigate dashboard", "open mobile navigation; verify Chat action", "route:/dashboard; identity:Audit Member; nav:mobile; action:open_chat", "redirect:/login; text:Accès refusé"),
    row("PF05", "preflight_admin_shell_desktop", "admin", "audit.admin", "1440x900", "landscape", "dense", "/dashboard", "/dashboard", "inject local audit.admin token; navigate dashboard", "verify desktop navigation; open Membres action", "route:/dashboard; identity:Audit Admin; nav:desktop; action:open_members", "redirect:/login; text:Accès refusé"),
    row("PF06", "preflight_admin_dashboard_dense", "admin", "audit.admin", "1440x900", "landscape", "dense", "/dashboard", "/dashboard", "inject local audit.admin token", "wait until dashboard loaded", "route:/dashboard; identity:Audit Admin; text:Cartes adaptées à ton rôle; text:Actions rapides; text:À suivre; state:dense", "redirect:/login; text:Accès refusé"),
    row("PF07", "preflight_member_dashboard_mobile", "member", "audit.member", "390x844", "portrait", "nominal", "/dashboard", "/dashboard", "inject local audit.member token; navigate dashboard", "activate my-space action", "route:/dashboard; identity:Audit Member; action:open_my_space; absence:admin_finance_control", "redirect:/login; text:Accès refusé; text:Dette de Audit"),
    row("PF08", "preflight_member_profile_tablet", "admin", "audit.admin", "768x1024", "portrait", "partial", "/members", "/members", "inject local audit.admin token; navigate members", "open Audit MultiRole profile", "route:/members; identity:Audit Admin; text:Audit MultiRole; sheet:member_profile; action:close_profile", "redirect:/login; text:Accès refusé"),
    row("PF09", "preflight_attendance_open_tablet", "secretary", "audit.secretary", "1024x768", "landscape", "attendance_open", "/attendance", "/attendance", "inject local audit.secretary token; navigate attendance", "activate Gestion; find Rechercher une session; enter Session audit 2; open Session audit 2; verify detail", "route:/attendance; identity:Audit Secretary; text:Session audit 2; text:Pilotage de la session; text:Pointage NFC; text:Visibilité SG; state:open; action:open_attendance_detail", "redirect:/login; text:Accès refusé; state:closed"),
    row("PF10", "preflight_payment_pending_actions_desktop", "finance", "audit.finance", "1366x768", "landscape", "payment_pending", "/finance", "/finance", "inject local audit.finance token; navigate finance", "find finance search; enter AUDIT-PAY-000; open Actions du paiement; open Rejeter; verify rejection dialog; close with Retour", "route:/finance; identity:Audit Finance; text:AUDIT-PAY-000; text:En attente; dialog:payment_rejection; action:close_payment_rejection", "redirect:/login; text:Accès refusé; state:rejected"),
    row("PF11", "preflight_chat_conversation_mobile", "member", "audit.member", "390x844", "portrait", "dense", "/chat", "/chat", "inject local audit.member token; navigate chat", "open Conversation audit 7", "route:/chat; identity:Audit Member; text:Conversation audit 7; text:Message audit; action:focus_composer", "redirect:/login; text:Accès refusé; state:empty"),
    row("PF12", "preflight_archive_project_detail_desktop", "alumni", "audit.alumni", "1440x900", "landscape", "long_content", "/archives", "/archives", "inject local audit.alumni token; navigate archives", "find archive search; enter Projet historique audit 2021; open project card; verify project detail; close project detail", "route:/archives; identity:Audit Alumni; text:Projet historique audit 2021; text:Problème; text:Solution; text:Impacts et indicateurs; text:Prix; text:Leçons apprises; sheet:archive_project; action:close_archive_detail", "redirect:/login; text:Accès refusé; state:archive_list_only"),
]

# The product deliberately presents real Enactus archive stories rather than the
# backend-only synthetic records; PF12 exercises the shipped DIMBALI bottom sheet.
ROWS[-1].update({
    "interaction_steps": "find archive search; enter DIMBALI; open project card; verify project detail; close project detail",
    "expected_markers": "route:/archives; identity:Audit Alumni; text:DIMBALI; text:Probl\u00e8me; text:Solution; text:Impacts et indicateurs; text:Prix; text:Le\u00e7ons apprises; sheet:archive_project; action:close_archive_detail",
})


def main() -> None:
    with PLAN.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=COLUMNS, extrasaction="raise")
        writer.writeheader()
        writer.writerows(ROWS)


if __name__ == "__main__":
    main()
