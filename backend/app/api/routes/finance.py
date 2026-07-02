import csv
from datetime import datetime
from io import StringIO

from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.responses import Response
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
from app.models.pole import PoleMember
from app.models.project import ProjectMember
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
    FeeBulkCreate,
    FeeCancelRequest,
    PaymentRejectRequest,
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
VALID_FEE_TYPES = {
    "membership_fee",
    "attendance_penalty",
    "late_penalty",
    "manual_penalty",
    "contribution",
    "adjustment",
    "penalite_retard",
    "penalite_absence",
    "penalty",
}

FINANCE_MANAGER_ROLES = {"administrateur", "team_leader", "financier"}
PAYMENT_SUPERVISOR_ROLES = {"administrateur", "team_leader"}


def is_finance_manager(db: Session, current_user: User) -> bool:
    return user_has_any_role(db, current_user.id, FINANCE_MANAGER_ROLES)


def can_review_payment(db: Session, current_user: User, payment: Payment) -> bool:
    if not is_finance_manager(db, current_user):
        return False
    if payment.user_id != current_user.id:
        return True
    return user_has_any_role(db, current_user.id, PAYMENT_SUPERVISOR_ROLES)


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
    reviewer = can_review_payment(db, current_user, payment)
    data = PaymentRead.model_validate(payment).model_dump()
    data["can_validate"] = reviewer and payment.status == "pending"
    data["can_reject"] = reviewer and payment.status == "pending"
    data["can_cancel"] = payment.status in {"pending", "rejected"} and (
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
        if fee.paid_at is None:
            fee.paid_at = datetime.utcnow()

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
        category=payload.category,
        label=payload.label,
        description=payload.description,
        amount=payload.amount,
        currency=payload.currency,
        amount_paid=0,
        status="unpaid",
        due_date=payload.due_date,
        source_type=payload.source_type,
        source_id=payload.source_id,
        proof_file_id=payload.proof_file_id,
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


@router.post("/fees/bulk", response_model=list[FeeRead])
def create_bulk_fees(
    payload: FeeBulkCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    label = payload.label.strip()
    if not label:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le libelle est obligatoire",
        )

    user_ids = target_user_ids_for_fee_scope(db, payload)
    if not user_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Aucun membre trouve pour ce perimetre",
        )

    fees = []
    source_label = "_".join(label.lower().split())[:40]
    source_type = f"bulk_{payload.scope_type}_{payload.type}_{source_label}"[:80]
    source_id = (
        payload.pole_id
        or payload.project_id
        or payload.season_id
        or current_user.id
    )
    for user_id in user_ids:
        fees.append(
            create_fee_record(
                db,
                user_id=user_id,
                current_user=current_user,
                season_id=payload.season_id,
                fee_type=payload.type,
                category=payload.category,
                label=label,
                description=payload.description,
                amount=payload.amount,
                currency=payload.currency,
                due_date=payload.due_date,
                source_type=source_type,
                source_id=source_id,
            )
        )
    db.commit()
    for fee in fees:
        db.refresh(fee)
    return fees


@router.post("/penalties", response_model=FeeRead)
def create_manual_penalty(
    payload: FeeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    fee = create_fee_record(
        db,
        user_id=payload.user_id,
        current_user=current_user,
        season_id=payload.season_id,
        fee_type="manual_penalty",
        category=payload.category or "manual_penalty",
        label=payload.label,
        description=payload.description,
        amount=payload.amount,
        currency=payload.currency,
        due_date=payload.due_date,
        source_type=payload.source_type or "manual_penalty",
        source_id=payload.source_id,
        proof_file_id=payload.proof_file_id,
    )
    db.commit()
    db.refresh(fee)
    return fee


@router.post("/fees/{fee_id}/cancel", response_model=FeeRead)
def cancel_fee(
    fee_id: str,
    payload: FeeCancelRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    fee = db.query(Fee).filter(Fee.id == fee_id).first()
    if not fee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Frais introuvable",
        )
    if fee.status == "paid":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Impossible d'annuler un frais deja paye",
        )
    reason = payload.reason.strip()
    if not reason:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le motif d'annulation est obligatoire",
        )
    old_status = fee.status
    remaining = max(0, float(fee.amount or 0) - float(fee.amount_paid or 0))
    fee.status = "cancelled"
    fee.cancelled_at = datetime.utcnow()
    fee.description = f"{fee.description or ''}\nAnnulation: {reason}".strip()
    fee.updated_at = datetime.utcnow()
    account = ensure_financial_account(db, fee.user_id)
    account.balance_due = max(0, float(account.balance_due or 0) - remaining)
    account.updated_at = datetime.utcnow()
    notify_user(
        db,
        user_id=fee.user_id,
        title="Montant annule",
        message=f"{fee.label} a ete annule: {reason}",
        notification_type="fee_cancelled",
        related_type="fee",
        related_id=fee.id,
        dedupe=True,
    )
    create_audit_log(
        db=db,
        action="annulation_frais",
        user_id=current_user.id,
        entity_type="fee",
        entity_id=fee.id,
        old_value={"status": old_status},
        new_value={"status": fee.status, "reason": reason},
        ip_address=get_client_ip(request),
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


def display_user(user: User | None) -> str:
    if user is None:
        return ""
    value = f"{user.first_name or ''} {user.last_name or ''}".strip()
    return value or user.email


def target_user_ids_for_fee_scope(db: Session, payload: FeeBulkCreate) -> list:
    if payload.scope_type == "members":
        return list(dict.fromkeys(payload.user_ids))
    if payload.scope_type == "pole" and payload.pole_id:
        return [
            row[0]
            for row in db.query(PoleMember.user_id)
            .filter(
                PoleMember.pole_id == payload.pole_id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
            )
            .all()
        ]
    if payload.scope_type == "project" and payload.project_id:
        return [
            row[0]
            for row in db.query(ProjectMember.user_id)
            .filter(
                ProjectMember.project_id == payload.project_id,
                ProjectMember.is_active.is_(True),
                ProjectMember.left_at.is_(None),
            )
            .all()
        ]
    if payload.scope_type == "club":
        return [
            row[0]
            for row in db.query(User.id)
            .filter(User.is_active.is_(True), User.status == "active")
            .all()
        ]
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Perimetre de cotisation invalide",
    )


