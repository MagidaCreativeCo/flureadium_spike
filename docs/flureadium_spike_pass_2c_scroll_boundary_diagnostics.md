# Flureadium Spike Pass 2C — Scroll Boundary Diagnostics

## Purpose

Pass 2C follows the first device result from Pass 2B:

- `getCurrentLocator()` is not exposed by the current Flureadium build and produced a `NoSuchMethodError`.
- Vertical scroll still does not naturally continue into the next chapter/spine item.

This pass does not add fake continuous-scroll logic. It narrows the test surface so we can decide whether Leafra should treat vertical scroll as single-spine native scrolling, while exposing chapter movement through explicit reader controls.

## What changed

### Removed noisy locator probe

The Capability Lab no longer calls a dynamic `getCurrentLocator()` method. The spike now treats the stream/widget locator state as the source of truth:

- `onTextLocatorChanged`
- `ReadiumReaderWidget.onLocatorChanged`

The lab now has a **Show stream locator** action that logs the latest cached locator without calling unavailable API.

### Added chapter/spine boundary diagnostics

The navigation section now includes logged tests for:

- `skipToPrevious()`
- `skipToNext()`
- explicit previous `readingOrder` jump
- explicit next `readingOrder` jump

Each boundary test logs:

- locator before the command,
- locator after the command,
- href,
- progression,
- readingOrder index when it can be matched.

## Test procedure

1. Run the spike app.
2. Open Capability Lab.
3. Enable vertical mode with **Default vertical + reopen** or **Apply vertical + reopen**.
4. Scroll normally to the bottom of a chapter/spine item.
5. Confirm whether native WebView scrolling naturally crosses into the next chapter.
6. Press **skip next chapter + log**.
7. Press **jump next readingOrder**.
8. Repeat the same backward with **skip previous chapter + log** and **jump previous readingOrder**.
9. Open Diagnostics and compare before/after href, progression, and readingOrder index.

## How to interpret results

### If native vertical scroll does not cross chapters

This suggests Flureadium scroll mode is likely native scrolling only inside the current EPUB resource/spine item. Leafra should not fake continuous scroll with Flutter drag gestures. Instead, product UX should expose clear chapter controls in vertical mode.

### If `skipToNext()` works but native scroll does not

Leafra can support vertical mode as:

- native vertical scrolling within the current chapter/spine item,
- explicit next/previous chapter buttons,
- optional edge affordance such as “Next chapter” once end-of-chapter detection is proven by locator/progression.

### If explicit `readingOrder` jump works but `skipToNext()` does not

The product fallback should use the publication `readingOrder` index and `goByLink()` / `goToLocator()` for chapter controls.

### If backward navigation lands at the beginning of the previous chapter

That may be expected behavior for spine-entry jumps. It is not the same as preserving an exact previous-scroll offset. Leafra should avoid promising seamless continuous-scroll history unless Flureadium exposes reliable boundary/offset APIs.

## Current decision pressure

The key remaining question is not whether vertical scroll can scroll a page vertically. It is whether Flureadium supports seamless multi-spine continuous scroll. Pass 2C is designed to prove that distinction.
