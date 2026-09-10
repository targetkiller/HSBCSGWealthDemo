# Other demo configuration

[账户与组合编辑指南](../README.md) · [Project README](../../README.md)

日常账户、持仓和组合价值统一在 **[../Portfolios.csv](../Portfolios.csv)** 编辑。本文件夹只放汇率、银行选项、分析参数、场景、产品文案和兼容规则。以下为配置维护人员的字段说明。

Daily account, holding, and portfolio-value changes belong in **[Portfolios.csv](../Portfolios.csv)**. This folder contains the remaining demonstration settings and their technical reference.

## Tables

| File | Purpose and key fields |
| --- | --- |
| [currencies.csv](currencies.csv) | Currency code in `id`; `cnyRate` is the value of one unit in CNY. `symbol` is the display symbol. `wealthRegion` assigns a currency to the Wealth summary's illustrative region. GIV uses the holding's explicit region, falling back to its account market. |
| [settings.csv](settings.csv) | `id,value` pairs for default currency, account, bank, market, and Wealth scenario, plus imported portfolio labels and reference assumptions. Default selections refer to configured IDs. |
| [banks.csv](banks.csv) | Bank names and availability. `portfolioEnabled` controls the Add a portfolio chooser; `accountEnabled` controls the menu's Add account flow. |
| [markets.csv](markets.csv) | `name` is stored on the account, `shortName` labels compact filters, and `currency` selects the default reporting currency of a new account. |
| [legacy_accounts.csv](legacy_accounts.csv) | Compatibility rules for older saved demo accounts. `id` matches an account UUID; `previousName` and `signatureSymbols` identify its earlier form. Rules may remain after their account is removed from `Portfolios.csv`. Preserve these rules when changing display names. |
| [asset_profiles.csv](asset_profiles.csv) | Asset-class `id`, illustrative `riskScore` and `liquidityScore`, `riskLabel`, and fallback `defaultSector`. All supported asset classes must be present. |
| [regions.csv](regions.csv) | GIV region labels, matching `aliases`, and normalized map coordinates `mapX` and `mapY`. |
| [performance.csv](performance.csv) | One `default` row defines fixed `asOfDate`, initial dates and filters, the SG/HK reference accounts, and bounded illustrative-history parameters. See [Performance and reference portfolios](#performance-and-reference-portfolios). |
| [performance_banks.csv](performance_banks.csv) | Per-bank illustrative YTD targets, wave amplitude, frequencies, and drawdown/recovery settings. `institution` matches an account's bank; `*` is the fallback for other banks. Each account has its own rises and falls rather than copying the index curve. |
| [benchmarks.csv](benchmarks.csv) | Benchmark names, `colorHex`, chart `symbol`, and `defaultSelected`. Market indexes use independent curve parameters; the HSBC reference row leaves those parameters blank because its curve comes from the current mapped account. |
| [analytics.csv](analytics.csv) | One `default` row defines `currencyIllustrationShock`, `concentrationThreshold`, and `defaultScenarioID`, referring to `scenarios.id`. |
| [scenarios.csv](scenarios.csv) | GIV stress scenarios. `currencies`, `assetClasses`, and `regions` select exposure; `shock` defines signed change. `skipMatchingReportingCurrency` controls the reporting-currency exception. |
| [wealth_scenarios.csv](wealth_scenarios.csv) | Wealth stress-test tabs: `name`, `description`, positive `shockRate`, and `referenceDecline` in percentage points. |
| [wealth_scenario_targets.csv](wealth_scenario_targets.csv) | Exposure rules for each `scenarioID`. A row's nonblank `category` and `currency` must both match; any matching row includes a holding once. |
| [wealth_regions.csv](wealth_regions.csv) | Wealth chart groups and colors. `name` matches `currencies.wealthRegion`; `color` is a decimal RGB integer. |
| [products.csv](products.csv) | Product preview cards: `category`, `title`, and SF Symbol `symbol`. A literal `\n` in `title` creates a display line break. |
| [assistant_suggestions.csv](assistant_suggestions.csv) | Suggested prompts in display order: `id,prompt`. |
| [assistant_rules.csv](assistant_rules.csv) | Local answer rules: `keywords` and `response`. Preserve supported response placeholders. The final row has empty keywords and serves as the fallback response. |

Within each table, keep IDs unique. Row order determines chooser, card, rule, or scenario order where applicable. `defaultAccountID` is a valid UUID used to select a default account in `Portfolios.csv`; if that account has been removed, selection falls back to the first configured account. `defaultBankID`, `defaultMarketID`, and `defaultWealthScenarioID` refer to existing rows in their respective tables. The default bank must be enabled in both bank choosers.

## Portfolios.csv structural reference

`portfolioID` is a readable group key, shared by every holding in that group. Group metadata is supplied on one row; subsequent rows may leave it blank. Repeated nonempty metadata must agree. Rows are grouped by key rather than by adjacency, so sorting cannot attach holdings to the preceding account accidentally.

| Field | Meaning |
| --- | --- |
| `portfolioID` | Stable group key, such as `hsbc-sg-current`; required on every row. |
| `purpose` | `account` for defaults, `template` for new-account metadata, or `holdings` for standalone samples. |
| `name`, `bank`, `market`, `currency` | Account or template display metadata. `currency` is its reporting currency. |
| `portfolioValue` | Optional nonnegative target total, in account currency. Blank means calculate from holdings. |
| `accountNumber`, `note`, `colorIndex` | Optional account number, descriptive note, and account color selection. Preserve existing color values unless a visual change is intended. |
| `accountID` | Stable UUID for default accounts and persisted references. A blank new account ID is generated from `portfolioID`. Template accounts receive fresh UUIDs when instantiated. |
| `holdingID` | Stable UUID for a configured holding. If blank, generated from `portfolioID`, `symbol`, `holdingCurrency`, and `category`. Duplicate lots with the same combination require distinct explicit UUIDs. Template/sample copies receive fresh UUIDs when instantiated. |
| `holdingName`, `symbol`, `category`, `holdingCurrency` | Security identity, asset class, and quotation currency. |
| `quantity`, `price`, `averageCost` | Position quantity, current unit price, and average unit cost. Quantity may be blank when `holdingValue` is set. |
| `holdingValue` | Optional nonnegative value in holding currency; derives quantity as value ÷ price. A positive target requires positive price; zero may also use zero price. |
| `region`, `sector` | Holding classifications used in analysis. |
| `holdingsFrom` | Reuses holdings from another `portfolioID`, such as `linked-account` using `hsbc-sg-unit-trust`. Includes source `holdingValue` adjustments but excludes the source account's `portfolioValue` scaling. Each destination template may set its own total target. |

The supplied account/template/holding groups include:

- Eight `account` groups with the existing 40 default holdings.
- `bank-connection` and `linked-account` templates for the two account-connection flows. The former has its own holdings; the latter uses `holdingsFrom`.
- `statement-review` and `statement-import` templates for imported account metadata. Actual document imports provide their own holdings.
- `statement-preview` (8 holdings), `csv-import` (2), and `csv-file-export` (4) standalone sample groups.

Do not rename flow keys such as `bank-connection`, `statement-review`, or `csv-import` without updating their consumers. Template names may contain `{bank}` and statement-review notes may contain `{source}`. Existing configured UUIDs remain stable for persistence and migration. Preserve IDs when changing names or values; if newly generated IDs need to survive a later identifier change, first place their generated values explicitly in the CSV.

For a new default account, copy an existing group, assign a distinct `portfolioID`, and clear copied `accountID` and `holdingID` values to generate new IDs. For a new holding, add a row with the target `portfolioID`, fill its holding fields, and leave account metadata and `holdingID` blank. Validate before rebuilding. When removing an account, update `defaultAccountID` if a particular replacement should be selected; otherwise the first configured account is used. Old compatibility rules may remain. Any `holdingsFrom` references must still point to an existing group.

## Values and calculations

Supported currencies: `SGD`, `USD`, `HKD`, `CNY`. Supported categories: `Stocks`, `Unit trusts`, `Bonds`, `Cash and FX`, `Structured products`, `Insurance`, `Options`. Adding a new enum code also requires a model change. Boolean fields accept `true` or `false`.

Market value = quantity × price; invested cost = quantity × averageCost; unrealised gain/loss = value − cost. Currency conversion uses `currencies.cnyRate`. A holding-value override first derives its quantity; a portfolio-value override then scales all quantities to reach the target in account currency. For templates used by the menu's Add account flow, market selection sets the final account currency before the target is applied, such as HKD for Hong Kong. A template using `holdingsFrom` starts from the source positions after holding overrides, before source-account target scaling. Prices and average costs stay fixed. Blank targets keep normal calculations, zero targets produce zero quantities, and positive portfolio targets require a nonzero starting value. No extra balancing holding is created. These overrides configure demo positions and never rewrite real import data or saved user edits automatically.

All numeric values must be finite. Use plain decimals without currency signs, grouping commas, or `%`. Note the different percentage units:

- `scenarios.shock=-0.10` means a 10% decline.
- `analytics.currencyIllustrationShock` also uses a signed fraction, default `-0.10`, accepted range `-1...1`.
- `wealth_scenarios.shockRate=0.10` is a positive fraction used to calculate the decline amount.
- `referenceDecline=6` and `ytdReturnPercent=9.6` mean 6% and 9.6%.

Update scenario text when changing its numeric shock. `performance.maxYears` must be greater than 0 and at most 100. After currency conversion, the combined value and cost of configured holdings must each remain below `100,000,000,000,000` for every supported reporting currency; validation checks this limit to protect chart calculations.

## Performance and reference portfolios

The Performance screen starts on **YTD**, from January 1 through the fixed `asOfDate`. Past 1 month, Past 1 year, and Customized remain available. The existing default account selection is unchanged: use Global view or the global-holdings entry to see the All global accounts scenario.

The supplied illustrative YTD targets are:

| Series / bank | YTD return |
| --- | --- |
| S&P 500 | 9.60% |
| HSBC accounts, including the SG/HK reference sources | 11.20% |
| DBS | 3.60% |
| Standard Chartered | 3.10% |
| Other banks (`*` profile) | 3.30% |

With the supplied holdings, All global accounts has a cost-weighted YTD return of approximately **8.30%**. This value is calculated from the actual selected accounts; it is not an override. Changing holdings, portfolio values, account selection, or market filters can change the aggregate. Selecting only the Equity Investment Account gives My total return **11.20%**, exactly overlapping its reference. The corresponding HK source behaves the same way.

HSBC reference portfolio and S&P 500 are selected by default through `benchmarks.defaultSelected`. The reference uses the current account and holdings saved in the app, including local edits. It has no separate reference holdings or independently configured curve.

| `performance.csv` field | Meaning |
| --- | --- |
| `asOfDate` | Fixed end date used to calibrate the YTD targets. Must be after January 1 of that year. Dates use the Gregorian calendar and UTC for consistent period boundaries. |
| `initialPeriod`, `initialStartDate`, `initialEndDate` | Default period (`ytd`, `month`, `year`, or `custom`) and initial custom dates. |
| `referenceBenchmarkID` | Account-based legend row; currently `hsbc-reference`. Keep all six return/shape fields blank in that row of `benchmarks.csv`. |
| `defaultReferenceMarket` | Reference market for mixed or other-account selections; currently `Singapore`. |
| `sgReferencePortfolioID`, `hkReferencePortfolioID` | Source `portfolioID` values from `Portfolios.csv`: `hsbc-sg-equity` and `hsbc-hk-investment`. |
| `sampleIntervals`, `maxYears`, `minDuration` | Number of chart intervals (120), maximum modelled duration in years, and minimum index-variation scale (about one day). `maxYears` must cover the complete YTD range through `asOfDate`. |
| `seedModulus`, `primarySeedMultiplier`, `secondarySeedMultiplier`, `secondaryWeight` | Deterministic seed and wave-mixing inputs. Holdings and account market influence the account path; the same inputs reproduce the same history. |
| `primaryFrequency`, `secondaryFrequency` | Market-index cycle frequencies. Bank curves have their own frequencies. |
| `trendVariation` | Variation in the pace of the trend, from 0 to 1. It changes the journey without moving its endpoints. |
| `recoveryStrength` | Strength of the recovery following a drawdown, from 0 to 1. |
| `eventPhaseWeight` | Maximum shift in drawdown/recovery timing from the holding mix and account market, from 0 to 0.15 of the chart range. |
| `holdingTiltWeight`, `maxHoldingTiltPercent` | Small effect of current eligible holding returns on the interior of the curve, capped in percentage points. This adjustment fades to zero at the endpoints, preserving the configured YTD target. |

An explicit Singapore or Hong Kong Performance filter selects the corresponding reference market. Otherwise Singapore-only account selections use the SG reference, Hong Kong-only selections use the HK reference, and mixed or other selections use `defaultReferenceMarket`. Performance filters eligible holdings by their region; the account selector's market describes the account itself. The same holding-region filter applies to the selected portfolio and the reference, preserving exact point-for-point overlap when the source account is selected alone.

The reference follows the saved account even after its display name changes. If that account was deleted locally, the reference becomes unavailable. It is not restored from the original sample.

Each bank has independent cycles, a local drawdown and recovery, and a varying trend speed. These deliberately larger movements make the curves visually distinct; the cost-weighted global portfolio also retains visible pullbacks. Paths can cross along the way. All adjustments vanish at the start and end of the range.

| Curve field | Meaning |
| --- | --- |
| `ytdReturnPercent` | Return from January 1 through `asOfDate`, expressed as a percentage such as `11.2`. Used in both `performance_banks.csv` and ordinary benchmark rows. Valid range: -99 to 100. |
| `waveAmplitude` / `amplitude` | Bank / index oscillation strength at the YTD duration, from 0 to 10 percentage points. Other periods scale variation with the square root of their relative duration. |
| `drawdownPosition` | Approximate location of the local retreat, from 0 at the range start to 1 at the end. |
| `drawdownDepth` | Strength of the retreat at the YTD duration, from 0 to 20 percentage points. The visible peak-to-trough decline also depends on cycles and trend. |
| `drawdownWidth` | Width of the retreat as a fraction of the range, from 0.02 to 0.30. Larger values make it more gradual. |
| `recoveryPosition` | Location of the recovery, after `drawdownPosition`. Keep event positions inside the range, allowing for `eventPhaseWeight` in bank curves. |
| `institution` | Bank-profile matching key, case-insensitive. Exactly one `*` fallback profile is required. |
| Bank `primaryFrequency`, `secondaryFrequency`, `phaseOffset` | Independent cycle frequencies and phase in radians. These alter the timing of rises and falls; current holdings and the account market provide additional variation. |

For month, year, or customized ranges, the endpoint uses a constant compounded rate implied by the configured YTD return: `((1 + YTD / 100) ^ (selected days / YTD days) - 1) × 100`. The YTD range itself uses the configured value exactly. This is a repeatable presentation model, not recorded daily history. Multiple accounts are weighted by their eligible invested cost, so the global return changes naturally when account values or holdings change. Reporting currency and benchmark visibility do not alter an external benchmark's percentage series.

These settings affect only the **illustrative Performance chart**. They do not change holding prices, average costs, portfolio values, or unrealised gain/loss. TWRR and MWRR remain equal because the demo models no external cash flows. The targets describe a presentation scenario, not actual bank or index performance.

BA 日常仍只需修改 `Portfolios.csv`。YTD 是当年 1 月 1 日至 `asOfDate`；基准目标在 `benchmarks.csv` 修改，银行目标在 `performance_banks.csv` 的 `ytdReturnPercent` 修改。当前全局组合约 8.3% 来自实际账户成本加权，单选 SG 或 HK 参考源时仍与 HSBC reference 精确重叠并显示 11.2%。需要调整波动时修改波幅、回撤深度/位置/宽度和恢复位置；这些设置不改变组合价值。

## Editing and validation

Import and export UTF-8 CSV. Treat IDs, account numbers, security symbols, and list fields as text in Excel or Numbers to preserve leading zeroes. Keep dates as `YYYY-MM-DD`. Quote fields containing commas, quotes, or line breaks; escape a quote by doubling it. List fields such as `keywords`, `marketFilters`, `aliases`, and `signatureSymbols` use `|`. CSV configuration has no comment rows.

From the project root:

```bash
./scripts/sample-data.sh validate
./scripts/sample-data.sh summary
./scripts/sample-data.sh export-statement
```

Validation uses the app's loader and checks both `Portfolios.csv` and `Others/`. Summary shows default account names, reporting currencies, market values, costs, and holding counts. Export generates `build/Sample/statement.csv` from the `csv-file-export` group in `Portfolios.csv`; an optional final argument selects another output path. Regenerate the statement after changing its source rows. Do not maintain a second editable statement fixture.

Rebuild to bundle edited CSV files. Existing saved accounts remain intact. **Menu → Settings → Restore demo data** replaces local accounts and holdings with the new defaults, discarding local edits. Configuration errors show on the startup error screen instead of silently falling back to hardcoded data.

All exchange rates, risk scores, scenario shocks, and benchmark/history parameters are demo inputs, not live quotes or actual historical performance. Bank connections and assistant responses use local sample data.
