# TestFlight submission details

[English guide](TESTFLIGHT.md) | [中文步骤](TESTFLIGHT.zh-CN.md)

The copy below describes the current local demo. Fill in the account-specific fields in App Store Connect before submitting. This file does not create an App Store Connect record or submit a build.

## App record

| Field | Prepared value or action |
| --- | --- |
| Platform | iOS |
| Name | HSBC SG Wealth Demo — subject to availability and your team's permission to publish this branding |
| Primary language | English |
| Bundle ID | Select the identifier registered to your paid team; it must exactly match Xcode's Release target |
| SKU | `HSBCSG-WEALTH-DEMO-001`, or another unique internal identifier |
| Version / build | `1.0.1` / `2`; use an unused build number for every new upload |
| Category, if requested | Finance |
| Privacy policy URL | https://github.com/targetkiller/HSBCSGWealthDemo/blob/main/docs/PRIVACY.md |
| Support URL | https://github.com/targetkiller/HSBCSGWealthDemo/issues |

The installed app name remains **HSBC SG**. The public repository keeps a sample Bundle ID and no personal Team ID; use the identifier and paid team configured in your local Xcode project. Do not run `xcodegen generate` after configuring them unless you also preserve those local settings.

## Beta App Description

HSBC SG Wealth Demo is an interactive portfolio analysis prototype. Explore asset allocation, investment performance, risk scenarios, account management, and comparisons across multiple sample accounts. Import a sample statement or review holdings extracted locally from a selected statement. The app uses local demo data and does not connect to bank accounts, execute transactions, or call a remote AI service.

## What to Test

1. Open Wealth and tap Generate AI analysis.
2. Change the selected Singapore and Hong Kong accounts, including the DBS and Standard Chartered samples. Confirm that tapping the edges of Confirm also works.
3. Open Add other holdings to analyse. Try the existing HSBC account flow and the sample statement flow; review, edit, cancel, and confirm extracted holdings.
4. Open Global Investment View and explore Markets, Performance, and Analysis, including currency, region, sector exposure, and stress scenarios.
5. Use the menu to compare accounts. Check navigation, readability, and button responsiveness. Please report the device model, iOS version, and steps to reproduce any issue.

## Beta App Review notes

No app login, bank credentials, subscription, or purchase is required. The app starts on Wealth with local sample accounts. The bank connection screens add sample data only. For a complete import flow without personal documents, select Add other holdings to analyse → Upload or scan a statement → Try a sample statement → Proceed. Camera/photo access is optional. Generated analysis is local demo logic.

## Complete these fields yourself

- Feedback email: a monitored address you control.
- Beta App Review contact: your real first name, last name, email, and phone number.
- Sign-in required: **No** for the current demo.
- App access: select who on your App Store Connect team may manage this app.
- Internal testing group and testers: select the eligible members of your team.
- External testing group: create it when you are ready for Beta App Review; enable a public link only when you want to share it.

## Privacy and export answers

The current app has no app-operated data collection or tracking. It processes imported statements on the device and declares its own UserDefaults access in `PrivacyInfo.xcprivacy`. Its `Info.plist` declares no non-exempt encryption. Review these answers again if you later add analytics, a backend, remote AI, bank connections, or other SDKs. Answer any remaining App Store Connect questions for the build you are uploading.
