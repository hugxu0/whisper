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
- Chat timeline slice added with bootstrap history, channel switching, pending
  text sends, authoritative ACK replacement, retryable failures, and
  `message:new` / `message:update` event consumption.
- Public GitHub Actions macOS CI now runs Swift tests and an unsigned iOS
  Simulator build.

## Not started yet

- Message pagination and reconnect synchronization.
- Local persistence, durable outbox, media pipeline, and feature UI polish.

## Guardrail

No server endpoint, event name, authentication response, upload response, or
production data is changed or copied into this repository.
