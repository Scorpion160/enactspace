param()

$ErrorActionPreference = "Stop"
$output = Join-Path $PSScriptRoot "..\pilot_capture_plan.csv"

$scenarios = @(
    @("auth","splash","public","loading","session_absent","splash_bootstrap","clear_storage; open_app","text:EnactSpace","public","/splash","P0"),
    @("auth","login","public","default","nominal","login_form","clear_storage; navigate_login","text:Connexion","form","/login","P0"),
    @("auth","login","public","validation_error","invalid_credentials","invalid_login","submit_invalid_credentials","text:Identifiants","form","/login","P0"),
    @("auth","login","public","disabled_account","inactive_user","disabled_login","submit_inactive_credentials","text:Compte","form","/login","P1"),
    @("auth","login","public","password_visible","nominal","password_toggle","toggle_password_visibility","input:password","form","/login","P2"),
    @("auth","recovery","public","default","nominal","password_recovery","open_password_recovery","text:Mot de passe","public","/login","P1"),
    @("auth","login","member","session_expired","expired_token","expired_session","inject_expired_token; navigate_dashboard","text:Connexion","expired_token","/dashboard","P0"),
    @("shell","app_shell","member","mobile_active","nominal","shell_member_mobile","login_member; navigate_dashboard","nav:mobile","form","/dashboard","P0"),
    @("shell","app_shell","admin","desktop_active","dense","shell_admin_desktop","login_admin; navigate_dashboard","nav:desktop","form","/dashboard","P0"),
    @("shell","app_shell","finance","tablet_active","finance_dense","shell_finance_tablet","login_finance; navigate_dashboard","nav:tablet","form","/dashboard","P1"),
    @("shell","app_shell","admin","badges_visible","dense","shell_badges","login_admin; unread_notifications","badge:notifications","form","/dashboard","P1"),
    @("shell","app_shell","alumni","menu_limited","nominal","shell_alumni_menu","login_alumni; open_menu","nav:limited","form","/dashboard","P1"),
    @("shell","app_shell","member","offline","nominal","network_offline","login_member; set_offline; navigate_dashboard","state:offline","form","/dashboard","P0"),
    @("dashboard","dashboard","admin","loaded","dense","dashboard_dense","login_admin; profile_dense","text:Tableau de bord","form","/dashboard","P0"),
    @("dashboard","dashboard","member","loaded","nominal","dashboard_member","login_member; profile_nominal","text:Tableau de bord","form","/dashboard","P0"),
    @("dashboard","dashboard","finance","loaded","finance_dense","dashboard_finance","login_finance; profile_dense","text:Tableau de bord","form","/dashboard","P0"),
    @("dashboard","dashboard","polelead","loaded","dense","dashboard_pole","login_polelead; profile_dense","text:Tableau de bord","form","/dashboard","P0"),
    @("dashboard","dashboard","multirole","loaded","dense","dashboard_multirole","login_multirole; profile_dense","text:Tableau de bord","form","/dashboard","P0"),
    @("dashboard","dashboard","admin","empty","empty","dashboard_empty","login_admin; profile_empty","state:empty","form","/dashboard","P1"),
    @("dashboard","dashboard","admin","partial_data","partial","dashboard_partial","login_admin; profile_partial","state:partial","form","/dashboard","P1"),
    @("dashboard","dashboard","admin","server_error","nominal","dashboard_error","login_admin; intercept_dashboard_500","state:error","form","/dashboard","P0"),
    @("members","members","admin","loaded","dense","members_list","login_admin; profile_dense; navigate_members","text:Membres","form","/members","P0"),
    @("members","profile","admin","complete","nominal","member_profile","login_admin; open_member_complete","text:Audit","form","/members","P1"),
    @("members","profile","admin","incomplete","nominal","member_profile_incomplete","login_admin; open_member_incomplete","text:Audit","form","/members","P1"),
    @("members","profile","admin","multi_role","dense","member_profile_multirole","login_admin; open_multirole","text:MultiRole","form","/members","P1"),
    @("members","member_edit","admin","default","nominal","member_edit","login_admin; open_member_edit","dialog:edit_member","form","/members","P1"),
    @("members","member_disable","admin","confirmation","nominal","member_disable","login_admin; open_disable_confirmation","dialog:confirmation","form","/members","P0"),
    @("members","import","admin","default","nominal","member_import","login_admin; open_import","dialog:import","form","/members","P1"),
    @("attendance","attendance","secretary","loaded","dense","attendance_list","login_secretary; profile_dense; navigate_attendance","text:Presences","form","/attendance","P0"),
    @("attendance","session","secretary","open","attendance_open","attendance_open","login_secretary; open_attendance_session","text:Session","form","/attendance","P0"),
    @("attendance","session","secretary","closed","attendance_closed","attendance_closed","login_secretary; open_closed_session","text:Session","form","/attendance","P1"),
    @("attendance","record","secretary","late","attendance_open","attendance_record","login_secretary; open_late_record","text:Retard","form","/attendance","P1"),
    @("attendance","justification","secretary","pending","attendance_open","attendance_justification","login_secretary; open_justification","dialog:justification","form","/attendance","P1"),
    @("attendance","qr_scan","secretary","valid","attendance_open","attendance_qr","login_secretary; open_qr; use_local_token","text:QR","form","/attendance/scan","P1"),
    @("attendance","nfc","secretary","unavailable","attendance_open","attendance_nfc_unavailable","login_secretary; simulate_nfc_unavailable","state:nfc_unavailable","form","/attendance/nfc","P1"),
    @("finance","finance","finance","loaded","dense","finance_dashboard","login_finance; profile_dense; navigate_finance","text:Finance","form","/finance","P0"),
    @("finance","payment","finance","pending","payment_pending","payment_pending","login_finance; open_pending_payment","text:Paiement","form","/finance","P0"),
    @("finance","proof","finance","preview","payment_pending","payment_proof","login_finance; open_payment_proof","preview:proof","form","/finance","P1"),
    @("finance","payment","finance","rejected","payment_rejected","payment_rejected","login_finance; open_rejected_payment","text:Refuse","form","/finance","P1"),
    @("chat","chat_list","member","loaded","dense","chat_list","login_member; profile_dense; navigate_chat","text:Discussions","form","/chat","P0"),
    @("chat","conversation","member","loaded","nominal","chat_conversation","login_member; open_private_conversation","message:Audit","form","/chat","P0"),
    @("chat","group","member","loaded","nominal","chat_group","login_member; open_group_conversation","text:Conversation audit","form","/chat","P1"),
    @("chat","composer","member","sending","nominal","chat_sending","login_member; open_private_conversation; delay_send","state:sending","form","/chat","P1"),
    @("chat","composer","member","send_failed","nominal","chat_send_failed","login_member; open_private_conversation; fail_send","state:send_failed","form","/chat","P0"),
    @("chat","conversation","member","empty","chat_empty","chat_empty","login_member; open_empty_conversation","state:empty","form","/chat","P1"),
    @("impact","impact","teamleader","loaded","dense","impact_dashboard","login_teamleader; profile_dense; navigate_impact","text:Impact","form","/impact","P1"),
    @("impact","impact","teamleader","partial_data","partial","impact_partial","login_teamleader; profile_partial; navigate_impact","state:partial","form","/impact","P1"),
    @("archives","archives","member","loaded","dense","archives_list","login_member; profile_dense; navigate_archives","text:Archives","form","/archives","P1"),
    @("archives","award","member","loaded","dense","archive_award","login_member; open_award","text:Prix audit","form","/archives","P1"),
    @("archives","story","member","long_content","long_content","archive_story","login_member; open_long_story","text:Recit","form","/archives","P2"),
    @("archives","award","member","missing_image","invalid_media","archive_missing_image","login_member; open_missing_image_award","state:missing_image","form","/archives","P1")
)

