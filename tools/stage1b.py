from pathlib import Path
ROOT = Path('/src')

def replace(rel, old, new):
    p = ROOT / rel
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise RuntimeError(f'marker missing: {rel}: {old[:60]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')

p = ROOT / 'backend/app/models/alumni.py'
text = p.read_text(encoding='utf-8')
if 'enactus_join_year' not in text:
    text = text.replace(
        '    graduation_year = Column(Integer)\n',
        '    graduation_year = Column(Integer)\n    enactus_join_year = Column(Integer)\n',
        1,
    )
    p.write_text(text, encoding='utf-8')

p = ROOT / 'backend/app/models/chat.py'
text = p.read_text(encoding='utf-8')
if 'client_message_id = Column' not in text:
    text = text.replace(
        '    content = Column(Text)\n',
        '    content = Column(Text)\n    client_message_id = Column(String(100), nullable=True)\n',
        1,
    )
    p.write_text(text, encoding='utf-8')

p = ROOT / 'backend/app/schemas/chat.py'
text = p.read_text(encoding='utf-8')
if 'client_message_id:' not in text:
    text = text.replace(
        '    content: str = ""\n',
        '    content: str = ""\n    client_message_id: str | None = None\n',
        1,
    )
    text = text.replace(
        '    message_type: str\n    created_at: datetime\n',
        '    message_type: str\n    client_message_id: str | None = None\n    created_at: datetime\n',
        1,
    )
    p.write_text(text, encoding='utf-8')
