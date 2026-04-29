# Plan — Attestation-based auth flows in `Requests`

> Status: **draft, not started.**
>
> The trigger came from a security review of an iOS consumer (Wallet Proxy):
> the consumer authenticates against a Hokan blockchain backend and we want
> to move from "publicly callable" to a Backend-For-Frontend (BFF) gated by
> Apple App Attest (iOS) or Google Play Integrity (Android). The OAuth
> `client_secret` for the IdP must live only on the BFF, never in the apps.
>
> This document captures both the **package-level work** in `Requests`
> (the small, focused part) and the **end-to-end picture** the consumer
> needs in mind, so a future implementer doesn't have to re-derive it.

---

## 1. Goal

Add support for an OAuth-shaped flow where, instead of presenting a
`client_id` / `client_secret`, the client presents a **device attestation
assertion** that a BFF verifies with Apple/Google before minting a session
JWT.

```
[ App ] ──attestation──▶ [ BFF ] ──client_credentials──▶ [ IdP ]
                              └──proxy with Bearer M2M──▶ [ resource server ]
```

The BFF holds the IdP secret. The app holds nothing — its identity is
proven cryptographically per-request via the platform attestation API,
which is hardware-backed (Secure Enclave on iOS, StrongBox/TEE on Android).

## 2. Why this belongs in `Requests`

The package already has the right primitives:

- `protocol OAuthFlow` (`Requests/Model/AuthFlow/OAuthFlow.swift`) —
  abstracts the credential-bearing payload sent to the token endpoint
- `ClientCredentials`, `CodeFlow`, `RefreshToken` — concrete flows
- `Authenticator` / `ARAuthenticator` (actor) — token lifecycle
- `ARTokenManager` + `TokenStore` — pluggable persistence
- `BearerToken` / `OAuth2Token` — the issued credential model

Adding an attestation-based flow is a **non-breaking extension**: a new
`OAuthFlow` conformance + (optionally) a tiny refresh helper.

Consumers benefit immediately: every `Resource` that already conforms to
`AuthenticatedResource` keeps working, the only change is which `OAuthFlow`
is configured into `ARAuthenticator`.

## 3. Package-level scope (the piece this repo owns)

### 3.1 New file: `Requests/Model/AuthFlow/AppAttestFlow.swift`

```swift
import Foundation

/// `OAuthFlow` that proves the calling app/device with an Apple App Attest
/// assertion. Designed for clients talking to a BFF that verifies the
/// assertion server-side and returns an `OAuth2Token`.
///
/// The BFF token endpoint is expected to accept an
/// `application/json` body of shape:
/// ```
/// {
///   "platform": "ios",
///   "key_id": "<base64>",
///   "assertion": "<base64>",
///   "nonce": "<server-issued>"
/// }
/// ```
public struct AppAttestFlow: Codable, Equatable, OAuthFlow {

    public let clientID: String
    let keyId: String
    let assertion: Data
    let nonce: String

    public init(clientID: String, keyId: String, assertion: Data, nonce: String) {
        self.clientID = clientID
        self.keyId = keyId
        self.assertion = assertion
        self.nonce = nonce
    }

    public var queryParameters: [String: String]? { nil }

