"""Read-only operational readiness of the Mobile Money integration.

Never returns secrets, customer data, tokens, or provider credentials.
A green configuration check does not prove PayDunya has enabled live payments.
"""
from ipaddress import ip_address
from urllib.parse import urlsplit


REQUIRED_CHANNELS = {"wave-senegal", "orange-money-senegal"}


def _is_valid_ipn(url: str | None, *, require_https: bool) -> bool:
    if not isinstance(url, str) or not url.strip():
        return False
    try:
        parsed = urlsplit(url.strip())
    except ValueError:
        return False
    if require_https and parsed.hostname:
        hostname = parsed.hostname.lower()
        if (
            "." not in hostname
            or hostname.endswith(
                (".invalid", ".test", ".example", ".localhost", ".local", ".internal")
            )
            or hostname == "localhost"
        ):
            return False
        try:
            if not ip_address(hostname).is_global:
                return False
        except ValueError:
            # A public-looking DNS name still requires a real connectivity check.
            pass
    return (
        parsed.scheme == ("https" if require_https else parsed.scheme)
        and parsed.scheme in {"http", "https"}
        and bool(parsed.hostname)
        and parsed.username is None
        and parsed.password is None
        and not parsed.query
        and not parsed.fragment
        and parsed.path.rstrip("/") == "/api/payments/paydunya/ipn"
    )


def get_mobile_money_readiness(config) -> dict:
    """Inspect settings without network access or side effects."""
    enabled = bool(config.MOBILE_MONEY_ENABLED)
    provider = config.MOBILE_MONEY_PROVIDER
    mode = config.PAYDUNYA_MODE
    channels = sorted(
        set(config.paydunya_allowed_channels_list).intersection(REQUIRED_CHANNELS)
    )
    credentials_present = all(
        isinstance(secret, str) and bool(secret.strip())
        for secret in (
            config.PAYDUNYA_MASTER_KEY,
            config.PAYDUNYA_PUBLIC_KEY,
            config.PAYDUNYA_PRIVATE_KEY,
            config.PAYDUNYA_TOKEN,
        )
    )
    callback = config.PAYDUNYA_CALLBACK_URL
    # A live callback must be explicitly configured, as required by the
    # production Settings validator. Do not mark a guessed URL as ready.
    if not callback and mode != "live" and config.PUBLIC_API_BASE_URL:
        callback = config.PUBLIC_API_BASE_URL.rstrip("/") + "/api/payments/paydunya/ipn"
    ipn_url_valid = _is_valid_ipn(callback, require_https=mode == "live")
    reconciliation_enabled = bool(config.PAYMENT_RECONCILIATION_ENABLED)
    currency_valid = config.PAYMENT_CURRENCY == "XOF"

    blockers = []
    if not enabled:
        blockers.append("Activation Mobile Money non effectuée")
    if provider != "paydunya":
        blockers.append("Prestataire PayDunya non sélectionné")
    if not credentials_present:
        blockers.append("Clés PayDunya non configurées")
    if not channels:
        blockers.append("Aucun canal Wave/Orange Money autorisé")
    if not currency_valid:
        blockers.append("Devise XOF non configurée")
    if not ipn_url_valid:
        blockers.append("URL IPN publique manquante ou invalide")
    if not reconciliation_enabled:
        blockers.append("Rapprochement des transactions désactivé")

    configuration_ready = len(blockers) == 0
    return {
        "enabled": enabled,
        "provider": provider,
        "mode": mode,
        "currency": config.PAYMENT_CURRENCY,
        "allowed_channels": channels,
        "credentials_present": credentials_present,
        "ipn_url_valid": ipn_url_valid,
        "reconciliation_enabled": reconciliation_enabled,
        "configuration_ready": configuration_ready,
        "ready_for_live_test": configuration_ready and mode == "live",
        "blocking_checks": blockers,
        "external_merchant_activation_verified": False,
        "notes": (
            "La configuration ne vérifie pas l'activation du compte marchand "
            "ni la capacité des opérateurs à encaisser. Un premier paiement "
            "réel doit être validé manuellement puis rapproché auprès du prestataire."
        ),
    }
