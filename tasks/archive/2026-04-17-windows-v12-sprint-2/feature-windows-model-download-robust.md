# Feature: Windows Model Download Robustness (F-3)

**Epic:** [Dikta Windows v1.2 — MVP Reliability & Polish](epic-windows-v12-mvp-reliability.md)

## 1. Introduction/Overview

The Whisper model is 488 MB (small), 1.5 GB (medium), or 3 GB (large). Today `ModelDownloader` uses `HttpClient` with the default 100-second timeout, which can fail mid-download on slow connections. It downloads directly into a `.tmp` and renames on success — but it never validates the final file size, so a truncated download ends up as a `.bin` that Whisper.net crashes on when loaded. The `ExpectedModelSizes` dictionary is already declared but never consulted. This Feature wires it in and hardens the download path for flaky networks.

## 2. Goals

- Model download does not fail on slow connections due to default HttpClient timeout
- Truncated or corrupt downloads are detected before the `.tmp` is promoted to the final `.bin`
- A failed validation keeps the `.tmp` for diagnostic capture (tester can send it to the developer)

## 3. User Stories

### US-001: No timeout on model download

**Description:** As a user on a slow connection, I want the Whisper model download to keep going so that I don't have to restart at 98% because of an arbitrary timeout.

**Acceptance Criteria:**
- [ ] `ModelDownloader`'s static `HttpClient` has `Timeout = Timeout.InfiniteTimeSpan`
- [ ] The download still honors cancellation via the `CancellationToken` from the progress window
- [ ] A slow download of the `small` model at 1 MB/s completes without a timeout exception

### US-002: Post-download size validation

**Description:** As a user, I want Dikta to detect a corrupt download so that I don't end up with a broken model that crashes every dictation.

**Acceptance Criteria:**
- [ ] After download, `ModelDownloader` validates the `.tmp` file size against `ExpectedModelSizes[modelName]` with ±1% tolerance
- [ ] A validation failure leaves the `.tmp` in place (not deleted) and throws an exception with the expected vs actual byte counts
- [ ] A validation success moves the `.tmp` to the final `.bin` path (existing behavior)
- [ ] The download progress window surfaces the validation error to the user via a readable message

## 4. Functional Requirements

- FR-1: `ModelDownloader.DownloadModelAsync` must set `HttpClient.Timeout = Timeout.InfiniteTimeSpan` (configure at static construction or on first use).
- FR-2: After the download loop completes (before `File.Move`), check `new FileInfo(tmpPath).Length` against `ExpectedModelSizes[modelName]`. Acceptable range: `[expected * 0.99, expected * 1.01]`.
- FR-3: On validation failure, throw `InvalidDataException` with message `"Downloaded model size mismatch: expected ~{expected} bytes, got {actual} bytes. Partial file kept at {tmpPath} for debugging."` — do NOT delete the `.tmp`.
- FR-4: On validation success, proceed with the existing `File.Move(tmpPath, destinationPath)` atomic rename.
- FR-5: The `DownloadProgressWindow` catch path must show the exception message (not a generic "Download failed") so the user can see the size mismatch.

## 5. Non-Goals (Out of Scope)

- SHA256 / MD5 checksum verification (size check is the 80% win; checksum requires a manifest we don't ship)
- Resume-from-interruption (partial download resume) — download restart is fine for v1.2
- Mirror fallback (alternative CDN if HuggingFace is slow)
- Bandwidth-limited download throttling
- Progressive download UI tuning beyond the existing progress window

## 6. Design Considerations

- **Keep `.tmp` on validation failure:** This is counter-intuitive (you'd expect cleanup) but valuable for remote debugging — the tester can zip and send the `.tmp` so the developer can inspect whether the HTTP response body was truncated by a proxy, got HTML-redirected, etc.
- **Message in DownloadProgressWindow:** Surface the validation exception message directly. The user sees something concrete ("expected ~488 MB, got 12 MB") instead of a generic error.

## 7. Technical Considerations

- **HttpClient.Timeout = InfiniteTimeSpan:** The timeout is static (a single `HttpClient` is reused across downloads). Setting it to infinite is safe because cancellation via the CTS from the progress window remains effective.
- **File size tolerance:** 1% accommodates variations in whisper.cpp model packaging if upstream re-packs the GGUF/GGML format. If upstream adds 5% of tensors, the tolerance will correctly flag it.
- **Model variants for "small":** `ggml-small.bin` is the standard target. If the URL format changes, adjust `BaseUrl` + file name; size check adjusts via the dictionary.

## 8. Success Metrics

- Zero timeout-related download failures on tester's home connection
- Corrupt / truncated downloads caught before Whisper.net crashes on load
- Developer can receive and inspect a failed `.tmp` from the tester for diagnosis

## 9. Open Questions

1. **`.tmp` disk usage on repeat failures** — If the user retries 5 times and each fails validation, we accumulate 5 `.tmp` files (different sizes?). Today each run starts by deleting any existing `.tmp`, so only one is ever kept. Confirm this.
2. **`ExpectedModelSizes` values correct?** — The declared sizes (511 MB, 1.5 GB, 3 GB) match current HuggingFace ggml-small / medium / large. If whisper.cpp ships new quantization variants, sizes must be updated. Flag for re-check before cutting release.
3. **Progress window behavior on validation error** — Should the window close and show a separate error dialog, or stay open with an inline error message + Retry button? Simpler: close + tray balloon.
