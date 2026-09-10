# HSBC SG iOS Demo

[English](README.md) | [简体中文](README.zh-CN.md)

A native SwiftUI and Swift Charts demo for portfolio analysis, account management, and comparison across accounts. Requires iOS 17 or later and has no third-party runtime dependencies.

## Download the iPhone app

**[Download HSBC-SG.ipa](https://github.com/targetkiller/HSBCSGWealthDemo/releases/latest/download/HSBC-SG.ipa)** · **[All releases](https://github.com/targetkiller/HSBCSGWealthDemo/releases)**

The download is an unsigned device IPA for iOS 17 or later. You must sign it yourself before installing it on an iPhone.

For distribution through Apple's TestFlight, follow the **[English submission guide](docs/TESTFLIGHT.md)** or **[中文提交指南](docs/TESTFLIGHT.zh-CN.md)**. They cover account setup, archiving, uploading, and inviting testers.

For App Store Connect screenshots and review materials, see the [native screenshot workflow](docs/APP_STORE_SCREENSHOTS.md) and [metadata draft](docs/APP_STORE_METADATA.md). The capture script exports actual iPhone and iPad screens at accepted upload dimensions.

The installed app is named **HSBC SG** and uses the supplied HSBC SG icon. The Xcode project and scheme are named `WealthHub`.

Based on the [Figma Wealth Hub design](https://www.figma.com/design/asmxuHgmIG5e4NMJHstoZh/Untitled?node-id=0-1). The app uses the design's Home / Pay / Cards / Wealth navigation at the top and opens on Wealth. The main focus is portfolio analysis, adding holdings, account selection, allocation, risk and stress scenarios, product previews, and the assistant bar. Home, Pay, Cards, and product journeys are lightweight previews.

## Run the app

Open `WealthHub.xcodeproj`, select the **WealthHub** scheme and an iPhone simulator, then click Run. Simulator builds do not require a development signing identity. For a physical device, select your development team under Signing & Capabilities.

The app has been built and run on an iPhone simulator. You can also use the included script to build, install, and launch it:

```bash
git clone https://github.com/targetkiller/HSBCSGWealthDemo.git
cd HSBCSGWealthDemo
bash scripts/run-demo.sh
```

The script uses a booted iPhone simulator, or the first available iPhone if none is running. You can pass a simulator UDID as an argument. Xcode, an iOS simulator runtime, and Python 3 are required. If XcodeGen is installed, the script regenerates the project; otherwise, it uses the committed `.xcodeproj`.

## Screenshots

| Wealth | Add holdings | Global Investment View | Performance |
| --- | --- | --- | --- |
| <img src="Screenshots/wealth.png" width="220" alt="Wealth overview"> | <img src="Screenshots/add-portfolio.png" width="220" alt="Add a portfolio"> | <img src="Screenshots/giv-markets.png" width="220" alt="Global Investment View"> | <img src="Screenshots/giv-performance.png" width="220" alt="Performance chart"> |

## Demo flows

1. **Wealth:** Starts with the HSBC Singapore equity investment account. Select one or more accounts, change the reporting currency, and view market value, returns, and account details. Amounts use a currency suffix, such as `1,234.00 SGD`.
2. **Portfolio analysis:** Generate AI analysis → loading → expanded What happened / What's next. Collapse or regenerate the analysis. Its content is calculated from the selected holdings, without fabricated live market news.
3. **Add other holdings to analyse:** Opens the Add a portfolio sheet. Include global HSBC accounts, connect another bank, or upload or scan a statement. The HSBC flow selects existing accounts without creating duplicates. Other bank connections use local sample data and a confirmation step.
4. **Upload or scan a statement:** Upload lets you choose a saved photo or a file; Take a photo uses the camera, with a photo-library fallback when a camera is unavailable. CSV, PDF and images are processed locally. FUTU / moomoo Accounts screenshots can suggest the account provider and extract the stacked market-value/quantity and price/cost rows across currencies. Extracted outcome shows an editable account and holding details before Proceed saves one new account. Cancelling does not create an account or link a brokerage.
5. **Return to analysis:** New holdings are included in the current selection, and analysis and totals refresh. View my global holdings opens Global Investment View with all accounts included.
6. **Global Investment View / GIV - L3:** Filter accounts across banks and markets from the account selector. Markets provides an allocation bar above vertical, expandable holdings rows with values, gains, and account-market tags, matching the “For Sept 14 Valentin's demo” design. Performance defaults to YTD and also supports the past month or year, custom dates, market filters, TWRR / MWRR, an interactive return chart, and S&P 500 / HSBC reference portfolio / HSI comparisons. Analysis provides a currency semicircle chart, region map, sector treemap, analysis cards, and selectable stress scenarios.
7. **Your holdings:** Displays the design's allocation bar and asset-class list. Expand holding details or switch to Allocation analysis / Risk analysis, double-ring charts, and stress scenarios.
8. **Products and assistant bar:** Follows the design's layout. Product journeys are previews; the assistant provides local portfolio summaries, allocation responses, and guidance on adding holdings.
9. **Supporting features in the menu:** Account management, account comparison, and settings remain available as supporting Wealth features.

Suggested walkthrough: Wealth → Generate AI analysis → Add other holdings to analyse → Upload or scan a statement → Try a sample statement → edit a holding → Proceed → refreshed analysis → View my global holdings.

## Demo data and calculation assumptions

BA colleagues can edit accounts, holdings, and portfolio values in one file: **[Sample/Portfolios.csv](Sample/Portfolios.csv)**. Enter an optional `holdingValue` or `portfolioValue` to set a target market value, or leave these blank to calculate values from quantities and prices. See the **[editing guide](Sample/README.md#english-quick-guide)** for examples. Exchange rates, analytics parameters, scenarios, and other settings live separately in **[Sample/Others/](Sample/Others/README.md)**. Saved local accounts remain unchanged until you explicitly restore demo data.

- Includes **8 prelinked demo accounts and 40 holdings**. Singapore: HSBC Current Account, (068) Equity Investment Account, (085) Unit Trust Investment Account, and DBS Account. Hong Kong: HSBC Current Account, HSBC One Investment Services, HSBC One FundMax Account, and Standard Chartered Account. The account selector displays account numbers and bank marks and supports global, regional, and cross-region selection.
- A one-time migration upgrades the previous three default accounts, adding demo accounts and classifications while preserving IDs, user edits, and user-created accounts. Subsequent deletions are not automatically restored, and an intentionally empty portfolio stays empty.
- Accounts and exchange rates are local demo data. There are no bank APIs, market-data APIs, real financial transactions, or remote document uploads.
- Market value = quantity × current unit price. Cost = quantity × average unit cost. Unrealised gain/loss = market value − cost. Values are converted into the reporting currency using fixed demo exchange rates.
- The overview return rate is unrealised gain/loss divided by cost; zero cost displays N/A. GIV Performance uses deterministic illustrative history anchored to the configured demo date, with distinct drawdowns and recoveries for each bank and benchmark. Default sample YTD returns are **S&P 500 9.6%, HSBC reference 11.2%, and all global accounts approximately 8.3%**; these are fictional demo values, not actual historical returns. The reference is selected by default and uses the Equity Investment Account for Singapore or HSBC One Investment Services for Hong Kong. Selecting only that source account makes its return curve overlap the reference. S&P 500 and HSI are independent of account selection. No external cash flows are modelled, so the displayed period TWRR and MWRR are equal. BA-editable return and volatility settings are documented in [Sample/Others](Sample/Others/README.md).
- GIV region and sector charts use each holding's classification fields. When imported data has no classification, the region falls back to the account's market and the sector falls back to an asset-class-based label. Funds and structured products use a primary classification, without look-through analysis. Currency exposure is grouped by each holding's quotation currency.
- Risk plots use fixed illustrative scores by asset class. Stress tests apply simple shocks to current holdings, such as a weaker US dollar, falling equity markets, or a decline in Hong Kong holdings. AI analysis uses local templates and does not call a language model.
- The Wealth statement flow accepts files up to **10 MB**, PDFs up to **5 pages**, images up to **40 megapixels**, and up to **1,000 holdings**. CSV requires a strict seven-column format. PDFs use text extraction first, with local Vision OCR when needed; images use local Vision OCR. Unrecognised files are not silently replaced with sample holdings.
- Document parsing supports clearly labelled share quantities, recognisable tables, and the FUTU / moomoo Accounts screenshot layout with SG/US/HK/CN currency sections. It distinguishes quantity from market value and average cost from daily P/L. Only visible holdings are imported; account balances and buying power are not cash positions. Truncated names and incomplete rows are flagged for review. Provider detection is a suggestion, with editable account name, institution, market and reporting currency; cropped account numbers are not guessed. Each holding retains its own currency. Other brokerage layouts may require manual correction or CSV import.
- Try a sample statement includes the design's eight Hong Kong stock holdings with illustrative prices and costs. The older CSV import screen in the menu retains its 1 MB limit; use the Wealth entry point for the main demo.
- Data is stored in the app's sandbox using UserDefaults. A production implementation would need secure storage, account authentication, authorisation services, real data adapters, and appropriate compliance review.

Run `./scripts/sample-data.sh validate` to check the configuration, then `./scripts/sample-data.sh summary` to review account values and holding counts before rebuilding. `./scripts/sample-data.sh export-statement` generates `build/Sample/statement.csv` for a manual import test; an optional final argument selects another output path. Its source is the `csv-file-export` group in [`Sample/Portfolios.csv`](Sample/Portfolios.csv), while the in-app two-position CSV sample uses `csv-import`. Supported `category` values: `Stocks`, `Unit trusts`, `Bonds`, `Cash and FX`, `Structured products`, `Insurance`, and `Options`.

## Tests

```bash
swift test
```

Core logic can be tested independently on macOS 14 or later, without a simulator. Coverage includes valuation and allocation across currencies, account and holding CRUD, CSV validation, prelinked accounts, data migration and persistence, YTD return targets, distinct performance paths, and reference-account equivalence.

`WealthHubUITests` covers top navigation, account selection and comparison, sample statement import and editing, returning to analysis, repeated inclusion of HSBC accounts, prelinked DBS and Standard Chartered accounts, and the GIV - L3 flow:

```bash
xcodebuild -project WealthHub.xcodeproj -scheme WealthHub \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Verification on **2026-09-09**, using an **iPhone 17 Pro / iOS 26.1 simulator**: all **9 core tests and 8 UI tests passed**. UI tests use isolated UserDefaults data and do not change the normal demo accounts. Coverage includes tapping Confirm near both corners, preserving its disabled state, tapping Proceed and Cancel away from their titles, adding and editing holdings, duplicate prevention, account selection and comparison, navigation, Global Investment View, and the in-app privacy policy. The Confirm corner-tap regression was reproduced before the fix and passes with the updated button.

The latest iPhone result bundle is `build/TestFlight/iPhone.xcresult`. Earlier GIV verification results remain in `build/GIVRevision.xcresult`, `build/GIVVerified.xcresult`, and `build/GIVFinal.xcresult`. These generated result bundles are excluded from the repository. Committed previews are in [`Screenshots/`](Screenshots/), including `wealth.png`, `add-portfolio.png`, `accounts-sg.png`, `accounts-hk.png`, and `giv-*.png`.

TestFlight preparation also passed an unsigned Release device-archive check for **1.0.1 (2)** using Xcode 26.2 / iOS SDK 26.2. The archive contains the privacy manifest, export-compliance declaration, and four iPad orientations. The privacy-policy flow also passed on an iPad Pro 11-inch (M5) / iOS 26.1 simulator in landscape; its result is `build/TestFlight/iPadVerified.xcresult`. Signing, App Store Connect upload validation, and Beta App Review still require the publishing team's account and Apple's services.

## Project structure

Swift source files are in `WealthHub/`:

- `Models.swift`: Accounts, holdings, asset classes, and currencies.
- `SampleData.swift`: CSV configuration loading, validation, and demo account construction from `Sample/Portfolios.csv` and `Sample/Others/`.
- `PortfolioStore.swift`: Aggregation, observable state, and local persistence.
- `StatementParser.swift`: Independently testable CSV parsing.
- `WealthView.swift`: Wealth overview, analysis cards, holdings, and stress scenarios.
- `BankingNavigation.swift`: Home / Pay / Cards / Wealth navigation and menu.
- `WealthSupportingViews.swift`: Product previews and the assistant bar.
- `AddPortfolioSheet.swift`: Three ways to add holdings, editable extraction results, and completion callbacks.
- `StatementExtractionService.swift`: Local PDF, image, and CSV extraction.
- `InvestmentViews.swift`: Global Investment View and risk components.
- `GIVPortfolioData.swift`: Aggregation by account, holding, asset class, currency, region, and sector.
- `GIVPerformanceView.swift`: Illustrative return series, benchmark selection, date filters, and chart selection.
- `GIVAnalysisView.swift`: Currency, region, and sector charts plus scenario analysis.
- `AccountsView.swift`: Account selection, management, and editing.
- `AddAccountFlow.swift`: Demo connections, file import, and preview.
- `CompareView.swift`: Account comparison and settings.
- `Theme.swift`: Colours, shared components, and charts.

At the repository root, `project.yml` is the XcodeGen configuration and `Package.swift` provides the standalone core test target.
