# App Store metadata draft

[TestFlight submission details](TESTFLIGHT_METADATA.md) · [Privacy policy](PRIVACY.md) · [README](../README.md)

Prepared for App Store Connect app **6810225249**, using the current implementation. The current product is a demo and should use **TestFlight** for its beta distribution. Apple's App Review Guideline 2.2 directs demos and beta versions to TestFlight; filling the App Store version page does not make this prototype ready for a public App Store release. Use the separate TestFlight metadata when preparing beta testing. [Apple's beta-testing guideline](https://developer.apple.com/app-store/review/guidelines/#beta-testing)

The text below describes the implemented demo accurately. The publishing team must resolve the outstanding identity and contact fields before using it for a submission.

## Suggested fields and limits

Counts include spaces and punctuation. The proposed copy uses ASCII, so character and UTF-8 byte counts are identical. Counts for multiline fields include line breaks, excluding the Markdown code fences and their surrounding newlines.

| Field | Suggested value | Count / limit |
| --- | --- | --- |
| App name | `HSBC SG Wealth Demo` | 19 / 30 characters; subject to availability and publishing rights |
| Primary language | English | Select the appropriate English localization in App Store Connect |
| Subtitle | `Explore sample portfolios` | 25 / 30 characters |
| Promotional text | See below | 149 / 170 characters |
| Description | See below | 1,447 / 4,000 characters |
| Keywords | See below | 82 / 100 bytes; also 82 characters |
| Primary category | Finance | Suggested based on the implemented portfolio features |
| App Review notes | See below | 1,517 characters |
| Sign-in required | No | The current demo opens without an account or password |
| Version / build | Match the selected uploaded build | Do not substitute metadata for the actual build's version |

Apple defines keywords in **bytes**, rather than characters. The limits above follow Apple's [platform version fields](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/) and [app information fields](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/).

## Promotional text

```text
Explore sample portfolios, compare accounts, and review allocation, illustrative performance, and risk scenarios in a local investment analysis demo.
```

## Subtitle

```text
Explore sample portfolios
```

## Keywords

```text
portfolio,holdings,allocation,analysis,investment,currency,risk,comparison,finance
```

## Description

```text
Explore a local portfolio analysis prototype with sample investment accounts.

HSBC SG Wealth Demo demonstrates how holdings across multiple accounts can be reviewed in one place. Start with sample accounts for Singapore and Hong Kong, compare allocations, and explore how different holdings affect portfolio totals.

PORTFOLIO EXPLORATION
- Review market value, invested amount, and unrealised gains or losses.
- Select accounts, compare portfolios, and switch reporting currencies.
- Explore asset, currency, region, and sector allocations.
- View illustrative performance charts and stress scenarios.
- Generate local explanations based on selected holdings.

STATEMENT WORKFLOW
- Try the built-in sample statement without using personal documents.
- Import supported CSV, PDF, or image files for on-device extraction.
- Review and edit extracted holdings before adding them to your local portfolio.

ABOUT THIS DEMO
All starting accounts and bank connection flows use sample data. Exchange rates are fixed. Performance charts do not represent actual historical returns, and risk scenarios use illustrative assumptions. Portfolio explanations run on the device without a remote AI service. The app does not connect to banks, access banking credentials, execute trades, or provide banking services.

No login, subscription, or purchase is required. Holdings are saved locally during the current app session; fully closing and reopening the app restores the initial demo accounts. Camera and photo access are optional for statement import.
```

## App Review information

Set **Sign-in required** to **No**. Leave username and password empty. Enter the following in Notes:

```text
This build is a portfolio analysis demonstration with local sample data. It does not provide banking services, connect to real bank accounts, request bank credentials, or execute transactions. Home, Pay, Cards, and product journeys are interface previews. Wealth contains the implemented portfolio flows.

Sign-in required: No. No username, password, subscription, purchase, or external hardware is needed to use the sample flows.

Suggested review steps:
1. Launch the app. It opens on Wealth with three HSBC accounts: Singapore Current Account, Singapore Equity Investment Account, and Hong Kong HSBC One Investment Services. The remaining HSBC Unit Trust and FundMax accounts, DBS, and Standard Chartered can be added through the portfolio flow. Fully close and relaunch to reset the demo and repeat first-time linking or import.
2. Tap Generate AI analysis to view locally generated portfolio explanations.
3. Open the account selector, select Singapore or Hong Kong sample accounts, and tap Confirm.
4. Open Add other holdings to analyse, then Upload or scan a statement, then Try a sample statement. Review the extracted holdings and tap Proceed. This route requires no personal documents or camera access.
5. Open View my global holdings. Explore Markets, Performance, and Analysis, including allocation views and stress scenarios.
6. Open the menu to compare accounts or open Settings. The privacy policy is available in Settings. Restore demo data resets local portfolios to the sample accounts.

CSV, PDF, and image extraction runs on the device. Camera and photo access are optional and are requested only for the corresponding import actions. Generated explanations use local demo logic. Exchange rates are fixed; performance charts and stress scenarios are illustrative, not live market data or actual historical returns.
```

The notes explain the current implementation; they do not claim a bank relationship or establish permission to publish the app's branding.

## URLs

| Field | Prepared URL | Status |
| --- | --- | --- |
| Privacy policy URL | [Repository privacy policy](https://github.com/targetkiller/HSBCSGWealthDemo/blob/main/docs/PRIVACY.md) | Describes the current local processing and storage; review it against the uploaded build |
| Support URL | [Repository issue tracker](https://github.com/targetkiller/HSBCSGWealthDemo/issues) | Existing feedback route; add actual support contact information to an accessible support page before treating this as ready for App Store submission |
| Marketing URL | [Project README](https://github.com/targetkiller/HSBCSGWealthDemo) | Optional project information page |

Apple requires the Support URL to reach actual contact information. A GitHub issue tracker alone should not be represented as a completed support page when it does not provide that information. Use a monitored address supplied by the publisher. [Support URL requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)

## Fields the publisher must provide or confirm

| Field | Required information |
| --- | --- |
| Copyright | Year and actual rights owner's legal name, such as `2026 [RIGHTS OWNER]`; replace the placeholder and confirm the correct year. App Store Connect adds the copyright symbol |
| Review contact | Real first name, last name, monitored email address, and phone number |
| Support contact | A real contact route to publish on the support page; do not infer it from a GitHub handle |
| App identity | Confirm the name, icon, and other branding the publishing team is entitled to distribute; the draft does not assert HSBC authorization |
| Bundle ID | The identifier registered to the publishing team, exactly matching the uploaded build |
| Build | Select the intended processed build in App Store Connect |
| Screenshots | Screenshots from that build, accurately showing the current interface |
| Privacy and age-rating answers | Confirm against the current build and answer every required question shown in App Store Connect |

The current code processes statements locally, stores confirmed holdings on the device, and uses local analysis logic. It has no app-operated tracking, bank API connection, remote AI service, or live market-data service. Keep privacy answers aligned with the [privacy policy](PRIVACY.md), and reassess them if the implementation changes.

This file is a draft artifact. No App Store record was changed and no review or release was submitted by creating it. Field limits were checked against Apple's documentation on **September 9, 2026**.
