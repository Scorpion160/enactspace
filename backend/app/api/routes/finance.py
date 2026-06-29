from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status, Request
from app.services.audit_service import create_audit_log, get_client_ip
from app.services.notification_service import notify_user, notify_users

from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.finance import (
    Fee,
    FinancialAccount,
    Payment,
    PaymentAllocation,
    ClubTransaction,
)
from app.models.role import Role, UserRole
from app.models.user import User
from app.schemas.finance import (
    FeeCreate,
    FeeRead,
    FinancialAccountRead,
    PaymentCreate,
    PaymentRead,
    PaymentAllocationRead,
    ClubTransactionCreate,
    ClubTransactionRead,
)
from app.api.deps import (
    get_current_active_validated_user,
    require_finance_or_admin,
    user_has_any_role,
)

router = APIRouter(prefix="/finance", tags=["Finances"])


VALID_PAYMENT_METHODS = {
    "manuel",
    "especes",
    "wave",
    "orange_money",
    "free_money",
    "bank_transfer",
}

VALID_FEE_STATUSES = {
    "unpaid",
    "partial",
    "paid",
    "cancelled",
}

FINANCE_MANAGER_ROLES = {"administrateur", "team_leader", "financier"}


def is_finance_manager(db: Session, current_user: User) -> bool:
    return user_has_any_role(db, current_user.id, FINANCE_MANAGER_ROLES)


def get_payment_or_404(db: Session, payment_id: str) -> Payment:
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    if payment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Paiement introuvable",
        )
    return payment


def payment_payload(
    db: Session,
    current_user: User,
    payment: Payment,
) -> dict:
    manager = is_finance_manager(db, current_user)
    data = PaymentRead.model_validate(payment).model_dump()
    data["can_validate"] = manager and payment.status == "pending"
    data["can_cancel"] = payment.status == "pending" and (
        manager or payment.user_id == current_user.id
    )
    return data


def finance_manager_ids(db: Session) -> list:
    rows = (
        db.query(UserRole.user_id)
        .join(Role, Role.id == UserRole.role_id)
        .filter(Role.name.in_(FINANCE_MANAGER_ROLES))
        .distinct()
        .all()
    )
    return [row[0] for row in rows]


def ensure_financial_account(db: Session, user_id):
    account = db.query(FinancialAccount).filter(
        FinancialAccount.user_id == user_id
    ).first()

    if not account:
        account = FinancialAccount(
            user_id=user_id,
            balance_due=0,
            total_paid=0,
        )
        db.add(account)
        db.flush()

    return account


def update_fee_status(fee: Fee):
    amount = float(fee.amount or 0)
    amount_paid = float(fee.amount_paid or 0)

    if amount_paid <= 0:
        fee.status = "unpaid"
    elif amount_paid < amount:
        fee.status = "partial"
    else:
        fee.status = "paid"

    fee.updated_at = datetime.utcnow()


def allocate_payment_to_unpaid_fees(
    db: Session,
    payment: Payment,
):
    remaining = float(payment.amount or 0)

    fees = db.query(Fee).filter(
        Fee.user_id == payment.user_id,
        Fee.status.in_(["unpaid", "partial"]),
    ).order_by(Fee.created_at.asc()).all()

    allocations = []

    for fee in fees:
        if remaining <= 0:
            break

        fee_amount = float(fee.amount or 0)
        fee_paid = float(fee.amount_paid or 0)
        fee_remaining = fee_amount - fee_paid

        if fee_remaining <= 0:
            update_fee_status(fee)
            continue

        allocation_amount = min(remaining, fee_remaining)

        allocation = PaymentAllocation(
            payment_id=payment.id,
            fee_id=fee.id,
            amount=allocation_amount,
        )

        db.add(allocation)

        fee.amount_paid = fee_paid + allocation_amount
        update_fee_status(fee)

        remaining -= allocation_amount
        allocations.append(allocation)

    return allocations


