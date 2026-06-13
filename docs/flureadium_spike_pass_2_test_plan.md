# Flureadium Spike Pass 2 Test Plan

**Purpose:** Use the spike app as Leafra's reader-engine laboratory before further Leafra UI or feature work.

## Why this pass exists

Leafra must be reader-first. The previous Leafra passes showed that polishing the app around an uncertain reader engine creates unstable behavior, especially around vertical scrolling and chapter transitions. This pass moves testing back into the Flureadium spike app so the engine can be tested directly.

## Test harness additions

The spike app now includes a **Capability Lab** reachable from the science icon in the top app bar.

It tests:

- page navigation with `goLeft()` and `goRight()`,
- chapter navigation with `skipToPrevious()` and `skipToNext()`,
- TOC navigation through `goByLink()`,
- progress restore through `ReadiumReaderWidget.initialLocator`,
- progress saving through `onLocatorChanged` and `onTextLocatorChanged`,
- EPUB preference changes,
- native vertical scroll mode without a Flutter gesture bridge,
- bookmark persistence,
- decoration/highlight persistence through `applyDecorations()`,
- TTS enable/play/pause/resume/stop/next/previous,
- system voice listing and voice selection,
- reader status, locator, timebased playback, and error streams.

## Critical scroll-mode rule

Do **not** simulate continuous chapter scrolling with Flutter drag detection in this spike.

The Android and iOS Flureadium platform docs say EPUB scroll mode disables gesture interception so the native WebView/WKWebView can handle scrolling. This pass tests that native behavior directly.

## Navigation rules to verify

```dart
goLeft();          // previous visual page
 goRight();         // next visual page
skipToPrevious();  // previous chapter/resource/TOC entry
skipToNext();      // next chapter/resource/TOC entry
goToLocator();     // exact saved/bookmark/highlight/TOC locator
```

## Test checklist

### 1. Open and restore

- Open Tom Sawyer.
- Turn pages.
- Close and reopen the app.
- Confirm restore uses the saved locator.
- Switch to Minimal EPUB and back.
- Confirm progress is per book.

### 2. Paginated mode

- Confirm right-edge tap moves forward.
- Confirm left-edge tap moves backward.
- Confirm swipe moves page where native reader supports it.
- Confirm `goLeft()` / `goRight()` buttons in Capability Lab work.

### 3. Vertical scroll mode

- Enable vertical scroll in Preferences.
- Confirm vertical scroll persists after app restart.
- Scroll naturally inside the current spine/chapter.
- Test native horizontal swipe between spine items.
- Test whether swipe-back restores the previous spine item's last scroll position.
- Test `skipToNext()` / `skipToPrevious()` separately.
- Record whether true seamless full-book scrolling exists or whether scroll is spine-local.

### 4. Preferences

- Test Light, Sepia, Dark, and OLED.
- Test font family differences.
- Test font size.
- Test page margins.
- Record which settings re-layout the reader and whether changes feel acceptable.

### 5. Decorations and highlights

- Add a highlight at the current locator.
- Confirm it appears in the reader.
- Restart the app.
- Confirm saved highlights reapply.
- Delete a highlight.
- Confirm the decoration is removed.

### 6. TTS

- Open the TTS panel.
- Run `ttsCanSpeak()` and `ttsEnable()`.
- Test play, pause, resume, stop.
- Test next/previous utterance.
- Test available system voices.
- Select a voice.
- Confirm playback state events appear in Diagnostics.
- Confirm TTS decoration style produces visible current-sentence/current-range styling if supported.

### 7. Diagnostics

- Open Diagnostics while testing.
- Confirm locator events are emitted.
- Confirm reader status events are emitted.
- Confirm TTS/audio state events are emitted.
- Capture any errors.

## Expected report output

After device testing, update the spike report with:

- confirmed working features,
- confirmed broken or unstable features,
- platform-specific notes,
- Flureadium fork changes required,
- Leafra implementation recommendations.
