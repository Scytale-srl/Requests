# ``Requests``

A lightweight Swift framework for building HTTP clients with first-class
OAuth 2.0 and attestation-based authentication.

## Overview

`Requests` models every API call as a value type conforming to
``Resource`` (or ``AuthenticatedResource`` when the call needs a token).
Authentication is handled by ``Authenticator``, with ``ARAuthenticator``
as the default actor-based implementation.

The package supports the standard OAuth 2.0 grants out of the box —
``ClientCredentials``, ``CodeFlow`` (Authorization Code, with PKCE
support), and ``RefreshToken`` — plus ``AppAttestFlow`` for clients that
authenticate via Apple App Attest against a Backend-For-Frontend.

Token storage is pluggable via ``TokenStore``, and the included
``ARTokenManager`` wraps a `TokenStore` with namespacing so multiple
clients can coexist in the same Keychain.

## Topics

### Resources

- ``Resource``
- ``AuthenticatedResource``
- ``HttpMethod``
- ``Header``
- ``ContentType``
- ``ResourceError``

### OAuth flows

- ``OAuthFlow``
- ``ClientCredentials``
- ``CodeFlow``
- ``RefreshToken``
- ``AppAttestFlow``

### Authenticator

- ``Authenticator``
- ``ARAuthenticator``
- ``LegacyARAuthenticator``
- ``AuthenticationEndpoint``
- ``AuthenticatorError``

### Tokens

- ``BearerToken``
- ``OAuth2Token``
- ``ARTokenManager``
- ``TokenStore``
- ``KeychainKey``

### Errors

- ``DebuggableError``
- ``DefaultError``

### Configuration

- ``RequestConfiguration``

### Articles

- <doc:AttestationFlow>
