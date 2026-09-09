# Distribute HSBC SG with TestFlight

[English](TESTFLIGHT.md) | [简体中文](TESTFLIGHT.zh-CN.md) · [Back to README](../README.md)

TestFlight lets people install this demo on an iPhone using an invitation link. This repository provides local preparation tools; an upload, Apple's processing, and any required beta review must still be completed before a working invitation link exists.

## 1. Prepare the Apple account and Xcode

- Use an active **Apple Developer Program** membership, or join an existing organization's team with the necessary access. A free Personal Team cannot distribute through TestFlight. Standard membership is USD 99 per year, with regional pricing; eligible organizations may qualify for a waiver. Testers install the free TestFlight app and do not need a developer membership. [Membership](https://developer.apple.com/programs/enroll/) · [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- Use **Xcode 26 or later with the iOS 26 SDK or later**. Apple requires these SDKs for App Store Connect uploads from April 28, 2026. This build requirement does not change the demo's minimum supported device version, iOS 17. [Current upload requirements](https://developer.apple.com/news/upcoming-requirements/)
- Sign in through **Xcode → Settings → Accounts** and select the appropriate paid team when configuring signing. The Account Holder must accept any outstanding agreements. [App Store Connect workflow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow/)

| Task | App Store Connect roles |
| --- | --- |
| Create the app record | Account Holder, Admin, App Manager |
| Upload a build | Account Holder, Admin, App Manager, Developer |
| Manage external testing | Account Holder, Admin, App Manager |

App access and access to certificates, identifiers, and profiles must also be sufficient for the selected signing workflow. See Apple's [app creation](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/), [upload](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/), and [external testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/) requirements.

## 2. Register the app in App Store Connect

1. Choose a unique **Bundle ID registered to your own team**. The IDs found in a checkout are local project settings, not evidence that your team can register or use them.
2. In Xcode, open `WealthHub.xcodeproj`, select the **WealthHub** target, and open **Signing & Capabilities**. Select your team, enable automatic signing, and set the Bundle Identifier. Use the same identifier for the archive and the App Store Connect record. If you regenerate with XcodeGen, keep `project.yml` consistent with your chosen settings.
3. In [App Store Connect](https://appstoreconnect.apple.com/), open **Apps → + → New App**. Select **iOS**, an available app name, a primary language, your registered Bundle ID, and a unique internal SKU. Create the record before uploading. [Apple's app-record instructions](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)

The on-device display name is **HSBC SG**. The name entered in App Store Connect is subject to availability; use a name and app identity that your publishing team can legitimately publish.

## 3. Prepare and archive the project

From the repository root, run:

```bash
./scripts/testflight.sh preflight
```

Preflight does not need a membership or signing identity. It creates an unsigned device archive for inspection; that output cannot be uploaded to TestFlight.

Once your paid team and Bundle ID are configured, replace `YOURTEAMID` below with your team's 10-character Team ID and run. Find it on the Apple Developer account page under **Membership details**. [Account page](https://developer.apple.com/help/account/basics/account-landing-page/)

```bash
TESTFLIGHT_TEAM_ID=YOURTEAMID ./scripts/testflight.sh archive
```

This creates a signed archive and prints its absolute path. Each run uses a new directory under `build/TestFlight/`, such as `archive-<date>.<suffix>/HSBC-SG.xcarchive`; preflight directories use the `preflight-` prefix. Generated files stay outside Git. The script does not upload anything.

The project starts at version **1.0.1 (2)**. You can override the version and build for an archive without editing the project, for example:

```bash
TESTFLIGHT_TEAM_ID=YOURTEAMID \
TESTFLIGHT_VERSION=1.0.1 \
TESTFLIGHT_BUILD_NUMBER=3 \
./scripts/testflight.sh archive
```

Alternatively, in Xcode choose the **WealthHub** scheme and **Any iOS Device (arm64)**, then **Product → Archive**. Do not select an iPhone simulator for the distribution archive. For each new upload, increase **Build** (`CURRENT_PROJECT_VERSION`); keep the marketing version unchanged if you are continuing the same beta version. [Apple's beta-build tutorial](https://developer.apple.com/tutorials/develop-in-swift/test-your-beta-app)

## 4. Upload with Xcode Organizer

1. If you used the script, double-click the signed `.xcarchive` at the path it printed in Finder to open it in Xcode Organizer. Script archives are saved outside Organizer's default archive directory. If you used **Product → Archive**, find the result in **Window → Organizer → Archives**. Select the signed archive, then **Distribute App**.
2. Choose **App Store Connect** and the upload option offered by your Xcode version. Use automatic distribution signing unless your team manages profiles manually.
3. Review the team, Bundle ID, version, build, signing details, and validation results. Resolve validation errors, then click **Upload**. [Apple's Organizer upload steps](https://help.apple.com/xcode/mac/current/en.lproj/dev442d7f2ca.html)

Choose the regular App Store Connect distribution path if you want external testers. A build uploaded as **TestFlight Internal Only** cannot later be used for external testing. [Apple's testing restriction](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)

Uploading to TestFlight does not publish an App Store release. The unsigned IPA attached to GitHub Releases and the Appetize simulator ZIP are separate artifacts; create and upload the signed archive for this workflow.

## 5. Finish build processing and test information

Open **App Store Connect → Apps → your app → TestFlight**. Wait for processing to finish; Apple sends an email when the build becomes available. The Bundle ID and version determine where the build appears. [Build processing](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)

If the build shows **Missing Compliance**, open **Manage** beside it and answer the encryption questions for the implementation you are uploading. The project declaration must remain consistent with any encryption functionality added later. [Beta export-compliance steps](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-export-compliance-information-for-beta-builds/)

Under **Test Information**, fill in the beta description and a working feedback email. Use the repository's [metadata template](TESTFLIGHT_METADATA.md) for the description, test focus, and review walkthrough, replacing its contact placeholders with real details. Before external review, provide the review contact details, notes, and sign-in information if the app requires it. This demo currently opens without a login and uses local sample accounts; describe it that way. Complete all fields requested by App Store Connect. [Test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/)

## 6. Test internally first

In **TestFlight → Internal Testing**, create a group such as **Demo Team**, add the processed build, and select the eligible App Store Connect users who should test it. Internal testing supports up to **100 users** with access to the app; it is intended for your App Store Connect team and does not use the external beta-review step. [Internal testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)

On an iPhone running iOS 17 or later, install **TestFlight**, accept the invitation, and install the demo. Check Wealth, account selection, adding holdings, and Global Investment View before inviting a wider group.

## 7. Invite external testers with a link

Create the internal group first, then an **External Testing** group. Add the build, fill in **What to Test**, and submit it for beta review. The first submitted build requires a full review; later builds for the same version may still need review. Approval timing is determined by Apple.

Once approved and available to test, start testing if it was not distributed automatically. In the external group's **Testers** tab, select **Create Public Link**, configure eligibility and the tester limit, then copy the link. External testing supports up to **10,000 testers per app**. [External groups, review, and public links](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)

Send that TestFlight invitation link to testers. They install the free TestFlight app, open the link, accept the invitation, and install HSBC SG. They do not need the GitHub IPA or a developer account. [Tester instructions](https://testflight.apple.com/)

## 8. Ship the next beta

Increase the build number, create a new signed archive, upload it, and add the processed build to the intended groups. Every build is testable for up to **90 days from upload**; publish a replacement build before it expires. Use App Store Connect's TestFlight feedback and crash reports to review tester findings. [Build lifetime](https://testflight.apple.com/)

## Common blockers

| Symptom | Check |
| --- | --- |
| Only Personal Team is available | Membership activation and the account/team selected in Xcode. |
| Bundle ID is unavailable or a profile cannot be created | Use an identifier your team owns and verify signing access. |
| Build number already used | Increment Build and create a new archive. |
| Uploaded build is missing | Check processing emails, upload errors, and the record's Bundle ID/version. |
| External group cannot select the build | Check processing, compliance, and whether it was uploaded as Internal Only. |
| Invitation cannot install the app | Check build expiry, group distribution, device/iOS eligibility, and tester limits. |

Apple requirements were checked on **September 9, 2026**. Recheck the linked official pages before a later submission.
