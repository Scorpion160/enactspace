from datetime import datetime
from decimal import Decimal, InvalidOperation
from uuid import UUID

from fastapi import HTTPException, Request, status
from sqlalchemy.orm import Session

from app.models.finance import (
    ClubTransaction,
    Fee,
    FinancialAccount,
    Payment,
    PaymentAllocation,
)
from app.models.mobile_money import (
    MobileMoneyTransaction,
    MobileMoneyTransactionEvent,
)
from app.services.audit_service import create_audit_log, get_client_ip
from app.services.notification_service import notify_user
from app.services.payments import get_payment_provider


ACTIVE_MOBILE_MONEY_STATUSES = {"created", "pending", "processing"}


def normalize_currency(currency: str | None) -> str:
    value = (currency or "XOF").upper()
    if value in {"XOF", "FCFA", "CFA"}:
        return "XOF"
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Devise Mobile Money non prise en charge",
    )


def amount_to_int(value) -> int | None:
    if value is None:
        return None
    try:
        amount = Decimal(str(value))
    except InvalidOperation as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Montant provider invalide",
        ) from exc
    if amount != amount.to_integral_value():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Montant provider non entier",
        )
    return int(amount)


def fee_remaining_amount(fee: Fee) -> int:
    normalize_currency(fee.currency)
    amount = Decimal(str(fee.amount or 0))
    amount_paid = Decimal(str(fee.amount_paid or 0))
    remaining = amount - amount_paid
    if remaining <= 0:
        return 0
    if remaining != remaining.to_integral_value():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le montant Mobile Money doit etre un entier en FCFA",
        )
    return int(remaining)


def update_fee_status(fee: Fee) -> None:
    amount = Decimal(str(fee.amount or 0))
    amount_paid = Decimal(str(fee.amount_paid or 0))
    if amount_paid <= 0:
        fee.status = "unpaid"
    elif amount_paid < amount:
        fee.status = "partial"
    else:
        fee.status = "paid"
        if fee.paid_at is None:
            fee.paid_at = datetime.utcnow()
    fee.updated_at = datetime.utcnow()


def create_event(
    db: Session,
    transaction: MobileMoneyTransaction,
    *,
    event_type: str,
    old_status: str | None = None,
    new_status: str | None = None,
    provider_event_id: str | None = None,
    is_duplicate: bool = False,
    error_message: str | None = None,
    metadata_json: dict | None = None,
) -> MobileMoneyTransactionEvent:
    event = MobileMoneyTransactionEvent(
        transaction_id=transaction.id,
        event_type=event_type,
        old_status=old_status,
        new_status=new_status,
        provider_event_id=provider_event_id,
        processed_at=datetime.utcnow(),
        is_duplicate=is_duplicate,
        error_message=error_message,
        metadata_json=metadata_json or {},
    )
    db.add(event)
    return event


def public_payload(
    transaction: MobileMoneyTransaction,
    *,
    message: str | None = None,
) -> dict:
    status_messages = {
        "created": "Paiement cree.",
        "pending": "Le paiement est en cours de verification.",
        "processing": "Le paiement est en cours de verification.",
        "successful": "Le paiement a ete confirme.",
        "failed": "Le paiement n'a pas ete finalise.",
        "cancelled": "Le paiement a ete annule.",
        "expired": "La transaction a expire.",
        "refunded": "Le paiement a ete rembourse.",
    }
    return {
        "transaction_id": transaction.id,
        "amount": transaction.amount,
        "currency": transaction.currency,
        "status": transaction.status,
        "checkout_url": transaction.checkout_url,
        "expires_at": transaction.expires_at,
        "message": message or status_messages.get(transaction.status, "Paiement."),
    }


def can_access_transaction(db: Session, user, transaction: MobileMoneyTransaction) -> bool:
    from app.api.routes.finance import is_finance_manager

    return transaction.member_id == user.id or is_finance_manager(db, user)


