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
| [performance.csv](performance.csv) | One `default` row defines fixed `asOfDate`, initial dates and filters, the anchor benchmark, the SG/HK reference accounts, and bounded illustrative-history parameters. See [Performance and reference portfolios](#performance-and-reference-portfolios). |
| [performance_banks.csv](performance_banks.csv) | Per-bank illustrative return spreads, wave amplitude, frequencies, and phase. `institution` matches an account's bank; `*` is the fallback for other banks. Each account has its own rises and falls rather than copying the index curve. |
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
- `referenceDecline=6` and `annualReturnPercent=8.7` mean 6% and 8.7%.

Update scenario text when changing its numeric shock. `performance.maxYears` must be greater than 0 and at most 100. After currency conversion, the combined value and cost of configured holdings must each remain below `100,000,000,000,000` for every supported reporting currency; validation checks this limit to protect chart calculations.

## Performance and reference portfolios

HSBC reference portfolio is selected by default through `benchmarks.defaultSelected=true`. It uses the current account and holdings saved in the app, including local edits. It does not keep a separate reference dataset.

| `performance.csv` field | Meaning |
| --- | --- |
| `anchorBenchmarkID` | Market-index row in `benchmarks.csv` providing the return scale for account-period targets; currently `sp500` (S&P 500). Account histories do not copy its wave shape. |
| `referenceBenchmarkID` | Account-based legend row; currently `hsbc-reference`. Keep its `annualReturnPercent`, `sqrtReturnPercent`, and `amplitude` cells blank in `benchmarks.csv`. |
| `defaultReferenceMarket` | Reference market when the selected accounts span markets or have no SG/HK match; currently `Singapore`. |
| `sgReferencePortfolioID` | `portfolioID` in `Portfolios.csv` for the SG reference; currently `hsbc-sg-equity`, the Equity Investment Account. |
| `hkReferencePortfolioID` | `portfolioID` in `Portfolios.csv` for the HK reference; currently `hsbc-hk-investment`, HSBC One Investment Services. |
| `holdingTiltWeight` | Small influence of the account's eligible holdings' current return on illustrative annual drift; currently `0.005`. |
| `maxHoldingTiltPercent` | Absolute cap on that influence, in percentage points; currently `0.05`. |
| `sampleIntervals`, `maxYears`, `minDuration` | Number of intervals, maximum modelled duration in years, and minimum duration used to scale index-curve oscillation (about one day by default, so short custom periods retain appropriately smaller waves). |
| `seedModulus`, `primarySeedMultiplier`, `secondarySeedMultiplier`, `secondaryWeight` | Deterministic seed and wave-mixing inputs. An account's holding mix and market contribute to its phase; the same inputs reproduce the same curve. |
| `primaryFrequency`, `secondaryFrequency` | Market-index wave frequencies. Account histories use the frequencies in `performance_banks.csv` instead. |

An explicit **Singapore** or **Hong Kong** filter in Performance selects the corresponding reference market. Otherwise a selection containing only Singapore accounts uses the SG reference, and a selection containing only Hong Kong accounts uses the HK reference; mixed or other selections use `defaultReferenceMarket`. The account selector's market describes the account's market, while Performance filters eligible holdings by their region. The same holding-region filter applies to the selected portfolio and reference. Selecting only the mapped account therefore makes My total return and HSBC reference portfolio overlap at every chart point. The reference follows the current saved account even if its display name changes. If that account was deleted locally, the reference is unavailable rather than being restored from the original sample.

Each account history has an independent wave shape while keeping its period-end target on a similar scale to S&P 500. The bank settings control both the target and the timing of rises and falls:

| `performance_banks.csv` field | Meaning |
| --- | --- |
| `id` | Unique profile key. |
| `institution` | Account bank name, matched without case sensitivity. Exactly one `*` fallback profile is required. |
| `annualSpreadPercent` | Annual target offset in percentage points, multiplied by the duration in years. |
| `sqrtSpreadPercent` | Additional target offset multiplied by the square root of the duration in years. This keeps short-period differences visible without requiring a large annual offset. |
| `waveAmplitude` | Strength of the account's independent fluctuations, scaled by the square root of the actual duration. Variation fades to zero at the range endpoints. |
| `primaryFrequency`, `secondaryFrequency` | Frequencies of the account's two wave components. Different values change how often rises and pullbacks occur over the selected range. |
| `phaseOffset` | Phase in radians, shifting where rises and pullbacks occur. The current holding mix and account market also influence the phase. |

With duration `d` measured in years, the period-end target is `(anchor annual return + annualSpreadPercent + capped holdings tilt) × d + (anchor square-root return + sqrtSpreadPercent) × √d`. The curve moves around the line from zero to this target using its own frequencies, phase, and amplitude. Account waves use the actual duration, including short custom date ranges; `performance.minDuration` applies only to index-curve oscillation. The account's current holdings influence the capped tilt and wave phase, so edited holdings are reflected in both the account curve and its mapped reference.

The supplied HSBC spreads are `0.20` and `0.20`; DBS uses `-0.50` and `-0.45`, Standard Chartered `-0.75` and `-0.60`, and the fallback `-0.65` and `-0.50`. These produce a modestly higher HSBC period-end return and other-bank period-end returns below both HSBC and S&P 500. Curves may cross locally along the way: their rises, falls, and recovery timing are intentionally different. Multiple selected accounts are weighted by their eligible invested cost. Selecting accounts or enabling the reference never changes an index benchmark's curve.

These settings change the **illustrative Performance chart**, not holding prices, average costs, account values, or unrealised gain/loss. TWRR and MWRR remain equal because the demo models no external cash flows. The supplied bank offsets describe a presentation scenario, not actual bank performance or live market history.

BA 日常仍只需修改 `Portfolios.csv` 的账户和持仓。SG/HK reference 分别读取上表指定的当前账户，单选该账户时两条线精确重叠。HSBC reference、S&P 500 和他行曲线采用不同的涨跌节奏；他行期末收益略低，途中允许局部交叉。需要调整目标差距时修改 `annualSpreadPercent` 和 `sqrtSpreadPercent`，调整波动大小时修改 `waveAmplitude`，调整转折节奏时修改频率和 `phaseOffset`。这些参数不会修改组合价值或未实现盈亏。

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
