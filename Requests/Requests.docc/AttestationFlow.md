# Attestation-based authentication

Use Apple App Attest to prove an iOS app's identity to a backend without
embedding any OAuth `client_secret`.

## Overview

OAuth 2.0 explicitly forbids embedding a `client_secret` in distributed
mobile apps — they are *public clients* per
[RFC 8252](https://datatracker.ietf.org/doc/html/rfc8252) and must not be
treated as confidential clients. Anything bundled in an IPA is extractable.

The standard alternative for machine-to-machine flows where there's no
human user is to introduce a **Backend-For-Frontend (BFF)** that:

1. holds the IdP `client_secret`,
2. trusts only requests that carry a valid Apple App Attest assertion,
3. mints short-lived session tokens that the app then uses for normal API
   calls.

Apple App Attest provides a hardware-backed key (lives in the Secure
Enclave) plus a signed attestation statement that proves to a server that
the request is coming from a genuine, unmodified instance of *your* app on
a real Apple device.

This package supports the pattern with two pieces:

- ``AppAttestFlow`` — an ``OAuthFlow`` conformance that carries the
  attestation assertion, key id, and server-issued nonce in a JSON body.
- ``ARAuthenticator/setFreshFlowProvider(_:)`` — a hook to regenerate the
  flow value on demand, since attestation nonces can't be replayed.

## Where each piece runs

```
┌──────────────────┐    1. one-off attestation registration       ┌───────────┐
│                  │ ────────────────────────────────────────────▶│           │
│   App + Requests │                                               │   BFF     │
│                  │ ◀──────────────────────────────────────────── │           │
│                  │    2. session token (short-lived JWT)         │           │
│                  │                                               │  Key      │
│                  │ ────3. authenticated API calls───────────────▶│  Vault    │
└──────────────────┘                                               └─────┬─────┘
                                                                         │
                                  client_credentials grant (cached)      │
                                                                         ▼
                                                                  ┌───────────┐
                                                                  │   IdP     │
                                                                  └─────┬─────┘
                                                                        │
                                                          proxy w/ M2M  │
                                                                        ▼
                                                                  ┌───────────┐
                                                                  │ Resource  │
                                                                  │  server   │
                                                                  └───────────┘
```

## What goes on the wire

The package never sends the app binary. The two artifacts produced by
`DCAppAttestService` are small, cryptographically-signed blobs:

- **Attestation object** (~600 bytes, CBOR, sent once at first launch):
  contains the public key of a Secure-Enclave–generated key pair, an
  Apple-issued certificate chain, and a hash of `teamID.bundleID`. Apple
  signs this to prove the key was generated on a genuine device inside
  *your* app.
- **Assertion** (~150 bytes, sent every time the session token is
  refreshed): an ECDSA-P256 signature over the server-issued nonce plus a
  monotonic counter. The BFF verifies it using the public key registered
  during the attestation step.

## What the package and the consumer don't have to know

A common misconception is that the app must read `Info.plist`,
`teamID`, the provisioning profile, or somehow ship the bundle. **None of
that is needed.**

- The system framework `DeviceCheck` knows the calling process's
  `teamID.bundleID` from the code-signing identity, hashes it as `rpIdHash`
  inside the attestation blob, and Apple signs it.
- The BFF has the expected `appID` (formatted as `teamID.bundleID`) in its
  configuration and verifies that the hash matches.

So both `Requests` and the consumer app stay free of any platform-specific
identity reads. The attestation blob carries the proof, signed by Apple,
and the BFF is the only party that needs to know which `appID` is allowed.

## Example consumer setup

The package itself does not depend on `DeviceCheck` so it remains usable
on macOS and pre-iOS-14 deployments. The consumer wires it up.

```swift
import DeviceCheck
import Requests

@MainActor
final class AttestationManager {

    let bff: BFFEndpoint
    private let service = DCAppAttestService.shared
    private var keyId: String?

    init(bff: BFFEndpoint) {
        self.bff = bff
        self.keyId = AttestationStorage.keyId   // your Keychain wrapper
    }

    /// Run once on first launch (idempotent).
    func bootstrap() async throws {
        guard service.isSupported else {
            throw AttestError.unsupported
        }
        if keyId != nil { return }

        let newKeyId = try await service.generateKey()
        let challenge = try await bff.fetchChallenge()
        let attestation = try await service.attestKey(
            newKeyId,
            clientDataHash: SHA256.hash(of: challenge)
        )
        try await bff.register(
            keyId: newKeyId,
            attestation: attestation,
            challenge: challenge
        )
        AttestationStorage.keyId = newKeyId
        self.keyId = newKeyId
    }

    /// Build a fresh `AppAttestFlow` for the authenticator.
    func freshFlow() async throws -> AppAttestFlow {
        guard let keyId else { throw AttestError.notBootstrapped }
        let nonce = try await bff.fetchSessionNonce()
        let assertion = try await service.generateAssertion(
            keyId,
            clientDataHash: SHA256.hash(of: nonce)
        )
        return AppAttestFlow(
            clientID: bff.clientID,
            keyId: keyId,
            assertion: assertion,
            nonce: nonce
        )
    }
}
```

Then plug it into ``ARAuthenticator``:

```swift
let authenticator = ARAuthenticator(
    tokenStore: tokenManager,
    baseEndpoint: AuthenticationEndpoint(
        baseEndpoint: bff.baseURL,
        path: "/v1/session"
    )
)

// Initial flow value (placeholder — the provider replaces it on use).
let initial = try await attestationManager.freshFlow()
await authenticator.configure(with: initial)

// Critical: every refresh asks the manager for a brand-new flow value
// because the nonce inside an `AppAttestFlow` is single-use.
await authenticator.setFreshFlowProvider {
    try await attestationManager.freshFlow()
}
```

From here on, any `AuthenticatedResource` that hands back this
`authenticator` Just Works.

## When the attestation actually runs

The session JWT is cached inside ``ARAuthenticator``. As long as it's
valid, every API call reuses it without any cryptographic work or BFF
roundtrip.

When the JWT expires:

1. The first call that needs a token triggers a refresh.
2. The actor serializes concurrent refreshes through a single `Task`, so
   N parallel callers cause **one** refresh, not N.
3. The fresh-flow provider runs (assertion + nonce roundtrip).
4. The new JWT is cached and returned to all waiting callers.

For a 15-minute JWT lifetime, an app making 100 calls in a session does
exactly 1 attestation. This matters because:

- Apple's Secure Enclave assertion is fast but not free (~50–200 ms).
- Google Play Integrity (the Android counterpart) has a 10k/day free
  quota; per-call attestation would burn through it on any moderately
  active app.

## Topics

### Flow types

- ``AppAttestFlow``
- ``OAuthFlow``
- ``ClientCredentials``
- ``CodeFlow``
- ``RefreshToken``

### Authenticator

- ``ARAuthenticator``
- ``ARAuthenticator/setFreshFlowProvider(_:)``
