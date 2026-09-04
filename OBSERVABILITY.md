# Meet6 Analytics & Crash Reporting

Meet6 mobile observability uses Firebase Analytics and Firebase Crashlytics.

## Product funnel

The canonical funnel events are:

1. `registration_completed` — backend confirms the OTP verification created a new Meet6 user.
2. `profile_completed` — the completed profile update succeeds.
3. `room_search_started` — a matchmaking queue join is initiated.
4. `room_found` — the client receives a six-person active room.
5. `room_completed` — the room moves into the selection phase.
6. `selection_submitted` — the selection request succeeds.
7. `match_created` — the server confirms a mutual match.
8. `first_message_sent` — the first successful private message sent by that user in that match.

Room and match identifiers may be attached as internal debugging dimensions. Phone numbers, message bodies, profile text, exact location, and photo data must never be sent as Analytics parameters or Crashlytics custom keys.

## Crash capture

`ObservabilityService` installs crash/error capture at application startup:

- Flutter framework fatal errors via `FlutterError.onError`.
- Unhandled Dart zone failures via `runZonedGuarded`.
- Root-isolate/platform dispatcher failures via `PlatformDispatcher.instance.onError`.
- Funnel events are also written as Crashlytics breadcrumb logs, so the last product step before a crash is visible in a crash report.

Collection is disabled in debug mode and enabled in release/profile mode.

## Firebase platform configuration

Android is configured through `android/app/google-services.json` and the Google Services + Crashlytics Gradle plugins.

The iOS target must have the Firebase iOS app configuration (`GoogleService-Info.plist`, or an equivalent FlutterFire-generated configuration) for Analytics and Crashlytics to collect on iOS. Do not commit a replacement or fabricated plist; use the real file exported from the Meet6 Firebase project.

## Firebase console setup

In Firebase Analytics / Google Analytics, build a funnel exploration in the exact event order above. Useful conversion rates include:

- registration → profile completion
- profile completion → room search
- room search → room found
- room found → room completion
- room completion → selection
- selection → match
- match → first message

Crashlytics should be monitored by release/version, device/OS, fatal vs non-fatal error, and the breadcrumb immediately preceding the crash.
