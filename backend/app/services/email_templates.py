"""Responsive, accessible and injection-safe EnactSpace email templates."""

from html import escape
import re


APP_URL = "https://enactspace.kerunjombor.net"
OTP_PATTERN = re.compile(r"(?<!\d)(\d{6})(?!\d)\.?")


def _paragraphs(text_body: str) -> str:
    rendered: list[str] = []
    for raw_part in text_body.split("\n\n"):
        part = raw_part.strip()
        if not part:
            continue
        safe = escape(part).replace("\n", "<br>")
        safe = OTP_PATTERN.sub(
            '<span style="display:inline-block;margin:8px 0;padding:12px 18px;'
            'border-radius:10px;background:#fff5d6;color:#070d0d;'
            'font-size:28px;font-weight:800;letter-spacing:7px">\\1</span>',
            safe,
        )
        rendered.append(
            '<p style="margin:0 0 18px;font-size:16px;line-height:1.65;'
            f'color:#26352c">{safe}</p>'
        )
    return "".join(rendered)


def _action(subject: str, text_body: str) -> tuple[str, str] | None:
    lowered = subject.casefold()
    if OTP_PATTERN.search(text_body) or "code de réinitialisation" in lowered:
        return None
    if "candidature" in lowered:
        return ("Suivre ma candidature", APP_URL)
    if "invitation" in lowered or "réunion" in lowered or "enactmeet" in lowered:
        return ("Ouvrir EnactSpace", APP_URL)
    return ("Accéder à EnactSpace", APP_URL)


def render_email_html(subject: str, text_body: str) -> str:
    title = escape(subject.strip())
    content = _paragraphs(text_body)
    action = _action(subject, text_body)
    button = ""
    if action is not None:
        label, url = action
        button = (
            '<table role="presentation" cellspacing="0" cellpadding="0" '
            'style="margin:26px 0 10px"><tr><td style="border-radius:10px;'
            'background:#1f7a45"><a href="' + escape(url, quote=True) + '" '
            'style="display:inline-block;padding:14px 24px;color:#ffffff;'
            'font-size:15px;font-weight:700;text-decoration:none">'
            + escape(label) + "</a></td></tr></table>"
        )
    preheader = escape(text_body.strip().replace("\n", " ")[:120])
    return f'''<!doctype html>
<html lang="fr">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f0efec;color:#070d0d;font-family:Arial,Helvetica,sans-serif">
<div style="display:none;max-height:0;overflow:hidden;opacity:0">{preheader}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f0efec">
<tr><td align="center" style="padding:28px 12px">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:620px;background:#ffffff;border-radius:18px;overflow:hidden;box-shadow:0 8px 28px rgba(7,13,13,.12)">
<tr><td style="padding:25px 30px;background:#070d0d;border-bottom:5px solid #ffc222">
<table role="presentation" width="100%"><tr>
<td width="52"><div style="width:44px;height:44px;line-height:44px;text-align:center;border-radius:13px;background:#ffc222;color:#070d0d;font-size:20px;font-weight:800">ES</div></td>
<td><div style="color:#ffffff;font-size:21px;font-weight:800">EnactSpace</div><div style="margin-top:3px;color:#f0efec;font-size:13px">L'espace numérique d'Enactus ESP</div></td>
</tr></table></td></tr>
<tr><td style="padding:34px 30px 28px">
<div style="margin-bottom:10px;color:#c88a12;font-size:12px;font-weight:800;letter-spacing:1.4px;text-transform:uppercase">Enactus ESP</div>
<h1 style="margin:0 0 22px;color:#070d0d;font-size:27px;line-height:1.25">{title}</h1>
{content}{button}
<div style="margin-top:28px;padding:15px 17px;border-radius:11px;background:#f0efec;color:#515356;font-size:13px;line-height:1.55;border-left:4px solid #ffc222">Pour votre sécurité, ne partagez jamais un code de vérification ou un lien de connexion confidentiel.</div>
</td></tr>
<tr><td style="padding:20px 30px;background:#070d0d;color:#f0efec;font-size:12px;line-height:1.6;text-align:center">
Message automatique envoyé par EnactSpace<br>
Enactus ESP · École Supérieure Polytechnique de Dakar
</td></tr></table>
</td></tr></table>
</body></html>'''