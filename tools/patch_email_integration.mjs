import fs from 'node:fs';
import path from 'node:path';

const root = 'C:/Users/DIOP/Documents/EnactSpaceRecovery/enactspace-20260927';
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8').replace(/\r\n/g, '\n');
const write = (rel, text) => fs.writeFileSync(path.join(root, rel), text.replace(/\r\n/g, '\n'), 'utf8');

function replaceOnce(text, oldText, newText, rel) {
  const first = text.indexOf(oldText);
  if (first < 0) throw new Error(`marker missing in ${rel}`);
  if (text.indexOf(oldText, first + oldText.length) >= 0) {
    throw new Error(`marker not unique in ${rel}`);
  }
  return text.slice(0, first) + newText + text.slice(first + oldText.length);
}

{
  const rel = 'backend/app/api/routes/auth.py';
  let text = read(rel);
  const oldText = `        else:\n            reset_otp.otp_hash = hash_password(otp)\n            reset_otp.expires_at = utc_now() + timedelta(minutes=15)\n            reset_otp.created_at = utc_now()\n        db.commit()\n`;
  const newText = `        else:\n            reset_otp.otp_hash = hash_password(otp)\n            reset_otp.expires_at = utc_now() + timedelta(minutes=15)\n            reset_otp.created_at = utc_now()\n        enqueue_email_delivery(\n            db,\n            recipient_email=user.email,\n            user_id=user.id,\n            subject="EnactSpace - Code de réinitialisation",\n            text_body=(\n                f"Bonjour {user.first_name},\\n\\n"\n                f"Votre code de réinitialisation est : {otp}\\n"\n                "Il expire dans 15 minutes.\\n\\n"\n                "Si vous n'êtes pas à l'origine de cette demande, ignorez cet email."\n            ),\n        )\n        db.commit()\n`;
  text = replaceOnce(text, oldText, newText, rel);
  write(rel, text);
}

{
  const rel = 'backend/app/api/routes/recruitment.py';
  let text = read(rel);
  const importMarker = 'from app.services.audit_service import create_audit_log, get_client_ip\n';
  text = replaceOnce(text, importMarker, importMarker + 'from app.services.email_delivery_service import enqueue_email_delivery\n', rel);
  const oldSubmit = `    ensure_tracking_code(db, application)\n    notify_recruitment_responsibles(db, application, campaign)\n    candidate_email_ready()\n    db.commit()\n`;
  const newSubmit = `    ensure_tracking_code(db, application)\n    notify_recruitment_responsibles(db, application, campaign)\n    enqueue_email_delivery(\n        db,\n        recipient_email=application.email,\n        subject=f"EnactSpace - Candidature {campaign.title}",\n        text_body=(\n            f"Bonjour {application.first_name},\\n\\n"\n            "Votre candidature à Enactus ESP a bien été reçue.\\n"\n            f"Code de suivi : {application.tracking_code}\\n\\n"\n            "Conservez ce code pour suivre l'avancement de votre candidature."\n        ),\n        dedupe_key=f"recruitment-submission:{application.id}",\n    )\n    db.commit()\n`;
  text = replaceOnce(text, oldSubmit, newSubmit, rel);
  write(rel, text);
}

console.log('email integration patched');
