import logging

import httpx

from config import get_settings

logger = logging.getLogger(__name__)

RESEND_API_URL = "https://api.resend.com/emails"


class EmailService:
    """Transactional email via Resend, with a dev-mode logging fallback.

    Mirrors the shape of NotificationService: when no API key is configured the
    message is logged and reported as sent, so local development and the test
    suite never depend on an external provider.
    """

    @property
    def enabled(self) -> bool:
        return bool(get_settings().resend_api_key)

    async def send(
        self,
        to: str,
        subject: str,
        html: str,
    ) -> bool:
        settings = get_settings()

        if not self.enabled:
            logger.info(
                "Email (dev fallback, not sent) to=%s subject=%s", to, subject
            )
            return True

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    RESEND_API_URL,
                    headers={
                        "Authorization": f"Bearer {settings.resend_api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "from": settings.email_from,
                        "to": [to],
                        "subject": subject,
                        "html": html,
                    },
                )
                response.raise_for_status()
            return True
        except Exception as e:
            logger.error("Failed to send email to %s: %s", to, e)
            return False


email_service = EmailService()