def create_fee_record(
    db: Session,
    *,
    user_id,
    current_user: User,
    season_id=None,
    fee_type: str,
    category: str | None,
    label: str,
    description: str | None,
    amount: float,
    currency: str,
    due_date=None,
    source_type: str | None = None,
    source_id=None,
    related_attendance_id=None,
    proof_file_id=None,
) -> Fee:
    if amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le montant doit etre superieur a zero",
        )
    if fee_type not in VALID_FEE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de frais invalide",
        )
    if related_attendance_id:
        existing = (
            db.query(Fee)
            .filter(Fee.related_attendance_id == related_attendance_id)
            .first()
        )
        if existing:
            return existing
    if source_type and source_id:
        existing = (
            db.query(Fee)
            .filter(
                Fee.user_id == user_id,
                Fee.source_type == source_type,
                Fee.source_id == source_id,
                Fee.status != "cancelled",
            )
            .first()
        )
        if existing:
            return existing

    fee = Fee(
        user_id=user_id,
        season_id=season_id,
        type=fee_type,
        category=category,
        label=label,
        description=description,
        amount=amount,
        currency=currency,
        amount_paid=0,
        status="unpaid",
        due_date=due_date,
        related_attendance_id=related_attendance_id,
        source_type=source_type,
        source_id=source_id,
        proof_file_id=proof_file_id,
        created_by=current_user.id,
    )
    account = ensure_financial_account(db, user_id)
    account.balance_due = float(account.balance_due or 0) + amount
    account.updated_at = datetime.utcnow()
    db.add(fee)
    db.flush()
    notify_user(
        db,
        user_id=user_id,
        title="Nouveau montant a payer",
        message=f"{label}: {amount:.0f} {currency}.",
        notification_type="fee_due",
        related_type="fee",
        related_id=fee.id,
        dedupe=True,
    )
    return fee


@router.get("/accounts/me", response_model=FinancialAccountRead)
def get_my_financial_account(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    account = ensure_financial_account(db, current_user.id)
    db.commit()
    db.refresh(account)
    return account


def finance_stats_payload(
    *,
    accounts: list[FinancialAccount],
    fees: list[Fee],
    payments: list[Payment],
    transactions: list[ClubTransaction],
) -> dict:
    total_due = sum(float(account.balance_due or 0) for account in accounts)
    total_paid = sum(float(account.total_paid or 0) for account in accounts)
    pending_payments = [
        payment for payment in payments if payment.status == "pending"
    ]
    validated_payments = [
        payment for payment in payments if payment.status == "validated"
    ]
    rejected_payments = [
        payment for payment in payments if payment.status == "rejected"
    ]
    income = sum(
        float(transaction.amount or 0)
        for transaction in transactions
        if transaction.type == "income"
    )
    expenses = sum(
        float(transaction.amount or 0)
        for transaction in transactions
        if transaction.type == "expense"
    )

    return {
        "total_due": total_due,
        "total_paid": total_paid,
        "pending_payment_amount": sum(
            float(payment.amount or 0) for payment in pending_payments
        ),
        "validated_payment_amount": sum(
            float(payment.amount or 0) for payment in validated_payments
        ),
        "pending_payment_count": len(pending_payments),
        "rejected_payment_count": len(rejected_payments),
        "debtor_count": len(
            [account for account in accounts if float(account.balance_due or 0) > 0]
        ),
        "unpaid_fee_count": len(
            [fee for fee in fees if fee.status in {"unpaid", "partial"}]
        ),
        "income": income,
        "expenses": expenses,
        "cash_balance": income - expenses,
    }


@router.get("/stats")
def get_finance_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    return finance_stats_payload(
        accounts=db.query(FinancialAccount).all(),
        fees=db.query(Fee).all(),
        payments=db.query(Payment).all(),
        transactions=db.query(ClubTransaction).all(),
    )


@router.get("/stats/me")
def get_my_finance_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return finance_stats_payload(
        accounts=[
            ensure_financial_account(db, current_user.id),
        ],
        fees=db.query(Fee).filter(Fee.user_id == current_user.id).all(),
        payments=db.query(Payment).filter(Payment.user_id == current_user.id).all(),
        transactions=[],
    )


def csv_download(filename: str, rows: list[list]) -> Response:
    output = StringIO()
    writer = csv.writer(output)
    writer.writerows(rows)
    return Response(
        content=output.getvalue(),
        media_type="text/csv",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
        },
    )


