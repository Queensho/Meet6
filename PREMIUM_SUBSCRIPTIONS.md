# Meet6 Premium subscriptions

Meet6 Premium is server-authoritative. A client-side purchase result never grants matchmaking privileges by itself.

## Product behavior

- Free users: 15-minute rooms.
- Premium users: priority inside the selected matchmaking pool.
- Premium users may choose 15-minute or 30-minute rooms.
- 30-minute rooms are a separate pool; every member in that pool must have an active Premium entitlement.
- Expired Premium users lose queue priority and stale 30-minute queue requests fall back to 15 minutes on the server.
- Existing +5-minute room extension voting remains available after either base duration.

## RevenueCat dashboard

1. Connect the Google Play and App Store apps to one RevenueCat project.
2. Create the entitlement identifier `premium`.
3. Attach the Play Store / App Store subscription products to that entitlement.
4. Configure a current Offering and packages. The Flutter app reads the current Offering dynamically; product IDs are not hard-coded in the app.
5. Add a webhook pointing to:
   `${MEET6_API_BASE_URL}/api/billing/revenuecat/webhook`
6. Set the webhook Authorization header to exactly the same value configured as `REVENUECAT_WEBHOOK_AUTHORIZATION` on the Meet6 API.

## Backend environment

Configure on the production API host:

```text
REVENUECAT_SECRET_API_KEY=sk_...
REVENUECAT_PREMIUM_ENTITLEMENT=premium
REVENUECAT_WEBHOOK_AUTHORIZATION=Bearer <long-random-secret>
```

The RevenueCat secret API key must never be shipped in Flutter, committed to Git, or exposed to the browser.

## Flutter build configuration

Use RevenueCat public SDK keys as build-time defines:

```text
--dart-define=REVENUECAT_ANDROID_API_KEY=<public_android_sdk_key>
--dart-define=REVENUECAT_IOS_API_KEY=<public_ios_sdk_key>
--dart-define=REVENUECAT_ENTITLEMENT_ID=premium
```

Keep the existing production API define as well:

```text
--dart-define=MEET6_ENV=production
--dart-define=MEET6_API_BASE_URL=https://<api-host>
```

## Store project setup

- Android: `com.android.vending.BILLING` is declared in `AndroidManifest.xml`; minimum SDK is 23 for the current RevenueCat/Google Billing stack.
- iOS: the project deployment target is already iOS 15. Enable **In-App Purchase** for the Runner target in Xcode/App Store signing configuration before App Store release.
- Create the actual subscription products/base plans/prices in Google Play Console and App Store Connect, then map them in RevenueCat.

## Verification flow

1. Flutter configures RevenueCat with the logged-in Meet6 user ID as `appUserID`.
2. Flutter purchases/restores a package from RevenueCat's current Offering.
3. Flutter calls `POST /api/billing/me/refresh`.
4. The backend calls RevenueCat's subscriber REST API with the server-only secret key.
5. Only the resulting server `user_subscriptions` entitlement controls queue priority and 30-minute room access.
6. RevenueCat webhooks keep renewals, cancellations, billing issues and expirations synchronized even when the app is closed.

## Production checks before release

- RevenueCat Play and App Store integrations show healthy credentials.
- `premium` entitlement is attached to every intended subscription product.
- Current Offering returns at least one package on both Android and iOS.
- Purchase and Restore are tested with Google license testers and App Store sandbox/TestFlight accounts.
- Webhook deliveries return HTTP 2xx and update `user_subscriptions`.
- A free account receives HTTP 403 for a 30-minute queue request.
- An active Premium account can enter the 30-minute pool and receives queue priority in the 15-minute pool.
