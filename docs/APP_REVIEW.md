# App Store submission — Tweli 1.0

Everything App Review needs, plus the answers to fill into App Store Connect.
Keep this file updated each submission; it is the checklist, not a summary.

---

## 1. The reviewer-access problem, and how we solve it

Tweli offers **Sign in with Apple and nothing else**. There is no email/password
pair to type into App Store Connect's "Demo Account" fields, and a space holds
**exactly two people** — enforced both by a Firestore transaction and
independently by `firestore.rules`. So a reviewer who signs in with their own
Apple ID lands in an empty, unpaired space and cannot see what the app is for.

**Solution**: pre-seeded demo spaces plus long-lived invite codes. The reviewer
signs in with their own Apple ID, then redeems a demo code and joins a space
that already has a partner, moods, letters, reminders and a countdown in it.
This runs the genuine redemption path — there is no reviewer-only bypass
compiled into the shipping app.

Because each space caps at two members, **each code works exactly once**. Three
are seeded, and they must be reset before every resubmission.

```bash
# from the repo root, with Firebase admin credentials available
GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json node scripts/seed-review-demo.js

node scripts/seed-review-demo.js --status   # which codes are still unused
node scripts/seed-review-demo.js --reset    # rebuild all three before resubmitting
```

Run `--status` immediately before submitting. A code showing `TAKEN` will fail
for the reviewer.

---

## 2. App Review notes (paste into App Store Connect)

> Tweli is a private shared space for two people in a long-distance
> relationship — moods, "open when" letters, shared reminders and countdowns.
> There is no feed, no public profile and no way to discover other users.
>
> **Signing in**
> Tweli uses Sign in with Apple as its only sign-in method, so there is no
> demo username or password. Please sign in with any Apple ID; no personal
> information is required beyond what Apple provides, and Hide My Email is
> fully supported.
>
> **Seeing the app with a partner connected**
> The app is built for two people, so a brand-new account starts in an empty
> space. To see it populated, use one of these invite codes at the
> "Connect with your partner" step:
>
> * RVW-201
> * RVW-202
> * RVW-203
>
> Each code joins a demo space that already contains a partner ("Anaya"),
> her current mood, two open-when letters, two shared reminders and a
> countdown. Each code can be used once — if one reports "this space is
> full", please try the next.
>
> **Location**
> Location is optional and the app is fully usable without it. If you allow
> it, the Home screen shows the approximate distance between you and your
> partner and her local time. Tweli requests city-level accuracy only
> (`kCLLocationAccuracyKilometer`) and never requests location in the
> background.
>
> **Notifications**
> Push notifications tell you when your partner sends a mood, letter or
> reminder. They are optional and requested in context.
>
> **Deleting the account**
> Our space → Your account → Delete my account. This performs a server-side
> deletion of the Firebase account and all associated content.
>
> Privacy policy: https://tweli-9a99e.web.app/privacy

---

## 3. App Store Connect — App Privacy answers

Derived from the code, not guessed. Matches `Tweli/PrivacyInfo.xcprivacy`.

**Do you or your third-party partners collect data from this app?** Yes
**Do you use data for tracking?** No — no ad SDKs, no ad identifiers, no data
shared with brokers. `NSPrivacyTracking` is `false`.

| Data type | Collected | Linked to identity | Used for tracking | Purpose |
|---|---|---|---|---|
| Name | Yes | Yes | No | App Functionality |
| Email Address | Yes (Firebase Auth, often an Apple relay address) | Yes | No | App Functionality |
| Coarse Location | Yes, optional | Yes | No | App Functionality |
| User ID | Yes (Firebase UID) | Yes | No | App Functionality |
| Other User Content | Yes (moods, letters, reminders, countdowns, dates) | Yes | No | App Functionality |
| Other Data Types | Yes (optional birthday and self-typed city) | Yes | No | App Functionality |

