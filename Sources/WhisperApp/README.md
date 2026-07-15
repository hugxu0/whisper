# WhisperApp composition root

This module owns dependency composition and the first SwiftUI root surface. It
contains no HTTP or Socket.IO implementation details and does not store a
production password. The generated Xcode application target supplies device
metadata and the configured server base URL.

Feature code must remain in its feature module; this target is only the
composition and navigation edge.
