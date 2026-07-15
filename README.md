# Whisper

Whisper is a clean-slate rewrite of the CoupleChat product.

This repository is intentionally independent from the legacy implementation. The legacy project may be consulted as a black-box reference for observed behavior, visual direction, API contracts, and known user flows, but its source code is not an architectural template and must not be imported into this project.

## Current status

Repository bootstrap only. No product source code has been copied from the legacy project.

## Rewrite rules

- Start from product behavior and explicit contracts, not legacy class names or file structure.
- Keep the new app and any new server implementation independently buildable.
- Prefer explicit feature state, actions, effects, and injected clients over global stores.
- Keep UI behavior and visual decisions intentional; existing screens are references, not implementation constraints.
- Add tests and CI with each completed vertical slice.

## Next milestone

Create the product behavior brief, protocol fixtures, and target architecture before implementing the first feature.