@router.post("/fees", response_model=FeeRead)
def create_fee(
    payload: FeeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    if payload.amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le montant doit être supérieur à zéro",
        )

    fee = Fee(
        user_id=payload.user_id,
        season_id=payload.season_id,
        type=payload.type,
        label=payload.label,
        amount=payload.amount,
        amount_paid=0,
        status="unpaid",
        due_date=payload.due_date,
        created_by=current_user.id,
    )

    account = ensure_financial_account(db, payload.user_id)
    account.balance_due = float(account.balance_due or 0) + payload.amount
    account.updated_at = datetime.utcnow()

    db.add(fee)
    db.flush()
    notify_user(
        db,
        user_id=payload.user_id,
        title="Nouveau frais ajouté",
        message=f"{payload.label}: {payload.amount:.0f} FCFA.",
        notification_type="fee_due",
        related_type="fee",
        related_id=fee.id,
    )
    db.commit()
    db.refresh(fee)

    return fee


@router.get("/fees", response_model=list[FeeRead])
def list_fees(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    return db.query(Fee).order_by(Fee.created_at.desc()).all()


@router.get("/fees/user/{user_id}", response_model=list[FeeRead])
def list_user_fees(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    return db.query(Fee).filter(
        Fee.user_id == user_id
    ).order_by(Fee.created_at.desc()).all()


@router.get("/fees/me", response_model=list[FeeRead])
def list_my_fees(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return db.query(Fee).filter(
        Fee.user_id == current_user.id
    ).order_by(Fee.created_at.desc()).all()


@router.get("/accounts", response_model=list[FinancialAccountRead])
def list_financial_accounts(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    return db.query(FinancialAccount).order_by(
        FinancialAccount.balance_due.desc()
    ).all()


@router.get("/accounts/user/{user_id}", response_model=FinancialAccountRead)
def get_user_financial_account(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    account = ensure_financial_account(db, user_id)
    db.commit()
    db.refresh(account)
    return account


@router.get("/accounts/me", response_model=FinancialAccountRead)
def get_my_financial_account(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    account = ensure_financial_account(db, current_user.id)
    db.commit()
    db.refresh(account)
    return account


@router.post("/payments", response_model=PaymentRead)
def create_payment(
    payload: PaymentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    if payload.amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le montant doit être supérieur à zéro",
        )

    if payload.method not in VALID_PAYMENT_METHODS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Méthode de paiement invalide",
        )
    if (
        payload.user_id != current_user.id
        and not is_finance_manager(db, current_user)
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous ne pouvez enregistrer qu’un paiement pour votre compte",
        )
    if not is_finance_manager(db, current_user):
        if payload.method in {"manuel", "especes"}:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Les paiements en espèces sont saisis par le financier",
            )
        if not (payload.reference or payload.proof_url):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ajoutez une référence ou une preuve de paiement",
            )

    payment = Payment(
        user_id=payload.user_id,
        amount=payload.amount,
        method=payload.method,
        status="pending",
        reference=payload.reference,
        proof_url=payload.proof_url,
    )

    db.add(payment)
    db.flush()
    if not is_finance_manager(db, current_user):
        notify_users(
            db,
            user_ids=finance_manager_ids(db),
            title="Paiement à vérifier",
            message=(
                f"{current_user.first_name} {current_user.last_name}".strip()
                + f" a déclaré {payload.amount:.0f} FCFA."
            ),
            notification_type="payment_submitted",
            related_type="payment",
            related_id=payment.id,
        )
    db.commit()
    db.refresh(payment)

    return payment_payload(db, current_user, payment)


@router.get("/payments", response_model=list[PaymentRead])
def list_payments(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    payments = db.query(Payment).order_by(Payment.created_at.desc()).all()
    return [
        payment_payload(db, current_user, payment)
        for payment in payments
    ]


@router.get("/payments/me", response_model=list[PaymentRead])
def list_my_payments(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    payments = db.query(Payment).filter(
        Payment.user_id == current_user.id
    ).order_by(Payment.created_at.desc()).all()
    return [
        payment_payload(db, current_user, payment)
        for payment in payments
    ]


@router.get("/payments/user/{user_id}", response_model=list[PaymentRead])
def list_user_payments(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    payments = db.query(Payment).filter(
        Payment.user_id == user_id
    ).order_by(Payment.created_at.desc()).all()
    return [
        payment_payload(db, current_user, payment)
        for payment in payments
    ]


@router.post("/payments/{payment_id}/validate", response_model=PaymentRead)
def validate_payment(
    payment_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    payment = get_payment_or_404(db, payment_id)

    if payment.status == "validated":
        return payment_payload(db, current_user, payment)

    if payment.status == "cancelled":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Impossible de valider un paiement annulé",
        )

    payment.status = "validated"
    payment.validated_by = current_user.id
    payment.validated_at = datetime.utcnow()

    allocations = allocate_payment_to_unpaid_fees(db, payment)

    account = ensure_financial_account(db, payment.user_id)

    allocated_total = sum(float(a.amount or 0) for a in allocations)

    account.total_paid = float(account.total_paid or 0) + float(payment.amount or 0)
    account.balance_due = max(
        0,
        float(account.balance_due or 0) - allocated_total,
    )
    account.updated_at = datetime.utcnow()

    transaction = ClubTransaction(
        type="income",
        category="paiement_membre",
        label="Paiement membre",
        amount=payment.amount,
        payment_id=payment.id,
        created_by=current_user.id,
        validated_by=current_user.id,
    )
    notify_user(
        db,
        user_id=payment.user_id,
        title="Paiement validé",
        message=f"Votre paiement de {float(payment.amount):.0f} FCFA est validé.",
        notification_type="payment_validated",
        related_type="payment",
        related_id=payment.id,
    )

    db.add(transaction)
    create_audit_log(
        db=db,
        action="validation_paiement",
        user_id=current_user.id,
        entity_type="payment",
        entity_id=payment.id,
        old_value={"status": "pending"},
        new_value={
            "status": "validated",
            "amount": float(payment.amount or 0),
            "method": payment.method,
            "allocated_total": allocated_total,
        },
        ip_address=get_client_ip(request),
    )

    db.commit()
    db.refresh(payment)

    return payment_payload(db, current_user, payment)

@router.post("/payments/{payment_id}/cancel", response_model=PaymentRead)
def cancel_payment(
    payment_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    payment = get_payment_or_404(db, payment_id)
    if not (
        is_finance_manager(db, current_user)
        or payment.user_id == current_user.id
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous ne pouvez pas annuler ce paiement",
        )

    old_status = payment.status

    if payment.status == "cancelled":
        return payment_payload(db, current_user, payment)

    if payment.status == "validated":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Impossible d'annuler directement un paiement déjà validé",
        )

    payment.status = "cancelled"
    if is_finance_manager(db, current_user) and payment.user_id != current_user.id:
        notify_user(
            db,
            user_id=payment.user_id,
            title="Paiement annule",
            message=f"Votre paiement de {float(payment.amount):.0f} FCFA a ete annule.",
            notification_type="payment_cancelled",
            related_type="payment",
            related_id=payment.id,
            dedupe=True,
        )
    elif payment.user_id == current_user.id:
        manager_ids = [
            user_id for user_id in finance_manager_ids(db) if user_id != current_user.id
        ]
        notify_users(
            db,
            user_ids=manager_ids,
            title="Paiement annule",
            message=f"Un paiement de {float(payment.amount):.0f} FCFA a ete annule.",
            notification_type="payment_cancelled",
            related_type="payment",
            related_id=payment.id,
            dedupe=True,
        )
    create_audit_log(
        db=db,
        action="annulation_paiement",
        user_id=current_user.id,
        entity_type="payment",
        entity_id=payment.id,
        old_value={
            "status": old_status,
        },
        new_value={
            "status": payment.status,
        },
        ip_address=get_client_ip(request),
    )

    db.commit()
    db.refresh(payment)

    return payment_payload(db, current_user, payment)


@router.get("/payments/{payment_id}/allocations", response_model=list[PaymentAllocationRead])
def list_payment_allocations(
    payment_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    return db.query(PaymentAllocation).filter(
        PaymentAllocation.payment_id == payment_id
    ).order_by(PaymentAllocation.created_at.asc()).all()


@router.post("/transactions", response_model=ClubTransactionRead)
def create_club_transaction(
    payload: ClubTransactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    if payload.amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le montant doit être supérieur à zéro",
        )

    if payload.type not in {"income", "expense"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le type doit être income ou expense",
        )

    transaction = ClubTransaction(
        season_id=payload.season_id,
        type=payload.type,
        category=payload.category,
        label=payload.label,
        amount=payload.amount,
        project_id=payload.project_id,
        pole_id=payload.pole_id,
        proof_url=payload.proof_url,
        created_by=current_user.id,
    )

    db.add(transaction)
    db.commit()
    db.refresh(transaction)

    return transaction


@router.get("/transactions", response_model=list[ClubTransactionRead])
def list_club_transactions(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    return db.query(ClubTransaction).order_by(
        ClubTransaction.created_at.desc()
    ).all()
