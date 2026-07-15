# Rewrite status

## Completed

- New repository created independently of the legacy source tree.
- Product behavior and the retained API/Socket boundary documented.
- Synthetic login, bootstrap, messages, upload, sync, and Socket.IO fixtures added.
- Pure Swift package modules added for domain contracts, clients, and feature state.
- Initial Swift Testing contract tests added without live network access.
- Fixture-backed login → Bootstrap → Socket lifecycle slice added with retryable
  session state and injectable clients.
- SwiftUI composition root, XcodeGen application target, and Socket.IO v4
  adapter added behind the retained realtime boundary.

## Not started yet

- macOS generation of the Xcode project and first Simulator build.
- Chat timeline, pending outbox, and consumption of Socket.IO message events.
- Local persistence, outbox, media pipeline, and feature UI.
- macOS CI build and Simulator verification.

## Guardrail

No server endpoint, event name, authentication response, upload response, or
production data is changed or copied into this repository.