    public var httpBody: Data? {
        let payload: [String: Any] = [
            "platform": "ios",
            "client_id": clientID,
            "key_id": keyId,
            "assertion": assertion.base64EncodedString(),
            "nonce": nonce
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    public var isValid: Bool {
        !clientID.isEmpty && !keyId.isEmpty && !assertion.isEmpty && !nonce.isEmpty
    }

    public func isEqualTo(otherFlow: OAuthFlow?) -> Bool {
        guard let other = otherFlow as? AppAttestFlow else { return false }
        return other == self
    }
}
```

### 3.2 Optional sibling: `PlayIntegrityFlow`

Same shape, different payload — useful only if the package is consumed
from a Kotlin Multiplatform context or if we want symmetric API surface.
For a Swift-only package this is **out of scope**; the Android
counterpart will live in the Android project's network layer (see §6.4).

### 3.3 Content-Type considerations

Existing flows (`ClientCredentials`, `CodeFlow`) submit
`application/x-www-form-urlencoded` bodies. `AppAttestFlow` carries binary
data (the assertion CBOR, base64-encoded), so JSON is more ergonomic.

Verify that `AuthenticationEndpoint.urlRequest(using:)` already lets the
flow drive the `Content-Type` header, or extend it. If the endpoint
hardcodes `x-www-form-urlencoded`, add a `contentType: ContentType` member
to `OAuthFlow` with a default of `.formUrlEncoded` and let
`AppAttestFlow` override to `.applicationJson`. This is the **only**
potentially breaking change to consider — keep it source-compatible by
defaulting on the protocol extension.

### 3.4 Refresh semantics

A typical `OAuth2Token` carries a `refresh_token`. With attestation flows
the BFF can *optionally* return one, but a cleaner model is:

- No refresh token. When the JWT expires, generate a fresh assertion and
  call the same endpoint again. `ARAuthenticator` would need a small
  override hook ("how do I refresh?" → "regenerate the flow and re-issue")
  rather than the current `RefreshToken` grant.

Two implementation paths:
1. Extend `Authenticator` with an optional `refreshFlowProvider:
   () async throws -> OAuthFlow?` closure. When set, used instead of the
   `RefreshToken` grant.
2. Leave the package alone and have the consumer subclass / wrap
   `ARAuthenticator` with attestation-aware refresh. Less elegant but
   keeps the package change tiny.

Recommend **option 1**: it's a single optional property and improves
the package for any non-OAuth-refresh flow we'll meet later.

### 3.5 Tests to add (`RequestsTests`)

- `AppAttestFlowTests`: `httpBody` shape, `isValid` edges, `isEqualTo`
  semantics, JSON round-trip.
- `AuthenticatorRefreshOverrideTests`: when `refreshFlowProvider` is set,
  the `RefreshToken` grant is bypassed.

### 3.6 Versioning

This is non-breaking if §3.3 stays source-compatible. Bump minor version,
add to `CHANGELOG.md` as `Added: AppAttestFlow conforming to OAuthFlow`.

---

## 4. End-to-end architecture (consumer context)

```
┌──────────────────┐    (1) attestation challenge → token       ┌─────────────────┐
│                  │ ──────────────────────────────────────▶   │                 │
│  iOS / Android   │ ◀──────────────────────────────────────── │     BFF         │
│   consumer       │    (2) session JWT (short-lived ~15 min)  │                 │
│                  │                                            │  Azure          │
│  Requests +      │ ────(3) API calls + Bearer JWT──────────▶ │  Function /     │
│  AppAttestFlow   │                                            │  App Service    │
└──────────────────┘                                            │                 │
                                                                 │  Key Vault      │
                                                                 │  ─ idp_secret   │
                                                                 │  ─ jwt_signing  │
                                                                 └────────┬────────┘
                                                                          │
                              client_credentials grant (cached ~1h)       │
                                                                          ▼
                                                                  ┌─────────────┐
                                                                  │     IdP     │
                                                                  └──────┬──────┘
                                                                         │
                              proxy w/ Bearer M2M                        │
                                                                         ▼
                                                                  ┌─────────────┐
                                                                  │  Resource   │
                                                                  │  server     │
                                                                  │  (Hokan)    │
                                                                  └─────────────┘
```

## 5. BFF (out of repo, but documented for context)

Stack: Azure Function (.NET 8 isolated or Node 20). Secrets in Azure Key
Vault, accessed via managed identity.

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `POST` | `/v1/attest/challenge` | none (rate-limited per IP) | Returns single-use nonce |
| `POST` | `/v1/attest/register` | attestation | iOS: validate App Attest CBOR. Android: validate Play Integrity JWT. Saves device record |
| `POST` | `/v1/session` | assertion | Validates signed nonce → issues session JWT (HS256/RS256, ~15 min) |
| `*` | `/v1/{resource}/...` | Bearer JWT | Proxies to upstream resource server with Bearer M2M obtained from IdP |

Server-side responsibilities:

- iOS attestation: validate CBOR, certificate chain to Apple's root,
  `appID == teamID.bundleID`, monotonically increasing counter, nonce
  matches the issued one.
- Android attestation: parse JWS, verify with Google's keys, check
  verdicts (`appIntegrity == PLAY_RECOGNIZED`,
  `deviceIntegrity` contains `MEETS_DEVICE_INTEGRITY`,
  `accountDetails == LICENSED`).
- Cache the M2M token from the IdP (refresh on `expires_in - 60s`).
- Store registered devices: `(deviceId, platform, publicKey, lastSeen,
  revoked)`. SQLite/Cosmos/Table Storage all fine.
- Per-IP rate limiting on unauthenticated endpoints.
- Per-device rate limiting on `/v1/session`.
- Revocation list — invalidate a leaked attestation server-side.
- Never log the JWT or M2M token.

## 6. Consumer integration

### 6.1 iOS — bootstrap (one-off, on first launch)

```swift
@MainActor
final class AttestationManager {
    private let service = DCAppAttestService.shared
    private let bff: BFFEndpoint

    func bootstrap() async throws {
        guard service.isSupported else { throw AttestError.unsupported }
        if AttestationStorage.keyId != nil { return }

        let keyId = try await service.generateKey()
        let challenge = try await bff.fetchChallenge()
        let attestation = try await service.attestKey(
            keyId,
            clientDataHash: SHA256.hash(of: challenge)
        )
        try await bff.register(keyId: keyId, attestation: attestation, challenge: challenge)
        AttestationStorage.keyId = keyId
    }
}
```

### 6.2 iOS — building the flow on demand

```swift
extension AttestationManager {
    func freshFlow(clientID: String) async throws -> AppAttestFlow {
        let keyId = AttestationStorage.keyId!
        let nonce = try await bff.fetchSessionNonce()
        let assertion = try await service.generateAssertion(
            keyId,
            clientDataHash: SHA256.hash(of: nonce)
        )
        return AppAttestFlow(
            clientID: clientID,
            keyId: keyId,
            assertion: assertion,
            nonce: nonce
        )
    }
}
```

Wired into `ARAuthenticator` via the `refreshFlowProvider` from §3.4 so a
401 transparently triggers `freshFlow()` → `/v1/session` → new JWT.

### 6.3 iOS — Resource conformance

Each request type that today is a plain `Resource` becomes
`AuthenticatedResource`, returning the shared `ARAuthenticator` configured
with `AppAttestFlow`. The existing path/method/body shape is unchanged —
only the base URL changes (consumer points at the BFF instead of the
public resource server).

### 6.4 Android (out of this repo)

The Android counterpart can either:

- Re-implement a small `OAuthFlow`-like abstraction in Kotlin and a
  `PlayIntegrityFlow` that mirrors `AppAttestFlow`, or
- If a Kotlin port of `Requests` ever lands, contribute the same flow there.

```kotlin
class AttestationManager(
    private val context: Context,
    private val bff: BffApi,
) {
    private lateinit var tokenProvider: StandardIntegrityTokenProvider

    suspend fun bootstrap() {
        val req = StandardIntegrityManager
            .PrepareIntegrityTokenRequest.builder()
            .setCloudProjectNumber(BuildConfig.GCP_PROJECT_NUMBER)
            .build()
        tokenProvider = IntegrityManagerFactory
            .createStandard(context)
            .prepareIntegrityToken(req)
            .await()
    }

    suspend fun freshFlow(clientID: String): PlayIntegrityFlow {
        val nonce = bff.fetchSessionNonce()
        val token = tokenProvider.request(
            StandardIntegrityTokenRequest.builder()
                .setRequestHash(sha256(nonce))
                .build()
        ).await().token()
        return PlayIntegrityFlow(clientID, integrityToken = token, nonce)
    }
}
```

Android-specific notes:

- **GCP project required** (Play Console > Setup > App integrity, ~30 min).
- **Quota**: 10k standard requests/day free per app, then paid.
- **Devices without GMS** (Huawei post-2019, some Xiaomi global): default
  policy is hard-block. Document in supported-devices list.
- JWT in `EncryptedSharedPreferences` with a `MasterKey` flagged
  `setUserAuthenticationRequired(true)` — Android equivalent of iOS
  `SecAccessControl(.userPresence)`.

## 7. Open questions

1. **§3.3 — `Content-Type` per flow.** Confirm the cleanest place to thread
   it through `AuthenticationEndpoint`. Default-on-protocol-extension is
   the lowest blast radius; verify it covers existing flows.
2. **§3.4 — refresh override.** Land it as part of this work, or punt to a
   follow-up? Punting means consumers wrap `ARAuthenticator` themselves.
3. **Single shared `BearerToken` shape** between OAuth and attestation
   sessions. The existing `OAuth2Token` works as-is for the BFF response
   if the BFF mimics the OAuth token endpoint shape.
4. **Replay window** for nonces: BFF responsibility, but the package's
   tests should at least exercise "stale nonce → 401 → fresh assertion".
5. **Kotlin port** of `Requests`. Out of scope here, but worth raising:
   the Android consumer would benefit from the same abstractions.
6. **Logging hygiene.** `RequestConfiguration.debugsHTTPRequests` will
   print the assertion + JWT to console. Add a redaction list for known
   sensitive headers/body fields, or document the risk.

## 8. Effort estimate (rough)

Package-side only:

| Stream | Days |
|---|---|
| `AppAttestFlow` + tests | 0.5 |
| `Content-Type` plumbing + tests (§3.3) | 0.5 |
| `refreshFlowProvider` on `Authenticator` + tests (§3.4) | 0.5 |
| Docs (`Requests.docc`) + `CHANGELOG.md` | 0.25 |
| **Package total** | **~2 days** |

Consumer-side (out of this repo, for context):

| Stream | Days |
|---|---|
| BFF (Azure Function, Key Vault, two attestation verifiers, proxy) | 3–4 |
| iOS integration (`AttestationManager` + wiring + tests) | 1–2 |
| Android integration (Play Integrity + GCP setup + wiring) | 1–2 |
| End-to-end testing across both platforms | 1–2 |
| **End-to-end total** | **7–11 days** |

## 9. References

- Apple — *Validating Apps That Connect to Your Server*
  https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server
- Apple — `DCAppAttestService`
  https://developer.apple.com/documentation/devicecheck/dcappattestservice
- Google — *Play Integrity API*
  https://developer.android.com/google/play/integrity
- Google — `StandardIntegrityManager`
  https://developer.android.com/reference/com/google/android/play/core/integrity/StandardIntegrityManager
- RFC 8252 — OAuth 2.0 for Native Apps
  https://datatracker.ietf.org/doc/html/rfc8252
- RFC 6819 — OAuth 2.0 Threat Model and Security Considerations
  https://datatracker.ietf.org/doc/html/rfc6819