Do **not** declare Precise Location: `LocationService` pins
`desiredAccuracy = kCLLocationAccuracyKilometer`.

Profile photos are **not** collected — `UserProfile.photoData` never leaves the
device.

---

## 4. Listing fields

| Field | Value |
|---|---|
| Privacy Policy URL | `https://tweli-9a99e.web.app/privacy` |
| Support URL | `https://tweli-9a99e.web.app/support` |
| Marketing URL | **Leave blank for 1.0.** The landing page's install button still points at TestFlight, so a Marketing URL would take a visitor off the product page and offer them a beta. Fill it in when `INSTALL_URL` is swapped to the App Store link — all four URL fields are editable on a live app without a new build |
| Sign-in required | Yes — see notes above; no demo credentials, use an invite code |
| Export compliance | Already declared: `ITSAppUsesNonExemptEncryption = false` in Info.plist |
| Content rights | No third-party content |
| Age rating | 4+ expected. The app has no user-generated content visible to strangers — content is only ever exchanged between two mutually-paired people |

### The Support URL must reach a page that offers support

Until 2026-08-19 the Support URL was the bare landing page, which had no email
address, no contact form and no support section anywhere on it — only a download
button and a privacy link. Guideline 1.5 expects a user to be able to reach the
developer from that URL, and a marketing page with no contact route is a routine
rejection.

`public/support/index.html` is now the target. It answers what people actually
write in about, and every answer is derived from the code rather than from
memory: invite-code format and its 48-hour expiry, the "space already has two
people" case, the quiet-hours behaviour that otherwise reads as "notifications
are broken", location being optional, reinstalling, and the delete-account path.

Three drafting errors were caught against the source before it shipped, which is
the argument for grepping rather than recalling: the example code `TWLI-4821`
(taken from the design comp, and a string `makeCode()` can never mint because I
and L are excluded), the claim that digits 0 and 1 are excluded (it is the
letters I, L and O that are), and Quiet hours being placed under
`Our space → Notifications` when it is its own screen off `Our space`.

---

## 5. Pre-flight checklist

Work top to bottom. Anything unchecked blocks the upload.

### Build
- [ ] **Do NOT pre-check the signing certificate with `security find-identity`.**
      It will report the distribution certificate as missing even when signing
      works perfectly. See §6 — the only trustworthy check is the exported
      `.ipa`'s own signature, below.
- [ ] `MARKETING_VERSION` set for this release (the build number is automatic — §6)
- [ ] Release build is clean: `xcodebuild -scheme Tweli -configuration Release build`
- [ ] Tests pass: `xcodebuild test -scheme Tweli -destination '<simulator>'`
- [ ] Exported `.ipa` shows `aps-environment = production` and
      `get-task-allow = false` (§6 — check the `.ipa`, never the archive)
- [ ] `PrivacyInfo.xcprivacy` present in **both** `Tweli.app/` and the
      `.appex/` inside it — verify against the `.ipa`, not the source tree

> Note: builds on this Mac must use an external `-derivedDataPath`. The repo
> lives under an iCloud-synced Desktop, and codesign fails against DerivedData
> inside it.

### Backend
- [ ] `firebase deploy --only hosting` — publishes `/privacy`
- [ ] `https://tweli-9a99e.web.app/privacy` loads in a browser
- [ ] `firebase deploy --only firestore:rules,functions` if either changed
- [ ] `node scripts/seed-review-demo.js --reset` then `--status` shows three OPEN codes

### Listing
- [ ] `public/index.html` and `public/join/index.html` both point `INSTALL_URL`
      at the current distribution channel. TestFlight today
      (`https://testflight.apple.com/join/jsJTMSdN`); swap both to
      `https://apps.apple.com/app/id<APP_ID>` the day the app is approved
- [ ] Screenshots for every required device size, from a **populated** space
- [ ] Screenshots are NEWER than the last visual fix. `05-distance.png` shipped a
      globe whose plane flew beside the route instead of along it, because the
      shot was captured 18 Aug 02:38 and the fix landed 19 Aug — compare
      `ls -la ~/Desktop/Tweli-store-screenshots/*/` against `git log` before upload
