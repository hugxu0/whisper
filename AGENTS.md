# Whisper repository guidance

Whisper is a clean-slate rewrite. Do not copy, import, or extend source files from `D:\Desktop\couplechat-ios`.

Use the legacy project only as a read-only black-box reference for:

- user-visible behavior and edge cases;
- visual and interaction references;
- API, Socket.IO, media, and persistence contracts when those contracts are intentionally retained;
- regression fixtures captured from observed behavior.

Every new feature should define its state, actions, effects, dependencies, and tests before implementation. Avoid global stores and compatibility facades. Keep feature boundaries explicit and make the smallest intentional dependency graph.

Windows validation can cover source review, pure Swift/domain tests, server tests, and static checks. iOS compilation, Simulator execution, and IPA packaging must run through the macOS CI path once it exists.

