import fs from 'node:fs';
import path from 'node:path';
const ROOT = 'C:/Users/DIOP/Documents/EnactSpaceRecovery/enactspace-20260927';
const file = (rel) => path.join(ROOT, rel);
const read = (rel) => fs.readFileSync(file(rel), 'utf8').replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');
const write = (rel, s) => fs.writeFileSync(file(rel), s.replace(/\n+$/, '\n'), 'utf8');
function once(s, oldValue, newValue, label) {
  const next = s.replace(oldValue, newValue);
  if (next === s) throw new Error(`replacement failed: ${label}`);
  return next;
}

let rel = 'backend/app/models/chat.py';
let s = read(rel);
s = once(s, '    content: Mapped[str] = mapped_column(Text, nullable=False)\n', '    client_message_id: Mapped[str | None] = mapped_column(String(120), nullable=True)\n    content: Mapped[str] = mapped_column(Text, nullable=False)\n', 'model client id');
s = once(s, '    reactions = relationship(\n', '    __table_args__ = (\n        UniqueConstraint("author_id", "client_message_id", name="uq_chat_message_author_client_id"),\n    )\n\n    reactions = relationship(\n', 'model constraint');
write(rel, s);
rel = 'backend/app/schemas/chat.py';
s = read(rel);
s = once(s, 'class ChatMessageCreate(BaseModel):\n    content: str\n', 'class ChatMessageCreate(BaseModel):\n    content: str\n    client_message_id: Optional[str] = None\n', 'create schema');
s = once(s, '    author_id: UUID\n    content: str\n', '    author_id: UUID\n    client_message_id: Optional[str] = None\n    content: str\n', 'read schema');
write(rel, s);

rel = 'backend/app/api/routes/chat.py';
s = read(rel);
s = once(s, '        "author_id": message.author_id,\n', '        "author_id": message.author_id,\n        "client_message_id": message.client_message_id,\n', 'serialize id');
s = once(s, '    get_participant_or_404(db, thread_id, current_user.id)\n\n    content = payload.content.strip()\n', `    get_participant_or_404(db, thread_id, current_user.id)\n\n    client_message_id = (payload.client_message_id or "").strip() or None\n    if client_message_id:\n        existing = db.query(ChatMessage).filter(\n            ChatMessage.author_id == current_user.id,\n            ChatMessage.client_message_id == client_message_id,\n        ).first()\n        if existing:\n            return serialize_message(existing, db=db, current_user_id=current_user.id)\n\n    content = payload.content.strip()\n`, 'idempotent lookup');
s = once(s, '        author_id=current_user.id,\n        content=build_message_content(\n', '        author_id=current_user.id,\n        client_message_id=client_message_id,\n        content=build_message_content(\n', 'persist id');
write(rel, s);
console.log('apply_chat_idempotency: OK');
