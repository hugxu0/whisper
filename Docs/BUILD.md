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

## GitHub Actions

The repository's [`iOS CI`](../.github/workflows/ios-ci.yml) workflow runs on
GitHub's `macos-15` runner with Xcode 16.4. It is triggered for changes pushed
to `main`, pull requests targeting `main`, and manual dispatches from the
Actions page.

The workflow resolves the Swift package graph, runs the package tests,
generates `Whisper.xcodeproj` with XcodeGen, and builds the app for a generic
iOS Simulator destination with code signing disabled. A failed Xcode build
uploads its log for seven days.

CI remains hermetic: tests use synthetic fixtures and do not contact or mutate
the production API at `https://hoo66.top`.

The checked-in `project.yml` is the Xcode project source of truth. On macOS:

```bash
xcodegen generate
xcodebuild -project Whisper.xcodeproj -scheme Whisper \
  -destination 'generic/platform=iOS Simulator' build
swift test
```

The generated `Whisper.xcodeproj` stays untracked. `Package.resolved` should be
committed after the first successful macOS dependency resolution so Socket.IO
and Starscream remain reproducible.

The first CI job should consume the synthetic fixtures without contacting
`https://hoo66.top`. Live API smoke tests, if ever needed, must be a separate,
explicitly configured job.
