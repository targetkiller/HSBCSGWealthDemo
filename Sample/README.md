# Sample data configuration

[English](#editing-the-demo) | [简体中文](#中文使用说明) | [Project README](../README.md)

The app's default accounts, portfolio templates, holdings, exchange rates, illustrative analytics, products, and assistant responses are configured in the 20 CSV tables in this folder. Edit these tables to change the demo's content. Account valuation, aggregation, filtering, and user document validation remain in Swift.

## Editing the demo

1. Change the relevant CSV, keeping its header and referenced IDs intact. For an existing holding, edit `quantity`, `price`, and `averageCost` in [holdings.csv](holdings.csv).
2. Export as UTF-8 CSV and run `./scripts/sample-data.sh validate` from the project root. It uses the same loader as the app to validate columns, values, and references. The supplied dataset contains 8 default accounts and 57 configured holding rows across 20 tables: 40 default holdings, 3 bank-connection positions, 8 statement-preview positions, 2 in-app CSV sample positions, and 4 statement-file export positions.
3. Rebuild the app in Xcode. These files are bundled build resources; editing a file on your Mac does not update an already installed build or a TestFlight build.
4. On a new installation, the app loads the configured defaults. On an installation with saved accounts, go to **Menu → Settings → Restore demo data** and confirm to replace local accounts and holdings with the newly bundled defaults. Restore discards local account and holding edits; rebuilding alone preserves them.

Configuration errors appear on the startup error screen with details to correct. Fix the CSV and rebuild; the app does not silently load a different hardcoded dataset. An intentionally empty saved portfolio remains empty until you explicitly restore or add accounts.

To validate the tables and export a statement for a manual import test:

```bash
./scripts/sample-data.sh validate
./scripts/sample-data.sh export-statement
```

The export command writes `build/Sample/statement.csv` by default. Supply an output path as its final argument to save elsewhere, for example `./scripts/sample-data.sh export-statement /tmp/statement.csv`. The production loader generates this seven-column file from the `csv-file-export` set, preserving the four positions in the original downloadable statement example: AAPL, VOO, SGS, and SGD. **Edit [holdings.csv](holdings.csv), set `csv-file-export`, as the export source; do not maintain a second editable statement fixture.** Regenerate the exported file after changing those rows. The app's separate two-position “Try a sample statement” CSV uses the `csv-import` set.

## Tables and relationships

| Table | Purpose and key fields |
| --- | --- |
| [accounts.csv](accounts.csv) | Default linked accounts. `id` is a stable UUID; `holdingsSet` selects rows from `holdings.setID`. `currency` is the account's reporting currency, while `market`, `accountNumber`, and `institution` describe the account. |
| [holdings.csv](holdings.csv) | All seed and template positions, grouped by `setID`. Each row has a UUID `id`, security `name`/`symbol`, `category`, `currency`, `quantity`, `price`, `averageCost`, and optional `region`/`sector`. |
| [account_templates.csv](account_templates.csv) | Newly connected and imported portfolio metadata. Uses the same account fields with stable template keys such as `bank-connection` and `linked-account`. `holdingsSet` can be blank for a portfolio that receives imported holdings. |
| [currencies.csv](currencies.csv) | Supported currency codes in `id`; `cnyRate` is the value of one unit in CNY. `wealthRegion` assigns currencies to the Wealth summary's illustrative regions. GIV uses each holding's explicit region, falling back to its account market. |
| [settings.csv](settings.csv) | `id,value` pairs for default currency, account, bank, market, and Wealth scenario, plus imported portfolio labels and reference assumptions. ID settings refer to the corresponding table. |
| [banks.csv](banks.csv) | Bank names and availability. `portfolioEnabled` controls the Add a portfolio bank chooser; `accountEnabled` controls the menu's Add account flow. |
| [markets.csv](markets.csv) | Account markets: `name` is stored on the account, `shortName` labels the compact filter, and `currency` selects the default reporting currency for a newly added account. |
| [legacy_accounts.csv](legacy_accounts.csv) | Compatibility rules for older saved demo accounts. `id` refers to a default account; `previousName` and the `signatureSymbols` list identify its earlier form. Keep these rules when changing current display names. |
| [asset_profiles.csv](asset_profiles.csv) | Asset-class `id`, illustrative `riskScore`/`liquidityScore`, `riskLabel`, and fallback `defaultSector`. |
| [regions.csv](regions.csv) | GIV region labels, matching `aliases`, and normalized map coordinates `mapX`/`mapY`. |
| [performance.csv](performance.csv) | One `default` row defines the fixed `asOfDate`, initial date range, market/period/metric selection, `marketFilters`, and parameters used to generate illustrative history. |
| [benchmarks.csv](benchmarks.csv) | Benchmark names, return and curve parameters, `colorHex`, chart `symbol`, and `defaultSelected`. Returns are independently generated for each benchmark. |
| [analytics.csv](analytics.csv) | One `default` row defines `currencyIllustrationShock`, `concentrationThreshold`, and `defaultScenarioID`, which refers to `scenarios.id`. |
| [scenarios.csv](scenarios.csv) | GIV stress scenarios. `currencies`, `assetClasses`, and `regions` select exposure; `shock` defines the signed change. `skipMatchingReportingCurrency` controls the currency scenario's reporting-currency exception. |
| [wealth_scenarios.csv](wealth_scenarios.csv) | Wealth stress-test tabs. Each row defines `name`, `description`, positive `shockRate`, and `referenceDecline` in percentage points. |
| [wealth_scenario_targets.csv](wealth_scenario_targets.csv) | Exposure rules for each `scenarioID` in `wealth_scenarios`. A row's nonblank `category` and `currency` must both match; any matching row includes a holding once. |
| [wealth_regions.csv](wealth_regions.csv) | Wealth chart groups and colors. `name` matches `currencies.wealthRegion`; `color` is a decimal RGB integer. |
| [products.csv](products.csv) | Product preview cards, their `category`, `title`, and SF Symbol `symbol`. |
| [assistant_suggestions.csv](assistant_suggestions.csv) | Suggested prompts in display order. Each row has `id,prompt`. |
| [assistant_rules.csv](assistant_rules.csv) | Local answer rules: `keywords` and `response`. Preserve supported response placeholders when editing the wording. |

Within each table, keep IDs unique. Preserve file order when you want to preserve chooser, card, or scenario order. Every nonblank `holdingsSet` must match at least one `holdings.setID`. The `defaultAccountID`, `defaultBankID`, `defaultMarketID`, and `defaultWealthScenarioID` settings must refer to existing rows; the default bank must be available in both bank choosers.

The account templates have distinct purposes:

- `bank-connection`: the three-position demo connection opened from Add a portfolio; `{bank}` in its name is replaced with the selected bank.
- `linked-account`: the account added through the menu; its named `holdingsSet` remains stable when the default account rows are reordered.
- `statement-review`: the portfolio created after the Wealth statement review; `{source}` in its note is replaced with the document source.
- `statement-import`: the older menu CSV import flow's initial account metadata.

`statement-preview` in `holdings.setID` supplies the eight-position Wealth sample statement. `csv-import` supplies the two-position sample for the menu import flow, while `csv-file-export` supplies the four-position file produced by the export command for manual file-import tests. These preserve the distinct original samples; all are maintained in `holdings.csv`. That file itself is a configuration table and is not a seven-column statement import file.

Default accounts and their holdings retain their configured UUIDs so saved references and migrations stay stable. A newly connected portfolio or sample import receives new account and holding UUIDs. Creating a second portfolio from the same template therefore creates a separate account rather than overwriting the first.

## CSV values and calculations

Use these exact enum values; adding a new code requires a corresponding model change:

- Currency: `SGD`, `USD`, `HKD`, `CNY`.
- Category: `Stocks`, `Unit trusts`, `Bonds`, `Cash and FX`, `Structured products`, `Insurance`, `Options`.
- Boolean: `true` or `false`.

Use decimal numbers without currency signs, thousands separators, or `%`. A fractional shock of `-0.10` means a 10% decline in `scenarios.shock`. `analytics.currencyIllustrationShock` also uses a signed fraction; its default is `-0.10`, and its accepted range is `-1...1`. Wealth's `shockRate` uses positive `0.10` to calculate the decline amount. `referenceDecline=6` and `annualReturnPercent=8.7` mean 6% and 8.7%, respectively. Preserve these unit differences when editing.

Market value is `quantity × price`; invested cost is `quantity × averageCost`; unrealised gain/loss is their difference. Do not add a separate total-value column: account totals and comparisons recalculate from the positions and `currencies.cnyRate`. Configure positive quantities and valid finite prices/costs. Update the descriptive scenario text and its numeric shock together.

For every supported reporting currency, the combined value and cost of all configured holdings must each remain below `100,000,000,000,000` after conversion. The validator checks this aggregate limit to prevent chart values from overflowing. `performance.maxYears` must be greater than `0` and no greater than `100`.

Save in UTF-8 CSV, with a comma separating columns. Quote fields containing commas, quotation marks, or line breaks; double an embedded quotation mark. For example, a security name containing a comma is saved as `"Example Fund, Class A"`. List fields such as `keywords`, `marketFilters`, `aliases`, and `signatureSymbols` use `|` between entries. In `products.title`, `\n` is an intentional display line break.

In Excel or Numbers, import **IDs, account numbers, security symbols, and all list fields as text** before editing. Otherwise a security code such as `00100` can become `100`, a date-like symbol may be converted to a date, or an account number may be reformatted. Keep dates as `YYYY-MM-DD`. Export CSV rather than renaming an `.xlsx` or `.numbers` file, then check that leading zeroes and quoted fields are still intact. CSV tables have no comment rows; use this guide for notes.

Risk scores, exchange rates, scenario shocks, and benchmark/history parameters are demonstration inputs. They are not live quotes or real historical performance. The assistant uses local rules, and connected banks do not retrieve real accounts.

## 中文使用说明

日常改数据，主要编辑 `accounts.csv`（默认账户）、`holdings.csv`（持仓）、`account_templates.csv`（新增账户模板）和 `settings.csv`（默认选择）。上方表格列出了全部 20 张 CSV 的职责与关键字段，其他文件分别控制银行选项、地区、风险、收益演示、产品和助手回答。

1. **修改现有资产**：在 `holdings.csv` 找到持仓，修改 `quantity`、`price`、`averageCost`。市值、成本、收益和账户对比会据此计算，无需另填总金额。
2. **添加账户**：在 `accounts.csv` 新增一行并使用新的 UUID；填写 `holdingsSet`，在 `holdings.csv` 中新增相同 `setID` 的持仓，每条持仓也使用独立 UUID。名称可修改，已有 ID 和外键不要随意更换。
3. **调整默认进入的账户或银行**：修改 `settings.csv` 的 `defaultAccountID`、`defaultBankID`、`defaultMarketID` 等字段，值必须对应目标表的 `id`。新增银行时，两个 `Enabled` 字段决定它在哪个入口出现。
4. **修改样例账单**：`statement-preview` 是 Wealth 入口的 8 条样例持仓；`csv-import` 是 App 菜单 CSV 导入页的 2 条样例持仓；`csv-file-export` 保留原文件示例中的 AAPL、VOO、SGS、SGD 共 4 条持仓，用于生成手动导入测试文件。以 `Sample/holdings.csv` 为唯一持仓数据源，执行 `./scripts/sample-data.sh export-statement` 可将 `csv-file-export` 导出为 `build/Sample/statement.csv`，也可以在命令末尾指定其他输出路径。不要另维护一份账单样例数据。新增模板生成新 UUID，不会复用默认账户 ID。
5. **校验并让修改生效**：先在项目根目录执行 `./scripts/sample-data.sh validate`，使用与 App 相同的加载器校验表格。配置共 20 张表、8 个默认账户和 57 条持仓：40 条默认账户持仓、3 条银行连接持仓、8 条 Wealth 账单样例、2 条 App 内 CSV 样例、4 条文件导出样例。CSV 是编译资源，校验后需要重新构建并安装 App。首次启动直接加载新配置；已有数据会保留。需要替换本机账户和持仓时，在 **Menu → Settings → Restore demo data** 中确认恢复，这会覆盖本机的账户及持仓修改。现有空组合不会自动补回数据。
6. **表格软件编辑**：用 UTF-8 CSV 导入和导出；ID、账号、证券代码提前设为文本，保留 `00100` 等前导零。包含逗号或换行的内容用双引号包裹，内容中的双引号写成两个双引号；列表用 `|` 分隔。不要把 `.xlsx` 或 `.numbers` 直接改扩展名为 `.csv`。

币种与资产类别必须使用上方列出的英文枚举值。`scenarios.shock=-0.10` 表示下跌 10%；`analytics.currencyIllustrationShock` 同样使用带正负号的小数，默认 `-0.10`，允许范围为 `-1...1`。`wealth_scenarios.shockRate=0.10` 表示按 10% 计算损失，而 `referenceDecline=6` 表示 6%。这些字段单位不同，调整数值后也要同步修改说明文字。

所有配置持仓换算为任一支持的展示币种后，市值合计和成本合计都必须小于 `100,000,000,000,000`；校验器会检查这个总量上限，避免图表数值溢出。`performance.maxYears` 必须大于 `0` 且不超过 `100`。

配置格式、字段或关联错误会在启动错误页显示；修复 CSV 后重新构建即可，不会静默切换到其他硬编码数据。汇率、风险评分、历史曲线、基准和压力情景均用于演示，并非真实行情；银行连接和助手分析也在本地完成。
