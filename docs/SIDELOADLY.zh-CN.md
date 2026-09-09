# 使用 Sideloadly 安装 HSBC SG

[English](SIDELOADLY.md) | [简体中文](SIDELOADLY.zh-CN.md) | [项目说明](../README.zh-CN.md)

**[下载 HSBC-SG.ipa](https://github.com/targetkiller/HSBCSGWealthDemo/releases/latest/download/HSBC-SG.ipa)** · [所有版本](https://github.com/targetkiller/HSBCSGWealthDemo/releases)

这是适用于 **iOS 17 及以上**的原生 iPhone Demo。发布包为未签名的真机版本，安装时由 Sideloadly 使用每位体验者自己的 Apple Account 签名。需要电脑；Appetize 的 ZIP 和 GitHub 源码压缩包不用于这种安装方式。

## 准备电脑

- **Mac：**从 [sideloadly.io](https://sideloadly.io/) 下载当前安装程序。新版已不需要旧教程中的 Mail 插件配置。[官方更新记录](https://sideloadly.io/changelog.html)
- **Windows：**从 [sideloadly.io](https://sideloadly.io/) 下载，并安装该页提供的 **网页版 iTunes 和 iCloud**。Sideloadly 官方要求先替换 Microsoft Store 版本。[官方要求](https://sideloadly.io/)
- 准备 USB 数据线、网络和自己的 Apple Account。Sideloadly 免费，也支持没有付费开发者会员的账号。[官方功能说明](https://sideloadly.io/)

账号密码和验证码只在官方 Sideloadly 应用提示时输入。这个 Demo 及项目维护者不收集这些信息。每位体验者使用自己的账号，项目不提供共用签名账号。

## 安装

1. 将 **HSBC-SG.ipa** 下载到电脑，保留 `.ipa` 文件，不用解压。
2. 用 USB 连接并解锁 iPhone，接受“信任此电脑”提示。在 Sideloadly 设备列表中选中 **iPhone**；Apple Silicon Mac 本身也可能出现在列表中。
3. 将 IPA 拖入 Sideloadly，在 Apple ID 一栏填写自己的 Apple Account。使用默认安装选项，保持自动续签开启。
4. 点击 **Start**，在 Sideloadly 中完成密码和验证码提示，等待安装结束。[官方安装流程](https://sideloadly.io/)
5. 在 iPhone 的**设置 → 通用 → VPN 与设备管理**中，信任用于签名的账号。[官方 FAQ](https://sideloadly.io/faq.html)
6. 在**设置 → 隐私与安全性 → 开发者模式**中开启开关，按提示重启，并在重启后确认。然后打开 **HSBC SG**。若暂时没有此开关，先完成首次安装尝试，再返回查看。[Apple 开发者模式说明](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)

建议体验路线：Wealth → Generate AI analysis → Add other holdings to analyse → Try a sample statement → View my global holdings。

## 续签与更新

免费签名 **7 天到期**。Apple 的免费个人签名还限制为每台设备同时安装 **3 个 App**，以及 **7 天内最多 10 个 App ID**。遇到相应限制时，腾出免费签名 App 名额，或等待 App ID 到期。[Apple 账号限制](https://developer.apple.com/help/account/basics/about-your-developer-account)

自动续签需要电脑保持唤醒、联网并运行 Sideloadly Daemon，同时能够通过 USB 或已配置的 Wi-Fi 发现手机。它不能仅靠手机自行续签。使用无线续签前，先通过 USB 配对，在 Finder 或 iTunes 中开启 Wi-Fi 设备显示／同步，并让两台设备连接同一网络。[官方续签配置](https://sideloadly.io/faq.html)

手动续签或更新版本时，使用相同 Apple Account 和相同 bundle ID 设置，将 IPA 覆盖安装，并继续开启自动续签。这样可以保留本地数据；删除 HSBC SG 会清除已保存的演示组合。[官方更新说明](https://sideloadly.io/faq.html)

## 安装问题

| 现象 | 下一步 |
| --- | --- |
| 找不到 iPhone | 解锁手机、重新连接 USB 并接受信任提示；检查 Finder／iTunes 是否识别。Windows 需确认安装了要求的网页版组件。 |
| 提示不受信任的开发者／需要开发者模式 | 完成上面的第 5–6 步。 |
| 一周后打不开 | 连接电脑续签，或覆盖安装现有 App。 |
| 架构或最低系统版本不符 | 在 iOS 17+ 使用此发布版的真机 IPA，不要使用模拟器 ZIP。 |

其他签名问题见 [Sideloadly 官方 FAQ](https://sideloadly.io/faq.html)。发布前可以检查真机构建与包结构；账号签名及实际启动仍需体验者连接自己的 iPhone 验证。

安装要求核对日期：2026 年 9 月 9 日。
