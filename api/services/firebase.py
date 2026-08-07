import base64
import json
import firebase_admin
from firebase_admin import credentials, auth
from config import get_settings


class FirebaseService:
    """Firebase service supporting real verification and development mocks."""

    def __init__(self) -> None:
        self._initialized = False

    def init_app(self) -> None:
        """Initialize Firebase Admin SDK. Call once at startup."""
        settings = get_settings()
        if not settings.firebase_project_id:
            return

        try:
            # Check if app is already initialized to avoid ValueError
            firebase_admin.get_app()
            self._initialized = True
            return
        except ValueError:
            pass

        try:
            if settings.firebase_service_account_json:
                # Decoded from base64 if it is base64 encoded
                try:
                    cred_bytes = base64.b64decode(settings.firebase_service_account_json)
                    cred_dict = json.loads(cred_bytes)
                except Exception:
                    # Fallback to direct json parsing
                    cred_dict = json.loads(settings.firebase_service_account_json)
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred)
            else:
                # Initialize with project ID
                firebase_admin.initialize_app(options={"projectId": settings.firebase_project_id})
            self._initialized = True
        except Exception as e:
            print(f"Failed to initialize Firebase Admin SDK: {e}")
            self._initialized = False

    async def verify_token(self, token: str) -> dict | None:
        """Verify a Firebase ID token and return decoded claims."""
        # Support mock tokens for easy testing and local development
        if token.startswith("mock-token-"):
            uid = token.removeprefix("mock-token-")
            return {
                "uid": uid,
                "email": f"{uid}@example.com",
                "name": uid.replace("_", " ").title(),
                "picture": None,
            }

        if not self._initialized:
            return None

        try:
            decoded_claims = auth.verify_id_token(token)
            return decoded_claims
        except Exception:
            return None


firebase_service = FirebaseService()

