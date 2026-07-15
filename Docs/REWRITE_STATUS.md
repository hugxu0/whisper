# Rewrite status

## Completed

- New repository created independently of the legacy source tree.
- Product behavior and the retained API/Socket boundary documented.
- Synthetic login, bootstrap, messages, upload, sync, and Socket.IO fixtures added.
- Pure Swift package modules added for domain contracts, clients, and feature state.
- Initial Swift Testing contract tests added without live network access.

## Not started yet

- Xcode iOS application target and dependency-injection composition root.
- Real HTTP/Socket clients backed by the retained server contract.
- Local persistence, outbox, media pipeline, and feature UI.
- macOS CI build and Simulator verification.

## Guardrail

No server endpoint, event name, authentication response, upload response, or
production data is changed or copied into this repository.
