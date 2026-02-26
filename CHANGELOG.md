# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-02-26

### Changed

- **BREAKING**: `ResourceError.apiError` now carries the HTTP status code as a second associated value: `apiError(resultError: any DebuggableError, statusCode: Int)`. Consumers that pattern-match on `.apiError` must update to include the new `statusCode` parameter.
- `validateResponse()` passes `response.statusCode` into `.apiError` so the HTTP status code is no longer lost when the response body decodes as `OutputError`.
- `localizedDescription` for `.apiError` now prefixes the status code: `"[statusCode] errorCode message"`.

## [1.1.3] - 2025-06-19

### Added

- Binary target support for Swift Package Manager distribution via CI/CD release workflow.

## [1.1.2] - 2025-03-07

### Fixed

- Token fetch requests now respect custom `userAgent` set on `AuthenticationEndpoint`.

### Added

- MIT License.

## [1.1.1] - 2024-12-05

### Added

- Swift Package Manager support.
- README documentation.

## [1.1.0] - 2024-01-30

### Added

- Closure-based request methods alongside async/await variants.
- `Resource.inject(session:)` for mocking `URLSession` in tests.
- `DebuggableError` protocol and `apiError` case in `ResourceError` for structured API error handling.
- Configurable HTTP request/response debug logging via `RequestConfiguration`.
- Download support (`Resource where Output == URL`).
- xcframework build script with dSYM symbols.

### Fixed

- URL encoding bug in request building.
