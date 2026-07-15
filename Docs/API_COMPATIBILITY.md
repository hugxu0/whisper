# Whisper API compatibility boundary

Status: frozen external contract

This snapshot was checked against the legacy server route registrations and its Socket.IO contract, not only against the legacy API prose document. The route names are external compatibility data; the legacy implementation is not a Whisper dependency.

Whisper must connect to the existing service without requiring a server rewrite. The server is an external dependency for this phase. The new client may replace its own models, stores, networking layer, and UI, but it must preserve the wire contract below.

## Connection and authentication

- Production base URL: `https://hoo66.top`.
- Authenticated REST requests send `Authorization: Bearer <token>`.
- Errors normally have the shape `{ "error": "code_or_message" }`.
- Timestamps are Unix milliseconds unless an endpoint explicitly says otherwise.
- Only the fixed accounts `xu` and `si` are supported. There is no registration, invitation, pairing, or user-created couple-space flow.
- Login is `POST /api/v2/login` with `username`, `password`, and a device description. A successful response contains `token`, `username`, `name`, and `deviceId`.

## REST endpoints

### Public and account state

| Method | Path | Purpose |
|---|---|---|
| GET | `/live` | Process liveness check |
| GET | `/ready` | Database/readiness check |
| GET | `/health` | Health/readiness check |
| GET | `/api/accounts` | Fixed account list or current couple members |
| POST | `/api/v2/login` | Login and bind the current device |
| GET | `/api/me` | Validate the current token |
| GET | `/api/bootstrap` | Recent messages, account, read state, and shared snapshot |
| GET | `/api/messages` | Message pagination or incremental reads |
| GET | `/api/v2/chat/stats` | Chat counts using Shanghai calendar semantics |
| GET | `/api/v2/me/devices` | Current account's active devices and Bark state |
| PUT | `/api/v2/me/devices/current/push/bark` | Bind/update current device Bark settings |
| POST | `/api/v2/me/devices/current/push/bark/test` | Send a Bark connectivity test |
| DELETE | `/api/v2/me/devices/:id` | Revoke a device |

`GET /api/messages` requires `channel=couple|ai` and supports `since`, `after`, `before`, `around`, and `limit` (`1...300`, default `80`). A request must not combine multiple paging directions. The response is `{ ok, list, total }`.

### Uploads and media

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/upload?purpose=message|avatar|sticker|album` | Multipart upload, maximum 50 MB |
| GET | `/media/:id?sig=...` | Signed media access |
| GET | `/uploads/:filename` | Compatibility media access for existing messages |

Upload responses contain `id`, `url`, `mimeType`, `size`, and `type`. Image, video, voice, and file messages must refer to the returned `id` as `uploadId`.

### Personal and shared items

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/me/items?kind=&scope=` | List visible reminders or memos |
| POST | `/api/me/items` | Create an item |
| PATCH | `/api/me/items/:id` | Update an item |
| DELETE | `/api/me/items/:id` | Delete an item |

`kind` is `reminder|memo`; `scope` is `personal|shared`. Main fields are `title`, `bodyMarkdown`, `dueAt`, and `isDone`. Server-side Bark delivery remains authoritative; Whisper must not create a second local deadline scheduler for these items.

### Memory

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/me/memory?scope=&layer=&perspective=&kind=&q=&limit=&cursor=` | List visible Memory cards |
| GET | `/api/me/memory/:id/evidence` | Compatibility endpoint; currently returns an empty array |
| GET | `/api/me/memory/:id/sources` | List referenced source cards |
| PATCH | `/api/me/memory/:id` | Correct content or importance with `baseVersion` |
| DELETE | `/api/me/memory/:id` | Delete a Memory card |
| POST | `/api/me/memory/refresh` | Refresh shared or private Memory |

Memory privacy is part of the contract: shared cards are visible to both accounts, while `ai:<username>` private Memory is visible only to that account. A version conflict returns HTTP 409 with the authoritative item.

### Recommendations, sync, transcription, albums, calendar, and pet

| Area | Endpoints |
|---|---|
| Recommendations | `/api/v2/recommendations/today`, `/refresh`, `/recommendations`, `/unread-count`, `/history`, `/:id/read`, `/:id` |
| Incremental sync | `GET /api/v2/sync?cursor=&limit=`, `POST /api/v2/sync/ack` |
| Transcription | `GET/POST /api/v2/messages/:messageId/transcript[/retry]` |
| Albums | `/api/v2/albums`, `/api/v2/albums/:albumId/items`, `/api/v2/media-assets/:assetId/note`, `/api/v2/media/on-this-day` |
| Calendar | `/api/v2/calendar/events`, `/api/v2/calendar/events/:id/complete` |
| Pet | `GET /api/v2/pet`, `POST /api/v2/pet/interactions` |

The exact method, body, cursor, and `baseVersion` rules for these endpoints must be captured as fixtures before implementing each Whisper feature. Do not infer a new endpoint from a UI requirement.

## Socket.IO contract

Connect with the token in the Socket.IO auth object:

```javascript
io("https://hoo66.top", { auth: { token } })
```

### Client-to-server events

| Event | Payload | Purpose |
|---|---|---|
| `health` | none | Connection health |
| `away` | `boolean` | Presence state |
| `message:send` | Message request | Send a message and receive `{ ok, message }` |
| `message:recall` | `{ id }` | Recall a message |
| `messages:search` | `{ channel, query, limit? }` | Search messages |
| `read` | `{ channel, ts }` | Update read position |
| `shared:set` | `{ key, value }` | Write a shared JSON object |
| `action:confirm` | `{ messageId, decision }` | Confirm/cancel an AI action |

### Server-to-client events

`message:new`, `message:recalled`, `message:update`, `read:update`, `presence`, `shared:update`, `personalItem:changed`, `ai:typing`, `ai:replying`, and `ai:activity`.

### Message send invariants

```json
{
  "channel": "couple",
  "type": "text",
  "text": "你好",
  "clientId": "device-generated-id",
  "replyTo": null,
  "replyPreview": null,
  "uploadId": null,
  "attachments": null,
  "meta": null
}
```

- `channel` is `couple` or `ai`.
- `type` is `text|image|video|sticker|voice|file`.
- `clientId` is required for retry idempotency.
- `url` is optional and is only a cross-check; the server resolves media by `uploadId`.
- `reply` may appear in compatibility payloads; new code should prefer the explicit `replyTo` and `replyPreview` fields.
- Media messages must reference an existing `uploadId`.
- The server supports Live Photo attachment pairs, even though the current client sends static photos.
- A successful ack or `message:new` is authoritative; the client must replace pending state with the server message.

## Non-negotiable compatibility rules

1. Do not change the production server in the Whisper bootstrap phase.
2. Do not rename or reinterpret existing REST paths or Socket event names.
3. Do not silently change timestamp units, channel names, cursor semantics, or conflict behavior.
4. Do not treat a successful upload as a sent message; `message:send` still has to reference the upload.
5. Do not make private AI or personal-item data shared for implementation convenience.
6. Any suspected server inconsistency becomes a recorded compatibility issue and fixture, not an implicit client-side protocol change.

## Fixture plan

Before feature implementation, capture sanitized fixtures for login, bootstrap, message pagination, message send ack, reconnect sync, upload response, recall, shared update, and one representative response for each non-chat feature. Fixtures must not contain tokens, passwords, private chat text, production media, or production database contents.
