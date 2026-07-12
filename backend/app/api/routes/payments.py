from datetime import datetime
from decimal import Decimal, InvalidOperation
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.finance import (
    ClubTransaction,
    Fee,
    FinancialAccount,
    Payment,
    PaymentAllocation,
)
from app.models.mobile_money import MobileMoneyTransaction
from app.services.audit_service import create_audit_log, get_client_ip
from app.services.notification_service import notify_user
from app.services.payments import PaymentProviderError, get_payment_provider
from app.api.routes.finance import (
    fee_remaining_xof_amount,
    mobile_money_event,
    normalize_mobile_money_currency,
    update_fee_status,
)

router = APIRouter(prefix="/payments", tags=["Paiements"])


def provider_amount_to_int(value) -> int | None:
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


def find_mobile_money_transaction(
    db: Session,
    *,
    provider_token: str | None,
    internal_transaction_id: str | None,
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


def selected_mobile_money_fees(
    db: Session,
    transaction: MobileMoneyTransaction,
) -> list[Fee]:
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


def ensure_financial_account_for_mobile_money(db: Session, user_id) -> FinancialAccount:
    account = db.query(FinancialAccount).filter(
        FinancialAccount.user_id == user_id
    ).first()
    if not account:
        account = FinancialAccount(user_id=user_id, balance_due=0, total_paid=0)
        db.add(account)
        db.flush()
    return account


def allocate_mobile_money_payment(
    db: Session,
    *,
    payment: Payment,
    transaction: MobileMoneyTransaction,
) -> int:
    remaining = int(transaction.amount or 0)
    allocated_total = 0
    fees = selected_mobile_money_fees(db, transaction)
    if not fees:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Aucune dette liee a la transaction",
        )
    for fee in fees:
        if remaining <= 0:
            break
        fee_remaining = fee_remaining_xof_amount(fee)
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


def mark_mobile_money_not_successful(
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
    transaction.updated_at = datetime.utcnow()
    if new_status == "cancelled":
        transaction.cancelled_at = datetime.utcnow()
    mobile_money_event(
        db,
        transaction,
        event_type="provider_status",
        old_status=old_status,
        new_status=new_status,
        provider_event_id=provider_event_id,
        metadata_json={"provider_status": provider_status},
    )


def confirm_mobile_money_transaction(
    db: Session,
    *,
    transaction: MobileMoneyTransaction,
    provider_status: str | None,
    provider_transaction_id: str | None,
    provider_event_id: str | None = None,
    request: Request,
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
    allocated_total = allocate_mobile_money_payment(
        db,
        payment=payment,
        transaction=transaction,
    )

    account = ensure_financial_account_for_mobile_money(db, transaction.member_id)
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
            validated_by=None,
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
    mobile_money_event(
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


@router.post("/paydunya/ipn")
async def paydunya_ipn(
    payload: dict,
    request: Request,
    db: Session = Depends(get_db),
):
    provider = get_payment_provider("paydunya")
    try:
        provider_result = await provider.verify_callback(payload)
    except PaymentProviderError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=exc.public_message,
        ) from exc

    metadata = provider_result.metadata or {}
    custom_data = metadata.get("custom_data") or {}
    internal_transaction_id = custom_data.get("enactspace_transaction_id")
    provider_event_id = metadata.get("event_id") or provider_result.provider_token
    transaction = find_mobile_money_transaction(
        db,
        provider_token=provider_result.provider_token,
        internal_transaction_id=internal_transaction_id,
    )
    if transaction is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction Mobile Money introuvable",
        )

    provider_amount = provider_amount_to_int(metadata.get("amount"))
    if provider_amount is not None and provider_amount != transaction.amount:
        mobile_money_event(
            db,
            transaction,
            event_type="amount_mismatch",
            old_status=transaction.status,
            new_status=transaction.status,
            provider_event_id=provider_event_id,
            error_message="provider_amount_mismatch",
        )
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Montant provider incoherent",
        )
    provider_currency = normalize_mobile_money_currency(metadata.get("currency"))
    if provider_currency != transaction.currency:
        mobile_money_event(
            db,
            transaction,
            event_type="currency_mismatch",
            old_status=transaction.status,
            new_status=transaction.status,
            provider_event_id=provider_event_id,
            error_message="provider_currency_mismatch",
        )
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Devise provider incoherente",
        )

    if transaction.status == "successful" and transaction.payment_id:
        mobile_money_event(
            db,
            transaction,
            event_type="duplicate_callback",
            old_status=transaction.status,
            new_status=transaction.status,
            provider_event_id=provider_event_id,
            is_duplicate=True,
            metadata_json={"provider_status": provider_result.provider_status},
        )
        db.commit()
        return {"ok": True, "status": transaction.status, "duplicate": True}

    if provider_result.status == "successful":
        payment = confirm_mobile_money_transaction(
            db,
            transaction=transaction,
            provider_status=provider_result.provider_status,
            provider_transaction_id=provider_result.provider_transaction_id,
            provider_event_id=provider_event_id,
            request=request,
        )
        db.commit()
        return {
            "ok": True,
            "status": transaction.status,
            "payment_id": str(payment.id),
        }

    mark_mobile_money_not_successful(
        db,
        transaction=transaction,
        new_status=provider_result.status,
        provider_status=provider_result.provider_status,
        provider_event_id=provider_event_id,
    )
    db.commit()
    return {"ok": True, "status": transaction.status}
