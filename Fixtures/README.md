# Synthetic protocol fixtures

These JSON files are **synthetic, non-production fixtures** for the clean-slate
Whisper client. They capture the server shapes that the new client must be able
to consume or produce without making a live request.

The fixtures are intentionally safe to commit:

- tokens, IDs, URLs, timestamps, and message text are fabricated;
- `example.invalid` is used for media URLs that must never resolve;
- no production account data or credentials belong here.

When the server contract changes, update the compatibility document and add a
new fixture that proves the intended shape. Do not change the server merely to
fit the new client.

## Directories

- `API/` — HTTP response bodies returned by the retained API contract.
- `Socket/` — Socket.IO payloads sent by or received by the client.
