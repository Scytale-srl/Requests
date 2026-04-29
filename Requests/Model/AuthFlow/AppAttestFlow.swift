//
//  AppAttestFlow.swift
//  Requests
//
//  Created by Francesco Bianco on 29/04/26.
//

import Foundation

/**
 An ``OAuthFlow`` that proves the calling app/device with an Apple App
 Attest assertion.

 Designed for clients that talk to a Backend-For-Frontend (BFF) which:
 - issues a single-use nonce,
 - verifies the assertion server-side against Apple's App Attest service,
 - mints an ``OAuth2Token`` (typically a short-lived JWT) on success.

 ## What's NOT in the flow

 - The app binary, an IPA hash, or any app metadata. The attestation
   blob is roughly 600 bytes (assertion is roughly 150) — never the bundle.
 - The bundle identifier or the team identifier. They're embedded by
   `DCAppAttestService` into the signed blob via `rpIdHash =
   SHA-256(teamID.bundleID)`, read by iOS from the calling process's
   code-signing identity. The package and the consumer don't have to
   read or send them — the BFF compares the hash against the `appID` it
   has configured server-side.

 ## Single-use

 The flow is single-use: the `nonce` is consumed by the BFF on the first
 request. To refresh the session token, the consumer must:
 1. fetch a new nonce from the BFF,
 2. call `generateAssertion` again,
 3. build a fresh `AppAttestFlow` and feed it back to the authenticator.

 See ``ARAuthenticator/setFreshFlowProvider(_:)`` for the supported
 pattern, and the <doc:AttestationFlow> article for an end-to-end example.

 ## Platform availability

 The flow type itself is platform-agnostic — it does not import
 `DeviceCheck` and does not call `generateAssertion` directly. Consumers
 do that on iOS 14+/macCatalyst and feed the result into this value type,
 which lets the package keep its existing minimum deployment targets.
 */
public struct AppAttestFlow: Codable, Equatable, OAuthFlow {

    public let clientID: String
    public let keyId: String
    public let assertion: Data
    public let nonce: String

    /// Creates a new instance of an App Attest flow.
    /// - Parameters:
    ///   - clientID: The client identifier registered with the BFF — used to
    ///     route the request and to namespace the stored token.
    ///   - keyId: The key identifier returned by
    ///     `DCAppAttestService.generateKey()` and previously registered with
    ///     the BFF via the attestation endpoint.
    ///   - assertion: The CBOR-encoded blob returned by
    ///     `DCAppAttestService.generateAssertion(_:clientDataHash:)`.
    ///   - nonce: The single-use nonce previously issued by the BFF, that the
    ///     assertion's `clientDataHash` was computed over.
    public init(clientID: String,
                keyId: String,
                assertion: Data,
                nonce: String) {
        self.clientID = clientID
        self.keyId = keyId
        self.assertion = assertion
        self.nonce = nonce
    }

    // MARK: OAuthFlow

    public var queryParameters: [String: String]? {
        return nil
    }

    public var httpBody: Data? {
        let payload: [String: Any] = [
            "platform": "ios",
            "client_id": clientID,
            "key_id": keyId,
            "assertion": assertion.base64EncodedString(),
            "nonce": nonce
        ]
        return try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }

    /// Attestation flows ship a JSON body — a base64-encoded CBOR blob is
    /// awkward to express as `application/x-www-form-urlencoded`.
    public var contentType: ContentType {
        return .applicationJson
    }

    public var isValid: Bool {
        guard !clientID.isEmpty,
              !keyId.isEmpty,
              !assertion.isEmpty,
              !nonce.isEmpty else {
            return false
        }
        return true
    }

    public func isEqualTo(otherFlow: OAuthFlow?) -> Bool {
        if let other = otherFlow as? AppAttestFlow {
            return other == self
        } else {
            return false
        }
    }
}
