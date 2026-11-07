from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.db.database import get_db
from app.models.mobile_money import MobileMoneyTransaction
import app.services.mobile_money_service as mm_service
from app.services.payments import PaymentProviderError, get_payment_provider
from app.services.operational_integrity import lock_row
from app.services.paydunya_callback import read_paydunya_callback

router = APIRouter(prefix="/payments", tags=["Paiements"])


@router.post("/paydunya/ipn")
async def paydunya_ipn(
    payload: dict = Depends(read_paydunya_callback),
    request: Request = None,
    db: Session = Depends(get_db),
):
    provider = get_payment_provider("paydunya")
    try:
        provider_result = await provider.verify_callback(payload)
    except PaymentProviderError as exc:
        invalid = exc.code in {"invalid_callback", "invalid_callback_hash"}
        raise HTTPException(
            status_code=400 if invalid else 503,
            detail="Notification de paiement invalide." if invalid else
                "La vérification du paiement est momentanément indisponible.",
            headers=None if invalid else {"Retry-After": "30"},
        ) from exc

    metadata = provider_result.metadata or {}
    custom_data = metadata.get("custom_data") or {}
    internal_transaction_id = custom_data.get("enactspace_transaction_id")
    provider_event_id = metadata.get("event_id") or provider_result.provider_token
    transaction = mm_service.find_transaction(
        db,
        provider_token=provider_result.provider_token,
        internal_transaction_id=internal_transaction_id,
    )
    if transaction is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction Mobile Money introuvable",
        )
    transaction = await run_in_threadpool(lock_row, db, MobileMoneyTransaction, transaction.id)
    if transaction is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction Mobile Money introuvable",
        )

    mm_service.validate_provider_result(transaction, provider_result)

    if transaction.status == "successful" and transaction.payment_id:
        mm_service.create_event(
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
        payment = mm_service.confirm_transaction(
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

    mm_service.mark_not_successful(
        db,
        transaction=transaction,
        new_status=provider_result.status,
        provider_status=provider_result.provider_status,
        provider_event_id=provider_event_id,
    )
    db.commit()
    return {"ok": True, "status": transaction.status}
