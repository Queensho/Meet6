# Meet6 Premium one-to-one voice

Meet6 Premium voice is a server-authoritative, one-to-one matchmaking mode. It is separate from the core six-person text-room experience.

## Product behavior

- Premium voice matches contain exactly 2 users.
- A one-to-one voice match lasts 15 minutes.
- Voice matchmaking is isolated from text matchmaking. The normal six-person 15/30-minute text-room pools are unchanged.
- Every queued voice participant must have an active Premium entitlement.
- Existing age, gender preference, distance, block, report, recent-room and historical-match exclusions are applied before pairing.
- Purpose is used as a soft ordering preference; all hard filters remain mutual.
- Existing +5 minute extension voting still applies. With two members, both users must vote yes.
- When the voice match ends, the same hidden selection flow is used. If both users select each other, a normal Meet6 match is created and private messaging continues as usual.

## Media architecture

LiveKit is used as the realtime audio SFU. Flutter never receives the LiveKit API secret.

1. Flutter joins the Meet6 Premium one-to-one voice matchmaking queue.
2. The Meet6 backend finds one mutually compatible Premium partner and creates a two-person voice room in PostgreSQL.
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

The LiveKit client connects first and then attempts to enable the microphone. If microphone permission is denied, the user can remain in the match to hear the other participant and retry microphone activation from the microphone button.

## Release checks

- Configure LiveKit Cloud or a production self-hosted LiveKit deployment.
- Put API key/secret only in the backend environment.
- Verify a free account receives 403 from `/api/voice-rooms/queue`.
- Verify two compatible Premium accounts form one voice room without waiting for six users.
- Verify six Premium CI accounts form exactly three independent two-person voice rooms.
- Verify each voice room is 15 minutes and contains exactly two members.
- Test microphone permission allow/deny on Android and iOS.
- Test wired headset/Bluetooth routing on physical devices.
- Test reconnect after temporary network loss.
- Test +5 minute extension requires both users and transition to hidden selection.
- Test mutual hidden selection creates a standard Meet6 match.
- Test Premium expiry while waiting in the voice queue.
- Test LiveKit provider outage: Meet6 should display an audio connection error without granting unauthorized access.
