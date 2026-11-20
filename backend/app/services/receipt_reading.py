"""Extract OCR candidates from payment receipts; never prove settlement."""
from __future__ import annotations

import re

_PHONE_RE = re.compile(
    r"(?<!\d)(?:\+?221[\s.\-]*)?(7(?:[\s.\-]*\d){8})(?!\d)",
    re.IGNORECASE,
)
_AMOUNT_TOKEN = r"([0-9][0-9 .\u00a0]{0,16})\s*(?:FCFA|F\s*CFA|XOF|F\b)"
_MONTHS = (
    "jan(?:v(?:ier)?)?|f[eé]v(?:r(?:ier)?)?|mars|avr(?:il)?|mai|juin|"
    "juil(?:let)?|ao[uû]t|sept(?:embre)?|oct(?:obre)?|nov(?:embre)?|"
    "d[eé]c(?:embre)?"
)


def _digits(value: str) -> str:
    return re.sub(r"\D", "", value)


def _phone(value: str) -> str | None:
    digits = _digits(value)
    if digits.startswith("221") and len(digits) == 12:
        digits = digits[3:]
    return digits if len(digits) == 9 and digits.startswith("7") else None


def _amount_after_label(text: str, labels: str) -> int | None:
    pattern = rf"(?:{labels})[\s\S]{{0,65}}?{_AMOUNT_TOKEN}"
    match = re.search(pattern, text, re.IGNORECASE)
    if not match:
        return None
    digits = _digits(match.group(1))
    if not digits:
        return None
    value = int(digits)
    return value if 0 < value <= 100_000_000 else None


def _labelled_phone(lines: list[str], labels: tuple[str, ...]) -> str | None:
    for index, line in enumerate(lines):
        lowered = line.lower()
        if not any(label in lowered for label in labels):
            continue
        window = "\n".join(lines[index : index + 3])
        match = _PHONE_RE.search(window)
        if match:
            return _phone(match.group(0))
    return None


def _first_match(text: str, patterns: list[str]) -> str | None:
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1).strip()
    return None


def parse_receipt(text: str) -> dict:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    normalized = "\n".join(lines)[:8000]
    lowered = normalized.lower()

    provider = None
    if "wave" in lowered:
        provider = "wave"
    elif "orange money" in lowered or "max it" in lowered or "#ofms" in lowered:
        provider = "orange_money"

    received_amount = _amount_after_label(
        normalized,
        r"montant\s+re[cç]u|montant\s+du\s+transfert",
    )
    sent_amount = _amount_after_label(normalized, r"montant\s+envoy[eé]")
    fee_amount = _amount_after_label(normalized, r"frais")
    generic_amount = _amount_after_label(
        normalized,
        r"montant(?!\s+(?:re[cç]u|envoy[eé]))|transf[eé]r[eé]|pay[eé]",
    )
    amount = received_amount or generic_amount

    if amount is None:
        fallback = re.search(_AMOUNT_TOKEN, normalized, re.IGNORECASE)
        if fallback:
            digits = _digits(fallback.group(1))
            value = int(digits) if digits else 0
            amount = value if 0 < value <= 100_000_000 else None

    phones = []
    for match in _PHONE_RE.finditer(normalized):
        candidate = _phone(match.group(0))
        if candidate and candidate not in phones:
            phones.append(candidate)

    sender = _labelled_phone(
        lines,
        ("expéditeur", "expediteur", "envoyé par", "envoye par"),
    )
    recipient = _labelled_phone(
        lines,
        ("destinataire", "bénéficiaire", "beneficiaire"),
    )

    reference = _first_match(
        normalized,
        [
            r"(?:r[eé]f[eé]rence)\s*[:#-]?\s*([A-Z0-9._-]{5,64})",
            r"(?:id\s+de\s+transaction)\s*[:#-]?\s*([A-Z0-9._-]{5,64})",
            r"(?:transaction\s*(?:id|n[°o]))\s*[:#-]?\s*([A-Z0-9._-]{5,64})",
        ],
    )

    numeric_date = re.search(
        r"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"
        r"(?:\s+(?:[àa]\s*)?\d{1,2}:\d{2}(?::\d{2})?(?:\s*(?:AM|PM))?)?\b",
        normalized,
        re.IGNORECASE,
    )
    written_date = re.search(
        rf"\b\d{{1,2}}\s+(?:{_MONTHS})\.?\s+\d{{4}}"
        rf"(?:\s+(?:[àa]\s*)?\d{{1,2}}:\d{{2}}(?:\s*(?:AM|PM))?)?\b",
        normalized,
        re.IGNORECASE,
    )
    date_text = (
        numeric_date.group(0)
        if numeric_date
        else written_date.group(0) if written_date else None
    )

    status_text = _first_match(
        normalized,
        [
            r"\b(Transfert\s+effectu[eé])\b",
            r"\b(Effectu[eé])\b",
            r"\b(Succ[eè]s|R[eé]ussi|Completed)\b",
        ],
    )

    return {
        "provider_candidate": provider,
        "amount": amount,
        "received_amount": received_amount,
        "sent_amount": sent_amount,
        "fee_amount": fee_amount,
        "date_text": date_text,
        "sender_phone": sender,
        "recipient_phone": recipient,
        "phone_candidates": phones[:4],
        "reference": reference,
        "status_text": status_text,
        "needs_confirmation": True,
    }
