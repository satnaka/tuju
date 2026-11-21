# Account sign-in

TuJu uses a public native OpenID Connect client. People can use the app as guests until an identity-provider administrator registers the app and supplies its public settings.

## Set up TuJu with Auth0 Universal Login

1. Select the Auth0 tenant owned by TuJu’s publisher. Under **Applications → Applications**, look for **TuJu iOS**. For a new registration, create a **Native** application with the settings in the [TuJu client manifest](auth0-native-client.json). The manifest also serves as the request body for the [Auth0 Create a client API](https://auth0.com/docs/api/management/v2/clients/post-clients).
2. Allow `com.satnaka.tuju:/oauth/callback` as the return URL from Auth0 to the iPhone. Copy the app’s public **Client ID** and the exact `issuer` from `https://<your-auth0-domain>/.well-known/openid-configuration` into the Xcode settings below. Preserve the issuer’s trailing slash.
3. For **Google**, create a Web application OAuth client in TuJu’s Google Cloud project. Register `https://<your-auth0-domain>/login/callback` as its redirect URI. In Auth0, enter that client’s credentials under **Authentication → Social → Google** and enable the connection for **TuJu iOS**. Use the publisher’s credentials for production. [Google connection setup](https://developer.auth0.com/resources/labs/authentication/google-social-connection-to-login)
4. For **Apple** on the hosted login page, Apple requires an existing App Store app using Sign in with Apple. Associate a Services ID with its primary App ID, register the Auth0 HTTPS domain and return URL, then enable the Apple social connection for **TuJu iOS**. If this is the publisher’s first iOS release and it lacks an eligible app, the alternative is a native Sign in with Apple button and Auth0’s native exchange. That path requires an iOS implementation and an Apple-enabled App ID. [Apple web requirements](https://developer.apple.com/documentation/signinwithapple/configuring-your-environment-for-sign-in-with-apple) · [Auth0 native Apple sign-in](https://auth0.com/docs/authenticate/identity-providers/social-identity-providers/apple-native)
5. For **MyDigital ID**, register TuJu as a relying party through the operator’s developer portal. Confirm that the operator accepts the Auth0 HTTPS callback and supplies an OIDC authorization-code flow with a supported token authentication method and stable subject claim. Using its sandbox details, create **Authentication → Enterprise → OpenID Connect** in Auth0. Set the display name to **MyDigital ID**, enable its login button and assign it to the TuJu test application. Test opening the MyDigital ID app on an iPhone and returning to TuJu before enabling the operator’s production registration. [MyDigital ID portal](https://developer.digital-id.my/auth/login) · [Auth0 OIDC connections](https://auth0.com/docs/authenticate/identity-providers/enterprise-identity-providers/oidc)

In Auth0, enable only the connections intended for this application. Enter upstream secrets in the provider dashboards. The native client manifest contains public registration settings.

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
