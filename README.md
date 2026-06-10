# Flureadium EPUB Spike

## Overview

`flureadium_spike` is the technical proof-of-concept created before the full Leafra build.

The goal of this spike was to confirm that **Flureadium** can be used as the EPUB reading engine for Leafra, and that the core reading behaviours required for the MVP are achievable in Flutter.

This spike is not intended to be the final Leafra app architecture. It is a focused test project that proves the reader engine works before we move into the real Leafra implementation.

---

## Product Context

Leafra is planned as a **mobile-first private reading library and smart reading companion**.

The long-term product will include:

- local EPUB reading,
- a polished mobile library,
- saved reading progress,
- reader customization,
- privacy locks,
- hidden shelves,
- profiles,
- bookmarks and notes,
- reading analytics,
- TTS/audio reading,
- and optional future sync/AI features.

This spike validates the most important foundation: **can we open and navigate EPUB books reliably in Flutter?**

---

## What This Spike Proves

The spike successfully confirmed the following:

- EPUB books open using Flureadium.
- A bundled EPUB asset can be copied to local app storage and opened from a file path.
- Tap on the right side of the reader moves to the next page.
- Tap on the left side of the reader moves to the previous page.
- Swipe page navigation works.
- Reading progress can be captured.
- Reading progress can be saved locally.
- The book can reopen at the last saved reading location.
- Debug build succeeds.
- Release build succeeds.
- The app runs as expected on device/emulator.

---

## Core Dependencies Used

The spike uses Flutter and Flureadium.

Expected dependencies include:

```yaml
dependencies:
    flutter:
        sdk: flutter
    flureadium:
        git:
            url: https://github.com/MagidaCreativeCo/flureadium.git
            path: flureadium
    shared_preferences: ^latest
```

> Note: The exact versions should be checked in the project `pubspec.yaml`.

---

## Asset Book Setup

The spike uses a local EPUB asset for testing.

Example asset path used during the spike:

```text
assets/books/The_Adventures_of_Tom_Sawyer.epub
```

The asset must be registered in `pubspec.yaml`:

```yaml
flutter:
    assets:
        - assets/books/The_Adventures_of_Tom_Sawyer.epub
```

If the book does not open, first confirm that the asset path in code matches the asset path in `pubspec.yaml`.

---

## Reader Behaviour Confirmed

### Page navigation

The spike confirmed this navigation model:

- tap right edge → next page,
- tap left edge → previous page,
- swipe left/right → page navigation,
- toolbar/icon navigation can also move between pages where implemented.

### Progress persistence

The spike confirmed that reading progress can be saved and restored.

Expected behaviour:

1. Open the EPUB.
2. Navigate to a later page.
3. Close or restart the app.
4. Reopen the book.
5. The reader should open at the last saved location.

---

## Important Fixes Completed During the Spike

### 1. Asset path mismatch

At one point the book did not open because the asset path had not been updated correctly in `pubspec.yaml`.

Resolution:

- Confirmed the EPUB asset path.
- Updated `pubspec.yaml` assets.
- Re-ran `flutter pub get`.

### 2. Missing `shared_preferences` dependency

A dependency error appeared because `shared_preferences` was imported but not declared in `pubspec.yaml`.

Resolution:

- Added `shared_preferences` to dependencies.
- Re-ran `flutter pub get`.

### 3. Widget type mismatch

A Flutter error occurred where `Text(...)` was passed to a parameter expecting `String?`.

Resolution:

- Adjusted the affected property to pass a string instead of a `Text` widget.

### 4. Locator API mismatch

An error appeared around `Link.locator` not being available.

Resolution:

- Adjusted the implementation to match the actual Flureadium API available in the fork.
- Progress saving/restoring was confirmed working after the fix.

---

## Commands Used

Run dependency install:

```bash
flutter pub get
```

Run app:

```bash
flutter run
```

Build debug APK:

```bash
flutter build apk --debug
```

Build release APK:

```bash
flutter build apk --release
```

If using VS Code, the project was also tested through the Flutter tooling from the editor.

---

## Expected Validation Checklist

Use this checklist before considering the spike healthy:

- [ ] `flutter pub get` completes successfully.
- [ ] Debug build succeeds.
- [ ] Release build succeeds.
- [ ] App launches.
- [ ] EPUB opens.
- [ ] Tap right edge moves to next page.
- [ ] Tap left edge moves to previous page.
- [ ] Swipe navigation works.
- [ ] Progress is captured.
- [ ] Progress restores after reopening.
- [ ] No missing asset errors.
- [ ] No missing dependency errors.

---

## Relationship to Leafra

This project is only the reader-engine spike.

The full Leafra app should not continue growing directly from messy spike code without restructuring.

The next real Leafra build should follow the agreed architecture:

```text
lib/
  app/
  core/
  shared/
  features/
    library/
    reader/
    settings/
    privacy/
```

The working reader logic from this spike should be migrated into:

```text
lib/features/reader/
```

The spike should be kept as a reference until the new Leafra MVP reader confirms the same behaviours.

---

## Next Step

The next step after this spike is **Leafra Pass 1: Project Foundation + Architecture Restructure**.

Pass 1 should:

1. create the clean Leafra folder architecture,
2. add app shell and routing,
3. add Library, Reader, and Settings screens,
4. migrate the working Flureadium reader logic,
5. preserve tap/swipe navigation,
6. preserve saved progress,
7. add the Leafra documentation into the repo,
8. confirm debug and release builds still pass.

---

## Status

Spike status: **successful**

The Flureadium EPUB reader foundation is viable for Leafra.
