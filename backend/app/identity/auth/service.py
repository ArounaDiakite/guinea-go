from app.identity.auth.repository import AuthRepository
from app.identity.auth.schemas import (
    LoginRequest,
    RegisterPartnerRequest,
    RegisterRequest,
)
from app.core.constants import UserRole
from app.core.exceptions import (
    EmailAlreadyExistsException,
    InvalidCredentialsException,
    PendingAccountException,
)
from app.core.permissions import get_permissions_for_role
from app.core.security import (
    create_access_token,
    hash_password,
    verify_password,
)
from app.core.utils import utc_now


class AuthService:
    def __init__(self):
        self.repository = AuthRepository()

    async def register(self, data: RegisterRequest):
        # Vérifier si l'utilisateur existe déjà
        existing_user = await self.repository.get_user_by_email(data.email)

        if existing_user:
            raise EmailAlreadyExistsException()

        # Convertir les données en dictionnaire
        user_data = data.model_dump()

        # Sécurité
        user_data["password"] = hash_password(data.password)

        # Informations utilisateur
        user_data["role"] = UserRole.PASSENGER
        user_data["is_active"] = True
        user_data["is_verified"] = False
        user_data["profile_picture"] = None

        # Multi-pays
        user_data["country_code"] = data.country_code.upper()
        user_data["preferred_language"] = data.preferred_language.lower()

        # Dates
        user_data["created_at"] = utc_now()
        user_data["updated_at"] = utc_now()
        user_data["last_login"] = None

        # Sauvegarde MongoDB
        user = await self.repository.create_user(user_data)

        # Génération du JWT
        token = create_access_token(self._build_token_payload(user))

        return {
            "access_token": token,
            "token_type": "bearer",
            "user": self._format_user(user),
        }

    async def register_partner(self, data: RegisterPartnerRequest):
        existing_user = await self.repository.get_user_by_email(data.email)

        if existing_user:
            raise EmailAlreadyExistsException()

        user_data = data.model_dump()

        user_data["password"] = hash_password(data.password)

        # Compte partenaire : inactif tant qu'un system_administrator
        # ne l'a pas validé via PATCH /admin/users/{id}/activate.
        user_data["is_active"] = False
        user_data["is_verified"] = False
        user_data["profile_picture"] = None

        user_data["country_code"] = data.country_code.upper()
        user_data["preferred_language"] = data.preferred_language.lower()

        user_data["created_at"] = utc_now()
        user_data["updated_at"] = utc_now()
        user_data["last_login"] = None

        user = await self.repository.create_user(user_data)

        return {
            "message": "Compte créé avec succès. Il est en attente de validation par un administrateur.",
            "user": self._format_user(user),
        }

    async def register_driver(self, company_id: str, data: RegisterRequest, session=None):
        existing_user = await self.repository.get_user_by_email(data.email, session=session)

        if existing_user:
            raise EmailAlreadyExistsException()

        user_data = data.model_dump()

        user_data["password"] = hash_password(data.password)

        # Créé directement par un company_owner déjà validé : pas
        # besoin de validation admin supplémentaire.
        user_data["role"] = UserRole.DRIVER
        user_data["company_id"] = company_id
        user_data["is_active"] = True
        user_data["is_verified"] = False
        user_data["profile_picture"] = None

        user_data["country_code"] = data.country_code.upper()
        user_data["preferred_language"] = data.preferred_language.lower()

        user_data["created_at"] = utc_now()
        user_data["updated_at"] = utc_now()
        user_data["last_login"] = None

        user = await self.repository.create_user(user_data, session=session)

        return self._format_user(user)

    async def register_institution_administrator(
        self, data: RegisterRequest, is_active: bool, session=None
    ):
        """Shared by both institution registration paths (education/
        institutions/service.py orchestrates the atomic account +
        Institution creation for each): is_active=True when a
        system_administrator creates a public institution directly,
        False when a school_administrator self-registers a private one
        pending admin validation - same account shape either way, only
        the activation state differs."""
        existing_user = await self.repository.get_user_by_email(data.email, session=session)

        if existing_user:
            raise EmailAlreadyExistsException()

        user_data = data.model_dump()

        user_data["password"] = hash_password(data.password)

        user_data["role"] = UserRole.SCHOOL_ADMINISTRATOR
        user_data["is_active"] = is_active
        user_data["is_verified"] = False
        user_data["profile_picture"] = None

        user_data["country_code"] = data.country_code.upper()
        user_data["preferred_language"] = data.preferred_language.lower()

        user_data["created_at"] = utc_now()
        user_data["updated_at"] = utc_now()
        user_data["last_login"] = None

        user = await self.repository.create_user(user_data, session=session)

        return self._format_user(user)

    async def delete_account(self, user_id: str, session=None):
        """Rollback helper for orchestrated, cross-module account creation
        (e.g. companies/router.py creating a driver's auth account + business
        profile together) when the second step fails."""
        await self.repository.delete_user(user_id, session=session)

    async def login(self, data: LoginRequest):
        user = await self.repository.get_user_by_email(data.email)

        if not user:
            raise InvalidCredentialsException()

        if not verify_password(data.password, user["password"]):
            raise InvalidCredentialsException()

        if not user.get("is_active", True):
            raise PendingAccountException()

        token = create_access_token(self._build_token_payload(user))

        return {
            "access_token": token,
            "token_type": "bearer",
            "user": self._format_user(user),
        }

    def _build_token_payload(self, user):
        return {
            "sub": str(user["_id"]),
            "email": user["email"],
            "role": user["role"],
            "permissions": get_permissions_for_role(user["role"]),
            "company_id": user.get("company_id"),
        }

    def _format_user(self, user):
        return {
            "id": str(user["_id"]),
            "first_name": user["first_name"],
            "last_name": user["last_name"],
            "email": user["email"],
            "phone": user["phone"],
            "city": user["city"],
            "country_code": user.get("country_code", "GN"),
            "preferred_language": user.get("preferred_language", "fr"),
            "role": user["role"],
            "is_active": user["is_active"],
            "is_verified": user["is_verified"],
            "profile_picture": user["profile_picture"],
            "created_at": user["created_at"],
        }