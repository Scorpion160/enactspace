"""Locks for finance declarations and account creation within the current transaction."""
import hashlib
from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.models.user import User
from app.models.finance import FinancialAccount
from app.services.operational_integrity import lock_row

def lock_payment_declaration(db: Session, *, method: str, reference: str | None,
                             checksum: str | None, proof_id=None) -> None:
    if db.get_bind().dialect.name != "postgresql":
        return
    identities = []
    if reference:
        identities.append("finance-reference:" + method + ":" + reference.lower())
    if checksum:
        identities.append("finance-proof:" + checksum)
    elif proof_id:
        identities.append("finance-proof-id:" + str(proof_id))
    keys = sorted({int.from_bytes(hashlib.sha256(value.encode("utf-8")).digest()[:8],
                                 "big", signed=True) for value in identities})
    for key in keys:
        db.execute(text("SELECT pg_advisory_xact_lock(:key)"), {"key": key})

def ensure_financial_account(db: Session, user_id) -> FinancialAccount:
    # Lock the existing parent before testing the unique account, including first creation.
    if lock_row(db, User, user_id) is None:
        raise HTTPException(status_code=404, detail="Membre introuvable")
    account = db.query(FinancialAccount).filter(
        FinancialAccount.user_id == user_id
    ).populate_existing().with_for_update().first()
    if account is None:
        account = FinancialAccount(user_id=user_id, balance_due=0, total_paid=0)
        db.add(account)
        db.flush()
    return account
