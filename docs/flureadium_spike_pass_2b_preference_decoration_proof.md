# Flureadium Spike Pass 2B — Preference Confirmation + Decoration Proof

## Purpose

Pass 2B pauses Leafra product/UI work and strengthens the Flutter spike so the Flureadium reader-engine behavior can be proven directly before Leafra continues.

This pass does **not** implement a simulated continuous-scroll bridge. In scroll mode, the spike still relies on Flureadium and the native Android WebView behavior. This is intentional because Flureadium's platform docs state that EPUB scroll mode disables the gesture overlay so the native view can handle scrolling.

## What changed

### Preference confirmation

The capability lab now exposes three explicit vertical-scroll proof paths:

1. **Default vertical + reopen**
    - Saves `verticalScroll=true`.
    - Calls `setDefaultPreferences()` before reopening the publication.
    - Reopens the current EPUB so the preference can be tested from reader construction/open time.

2. **Live vertical apply**
    - Saves `verticalScroll=true`.
    - Calls `setDefaultPreferences()`.
    - Calls `setEPUBPreferences()` against the currently open publication.

3. **Apply vertical + reopen**
    - Saves `verticalScroll=true`.
    - Calls live preference application.
    - Reopens the current EPUB to check whether a reopen changes behavior.

A reset button, **Reset paginated + reopen**, returns the requested state to `verticalScroll=false` and reopens the current EPUB.

The diagnostics log now records every preference request and whether `setDefaultPreferences()` and `setEPUBPreferences()` completed or were skipped.

## Decoration proof

Pass 2B separates decoration proof from selected-text highlighting:

- **Decorate locator highlight** creates a `ReaderDecoration` with `DecorationStyle.highlight` using the latest captured locator.
- **Decorate locator bookmark** saves a bookmark and applies an underline-style decoration using the same locator.
- **Apply saved decorations** reapplies both highlight and bookmark/underline groups.
- **Clear applied decorations** clears the rendered Flureadium decoration groups without deleting saved spike data.
- The capability lab displays highlight and bookmark/underline counts.
- Diagnostics now logs when `applyDecorations()` completes for each group.

Important limitation: current-position decoration is not the same as true selected-text highlighting. True selected-text highlighting still needs either an exposed selected-range callback from Flureadium or a native bridge that returns a valid `Locator` for the selected range.

## Locator proof

The capability lab now shows:

- requested preference state,
- last captured locator summary,
- last locator href,
- highlight count,
- bookmark/underline decoration count.

The **Get current locator** button logs the latest stream-cached locator. It also attempts a dynamic `getCurrentLocator()` call. If the current Flureadium API does not expose that method, diagnostics will explicitly show that it is unavailable rather than silently failing.

## TTS proof

The TTS panel now logs and displays clearer proof points:

- `ttsCanSpeak()` result,
- `ttsGetSystemVoices()` count,
- `ttsGetAvailableVoices()` count when exposed by the API,
- `ttsSetPreferences()` completion,
- `ttsEnable()` completion with the current locator,
- `play`, `pause`, `resume`, `next`, `previous`, and `stop` command results,
- timebased player state stream updates in Diagnostics.

## Manual test plan

### A. Baseline reader behavior

1. Launch the spike.
2. Open **The Adventures of Tom Sawyer**.
3. Confirm paginated behavior still works:
    - tap right edge = next page,
    - tap left edge = previous page,
    - swipe works,
    - TOC jump works,
    - progress is captured in Diagnostics.

### B. Vertical scroll proof

1. Open the capability lab.
2. Press **Default vertical + reopen**.
3. Try native vertical scrolling inside the reader.
4. Use Diagnostics to confirm:
    - requested preferences contain `"verticalScroll":true`,
    - `setDefaultPreferences()` completed before reopen,
    - the publication reopened.
5. Press **Reset paginated + reopen**.
6. Press **Live vertical apply** and test again.
7. Press **Apply vertical + reopen** and test again.
8. Record whether scroll works, whether chapter boundaries are reachable, and whether previous-chapter navigation restores to a useful locator or the start of the previous chapter.

### C. Decoration proof

1. Move to a visible paragraph.
2. Wait for a locator update or press **Get current locator**.
3. Press **Decorate locator highlight**.
4. Confirm Diagnostics logs `applyDecorations(leafra-spike-highlights) completed`.
5. Press **Decorate locator bookmark**.
6. Confirm Diagnostics logs `applyDecorations(leafra-spike-bookmarks) completed`.
7. Press **Clear applied decorations**.
8. Confirm both decoration groups are cleared visually and Diagnostics logs zero decorations.
9. Press **Apply saved decorations** to reapply persisted proof decorations.

### D. TTS proof

1. Open the TTS panel from the capability lab.
2. Check the displayed `ttsCanSpeak`, system voice count, and available voice count.
3. Press **Enable**.
4. Press **Play**, **Pause**, **Resume**, **Next**, **Previous**, and **Stop**.
5. Watch Diagnostics for command success/failure, locator updates, and `onTimebasedPlayerStateChanged` events.

## Expected Pass 2B decision output

After device testing, classify Flureadium behavior into one of these outcomes:

1. **Proven** — vertical scroll, locator restore, decorations, and TTS are stable enough to continue Leafra reader UX.
2. **Partially proven** — paginated mode is stable, but vertical scroll or selected-text highlight needs native/API work.
3. **Blocked** — Flureadium API/fork changes are required before Leafra feature expansion resumes.
