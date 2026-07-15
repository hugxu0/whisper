# Whisper architecture proposal

Whisper is a clean-slate implementation. The old application is not a module, dependency, or migration base. It is only a black-box reference for the behavior brief and sanitized protocol fixtures.

## Goals

- Make state ownership and side effects explicit.
- Keep the server contract stable while the client is replaced.
- Make each feature testable without rendering the whole app.
- Keep networking, persistence, media, and UI independently replaceable.
- Make new UI decisions from a new design system rather than copying old view structure.

## Initial dependency direction

```text
App / Composition Root
        ↓
Features → Domain
   ↓          ↑
Clients  ← protocol definitions
```

The dependency graph must point inward toward domain contracts. Views must not construct HTTP clients, Socket.IO connections, database handles, or multipart uploaders directly.

## Proposed source layout

```text
Sources/
  WhisperApp/
  WhisperDomain/
    Models/
    Errors/
    Contracts/
    UseCases/
  WhisperClients/
    HTTP/
    Socket/
    Persistence/
    Media/
    Auth/
  WhisperFeatures/
    Auth/
    Chat/
    Moments/
    Plans/
    Daju/
    Memory/
    Account/
  WhisperDesignSystem/
    Tokens/
    Components/
    Motion/

Tests/
  WhisperDomainTests/
  WhisperClientTests/
  WhisperFeatureTests/
  WhisperContractTests/
```

Start with a small number of local Swift modules. Add a module only when it enforces a real dependency boundary or materially improves test/build isolation.

## Feature state model

Each non-trivial feature owns a small, explicit state machine:

```text
FeatureState + FeatureAction
          ↓
      Reducer
          ↓
FeatureState changes + FeatureEffect
          ↓
   injected Client / UseCase
```

Use a reducer/effect style for Chat, authentication, synchronization, media delivery, and conflict handling. Simple static screens may remain ordinary SwiftUI MV views. Do not create a view model that only forwards properties.

## Client boundaries

- `HTTPClient`: request construction, authentication headers, decoding, status/error mapping.
- `SocketClient`: connection lifecycle, auth handshake, event streams, ack calls, reconnect signal.
- `PersistenceClient`: local cache and outbox access behind an actor.
- `MediaClient`: multipart uploads, progress, local file lifetime, signed URL resolution.
- `AuthClient`: secure token/device state and logout cleanup.
- Feature repositories/use cases: translate external DTOs into domain operations without exposing transport details to Views.

The existing API and Socket names remain at the client boundary. New internal names do not need to match old Swift types.

## Concurrency policy

- UI-owned observable models are `@MainActor`.
- Mutable persistence, outbox, and cache state are actors.
- Network and media clients are not `@MainActor` unless they directly touch UI state.
- Heavy media parsing or thumbnail work must not block the main actor.
- Long-running tasks are structured and cancellable; no untracked background task may outlive its feature.
- No `@unchecked Sendable` or detached task is allowed without a written invariant.

## SwiftUI and UIKit policy

Start the new product with SwiftUI as the default rendering layer. A UIKit adapter is allowed only when a measured requirement justifies it, and it must live behind a feature-owned boundary such as `ChatTimelineSurface` or `MediaPreviewSurface`.

UIKit adapters must not become a second state architecture. They receive explicit state and callbacks and do not reach into global stores.

## Backend compatibility policy

- The existing server at `https://hoo66.top` is not changed by Whisper bootstrap work.
- `Docs/API_COMPATIBILITY.md` is the new repository's frozen compatibility boundary.
- Protocol DTOs and fixtures are authored independently in Whisper; old Swift model files are not copied.
- A server mismatch is recorded as a compatibility issue and verified against a sanitized response before any client workaround is accepted.
- If a future server rewrite is approved, it must implement the same contract first and be tested behind the same client boundary.

## Verification policy

Windows checks:

- source and dependency review;
- pure domain and client fixture tests where the host toolchain supports them;
- server tests/build if the server is included in Whisper;
- `git diff --check` and documentation consistency.

macOS CI checks:

- XcodeGen/project generation;
- Swift compile and unit tests;
- iPhone Simulator tests;
- iPad compile/build;
- UI and media interaction checks when a feature needs them;
- unsigned Archive/IPA packaging.

No feature is considered complete because its source looks clean on Windows. It needs the applicable CI proof.

## First implementation boundary

The first implementation should contain only:

1. app composition and dependency injection;
2. secure session state;
3. API-compatible login;
4. bootstrap decoding;
5. Socket connection and visible connection state;
6. a fixture-backed empty/chat shell.

Do not add media, Memory, pet, album, calendar, or redesign polish until this boundary is testable and CI-buildable.

