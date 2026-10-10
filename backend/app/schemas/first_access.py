from typing import Literal
from uuid import UUID
from pydantic import BaseModel,ConfigDict,EmailStr,Field,field_validator
from app.core.account_identity import validate_join_year

class ActivationRequest(BaseModel):
    identifier: str = Field(min_length=1,max_length=150)
    model_config=ConfigDict(str_strip_whitespace=True)

class ActivationConfirm(ActivationRequest):
    model_config=ConfigDict(str_strip_whitespace=False)
    @field_validator("identifier","code",mode="before")
    @classmethod
    def clean_identity(cls,value):
        return value.strip() if isinstance(value,str) else value

    code: str = Field(pattern=r"^[0-9]{8}$",max_length=8)
    new_password: str = Field(min_length=15,max_length=72)
    @field_validator("new_password")
    @classmethod
    def password_bytes(cls,value):
        if len(value.encode("utf-8"))>72 or value.isspace():
            raise ValueError("Choisissez une phrase de passe de 15 caractères au moins, limitée à 72 octets.")
        return value

class FirstAccessComplete(BaseModel):
    model_config=ConfigDict(str_strip_whitespace=True)
    first_name: str = Field(min_length=1,max_length=100)
    last_name: str = Field(min_length=1,max_length=100)
    phone: str = Field(min_length=6,max_length=30,pattern=r"^\+?[0-9 ()-]+$")
    @field_validator("phone")
    @classmethod
    def phone_digits(cls,value):
        if sum(char.isdigit() for char in value)<6:
            raise ValueError("Renseignez un numéro de téléphone valide.")
        return value
    gender: str = Field(pattern=r"^(homme|femme)$")
    enactus_join_year: int
    academic_year_id: UUID | None = None
    department: str = Field(min_length=1,max_length=150)
    cursus: str | None = Field(default=None,max_length=80)
    study_level: str | None = Field(default=None,max_length=100)
    specialty: str | None = Field(default=None,max_length=150)
    promotion: str | None = Field(default=None,max_length=100)
    graduation_year: int | None = None
    bio: str | None = Field(default=None,max_length=5000)
    _years=field_validator("enactus_join_year","graduation_year")(validate_join_year)

class FirstAccessContact(BaseModel):
    model_config=ConfigDict(str_strip_whitespace=True)
    email: EmailStr = Field(max_length=150)
    phone: str | None = Field(default=None,max_length=30)

class FirstAccessRecovery(FirstAccessContact):
    expected_email: str = Field(min_length=1,max_length=150)
    verification_note: str = Field(min_length=20,max_length=1000)
    identity_verified: Literal[True]
    sessions_revocation_acknowledged: Literal[True]
