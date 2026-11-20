"""EnactSpace email copy, safe links and responsive HTML rendering."""

from datetime import datetime, timezone
from html import escape
import re
from urllib.parse import urlsplit


APP_URL = "https://enactspace.kerunjombor.net"
ROUTES = {
    "activate": "Activer mon accès",
    "application-tracking": "Suivre ma candidature",
    "recruitment": "Consulter les candidatures",
    "chat": "Ouvrir la messagerie",
    "meetings": "Ouvrir EnactMeet",
    "notifications": "Voir mes notifications",
    "login": "Se connecter à EnactSpace",
}
OTP_PATTERN = re.compile(r"^((?:Votre )?code[^\n\d]{0,55}?)(\d{6}|\d{8})(?!\d)", re.I | re.M)
LEGACY_ROUTES = re.compile(
    re.escape(APP_URL) + r"/(" + "|".join(ROUTES) + r")(?=$|[\s.,!;)])"
)
STANDARD_FOOTER = "Message automatique envoyé par EnactSpace"
WEB_LINK = re.compile(r"https://[^\s<>\"']+")
INTERVIEW_LINK = re.compile(r"(?m)^Lien de l’entretien : (https://[^\s<>\"']+)$")


def app_link(route: str) -> str:
    return APP_URL + "/#/" + route


def canonical_email_links(body: str) -> str:
    return LEGACY_ROUTES.sub(lambda match: app_link(match[1]), body)


def prepare_email_text(body: str, sent_at: datetime) -> str:
    """Apply the salutation at the current delivery attempt, including retries."""
    if sent_at.tzinfo is None:
        sent_at = sent_at.replace(tzinfo=timezone.utc)
    # Dakar uses UTC year-round, as do the campaign dates.
    greeting = "Bonsoir" if sent_at.astimezone(timezone.utc).hour >= 18 else "Bonjour"
    body = canonical_email_links(body)
    prefix = ""
    if body.startswith("MODE DE TEST ENACTSPACE\n") and "\n\n" in body:
        prefix, body = body.split("\n\n", 1)
        prefix += "\n\n"
    body = body.lstrip()
    opening = re.compile(r"\A(?:Bonjour|Bonsoir)(?=[ ,\n]|$)", re.I)
    if opening.match(body):
        body = opening.sub(greeting, body, count=1)
    else:
        body = greeting + ",\n\n" + body
    return prefix + body


def uses_standard_template(html: str | None) -> bool:
    return html is None or (
        html.startswith('<!doctype html>\n<html lang="fr">')
        and STANDARD_FOOTER in html
    )


def _safe_interview_url(subject: str, body: str) -> str | None:
    if subject.removeprefix("[TEST] ").strip() != "Votre entretien avec Enactus ESP":
        return None
    match = INTERVIEW_LINK.search(body)
    if not match:
        return None
    url = match[1]
    try:
        parts = urlsplit(url)
        if parts.hostname and not parts.username and not parts.password and "\\" not in url:
            return url
    except ValueError:
        pass
    return None


def _paragraphs(text_body: str, interview_url: str | None) -> str:
    rendered = []
    safe_links = {escape(app_link(route)) for route in ROUTES}
    if interview_url:
        safe_links.add(escape(interview_url))

    def link(match: re.Match) -> str:
        value = match[0]
        url = value if value in safe_links else value.rstrip(".,!;)")
        if url not in safe_links:
            return value
        return f'<a href="{url}" style="color:#00616b">{url}</a>' + value[len(url):]

    for raw_part in text_body.split("\n\n"):
        part = raw_part.strip()
        if not part:
            continue
        safe = WEB_LINK.sub(link, escape(part))
        safe = OTP_PATTERN.sub(
            r'\1<span style="display:inline-block;margin:6px 0;padding:10px 16px;'
            r'border-radius:8px;background:#fff2c2;color:#132733;font-family:monospace;'
            r'font-size:24px;font-weight:bold;letter-spacing:7px">\2</span>',
            safe,
        )
        safe = safe.replace("\n", "<br>")
        rendered.append(
            '<p style="margin:0 0 16px;font-size:16px;line-height:1.6;'
            f'overflow-wrap:anywhere;color:#263844">{safe}</p>'
        )
    return "".join(rendered)


def _action(subject: str, body: str) -> tuple[str, str] | None:
    actions = {app_link(route): label for route, label in ROUTES.items()}
    for match in reversed(list(WEB_LINK.finditer(body))):
        url = match[0].rstrip(".,!;)")
        if url in actions:
            return actions[url], url
    lowered = subject.removeprefix("[TEST] ").strip().casefold()
    if OTP_PATTERN.search(body) or "code de réinitialisation" in lowered:
        return None
    # Compatibility for messages already in the queue before links were explicit.
    if lowered == "nouvelle candidature reçue":
        return ROUTES["recruitment"], app_link("recruitment")
    if "candidature" in lowered:
        return ROUTES["application-tracking"], app_link("application-tracking")
    if lowered == "nouveau message sur enactspace":
        return ROUTES["chat"], app_link("chat")
    return ROUTES["login"], app_link("login")


def render_email_html(subject: str, text_body: str) -> str:
    text_body = canonical_email_links(text_body)
    title = escape(subject.strip())
    content = _paragraphs(text_body, _safe_interview_url(subject, text_body))
    action = _action(subject, text_body)
    button = ""
    if action is not None:
        label, url = action
        button = (
            '<table role="presentation" cellspacing="0" cellpadding="0" '
            'style="margin:24px 0 12px"><tr><td bgcolor="#ffca28" style="border-radius:8px">'
            f'<a href="{escape(url, quote=True)}" style="display:inline-block;'
            'padding:14px 20px;color:#102634;font-size:15px;font-weight:700;text-decoration:none">'
            + escape(label) + "</a></td></tr></table>"
        )
    security = ""
    preheader = "Un message EnactSpace vous attend."
    if OTP_PATTERN.search(text_body):
        preheader = "Consultez votre code personnel dans ce message."
        security = (
            '<p style="margin:24px 0 0;padding:12px 14px;border-left:3px solid #ffca28;'
            'background:#f6f3eb;color:#445660;font-size:13px;line-height:1.55">'
            "Gardez votre code personnel confidentiel.</p>"
        )
    return f'''<!doctype html>
<html lang="fr">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f4f3ef;color:#102634;font-family:Arial,Helvetica,sans-serif">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;mso-hide:all">{preheader}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="#f4f3ef">
<tr><td align="center" style="padding:22px 12px">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0"
 style="max-width:600px;background:#ffffff;border:1px solid #e4e5e0;border-radius:14px">
<tr><td bgcolor="#102634" style="padding:21px 22px;border-bottom:4px solid #ffca28">
<div style="color:#ffffff;font-size:23px;font-weight:bold;line-height:1.2">EnactSpace</div>
<div style="margin-top:5px;color:#f3d570;font-size:12px;font-weight:bold;letter-spacing:1px">ENACTUS ESP</div>
</td></tr>
<tr><td style="padding:26px 22px">
<h1 style="margin:0 0 20px;color:#102634;font-size:24px;line-height:1.28">{title}</h1>
{content}{button}{security}
</td></tr>
<tr><td bgcolor="#f7f7f3" style="padding:15px 22px;border-top:1px solid #e4e5e0;color:#445660;font-size:12px;line-height:1.55">
{STANDARD_FOOTER}<br>
Enactus ESP · École Supérieure Polytechnique de Dakar
</td></tr></table>
</td></tr></table>
</body></html>'''
