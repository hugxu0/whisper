# ADR 001: Socket.IO client boundary

Status: accepted

## Context

The retained server uses Socket.IO rather than a raw WebSocket protocol. Its
authentication middleware reads `socket.handshake.auth.token` and deliberately
rejects a token placed in the query string so reverse-proxy access logs do not
capture credentials.

## Decision

- Use the upstream `socketio/socket.io-client-swift` package, pinned to 16.1.1.
- Isolate that dependency in the `WhisperSocketIO` module.
- Send the token through `connect(withPayload:)` as `{ "token": token }`.
- Keep HTTP authentication separate as `Authorization: Bearer <token>`.
- Run every upstream manager/client interaction on one private serial
  `handleQueue`, as required by the package.
- Expose only async Whisper protocols, event envelopes, lifecycle events, and
  typed message acknowledgements to the rest of the app.
- Keep automatic reconnect disabled until cursor sync and reconnect recovery
  are implemented together; a disconnect becomes visible session state instead
  of silently pretending the client is current.

## Consequences

- The server and its event names remain unchanged.
- Windows can review the boundary and fixtures, but dependency resolution and
  Apple-platform compilation require the macOS build path.
- `Package.resolved` must be committed after the first successful macOS build.
- The next chat slice must consume the bounded event stream and repair gaps via
  the retained `/api/v2/sync` cursor contract.
