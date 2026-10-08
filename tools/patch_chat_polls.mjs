import fs from 'node:fs';
import path from 'node:path';

const root = 'C:/Users/DIOP/Documents/EnactSpaceRecovery/enactspace-20260927';
const rel = 'backend/app/api/routes/chat.py';
const file = path.join(root, rel);
let text = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');

function replaceOnce(oldText, newText) {
  const at = text.indexOf(oldText);
  if (at < 0) throw new Error(`marker missing: ${oldText.slice(0, 80)}`);
  if (text.indexOf(oldText, at + oldText.length) >= 0) {
    throw new Error(`marker not unique: ${oldText.slice(0, 80)}`);
  }
  text = text.slice(0, at) + newText + text.slice(at + oldText.length);
}

replaceOnce(
  '    ChatMessageReaction,\n)',
  '    ChatMessageReaction,\n    ChatPoll,\n    ChatPollOption,\n    ChatPollVote,\n)',
);
replaceOnce(
  '    ChatMessageReactionRead,\n)',
  '    ChatMessageReactionRead,\n    ChatPollCreate,\n    ChatPollVoteCreate,\n    ChatPollRead,\n)',
);
replaceOnce(
  'VALID_MESSAGE_TYPES = {"text", "image", "video", "audio", "document", "sticker"}\nMEDIA_MESSAGE_TYPES = VALID_MESSAGE_TYPES - {"text"}',
  'VALID_MESSAGE_TYPES = {"text", "image", "video", "audio", "document", "sticker", "poll"}\nMEDIA_MESSAGE_TYPES = VALID_MESSAGE_TYPES - {"text", "poll"}',
);
replaceOnce(
  '    "sticker": "Sticker",\n}',
  '    "sticker": "Sticker",\n    "poll": "Sondage",\n}',
);

const serializeMarker = 'def serialize_message(\n';
const helpers = `def serialize_poll(\n    db: Session,\n    poll: ChatPoll,\n    current_user_id=None,\n) -> ChatPollRead:\n    options = db.query(ChatPollOption).filter(\n        ChatPollOption.poll_id == poll.id\n    ).order_by(ChatPollOption.position.asc()).all()\n    counts = dict(\n        db.query(ChatPollVote.option_id, func.count(ChatPollVote.id))\n        .filter(ChatPollVote.poll_id == poll.id)\n        .group_by(ChatPollVote.option_id)\n        .all()\n    )\n`;
replaceOnce(serializeMarker, helpers + '\n' + serializeMarker);
const helperTailMarker = '    counts = dict(\n        db.query(ChatPollVote.option_id, func.count(ChatPollVote.id))\n        .filter(ChatPollVote.poll_id == poll.id)\n        .group_by(ChatPollVote.option_id)\n        .all()\n    )\n\ndef serialize_message(\n';
const helperTail = `    counts = dict(\n        db.query(ChatPollVote.option_id, func.count(ChatPollVote.id))\n        .filter(ChatPollVote.poll_id == poll.id)\n        .group_by(ChatPollVote.option_id)\n        .all()\n    )\n    selected = set()\n    if current_user_id is not None:\n        selected = {\n            row[0]\n            for row in db.query(ChatPollVote.option_id).filter(\n                ChatPollVote.poll_id == poll.id,\n                ChatPollVote.user_id == current_user_id,\n            ).all()\n        }\n    total_voters = int(\n        db.query(func.count(func.distinct(ChatPollVote.user_id)))\n        .filter(ChatPollVote.poll_id == poll.id)\n        .scalar()\n        or 0\n    )\n    total_votes = sum(int(value or 0) for value in counts.values())\n    is_closed = bool(poll.closes_at and poll.closes_at <= utc_now())\n    return ChatPollRead(\n        id=poll.id,\n        message_id=poll.message_id,\n        question=poll.question,\n        allows_multiple=poll.allows_multiple,\n        closes_at=poll.closes_at,\n        is_closed=is_closed,\n        total_votes=total_votes,\n        total_voters=total_voters,\n        options=[\n            {\n                "id": option.id,\n                "label": option.label,\n                "position": option.position,\n                "votes_count": int(counts.get(option.id, 0) or 0),\n                "current_user_voted": option.id in selected,\n            }\n            for option in options\n        ],\n    )\n\n\ndef serialize_message(\n`;
replaceOnce(helperTailMarker, helperTail);
replaceOnce(
  `    reactions_summary = (\n        message_reactions_summary(db, message.id)\n        if db is not None\n        else {}\n    )\n\n    return {`,
  `    reactions_summary = (\n        message_reactions_summary(db, message.id)\n        if db is not None\n        else {}\n    )\n    poll_payload = None\n    if db is not None and message.message_type == "poll":\n        poll = db.query(ChatPoll).filter(ChatPoll.message_id == message.id).first()\n        if poll is not None:\n            poll_payload = serialize_poll(db, poll, current_user_id)\n\n    return {`,
);
replaceOnce(
  `        "current_user_reaction": current_user_reaction(\n            db,\n            message.id,\n            current_user_id,\n        )\n        if db is not None and current_user_id is not None\n        else None,\n    }`,
  `        "current_user_reaction": current_user_reaction(\n            db,\n            message.id,\n            current_user_id,\n        )\n        if db is not None and current_user_id is not None\n        else None,\n        "poll": poll_payload,\n    }`,
);
replaceOnce(
  `def message_preview(message: ChatMessage) -> str:\n    if message.message_type == "text":\n        return message.content\n`,
  `def message_preview(message: ChatMessage) -> str:\n    if message.message_type == "text":\n        return message.content\n    if message.message_type == "poll":\n        return f"Sondage · {message.content}"\n`,
);
replaceOnce(
  `    if payload.message_type not in VALID_MESSAGE_TYPES:\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Type de message invalide",\n        )\n\n    if payload.message_type == "text" and not content:`,
  `    if payload.message_type not in VALID_MESSAGE_TYPES:\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Type de message invalide",\n        )\n    if payload.message_type == "poll":\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Utilisez l'endpoint sondage pour créer un sondage",\n        )\n\n    if payload.message_type == "text" and not content:`,
);

fs.writeFileSync(file, text, 'utf8');
console.log('chat poll base integration patched');
