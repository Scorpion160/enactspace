from pydantic import BaseModel, EmailStr
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.user import User
from app.core.config import settings
from app.services.seed_service import run_initial_seed


router = APIRouter(prefix="/seed", tags=["Initialisation"])


class SeedRequest(BaseModel):
    admin_first_name: str = "Cheikh Tidiane"
    admin_last_name: str = "DIOP"
    admin_email: EmailStr
    admin_password: str


@router.post("/initial")
def initial_seed(
    payload: SeedRequest,
    db: Session = Depends(get_db),
):
    if not settings.ENABLE_SEED:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="L'initialisation est désactivée sur ce serveur.",
        )

    user_count = db.query(User).count()

    if user_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="L'initialisation est bloquée car des utilisateurs existent déjà.",
        )

    if len(payload.admin_password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le mot de passe administrateur doit contenir au moins 8 caractères.",
        )

    return run_initial_seed(
        db=db,
        admin_first_name=payload.admin_first_name,
        admin_last_name=payload.admin_last_name,
        admin_email=payload.admin_email,
        admin_password=payload.admin_password,
    )