- [ ] App Privacy answers entered per §3
- [ ] Review notes pasted per §2, with the codes matching what `--status` reports
- [ ] Privacy Policy URL and Support URL set

---

## 6. The push entitlement — verified, and how to re-verify

`Tweli/Tweli.entitlements` declares `aps-environment = development`. That looks
wrong for a shipping build and is not: entitlements are rewritten at **export**,
not at archive time.

> **The verification below predates a change to `Tweli.entitlements` on
> 2026-08-19** (see "Entitlements removed", after the table). The rewrite it
> documents is a property of export and is unaffected in principle — but this
> table is evidence from one specific artifact, and that artifact no longer
> matches the source. Re-run the check against the next exported `.ipa` before
> submitting, and update the date here.

Verified on 2026-08-13 by exporting a real App Store `.ipa`:

| Artifact | `aps-environment` | `get-task-allow` |
|---|---|---|
| `Tweli.entitlements` (source) | development | — |
| `.xcarchive` | development | true |
| **Exported `.ipa`** | **production** | **false** |

So the archive is a misleading place to check — its `get-task-allow = true`
would be an automatic rejection if it were what shipped. Only inspect the
`.ipa`:

```bash
unzip -q -o Tweli.ipa -d /tmp/tweli-ipa
codesign -d --entitlements :- /tmp/tweli-ipa/Payload/Tweli.app 2>/dev/null \
  | plutil -convert xml1 -o - - | grep -A1 -E "aps-environment|get-task-allow"
```

Expected: `production` and `false`. Anything else means the export used the
wrong profile.

### Entitlements removed on 2026-08-19 — do not restore

Both were stale declarations of capabilities the app does not use. Neither was
causing a failure; the risk is that regenerating signing assets later starts
enforcing a capability the App ID never enabled, and you debug it under launch
pressure.

| Removed | From | Why |
|---|---|---|
| `CKSharingSupported` | `Tweli/Info.plist` | CloudKit is gone — only comments in `FirebaseService.swift` still mention it. The key told iOS the app accepts CKShare invitation URLs, which it cannot. Inert without a CloudKit container, but untrue |
| `com.apple.developer.associated-domains.mdm-managed` | `Tweli/Tweli.entitlements` | Lets an MDM server manage the app's associated domains. A consumer app has no MDM story |

`com.apple.developer.associated-domains` itself is KEPT and is required —
`TweliApp.swift` handles `NSUserActivityTypeBrowsingWeb` for https invite links,
and `public/.well-known/apple-app-site-association` serves the matching AASA.
Note `firebase.json` sets `"appAssociation": "NONE"`, which does not disable
universal links: it stops Firebase auto-generating an AASA so the hand-written
file is served instead, with a `headers` rule forcing `application/json`.

Verified after removal by building `-destination 'generic/platform=iOS'` — a real
device build, which is the only kind that runs `ProcessProductPackaging` against
a provisioning profile. A simulator build is ad-hoc signed and its entitlement
blob comes back empty, so it proves nothing here.

### iPhone orientation locked to portrait on 2026-08-19

`INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` previously allowed
landscape left and right. Nothing in the app was ever built for it: there is no
`horizontalSizeClass` / `verticalSizeClass` query anywhere in the source, and
seven screens are half-sheets sized by screen-height fraction — `.fraction(0.62)`
in landscape is a sliver. App Review rotates the device.

Signing identity in use: `Apple Distribution: Shalinth Adithyan (649T62WKAQ)`,
via the cached `iOS Team Store Provisioning Profile: me.adithyan.shalinth.Tweli`.

### `security find-identity` CANNOT see this certificate — do not trust it

This cost an hour on 2026-08-17, so it is worth stating flatly:

