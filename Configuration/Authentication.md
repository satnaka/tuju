# Account sign-in

TuJu uses a public native OpenID Connect client. People can use the app as guests until an identity-provider administrator registers the app and supplies its public settings.

## Register the app

1. In your OpenID Connect provider, create a **native/mobile public client** for TuJu. Enable the authorization code grant with **PKCE (S256)** and set token endpoint authentication to **none**.
2. Register the exact redirect URI `com.satnaka.tuju:/oauth/callback`. If the provider requires a different reverse-domain scheme, use that scheme in both the registered URI and the Xcode setting below. Preserve the single slash after the colon.
3. Enable the `openid` and `profile` scopes. TuJu also requests `offline_access` for refresh when supported. The provider must publish HTTPS discovery, authorization, token and UserInfo endpoints. UserInfo must return the same `sub` as the ID token. A `name` or `preferred_username` supplies the display name.
4. Copy the issuer identifier and the public client ID from the provider’s registration. Use the issuer exactly as published by discovery, including any tenant path or trailing slash.

## Connect Apple, Google and MyDigital ID

To offer multiple sign-in methods, register TuJu with one hosted identity provider that can broker upstream connections. The app opens that provider’s hosted page. Configure the methods, credentials, consent screens and HTTPS return URLs in the provider’s administrative console. The native callback above is for the return from the hosted provider to TuJu.

- **Apple** uses a Services ID associated with your Sign in with Apple-enabled App ID. Register the broker’s domain and HTTPS return URL with Apple. Keep the Sign in with Apple key and related team credentials in the broker’s configuration. [Apple setup](https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web/)
- **Google** uses a web OAuth client for the broker and its authorized HTTPS redirect URI. Configure that client’s ID and secret in the broker. [Google OpenID Connect setup](https://developers.google.com/identity/openid-connect/openid-connect)
- **MyDigital ID** requires a relying-party integration approved by its operator. Obtain the onboarding instructions and credentials for your organization, then configure the supported federation through the broker. Offer this choice after testing it in the operator’s approved environment. [MyDigital ID Developer Portal](https://developer.digital-id.my/)

The hosted provider must expose an OpenID Connect UserInfo endpoint for its TuJu client. Each upstream provider’s account setup and availability are managed by your organization.

## Configure Xcode

Open `TuJu.xcworkspace`. Under **TuJu target → Build Settings**, add the following user-defined settings for your chosen build configurations.

| Setting | Value |
| --- | --- |
| `TUJU_OIDC_ISSUER` | The provider’s HTTPS issuer URL |
| `TUJU_OIDC_CLIENT_ID` | The public client ID for TuJu |
| `TUJU_OIDC_CALLBACK_SCHEME` | Defaults to `com.satnaka.tuju` for the TuJu bundle ID. Set this only if the registered URI uses a different scheme. |

Xcode expands these values into the built application’s Info.plist. Keep client secrets, provider API keys and private signing keys on the provider or a trusted backend. The iPhone app needs only the public values above.

## Verify your registration

Run a normally signed app from Xcode so the operating system can authorize Keychain access. Select **Sign in** from the welcome screen or Profile. Complete sign-in in the provider’s system-browser window. After the callback, TuJu validates discovery and the ID token, checks the authenticated UserInfo identity, then shows the account name in Profile. Canceling the browser returns to TuJu. Reopen the app to check restoration, then use **Sign out** to clear this device’s TuJu session.

Tokens are kept in the device Keychain with access limited to the unlocked device. A provider may require a fresh interactive sign-in when tokens expire. Signing out clears TuJu’s local session. The identity provider manages its browser session. Trips, saved places and rewards use the app’s on-device storage.

The implementation uses the [AppAuth iOS SDK](https://github.com/openid/AppAuth-iOS) and the [OpenID Connect UserInfo specification](https://openid.net/specs/openid-connect-core-1_0.html#UserInfo).
