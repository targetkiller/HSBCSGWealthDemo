# Native screenshots for App Store Connect and review

The dedicated XCTest flow captures eight real app pages on iPhone 17 Pro Max and iPad Pro 13-inch (M5), using the newest installed simulator runtime for each model. It uses the app's isolated UI-test sample storage, portrait orientation, and a 9:41 status bar. Product UI and signing settings are not changed.

## Run

Requires Xcode, Node.js, and the two simulator models installed through Xcode.

```bash
./scripts/capture-app-store-screenshots.sh all
```

Use `iphone` or `ipad` instead of `all` to recapture one device. Only `testCaptureAppStoreScreenshots` runs. The test skips during ordinary test runs; the script opts in through `TEST_RUNNER_APP_STORE_SCREENSHOTS=1`.

Each run creates a new directory under `build/AppStoreScreenshots/` with:

- `README.md`: screenshot index with native dimensions and alpha-channel results.
- `manifest.json`: device, runtime, app version/build, file paths, and SHA-256 hashes.
- `iphone/PNG/` and `ipad/PNG/`: named PNG copies of the original XCTest attachments.
- Per-device XCTest result bundles, exported attachments, and logs for verification.

## Pages

1. Wealth overview
2. Global Investment View — Markets
3. Global Investment View — Performance
4. Global Investment View — Analysis
5. Account selection
6. Add a portfolio
7. Review extracted sample holdings
8. Account comparison

Screenshots use `XCUIScreen.main.screenshot()` to avoid application-frame cropping after device rotation. The exporter copies attachment bytes unchanged; it does not resize, crop, composite, recolor, or remove alpha. If alpha is detected, retain the originals and review the required conversion separately before an App Store screenshot upload.

Apple's current [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) accept iPhone 6.9-inch portrait images at 1260 × 2736, 1290 × 2796, or 1320 × 2868, and iPad 13-inch portrait images at 2064 × 2752 or 2048 × 2732. App Store screenshots must not contain alpha or transparency. The generated manifest checks these dimensions without changing the images.

App Store product screenshots and TestFlight test information are separate fields. These native captures may also be used as supporting material when responding to review questions; they do not replace required beta descriptions, contact details, or review notes.
