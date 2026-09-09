# Install HSBC SG with Sideloadly

[English](SIDELOADLY.md) | [简体中文](SIDELOADLY.zh-CN.md) | [Project README](../README.md)

**[Download HSBC-SG.ipa](https://github.com/targetkiller/HSBCSGWealthDemo/releases/latest/download/HSBC-SG.ipa)** · [All releases](https://github.com/targetkiller/HSBCSGWealthDemo/releases)

This is the native iPhone demo for **iOS 17 or later**. The release provides an unsigned device build; Sideloadly signs it with each tester's own Apple Account before installation. A computer is required. The Appetize ZIP and GitHub source archives are different downloads.

## Prepare your computer

- **Mac:** Download the current installer from [sideloadly.io](https://sideloadly.io/). Current Sideloadly no longer needs the old Mail plug-in setup. [Official changelog](https://sideloadly.io/changelog.html)
- **Windows:** Use the installer from [sideloadly.io](https://sideloadly.io/) and the **web versions of iTunes and iCloud linked on that page**. Sideloadly instructs users to replace Microsoft Store versions first. [Official requirements](https://sideloadly.io/)
- Have a USB cable, internet access, and your own Apple Account ready. Sideloadly is free and supports accounts without paid developer membership. [Official features](https://sideloadly.io/)

Enter your account credentials only in the official Sideloadly application when prompted. The demo and its maintainers do not collect Apple Account passwords or verification codes. Each tester uses their own account; no shared signing account is supplied.

## Install

1. Download **HSBC-SG.ipa** onto your computer. Keep the `.ipa` file intact.
2. Connect and unlock your iPhone. Accept the computer trust prompt, then select the **iPhone** in Sideloadly's device list. On Apple Silicon Macs, the Mac itself may also appear.
3. Drag the IPA into Sideloadly and enter your Apple Account in its Apple ID field. Keep the default installation options and leave automatic refresh enabled.
4. Click **Start** and complete the password and verification prompts in Sideloadly. Wait for installation to finish. [Official installation overview](https://sideloadly.io/)
5. On the iPhone, trust your signing account under **Settings → General → VPN & Device Management**. [Official FAQ](https://sideloadly.io/faq.html)
6. Enable **Settings → Privacy & Security → Developer Mode**, follow the restart prompts, and confirm after restarting. Then open **HSBC SG**. If the switch is missing, complete the initial installation attempt and check again. [Apple's Developer Mode guide](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)

Suggested walkthrough: Wealth → Generate AI analysis → Add other holdings to analyse → Try a sample statement → View my global holdings.

## Keep the app working

Free provisioning expires after **7 days**. Apple also limits free personal provisioning to **3 installed apps per device** and **10 App IDs in a 7-day period**. If a limit is reached, free an installed-app slot or wait for App IDs to expire, as appropriate. [Apple account limits](https://developer.apple.com/help/account/basics/about-your-developer-account)

Automatic refresh needs the Sideloadly Daemon running on an awake, online computer and the phone reachable over USB or configured Wi-Fi. It does not renew the app independently on the phone. For wireless refresh, first pair over USB, enable Wi-Fi device visibility/sync in Finder or iTunes, and use the same network. [Official refresh setup](https://sideloadly.io/faq.html)

For manual renewal or a new release, sideload the IPA over the existing app using the same Apple Account and bundle-ID settings. Keep automatic refresh enabled. This preserves the app's local data; deleting HSBC SG removes its saved demo portfolios. [Official update guidance](https://sideloadly.io/faq.html)

## If installation stops

| Symptom | Next step |
| --- | --- |
| iPhone is absent | Unlock it, reconnect USB, accept Trust, and check that Finder/iTunes can see it. On Windows, verify the required web installers. |
| Untrusted developer / Developer Mode required | Complete steps 5–6 above. |
| App no longer opens after a week | Reconnect to the computer and refresh or install over the existing app. |
| Architecture or minimum-system error | Use this release's device IPA on iOS 17+, rather than the simulator ZIP. |

For other signing errors, consult the [official Sideloadly FAQ](https://sideloadly.io/faq.html). This release can be checked as a device build before distribution; successful account signing and launch still require a tester's connected iPhone.

Requirements checked against official documentation on 9 September 2026.
