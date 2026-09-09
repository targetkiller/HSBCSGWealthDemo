# 通过 TestFlight 分发 HSBC SG

[English](TESTFLIGHT.md) | [简体中文](TESTFLIGHT.zh-CN.md) · [返回 README](../README.zh-CN.md)

TestFlight 可以让体验者通过邀请链接把 Demo 安装到 iPhone。仓库提供本地准备工具；完成上传、Apple 处理及所需的 Beta 审核后，才能生成可用的体验链接。

## 1. 准备 Apple 账号和 Xcode

- 使用已生效的 **Apple Developer Program** 会员，或加入已有组织的开发者团队并获得相应权限。免费 Personal Team 无法发布 TestFlight。标准会员费用为每年 99 美元，按地区提供当地价格；符合条件的组织可申请费用豁免。体验者使用免费的 TestFlight，无需开发者会员。[会员说明](https://developer.apple.com/programs/enroll/) · [TestFlight 概述](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- 使用 **Xcode 26 或以上版本及 iOS 26 或以上 SDK**。自 2026 年 4 月 28 日起，Apple 对上传至 App Store Connect 的应用实施此要求；这不会把本 Demo 的最低支持系统从 iOS 17 改成 iOS 26。[当前上传要求](https://developer.apple.com/news/upcoming-requirements/)
- 在 **Xcode → Settings → Accounts** 登录账号，配置签名时选择对应的付费团队。如果有待接受的协议，由 Account Holder 完成。[App Store Connect 流程](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow/)

| 操作 | App Store Connect 所需职能 |
| --- | --- |
| 创建 App 记录 | Account Holder、Admin、App Manager |
| 上传构建 | Account Holder、Admin、App Manager、Developer |
| 管理外部测试 | Account Holder、Admin、App Manager |

还需要拥有对应 App 的访问权限，以及签名流程所需的证书、标识符和描述文件权限。参见 Apple 的[创建 App](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)、[上传构建](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)和[外部测试](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)要求。

## 2. 在 App Store Connect 创建 App

1. 选择一个**由自己团队注册的唯一 Bundle ID**。本地工程中的标识符仅是工程配置，不代表你的团队已经注册或有权使用它。
2. 用 Xcode 打开 `WealthHub.xcodeproj`，选择 **WealthHub** target，进入 **Signing & Capabilities**。选择自己的团队，启用自动签名，并设置 Bundle Identifier。归档和 App Store Connect 必须使用同一个 ID。如果通过 XcodeGen 重新生成工程，也应同步 `project.yml` 中的配置。
3. 打开 [App Store Connect](https://appstoreconnect.apple.com/)，进入 **Apps → + → New App**。选择 **iOS**，填写可用的 App 名称、主要语言、已注册的 Bundle ID 和团队内部唯一的 SKU。先创建 App 记录，再上传构建。[Apple 创建说明](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)

手机上显示的 App 名称为 **HSBC SG**。App Store Connect 中的名称需通过可用性检查；使用发布团队有权发布的名称及应用身份。

## 3. 本地检查并归档

在仓库根目录运行：

```bash
./scripts/testflight.sh preflight
```

预检查不需要会员或签名证书，生成供检查的未签名真机 Archive；这个产物无法上传到 TestFlight。

付费团队和 Bundle ID 配置完成后，将下面的 `YOURTEAMID` 替换为自己团队的 10 位 Team ID，再运行。Team ID 可在 Apple Developer 账号页面的 **Membership details（会员详情）**找到。[账号页面说明](https://developer.apple.com/help/account/basics/account-landing-page/)

```bash
TESTFLIGHT_TEAM_ID=YOURTEAMID ./scripts/testflight.sh archive
```

脚本会生成签名归档，并打印其绝对路径。每次运行均在 `build/TestFlight/` 创建独立目录，例如 `archive-<日期>.<后缀>/HSBC-SG.xcarchive`；预检查目录使用 `preflight-` 前缀。产物保留在 Git 之外，脚本不会自动上传。

工程初始版本为 **1.0.1 (2)**。可通过环境变量覆盖版本号和 Build，无需修改工程，例如：

```bash
TESTFLIGHT_TEAM_ID=YOURTEAMID \
TESTFLIGHT_VERSION=1.0.1 \
TESTFLIGHT_BUILD_NUMBER=3 \
./scripts/testflight.sh archive
```

也可以直接使用 Xcode：选择 **WealthHub** scheme 和 **Any iOS Device (arm64)**，点击 **Product → Archive**。分发归档应选择真机目标，不要选择 iPhone 模拟器。每次上传新构建前递增 **Build**（`CURRENT_PROJECT_VERSION`）；同一 Beta 版本可以保留原营销版本号。[Apple Beta 构建教程](https://developer.apple.com/tutorials/develop-in-swift/test-your-beta-app)

## 4. 用 Xcode Organizer 上传

1. 如果使用脚本，在 Finder 中找到脚本打印路径下的签名 `.xcarchive`，双击后会在 Xcode Organizer 打开；脚本产物不在 Organizer 的默认归档目录。如果使用 **Product → Archive**，可在 **Window → Organizer → Archives** 找到结果。选中签名归档，点击 **Distribute App**。
2. 选择 **App Store Connect**，然后按当前 Xcode 界面选择上传。若团队没有手动管理描述文件，使用自动分发签名。
3. 检查团队、Bundle ID、版本号、Build、签名及校验结果。解决校验错误后，点击 **Upload**。[Apple Organizer 上传步骤](https://help.apple.com/xcode/mac/current/en.lproj/dev442d7f2ca.html)

要邀请外部体验者，请选择常规 App Store Connect 分发流程。以 **TestFlight Internal Only** 方式上传的构建只能用于内部测试，不能再用于外部测试。[Apple 测试限制](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)

上传到 TestFlight 不会自动在 App Store 正式上架。GitHub Releases 上的未签名 IPA 和 Appetize 使用的模拟器 ZIP 是不同产物；这个流程需要重新生成并上传签名归档。

## 5. 完成构建处理和测试信息

打开 **App Store Connect → Apps → 对应 App → TestFlight**，等待 Apple 处理构建。处理完成后会收到邮件；上传包的 Bundle ID 和版本号决定它出现在哪个 App 及版本下。[构建处理说明](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)

如果构建显示 **Missing Compliance**，点击旁边的 **Manage**，根据实际上传版本回答加密相关问题。以后增加加密功能时，也要同步检查工程中的声明。[Beta 出口合规步骤](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-export-compliance-information-for-beta-builds/)

在 **Test Information** 填写 Beta 描述及可用的反馈邮箱。仓库的[提交信息模板](TESTFLIGHT_METADATA.md)提供英文描述、测试重点和审核操作路线，将其中的联系人占位符替换为真实信息。外部审核前补全审核联系人、备注，以及需要登录时的测试账号。当前 Demo 无需登录，使用本地示例账户，应如实说明，并按 App Store Connect 的要求补全字段。[测试信息说明](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/)

## 6. 先进行内部测试

进入 **TestFlight → Internal Testing**，创建一个组，例如 **Demo Team**，添加处理完成的构建和有权访问此 App 的内部测试员。内部测试最多支持 **100 位 App Store Connect 用户**，面向开发团队，不需要经过外部 Beta 审核步骤。[内部测试说明](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)

在 iOS 17 或以上的 iPhone 安装 **TestFlight**，接受邀请后安装 Demo。先检查 Wealth、账户选择、添加持仓和 Global Investment View，再邀请更多人体验。

## 7. 审核后生成外部体验链接

先创建内部测试组，再创建 **External Testing** 组。添加构建，填写 **What to Test**，提交 Beta 审核。首次提交的构建需要完整审核；同版本的后续构建仍可能需要审核，时间由 Apple 决定。

获批且构建可测试后，如果没有自动分发，手动开始测试。在外部组的 **Testers** 标签页点击 **Create Public Link**，设置参与条件和人数限制，再复制链接。每个 App 最多支持 **10,000 位外部测试员**。[外部组、审核及公开链接](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)

把这个 TestFlight 邀请链接发给体验者。对方安装免费的 TestFlight，打开链接、接受邀请，即可安装 HSBC SG，无需下载 GitHub IPA 或注册开发者账号。[体验者操作说明](https://testflight.apple.com/)

## 8. 更新下一版

递增 Build，重新签名归档并上传，处理完成后把新构建加入相应测试组。每个构建从上传日起最多可测试 **90 天**，到期前发布替代构建。可在 App Store Connect 的 TestFlight 页面查看反馈和崩溃信息。[构建有效期](https://testflight.apple.com/)

## 常见卡点

| 现象 | 检查项 |
| --- | --- |
| 只能选择 Personal Team | 会员是否已生效，以及 Xcode 中选择的账号和团队。 |
| Bundle ID 不可用或无法创建描述文件 | 使用本团队拥有的标识符，并检查签名权限。 |
| Build 已被使用 | 递增 Build 后重新归档。 |
| 上传后看不到构建 | 查看处理邮件、上传错误，以及 App 记录的 Bundle ID 和版本号。 |
| 外部组无法选择构建 | 检查处理状态、合规信息，以及是否误选 Internal Only 上传。 |
| 邀请链接无法安装 | 检查构建有效期、测试组分发状态、设备及 iOS 条件和人数限制。 |

Apple 要求核对日期：**2026 年 9 月 9 日**。以后提交时，请重新查看链接中的官方要求。