```
$ security find-identity -v -p codesigning
  ... "Apple Distribution: Fatbox LLC (B3XL3C9DD9)"     <- a DIFFERENT team
      4 valid identities found                          <- ours is not among them
```

That output is **not** evidence of a problem. `security find-certificate -a -Z`
also fails to find it, and Keychain Access's Certificates / My Certificates /
Keys tabs all show nothing for "Shalinth Adithyan" beyond a development key.
Every one of those tools uses the legacy keychain API.

Xcode 16 keeps automatically-managed signing assets in the **data-protection
keychain**, which the legacy `security(1)` tooling cannot enumerate. The
certificate and its private key are present and usable by Xcode; they are simply
invisible from the command line. On 2026-08-17 an export signed cleanly with
`09B0CC79DACF99C6143D9B9AA3229E8DBB9092C7` minutes after every CLI check
insisted that certificate did not exist.

**The only trustworthy check is the artifact.** Export, then read the signature
off the `.ipa`:

```bash
codesign -dvvv /tmp/tweli-ipa/Payload/Tweli.app 2>&1 | grep -E "Authority|TeamIdentifier"
```

Expected:
```
Authority=Apple Distribution: Shalinth Adithyan (649T62WKAQ)
TeamIdentifier=649T62WKAQ
```

To confirm the exact certificate rather than just its name — names are not
unique, fingerprints are:

```bash
codesign -d --extract-certificates=/tmp/sigcert- /tmp/tweli-ipa/Payload/Tweli.app
openssl x509 -inform DER -in /tmp/sigcert-0 -noout -subject -fingerprint -sha1
```

Expected SHA-1 `09:B0:CC:79:...:92:C7`, matching the certificate the store
profile pins.

> `~/Downloads/distribution.p12` is a backup of this identity. It was NOT needed
> on 2026-08-17, and its password is not known — do not burn time on it. If the
> identity is ever genuinely lost, the recovery is to mint a new certificate and
> regenerate the store profile, which is an account-level change.

### Build numbers are managed by Xcode, not by the project

`CURRENT_PROJECT_VERSION = 1` throughout `project.pbxproj`, but the exported
`.ipa` came out as build **28**. Xcode's `manageAppVersionAndBuildNumber` export
option defaults to `true` for App Store distribution and auto-increments past
the highest build already in App Store Connect.

Editing `CURRENT_PROJECT_VERSION` therefore has no effect on this path. If you
want deterministic build numbers, set `manageAppVersionAndBuildNumber` to
`false` in the export options and bump the project setting yourself.

---

## 7. Known review risks

| Risk | Guideline | Mitigation |
|---|---|---|
| Reviewer cannot get past the pairing step and rejects as "incomplete" | 2.1 | Demo codes in §2; also verify the app is genuinely usable solo before submitting |
| Location purpose questioned | 5.1.1 / 2.5.4 | Purpose string names the exact use; accuracy is coarse; app works fully without it |
| Missing privacy manifest warning (ITMS-91053) | — | `PrivacyInfo.xcprivacy` added to both targets, declaring `NSPrivacyAccessedAPICategoryUserDefaults` reasons `CA92.1` and `1C8F.1` |
| Account deletion not reachable | 5.1.1(v) | Our space → Your account → Delete my account, backed by the `deleteAccount` Cloud Function |
| Minimum iOS 26.0 narrows the test-device pool | — | Deliberate. Reviewers run current OS, so this does not affect review |

---

## 8. What is deliberately not in the app

Do not "fix" these during a review scramble — they are decisions:

- **No analytics SDK.** Nothing to declare, nothing to explain.
- **No seeded or mock content in the shipping build.** A fresh install shows
  genuine empty states. The `TWELI_*` launch hooks used for screenshots are all
  inside `#if DEBUG` and are compiled out of every distribution build.
- **Profile photos stay on-device.** Syncing them needs Firebase Storage, which
  is not wired up.
