# Meet6 Premium voice rooms

Meet6 voice rooms are a Premium-only, server-authoritative room mode.

## Product behavior

- Voice rooms contain exactly the configured Meet6 room size (currently 6 users).
- Voice rooms are fixed at 30 minutes.
- Voice matchmaking is isolated from text matchmaking, so a user searching for a 30-minute text room is never mixed with a voice-room user.
- Every queued voice participant must have an active Premium entitlement.
- The existing age, gender preference, distance, block, report, recent-room and historical-match exclusions are applied.
- Existing +5 minute extension voting still applies.
- When the room ends, the same hidden selection and mutual-match flow is used.

## Media architecture

LiveKit is used as the realtime audio SFU. Flutter never receives the LiveKit API secret.

1. Flutter joins the Meet6 Premium voice matchmaking queue.
2. The Meet6 backend creates the six-person voice room in PostgreSQL.
3. Flutter asks `POST /api/voice-rooms/:roomId/token` for a media token.
4. The backend verifies active Premium status, active room membership and `room_mode=voice`.
5. The backend signs a short-lived LiveKit token scoped to `meet6-voice-<internal-room-id>`.
6. The token is restricted to microphone publishing and subscribing to room audio.

Participant identity and LiveKit room names use only internal numeric IDs; phone numbers, email addresses and display names are not placed into LiveKit identity/room-name fields.

## Production environment

Configure these only on the API host:

```text
LIVEKIT_URL=wss://<your-livekit-host>
LIVEKIT_API_KEY=<server-api-key>
LIVEKIT_API_SECRET=<server-api-secret>
```

The Flutter app does not need LiveKit credentials. It receives only a short-lived participant token from Meet6.

If any LiveKit production setting is missing, the token endpoint fails closed with HTTP 503 and no media access is granted.

## Mobile permissions

Android declares `RECORD_AUDIO` and `MODIFY_AUDIO_SETTINGS`.

iOS declares `NSMicrophoneUsageDescription`.

The LiveKit client connects first and then attempts to enable the microphone. If microphone permission is denied, the user can remain in the room to hear other participants and retry microphone activation from the microphone button.

## Release checks

- Configure LiveKit Cloud or a production self-hosted LiveKit deployment.
- Put API key/secret only in the backend environment.
- Verify a free account receives 403 from `/api/voice-rooms/queue`.
- Verify six Premium accounts form one voice room.
- Test microphone permission allow/deny on Android and iOS.
- Test wired headset/Bluetooth routing on physical devices.
- Test reconnect after temporary network loss.
- Test +5 minute extension and transition to hidden selection.
- Test Premium expiry while waiting in the voice queue.
- Test LiveKit provider outage: Meet6 should display an audio connection error without granting unauthorized access.