def find_transaction(
    db: Session,
    *,
    provider_token: str | None = None,
    internal_transaction_id: str | None = None,
) -> MobileMoneyTransaction | None:
    if provider_token:
        transaction = (
            db.query(MobileMoneyTransaction)
            .filter(MobileMoneyTransaction.provider_invoice_token == provider_token)
            .first()
        )
        if transaction:
            return transaction
    if internal_transaction_id:
        try:
            transaction_uuid = UUID(str(internal_transaction_id))
        except ValueError:
            return None
        return (
            db.query(MobileMoneyTransaction)
            .filter(MobileMoneyTransaction.id == transaction_uuid)
            .first()
        )
    return None


def selected_fees(db: Session, transaction: MobileMoneyTransaction) -> list[Fee]:
    metadata_ids = (transaction.metadata_json or {}).get("finance_item_ids", [])
    fee_ids = []
    for item_id in metadata_ids:
        try:
            fee_ids.append(UUID(str(item_id)))
        except ValueError:
            continue
    if not fee_ids:
        return []
    fees = db.query(Fee).filter(Fee.id.in_(fee_ids)).all()
    fee_by_id = {str(fee.id): fee for fee in fees}
    return [fee_by_id[str(fee_id)] for fee_id in fee_ids if str(fee_id) in fee_by_id]


def ensure_financial_account(db: Session, user_id) -> FinancialAccount:
    account = db.query(FinancialAccount).filter(
        FinancialAccount.user_id == user_id
    ).first()
    if not account:
        account = FinancialAccount(user_id=user_id, balance_due=0, total_paid=0)
        db.add(account)
        db.flush()
    return account


def allocate_payment(
    db: Session,
    *,
    payment: Payment,
    transaction: MobileMoneyTransaction,
) -> int:
    remaining = int(transaction.amount or 0)
    allocated_total = 0
    fees = selected_fees(db, transaction)
    if not fees:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Aucune dette liee a la transaction",
        )
    for fee in fees:
        if remaining <= 0:
            break
        fee_remaining = fee_remaining_amount(fee)
        if fee_remaining <= 0:
            update_fee_status(fee)
            continue
        allocation_amount = min(remaining, fee_remaining)
        db.add(
            PaymentAllocation(
                payment_id=payment.id,
                fee_id=fee.id,
                amount=allocation_amount,
            )
        )
        fee.amount_paid = float(fee.amount_paid or 0) + allocation_amount
        update_fee_status(fee)
        remaining -= allocation_amount
        allocated_total += allocation_amount
    if allocated_total != int(transaction.amount or 0):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le montant confirme ne correspond pas aux dettes selectionnees",
        )
    return allocated_total


def mark_not_successful(
    db: Session,
    *,
    transaction: MobileMoneyTransaction,
    new_status: str,
    provider_status: str | None,
    provider_event_id: str | None = None,
) -> None:
    if transaction.status == "successful":
        return
    old_status = transaction.status
    transaction.status = new_status
    transaction.provider_status = provider_status
    transaction.last_verified_at = datetime.utcnow()
    transaction.updated_at = datetime.utcnow()
    if new_status == "cancelled":
        transaction.cancelled_at = datetime.utcnow()
    create_event(
        db,
        transaction,
        event_type="provider_status",
        old_status=old_status,
        new_status=new_status,
        provider_event_id=provider_event_id,
        metadata_json={"provider_status": provider_status},
    )


