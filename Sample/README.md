# 账户与组合配置 · Portfolio configuration

[English quick guide](#english-quick-guide) · [项目说明](../README.md) · [其他参数](Others/README.md)

**BA 同事日常只需编辑 [Portfolios.csv](Portfolios.csv)**：账户名称、银行、持仓和组合价值都在同一张表。汇率、风险参数、场景、产品文案等放在 `Others/`，按需调整。

Performance 中默认勾选的 HSBC reference portfolio 直接读取对应 SG/HK 账户及持仓，无需另填一份 reference 数据。账户映射和演示收益参数见 [Others 配置说明](Others/README.md#performance-and-reference-portfolios)。

```text
Sample/
├── Portfolios.csv       ← 账户、持仓、组合价值；日常编辑这张表
├── README.md            ← 本说明
└── Others/              ← 汇率、分析参数、场景等其他配置
```

## 表格怎么读

每一行是一项持仓，相同 `portfolioID` 的行属于同一个账户或组合。每组第一行填写账户信息，后续行的账户字段可以留空；每行都要保留 `portfolioID`。即使排序后行不相邻，也会归到同一组合；同一组若重复填写账户信息，内容必须一致。

先筛选 `purpose=account` 找到默认账户所在的组合，再按其 `portfolioID` 查看全部持仓。后续持仓行的 `purpose` 留空是正常的，不代表它们被停用。

| 要改什么 | 编辑的列 | 示例 / 单位 |
| --- | --- | --- |
| 账户名称、银行、市场 | `name`、`bank`、`market` | 在该组合的账户信息行填写 |
| 账户展示币种 | `currency` | `SGD`、`USD`、`HKD` 或 `CNY` |
| 整个组合的目标市值 | `portfolioValue` | `500000`，单位为账户的 `currency` |
| 持仓名称、代码、类别 | `holdingName`、`symbol`、`category` | 证券代码按文本保存，保留前导零 |
| 持仓数量、价格、成本 | `quantity`、`price`、`averageCost` | 单价和平均成本使用 `holdingCurrency` |
| 单项持仓的目标市值 | `holdingValue` | `10000`，单位为该行的 `holdingCurrency` |
| 持仓币种、地区、行业 | `holdingCurrency`、`region`、`sector` | 控制换算和分析图表中的分类 |

金额只填数字，不加货币符号、千位逗号或 `SGD` 后缀。例如填 `500000`，不要填 `500,000 SGD`。保留现有 `portfolioID`、`accountID`、`holdingID`；修改显示名称不需要修改这些 ID。

## 三个常用修改

1. **修改账户名称**：找到该组合有 `name` 的那一行，直接改名称。`bank`、`market`、`accountNumber`、`note` 也在这一行修改。
2. **修改某项持仓**：修改它的 `quantity`、`price`、`averageCost`。如果只关心这项持仓值多少钱，可以填写 `holdingValue`，系统会按 `holdingValue ÷ price` 算出数量，此时 `quantity` 可以留空；要恢复按数量计算，就清空 `holdingValue` 并填写数量。正数目标需要 `price` 大于 0。
3. **指定整个组合值多少钱**：在账户信息行填写 `portfolioValue`。例如账户币种为 SGD，填写 `500000` 后，组合总市值就是 500,000 SGD。系统先处理单项 `holdingValue`，再按比例缩放全部持仓数量，使总值达到目标；价格和平均成本不变。

`portfolioValue` 留空时，总值由持仓计算。填写 `0` 会将该组合持仓数量置零。正数目标需要组合本来就有非零市值的持仓，不能给空组合或全零组合直接指定正数总值。

**同时填写两种目标值时，以组合总值为最终目标。** 例如单项持仓先设为 10,000 SGD，而所有持仓合计为 100,000 SGD；若组合目标填 200,000 SGD，所有数量都会翻倍，这项持仓最终为 20,000 SGD。只设置组合目标会保留持仓比例及收益率；单独调整某项持仓则会改变配置比例。系统不会额外添加一笔现金来补差额。

## 保存并应用

1. 用 Excel、Numbers 或文本编辑器打开 `Portfolios.csv`。导入时将 ID、账号和证券代码设为**文本**，避免 `00100` 变成 `100`。
2. 保存或导出为 **UTF-8 CSV**，保留表头。包含逗号、双引号或换行的内容由表格软件按 CSV 格式转义；不要把 `.xlsx` 或 `.numbers` 直接改名成 `.csv`。
3. 在项目根目录运行以下命令，先校验，再查看各账户的市值、成本和持仓数量：

   ```bash
   ./scripts/sample-data.sh validate
   ./scripts/sample-data.sh summary
   ```

4. 确认数据后，重新构建并安装 App。新安装会读取默认账户；已有安装会保留已保存的数据。要应用新的默认账户，在 **Menu → Settings → Restore demo data** 中确认恢复，此操作会替换本机已有的账户、持仓及编辑内容。

CSV 是打包到 App 的资源，修改电脑上的文件不会直接更新已安装 App 或 TestFlight。配置错误会显示具体文件和字段信息，修复后再构建即可。目标价值只用于生成配置中的示例数据，不会重新缩放用户已保存的持仓或真实账单导入结果。

## 新增账户或持仓

- **新增账户**：复制现有账户的整组行，给它们填写同一个新的 `portfolioID`，修改账户信息和持仓，清空复制过来的 `accountID` 与 `holdingID`。系统会根据新组合标识与持仓信息生成稳定 ID。
- **新增持仓**：在新行填写所属的 `portfolioID` 和持仓信息，账户字段、`accountID`、`holdingID` 可以留空。新持仓的默认 ID 根据组合标识、证券代码、币种和类别生成；同一组合要分别记录同代码、同币种、同类别的多笔持仓时，需要为每笔填写不同的 UUID `holdingID`。

已有行的 ID 不要清空或更换。新增完成后运行校验；默认选中账户等高级关联配置在 [Others/](Others/README.md)。

## 模板与样例账单

同一张表还包含新增账户与导入演示的配置，按 `purpose` 区分：

- `account`：首次运行或 Restore demo data 后显示的默认账户。
- `template`：新增账户时使用的模板；`bank-connection` 是 Other bank account 的演示持仓，`linked-account` 是菜单新增账户模板，`statement-review` 和 `statement-import` 提供导入账户信息。
- `holdings`：独立样例持仓；`statement-preview` 用于 Wealth 的 8 项账单预览，`csv-import` 用于菜单内的 2 项 CSV 示例，`csv-file-export` 用于导出 4 项持仓的测试账单。

模板名称中的 `{bank}`、备注中的 `{source}` 会在使用时替换。`holdingsFrom` 表示复用另一组持仓，例如 `linked-account` 复用 `hsbc-sg-unit-trust`；需要调整它使用的持仓时，编辑来源组。复用会包含来源持仓的 `holdingValue` 调整，但不会继承来源账户的 `portfolioValue`：模板可以设置自己的组合目标。菜单新增账户时，该目标按最终所选市场的账户币种计算，例如选择香港后按 HKD 计算。新增模板账户会生成独立 ID，不会覆盖默认账户。

导出可手动导入 App 的样例账单：

```bash
./scripts/sample-data.sh export-statement
```

默认输出为 `build/Sample/statement.csv`，也可在命令末尾指定其他输出路径。修改 `Portfolios.csv` 中 `csv-file-export` 组后重新导出。`Portfolios.csv` 本身是配置文件，不能作为七列格式的账单导入。

允许的 `category`：`Stocks`、`Unit trusts`、`Bonds`、`Cash and FX`、`Structured products`、`Insurance`、`Options`。其他字段及参数说明见 [Others/README.md](Others/README.md)。

## English quick guide

Edit **[Portfolios.csv](Portfolios.csv)** for all default accounts, holdings, account templates, and portfolio values. Other settings, including exchange rates and scenario assumptions, live in **[Others/](Others/README.md)**.

Rows sharing a `portfolioID` belong to one group. Fill account metadata on its first row and leave those cells blank on subsequent rows; retain `portfolioID` on every row. Grouping uses the ID even after sorting. Any repeated nonempty metadata must agree.

- Change `name`, `bank`, `market`, or `accountNumber` to edit account details.
- Change `quantity`, `price`, and `averageCost` for a holding, or enter `holdingValue` in its `holdingCurrency` to derive quantity from value ÷ price. Quantity may then be blank; a positive target requires a positive price.
- Enter `portfolioValue` in the account's `currency` to set total market value. After individual holding overrides, all quantities scale proportionally to this total. Prices and average costs stay unchanged. Leave it blank to calculate the total from holdings; zero sets all quantities to zero. A positive target requires a nonzero starting portfolio value.

When both value overrides are set, the portfolio target applies last, so individual holding values may change again. This affects configured demo data only; saved user accounts and real statement imports are not rescaled.

Import IDs, account numbers, and symbols as text in Excel or Numbers. Preserve existing IDs and leading zeroes, use plain decimal numbers, and export UTF-8 CSV with the original header. Run `./scripts/sample-data.sh validate` and `./scripts/sample-data.sh summary`, then rebuild and install. On an existing installation, **Menu → Settings → Restore demo data** replaces saved accounts and holdings with the bundled defaults; rebuilding alone preserves saved data.

For a new account, copy a group, assign a new `portfolioID`, and clear copied `accountID` and `holdingID` values. For a new holding, add its position fields and the destination `portfolioID`; leave `holdingID` blank. New blank IDs are generated deterministically. Duplicate lots with the same symbol, currency, and category in one portfolio require distinct explicit UUIDs. Preserve IDs on existing rows.

`purpose=account` denotes defaults, `template` denotes new-account templates, and `holdings` denotes standalone statement samples. `holdingsFrom` copies the source positions including their `holdingValue` adjustments, but does not inherit the source account's `portfolioValue`. Each template has its own optional total target, measured in the account's final currency after market selection. See [Others/README.md](Others/README.md) for structural fields and advanced settings.
