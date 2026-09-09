# HSBC SG iOS Demo

[English](README.md) | [简体中文](README.zh-CN.md)

A native SwiftUI and Swift Charts demo for portfolio analysis, account management, and comparison across accounts. Requires iOS 17 or later and has no third-party runtime dependencies.

## Download the iPhone app

**[Download HSBC-SG.ipa](https://github.com/targetkiller/HSBCSGWealthDemo/releases/latest/download/HSBC-SG.ipa)** · **[All releases](https://github.com/targetkiller/HSBCSGWealthDemo/releases)**

The download is an unsigned device IPA for iOS 17 or later. You must sign it yourself before installing it on an iPhone.

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
4. **Upload or scan a statement:** Upload / Take a photo / Cancel. Extract holdings locally from CSV, PDF, or images. On a simulator without a camera, use the photo library or a sample statement. Review and edit holdings in Extracted outcome, then tap Proceed to save once. Cancelling does not create an account.
5. **Return to analysis:** New holdings are included in the current selection, and analysis and totals refresh. View my global holdings opens Global Investment View with all accounts included.
6. **Global Investment View / GIV - L3:** Filter accounts across banks and markets from the account selector. Markets provides double-ring asset and region charts with expandable holdings. Performance supports market filters, the past month or year, custom dates, TWRR / MWRR, an interactive return chart, and S&P 500 / HSBC reference portfolio / HSI benchmarks. Analysis provides a currency semicircle chart, region map, sector treemap, analysis cards, and selectable stress scenarios.
7. **Your holdings:** Displays the design's allocation bar and asset-class list. Expand holding details or switch to Allocation analysis / Risk analysis, double-ring charts, and stress scenarios.
8. **Products and assistant bar:** Follows the design's layout. Product journeys are previews; the assistant provides local portfolio summaries, allocation responses, and guidance on adding holdings.
9. **Supporting features in the menu:** Account management, account comparison, and settings remain available as supporting Wealth features.

Suggested walkthrough: Wealth → Generate AI analysis → Add other holdings to analyse → Upload or scan a statement → Try a sample statement → edit a holding → Proceed → refreshed analysis → View my global holdings.

## Demo data and calculation assumptions

- Includes **8 prelinked demo accounts and 40 holdings**. Singapore: HSBC Current Account, (068) Equity Investment Account, (085) Unit Trust Investment Account, and DBS Account. Hong Kong: HSBC Current Account, HSBC One Investment Services, HSBC One FundMax Account, and Standard Chartered Account. The account selector displays account numbers and bank marks and supports global, regional, and cross-region selection.
- A one-time migration upgrades the previous three default accounts, adding demo accounts and classifications while preserving IDs, user edits, and user-created accounts. Subsequent deletions are not automatically restored, and an intentionally empty portfolio stays empty.
- Accounts and exchange rates are local demo data. There are no bank APIs, market-data APIs, real financial transactions, or remote document uploads.
- Market value = quantity × current unit price. Cost = quantity × average unit cost. Unrealised gain/loss = market value − cost. Values are converted into the reporting currency using fixed demo exchange rates.
- The overview return rate is unrealised gain/loss divided by cost; zero cost displays N/A. GIV Performance uses deterministic illustrative history anchored to **2026-09-09**, updated for the selected holdings, market, and dates. These are not actual historical returns. Benchmark series are independent of account selection. No external cash flows are modelled, so the displayed period TWRR and MWRR are equal.
- GIV region and sector charts use each holding's classification fields. When imported data has no classification, the region falls back to the account's market and the sector falls back to an asset-class-based label. Funds and structured products use a primary classification, without look-through analysis. Currency exposure is grouped by each holding's quotation currency.
- Risk plots use fixed illustrative scores by asset class. Stress tests apply simple shocks to current holdings, such as a weaker US dollar, falling equity markets, or a decline in Hong Kong holdings. AI analysis uses local templates and does not call a language model.
- The Wealth statement flow accepts files up to **10 MB**, PDFs up to **5 pages**, images up to **40 megapixels**, and up to **1,000 holdings**. CSV requires a strict seven-column format. PDFs use text extraction first, with local Vision OCR when needed; images use local Vision OCR. Unrecognised files are not silently replaced with sample holdings.
- Document parsing supports clearly labelled share quantities and recognisable tables. Complex broker formats require manual review. Missing quantities, prices, or average costs must be completed before confirmation. Unreliable extraction shows an error so the user can retry. Review currencies and region assumptions as well. This is not a universal brokerage statement parser.
- Try a sample statement includes the design's eight Hong Kong stock holdings with illustrative prices and costs. The older CSV import screen in the menu retains its 1 MB limit; use the Wealth entry point for the main demo.
- Data is stored in the app's sandbox using UserDefaults. A production implementation would need secure storage, account authentication, authorisation services, real data adapters, and appropriate compliance review.

Sample import file: [`Samples/statement.csv`](Samples/statement.csv). Supported `category` values: `Stocks`, `Unit trusts`, `Bonds`, `Cash and FX`, `Structured products`, `Insurance`, and `Options`.

## Tests

```bash
swift test
```

Core logic can be tested independently on macOS 14 or later, without a simulator. Nine core tests have passed, covering valuation and allocation across currencies, account and holding CRUD, CSV validation, currency suffixes, prelinked accounts, compatibility with older data, migration that preserves user edits, and persistence after deletion or clearing a portfolio.

`WealthHubUITests` covers top navigation, account selection and comparison, sample statement import and editing, returning to analysis, repeated inclusion of HSBC accounts, prelinked DBS and Standard Chartered accounts, and the GIV - L3 flow:

```bash
xcodebuild -project WealthHub.xcodeproj -scheme WealthHub \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Verification on **2026-09-09**, using an **iPhone 17 Pro / iOS 26.1 simulator**: all **9 core tests and 7 UI tests passed**. UI tests use isolated UserDefaults data and do not change the normal demo accounts. Coverage includes tapping Confirm near both corners, preserving its disabled state, tapping Proceed and Cancel away from their titles, adding and editing holdings, duplicate prevention, account selection and comparison, navigation, and Global Investment View. The Confirm corner-tap regression was reproduced before the fix and passes with the updated button.

Local verification results are stored in `build/GIVRevision.xcresult`, `build/GIVVerified.xcresult`, and the final GIV run, `build/GIVFinal.xcresult`. These generated result bundles are excluded from the repository. Committed previews are in [`Screenshots/`](Screenshots/), including `wealth.png`, `add-portfolio.png`, `accounts-sg.png`, `accounts-hk.png`, and `giv-*.png`.

## Project structure

Swift source files are in `WealthHub/`:

- `Models.swift`: Accounts, holdings, asset classes, currencies, and demo data.
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
