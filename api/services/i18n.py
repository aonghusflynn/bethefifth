"""Minimal locale-aware catalogue for backend user-facing strings.

CLAUDE.md requires that user-facing text (emails, push notifications, errors)
goes through a translation layer and is delivered in the recipient's locale.
This is a deliberately thin implementation — a nested dict plus a lookup with
fallback — so call sites never hardcode English. Adding a language means adding
entries here, not touching the services that send messages.

Only `en` is populated today. Lookups for an unpopulated locale fall back to
`en` rather than failing, so shipping a new locale is additive and safe.
"""

SUPPORTED_LOCALES = ("en", "fr", "nl", "es", "it", "de")
DEFAULT_LOCALE = "en"

_CATALOGUE: dict[str, dict[str, str]] = {
    "squad_invite.subject": {
        "en": "{organiser_name} wants you in their five-a-side squad",
    },
    "marketplace.push_title": {
        "en": "{title} needs players",
    },
    "marketplace.push_body": {
        "en": "{slots} spot(s) left, kicking off at {time}. Tap to claim one.",
    },
    "squad_invite.body_html": {
        "en": (
            "<p>Hi {member_name},</p>"
            "<p><strong>{organiser_name}</strong> has added you to "
            "<strong>{squad_name}</strong> on BeTheFifth.</p>"
            "<p>Squad members get a notification before every match and can say "
            "whether they're playing with one tap.</p>"
            '<p><a href="{join_url}">Join the squad</a></p>'
            "<p>See you on the pitch.</p>"
        ),
    },
}


def resolve_locale(locale: str | None) -> str:
    """Return a supported locale, falling back to the default."""
    if locale and locale in SUPPORTED_LOCALES:
        return locale
    return DEFAULT_LOCALE


def t(key: str, locale: str | None = None, **kwargs: object) -> str:
    """Look up `key` for `locale`, interpolating any keyword arguments."""
    entry = _CATALOGUE.get(key)
    if entry is None:
        raise KeyError(f"Unknown translation key: {key}")

    template = entry.get(resolve_locale(locale)) or entry[DEFAULT_LOCALE]
    return template.format(**kwargs)
