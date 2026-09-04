# Meet6 notification permission onboarding

Meet6 does not trigger the OS notification permission dialog immediately after authentication.

The permission flow starts on the authenticated home screen after the user has completed profile setup:

1. Meet6 shows a product explanation: `Mesajlarını ve oda davetlerini kaçırma`.
2. `Bildirimleri aç` requests the OS notification permission.
3. If permission is already denied, or the OS request is denied, Meet6 offers `Sistem ayarlarını aç`.
4. Returning from system settings refreshes permission state and re-registers the FCM token when notifications are enabled.
5. `Şimdi değil` does not nag on every launch: first-time deferral is snoozed for 3 days and denied-permission reminders for 7 days.
6. If Meet6's own backend `notifications_enabled` setting is off, the onboarding is skipped.

Analytics events:

- `notification_permission_prompt_shown`
- `notification_permission_prompt_later`
- `notification_permission_enabled`
- `notification_permission_denied`
- `notification_settings_opened`

No message body, phone number, location, or profile content is attached to these events.
