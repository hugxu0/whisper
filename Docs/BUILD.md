# Build and verification path

Whisper is being authored on Windows, but the iOS app target cannot be
compiled, signed, or run in an iOS Simulator on Windows. The repository is
therefore split into checks that can run locally and checks that belong to a
macOS CI runner.

## Windows checks

- JSON fixture parsing and static contract checks;
- pure Swift package tests when a compatible Swift toolchain is available;
- documentation and formatting checks;
- server tests only if a future server package is intentionally added here.

## macOS checks

- Xcode build for the pinned iOS deployment target;
- Swift Testing and UI tests;
- Simulator smoke flows for login, bootstrap, messaging, upload, and reconnect;
- archive/signing only in the release pipeline.

The first CI job should consume the synthetic fixtures without contacting
`https://hoo66.top`. Live API smoke tests, if ever needed, must be a separate,
explicitly configured job.
