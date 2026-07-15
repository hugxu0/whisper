# Whisper

Whisper is a clean-slate rewrite of the CoupleChat product.

This repository is intentionally independent from the legacy implementation. The legacy project may be consulted as a black-box reference for observed behavior, visual direction, API contracts, and known user flows, but its source code is not an architectural template and must not be imported into this project.

## Current status

The repository now contains a clean-slate Swift package boundary, synthetic
API/Socket fixtures, injectable HTTP/Socket clients, and the first
login→Bootstrap→connection state slice. It also includes an XcodeGen iOS target
and a Socket.IO adapter that sends authentication in the retained CONNECT
payload. No product source code has been copied from the legacy project, and no
live server request is made by the test suite.

## Rewrite rules

- Start from product behavior and explicit contracts, not legacy class names or file structure.
- Keep the new app and any new server implementation independently buildable.
- Prefer explicit feature state, actions, effects, and injected clients over global stores.
- Keep UI behavior and visual decisions intentional; existing screens are references, not implementation constraints.
- Add tests and CI with each completed vertical slice.

## Next milestone

Generate and compile the Xcode project on macOS, then implement the first chat
timeline slice using the existing `message:new` and `message:send` contracts.