function Get-Viewports($state, $priority) {
    if ($state -eq "mobile_active") { return @(@("375x812","portrait"), @("390x844","portrait")) }
    if ($state -eq "desktop_active") { return @(@("1366x768","landscape"), @("1440x900","landscape"), @("1920x1080","landscape")) }
    if ($state -eq "tablet_active") { return @(@("768x1024","portrait"), @("1024x768","landscape")) }
    if ($priority -eq "P0") { return @(@("375x812","portrait"), @("1366x768","landscape")) }
    return @(@("390x844","portrait"), @("768x1024","portrait"), @("1440x900","landscape"))
}

$rows = [System.Collections.Generic.List[object]]::new()
$index = 0
foreach ($scenario in $scenarios) {
    foreach ($viewport in (Get-Viewports $scenario[3] $scenario[10])) {
        $index += 1
        $authMode = $scenario[8]
        if (($scenario[2] -ne "public") -and ($authMode -eq "form")) {
            $authMode = "token_storage"
        }
        $rows.Add([pscustomobject]@{
            capture_id = ("PILOT{0:D3}" -f $index)
            domaine = $scenario[0]
            vue = $scenario[1]
            role = $scenario[2]
            etat = $scenario[3]
            viewport = $viewport[0]
            orientation = $viewport[1]
            priorite = $scenario[10]
            donnees_requises = $scenario[4]
            scenario_driver = $scenario[5]
            setup_action = $scenario[6]
            expected_marker = $scenario[7]
            teardown_action = "clear_storage; close_target; restore_network"
                capture_mode = "screenshot_after_driver_validation"
            auth_mode = $authMode
            route_mode = $scenario[9]
        })
    }
}

if ($rows.Count -lt 120 -or $rows.Count -gt 220) { throw "Pilot count $($rows.Count) is outside 120-220." }
$rows | Export-Csv -LiteralPath $output -NoTypeInformation -Encoding utf8
Write-Output "Generated $($rows.Count) coherent pilot rows at $output"
