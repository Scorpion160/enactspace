"""Shared wording for recruitment messages and their review document."""
import json
from pathlib import Path
from app.services.email_templates import app_link

MAIL_COPY = json.loads(Path(__file__).with_suffix('.json').read_text(encoding='utf-8'))


def render_mail(kind, *, first_name, code='', username='', details=''):
    copy = MAIL_COPY[kind]
    values = dict(first_name=first_name, code=code, username=username, details=details,
                  activation_url=app_link('activate'))
    body = copy['body'].format_map(values)
    if kind not in {'activation', 'activation_complete'}:
        body += f"\n\nCode de suivi : {code}\nSuivre ma candidature : {app_link('application-tracking')}\n\nL’équipe Enactus ESP"
    return copy['subject'], body


def application_mail(kind, application, *, details=''):
    return render_mail(kind, first_name=application.first_name,
                       code=application.tracking_code or str(application.id), details=details)
