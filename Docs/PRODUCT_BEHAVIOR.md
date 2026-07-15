# Whisper product behavior brief

This is a behavior document, not a porting guide. It describes what the new product should do without prescribing legacy class names or implementation details.

## Product boundary

Whisper serves two fixed accounts, `xu` and `si`, with the same account usable on multiple iPhone/iPad devices. The main product areas are:

- Chat
- Moments
- Plans
- Daju
- Account

The existing server remains the source of truth for shared data, messages, Memory, pet state, reminders, and device state.

## Core behavior

### Launch and session

- Restore a token from secure device storage.
- Show a deterministic loading state while validating the session and loading the initial snapshot.
- Establish the real-time connection only after authentication is valid.
- Show connection state explicitly and recover after foregrounding or a dropped connection.
- Logging out clears local session state without changing server-owned shared data.

### Chat

- Support two channels: the shared couple conversation and the current account's private Daju conversation.
- Support text, images, video, voice, files, stickers, replies, search, read state, AI activity, and recall.
- Messages can be loading, sending, sent, failed, recalled, or replaced by an authoritative server message.
- The client must not claim a message is sent before the server ack or authoritative event arrives.
- History is windowed and paged; the client must not load the entire conversation into memory.
- Reconnect and foreground recovery must converge to server state without duplicating messages.

### Media

- Upload media first, then send a message referencing the server `uploadId`.
- Preserve upload progress and retry information in the UI.
- Support media preview, file access, video thumbnails, voice transcription status, and favorite/save actions where the server contract supports them.
- A media preview should not change the message's delivery state.
- The new design may improve the presentation, but upload ordering and server references are fixed by `API_COMPATIBILITY.md`.

### Moments

- Browse shared albums and grouped timeline posts.
- Create albums, add chat media, upload new media, edit captions/notes, and remove media from an album without deleting the original chat message.
- A post can contain multiple media items and should remain one logical timeline entry.
- Full-screen browsing is scoped to the current post's media set.

### Plans

- Support shared and personal calendar events.
- Support shared and personal reminders and memos.
- Shared reminders notify both accounts; personal reminders notify only the owner.
- Calendar events currently do not create automatic due notifications; reminder delivery remains a separate server concern.
- Conflicts use the server's version response and must be presented as a recoverable state, not overwritten silently.

### Daju

- The two accounts share one server-backed pet state.
- Display level, experience, four status values, recent interactions, and cooldowns.
- Interaction requests use server versioning and idempotency.
- Do not invent unsupported features such as streaks, sickness, room decoration, or collections during the rewrite unless explicitly requested.

### Memory and AI

- Show shared Memory separately from account-private Daju Memory.
- Support viewing, correcting, deleting, refreshing, and opening referenced source cards.
- A Memory version conflict shows the server-authoritative card and offers a deliberate retry path.
- AI typing, replying, activity, confirmation, and failure states are separate UI states.
- Private AI data must never be displayed in the shared conversation or shared Memory surface.

## Design direction

The current app is a visual reference only. Whisper should preserve the product's warmth and intimacy while being free to redesign hierarchy, spacing, motion, and information density.

The new design system should define semantic tokens before feature screens:

- background and surface roles;
- primary, secondary, destructive, and status colors;
- typography roles and Dynamic Type behavior;
- spacing and corner-radius scale;
- interactive control states;
- loading, empty, offline, failed, and conflict presentations;
- motion rules including reduced-motion behavior;
- iPhone, iPad Split View, and compact/regular size-class layouts.

## First acceptance matrix

The first complete Whisper vertical slice is accepted only when all of these are represented in tests or fixtures:

| Flow | Required result |
|---|---|
| Launch with valid session | Snapshot loads, connection starts, and the first screen is deterministic |
| Login failure | Credentials are not persisted as a valid session and the user sees a recoverable error |
| Socket disconnect | UI reports the disconnected state and reconnect/sync converges without duplicate messages |
| Text send | Pending → server ack → authoritative message, including retry failure |
| Media send | Upload → upload id → message send → authoritative message |
| Recall | Optimistic local hiding is reconciled by the server recall event |
| Private Daju chat | Private channel and Memory never appear in shared surfaces |
| Shared reminder | Both accounts receive the server-authoritative item state |
| Personal reminder | Only the owner receives the personal item state |
| Version conflict | The authoritative server object is shown and local data is not silently discarded |

## Explicitly out of scope for the first slice

- Redesigning or migrating the production database;
- changing the server's endpoint or Socket contract;
- importing old Swift files or old view models;
- implementing every feature before the login/chat foundation is proven;
- reproducing old bugs for compatibility.