def confirm_transaction(
    db: Session,
    *,
    transaction: MobileMoneyTransaction,
    provider_status: str | None,
    provider_transaction_id: str | None,
    provider_event_id: str | None = None,
    request: Request | None = None,
) -> Payment:
    if transaction.payment_id:
        payment = db.query(Payment).filter(Payment.id == transaction.payment_id).first()
        if payment:
            return payment

    old_status = transaction.status
    payment = Payment(
        user_id=transaction.member_id,
        amount=transaction.amount,
        currency="FCFA",
        method="mobile_money",
        status="validated",
        reference=(
            f"PayDunya:{provider_transaction_id[-12:]}"
            if provider_transaction_id
            else f"MobileMoney:{str(transaction.id)[-12:]}"
        ),
        validated_at=datetime.utcnow(),
    )
    db.add(payment)
    db.flush()
    allocated_total = allocate_payment(db, payment=payment, transaction=transaction)

    account = ensure_financial_account(db, transaction.member_id)
    account.total_paid = float(account.total_paid or 0) + transaction.amount
    account.balance_due = max(0, float(account.balance_due or 0) - allocated_total)
    account.updated_at = datetime.utcnow()

    db.add(
        ClubTransaction(
            type="income",
            category="mobile_money",
            label="Paiement Mobile Money",
            amount=transaction.amount,
            payment_id=payment.id,
        )
    )
    transaction.payment_id = payment.id
    transaction.status = "successful"
    transaction.provider_status = provider_status
    transaction.provider_transaction_id = (
        provider_transaction_id or transaction.provider_transaction_id
    )
    transaction.completed_at = datetime.utcnow()
    transaction.last_verified_at = datetime.utcnow()
    transaction.updated_at = datetime.utcnow()
    create_event(
        db,
        transaction,
        event_type="confirmed",
        old_status=old_status,
        new_status=transaction.status,
        provider_event_id=provider_event_id,
        metadata_json={"payment_id": str(payment.id), "allocated_total": allocated_total},
    )
    notify_user(
        db,
        user_id=transaction.member_id,
        title="Paiement confirme",
        message=f"Votre paiement de {transaction.amount:.0f} FCFA a ete confirme.",
        notification_type="payment_confirmed",
        related_type="payment",
        related_id=payment.id,
        dedupe=True,
    )
    create_audit_log(
        db=db,
        action="mobile_money_confirmed",
        user_id=None,
        entity_type="mobile_money_transaction",
        entity_id=transaction.id,
        old_value={"status": old_status},
        new_value={
            "status": transaction.status,
            "payment_id": str(payment.id),
            "amount": transaction.amount,
            "provider": transaction.provider,
        },
        ip_address=get_client_ip(request),
    )
    return payment


async def refresh_transaction(
    db: Session,
    *,
    transaction: MobileMoneyTransaction,
    request: Request | None = None,
) -> MobileMoneyTransaction:
    now = datetime.utcnow()
    if transaction.status == "successful":
        return transaction
    if transaction.expires_at and transaction.expires_at <= now:
        mark_not_successful(
            db,
            transaction=transaction,
            new_status="expired",
            provider_status=transaction.provider_status,
        )
        return transaction
    provider = get_payment_provider(transaction.provider)
    provider_result = await provider.get_payment_status(
        provider_token=transaction.provider_invoice_token,
        provider_transaction_id=transaction.provider_transaction_id,
    )
    provider_event_id = (
        provider_result.metadata or {}
    ).get("event_id") or provider_result.provider_token
    if provider_result.status == "successful":
        confirm_transaction(
            db,
            transaction=transaction,
            provider_status=provider_result.provider_status,
            provider_transaction_id=provider_result.provider_transaction_id,
            provider_event_id=provider_event_id,
            request=request,
        )
    else:
        mark_not_successful(
            db,
            transaction=transaction,
            new_status=provider_result.status,
            provider_status=provider_result.provider_status,
            provider_event_id=provider_event_id,
        )
    return transaction


async def reconcile_pending_transactions(
    db: Session,
    *,
    request: Request | None = None,
    limit: int = 50,
) -> dict:
    transactions = (
        db.query(MobileMoneyTransaction)
        .filter(MobileMoneyTransaction.status.in_(ACTIVE_MOBILE_MONEY_STATUSES))
        .order_by(MobileMoneyTransaction.created_at.asc())
        .limit(limit)
        .all()
    )
    summary = {
        "checked": 0,
        "successful": 0,
        "expired": 0,
        "failed": 0,
        "pending": 0,
    }
    for transaction in transactions:
        summary["checked"] += 1
        await refresh_transaction(db, transaction=transaction, request=request)
        if transaction.status in summary:
            summary[transaction.status] += 1
    return summary