@router.get("/export/fees.csv")
def export_fees_csv(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    rows = [
        [
            "id",
            "user_id",
            "type",
            "label",
            "amount",
            "amount_paid",
            "currency",
            "status",
            "due_date",
            "created_at",
        ]
    ]
    for fee in db.query(Fee).order_by(Fee.created_at.desc()).all():
        rows.append(
            [
                fee.id,
                fee.user_id,
                fee.type,
                fee.label,
                float(fee.amount or 0),
                float(fee.amount_paid or 0),
                fee.currency,
                fee.status,
                fee.due_date,
                fee.created_at,
            ]
        )
    return csv_download("enactspace_frais.csv", rows)


@router.get("/export/payments.csv")
def export_payments_csv(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    rows = [
        [
            "id",
            "user_id",
            "amount",
            "currency",
            "method",
            "status",
            "reference",
            "validated_at",
            "rejected_at",
            "rejection_reason",
            "created_at",
        ]
    ]
    for payment in db.query(Payment).order_by(Payment.created_at.desc()).all():
        rows.append(
            [
                payment.id,
                payment.user_id,
                float(payment.amount or 0),
                payment.currency,
                payment.method,
                payment.status,
                payment.reference,
                payment.validated_at,
                payment.rejected_at,
                payment.rejection_reason,
                payment.created_at,
            ]
        )
    return csv_download("enactspace_paiements.csv", rows)


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
        if not (payload.reference or payload.proof_url or payload.proof_file_id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ajoutez une référence ou une preuve de paiement",
            )

    payment = Payment(
        user_id=payload.user_id,
        amount=payload.amount,
        currency=payload.currency,
        method=payload.method,
        status="pending",
        reference=payload.reference,
        proof_url=payload.proof_url,
        proof_file_id=payload.proof_file_id,
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
    if not can_review_payment(db, current_user, payment):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous ne pouvez pas valider votre propre paiement",
        )

    if payment.status == "validated":
        return payment_payload(db, current_user, payment)

    if payment.status == "rejected":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Impossible de valider un paiement rejete",
        )

    if payment.status == "cancelled":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Impossible de valider un paiement annulé",
        )

    payment.status = "validated"
    payment.validated_by = current_user.id
    payment.validated_at = datetime.utcnow()
    payment.rejected_at = None
    payment.rejection_reason = None

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


@router.post("/payments/{payment_id}/reject", response_model=PaymentRead)
def reject_payment(
    payment_id: str,
    payload: PaymentRejectRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_finance_or_admin),
):
    payment = get_payment_or_404(db, payment_id)
    if not can_review_payment(db, current_user, payment):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous ne pouvez pas rejeter votre propre paiement",
        )

    if payment.status == "rejected":
        return payment_payload(db, current_user, payment)

    if payment.status in {"validated", "cancelled"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Impossible de rejeter ce paiement",
        )

    reason = payload.reason.strip()
    if not reason:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le motif de rejet est obligatoire",
        )

    old_status = payment.status
    payment.status = "rejected"
    payment.rejected_at = datetime.utcnow()
    payment.rejection_reason = reason
    payment.validated_by = None
    payment.validated_at = None

    notify_user(
        db,
        user_id=payment.user_id,
        title="Paiement rejete",
        message=(
            f"Votre paiement de {float(payment.amount):.0f} FCFA "
            f"est rejete: {reason}"
        ),
        notification_type="payment_rejected",
        related_type="payment",
        related_id=payment.id,
        dedupe=True,
    )
    create_audit_log(
        db=db,
        action="rejet_paiement",
        user_id=current_user.id,
        entity_type="payment",
        entity_id=payment.id,
        old_value={"status": old_status},
        new_value={"status": payment.status, "reason": reason},
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
        description=payload.description,
        amount=payload.amount,
        currency=payload.currency,
        project_id=payload.project_id,
        pole_id=payload.pole_id,
        proof_url=payload.proof_url,
        proof_file_id=payload.proof_file_id,
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
