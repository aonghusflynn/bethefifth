import logging
import firebase_admin
from firebase_admin import messaging
from services.firebase import firebase_service

logger = logging.getLogger(__name__)


class NotificationService:
    """Notification service supporting real Firebase Cloud Messaging and mock fallback."""

    async def send_push(self, user_id: str, title: str, body: str, data: dict | None = None) -> bool:
        """Send a push notification to a single user via their user topic."""
        # Convert all data values to string as FCM requires string values in the data payload
        data_payload = {}
        if data:
            data_payload = {str(k): str(v) for k, v in data.items()}

        logger.info(f"Sending push notification to user {user_id} - Title: {title}, Body: {body}, Data: {data_payload}")

        if not firebase_service._initialized:
            # Fallback mock logging in development
            return True

        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data_payload,
                topic=f"user_{user_id}",
            )
            # Send message using firebase-admin SDK
            messaging.send(message)
            return True
        except Exception as e:
            logger.error(f"Failed to send FCM push to user {user_id}: {e}")
            return False

    async def send_bulk(self, user_ids: list[str], title: str, body: str, data: dict | None = None) -> int:
        """Send push notifications to multiple users. Returns count of successful sends."""
        success_count = 0
        for user_id in user_ids:
            success = await self.send_push(user_id, title, body, data)
            if success:
                success_count += 1
        return success_count


notification_service = NotificationService()

