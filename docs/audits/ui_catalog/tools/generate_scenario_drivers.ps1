param()

$ErrorActionPreference = "Stop"
$catalog = Join-Path $PSScriptRoot ".."
$plan = Import-Csv (Join-Path $catalog "pilot_capture_plan.csv")
$requiresLocator = @(
    "invalid_login", "password_toggle", "password_recovery", "disabled_login",
    "expired_session", "network_offline", "dashboard_error", "chat_sending",
    "chat_send_failed", "member_edit", "member_disable", "member_import"
)
$directNavigation = @(
    "splash_bootstrap", "login_form", "dashboard_dense", "dashboard_member",
    "dashboard_finance", "dashboard_pole", "dashboard_multirole", "members_list",
    "attendance_list", "finance_dashboard", "chat_list", "impact_dashboard", "archives_list"
)
$rows = foreach ($group in ($plan | Group-Object scenario_driver | Sort-Object Name)) {
    $row = $group.Group | Select-Object -First 1
    $status = if ($directNavigation -contains $row.scenario_driver) { "implemented_navigation_driver" } elseif ($requiresLocator -contains $row.scenario_driver) { "locator_preflight_required" } else { "state_driver_preflight_required" }
    $mechanism = if ($status -eq "implemented_navigation_driver") {
        "CDP clears isolated storage, injects only a local audit token when required, navigates the declared route, waits for the declared marker, then clears target data."
    } elseif ($status -eq "state_driver_preflight_required") {
        "The route driver is available, but the declared state needs a real seeded entity, dialog, sheet, interception or user action to be validated before capture."
    } else {
        "CDP action is implemented but needs one live, accessible locator confirmation before any screenshot can be authorised."
    }
    [pscustomobject]@{
        scenario_driver = $row.scenario_driver
        setup_action = $row.setup_action
        real_mechanism = $mechanism
        expected_marker = $row.expected_marker
        teardown_action = $row.teardown_action
        implementation_status = $status
    }
}

$rows | Export-Csv (Join-Path $catalog "scenario_drivers.csv") -NoTypeInformation -Encoding utf8
Write-Output "Generated $($rows.Count) driver records."
