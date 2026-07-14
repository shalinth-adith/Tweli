# UI Impact Spec — Firebase Migration

**Feature**: `18-firebase-migration`
**Mode**: MVP
**Scope**: This is a backend swap. No visual redesign — colors, typography, spacing,
gradients, corner radii, and animations in `CreateSpaceView`, `JoinSpaceView`,
`JoinConfirmView`, and `SettingsView` stay pixel-identical. This document specs
which *states*, *copy*, and *data plumbing* change because the thing powering them
underneath is Firestore instead of CloudKit, and which accessibility identifiers
verification needs to drive the flows end-to-end.

Read alongside `requirements.md` R3 (invite flow parity) — this doc is the UI
projection of that section, plus the two other views that touch cloud state.

---

## 1. CreateSpaceView

**File**: `Tweli/Views/Room/CreateSpaceView.swift`

### What changes
- `createInviteLink()` currently: check `CKAccountStatus` → create/poll `CKShare` for
  a server-minted URL → publish pair code pointing at that URL. Under Firebase this
  collapses to one step: generate the space doc + pair code doc in Firestore, then
  build the invite link *client-side* by encoding the pair code into it
  (`https://tweli.app/join?code=XXXXXX` or the `tweli://join?code=XXXXXX` deep link
  itself, planner's call in `api-endpoints.md`/`database.md`). There is no
  "URL isn't minted yet" wait state anymore — `inviteLink` and `pairCode` become
  available together, synchronously with the Firestore write.
- The `preparingShare` spinner state ("Creating link…") stays, but now covers a
  single Firestore write (space doc + pair code doc), not "create CKShare, wait for
  server, then publish code." Expect it to resolve faster in practice, but the UI
  state and button copy are unchanged — still show it until both `inviteLink` and
  `pairCode` are set or an error surfaces.
- `accountStatus()` iCloud pre-flight check is deleted outright — Firebase Auth
  session state is already known before this screen is reachable (R1: auth happens
  earlier in the flow), so there's no per-write account-availability probe to run.
- Error surface (`shareError`) shrinks: the iCloud-specific branches (`noAccount`,
  `restricted`, `couldNotDetermine`, `temporarilyUnavailable`, `quotaExceeded`) are
  gone entirely — this is the whole point of the migration (R-Goal: "users must
  never be blocked by their personal storage"). Replaced by a smaller, generic set:
  network-unavailable and generic-write-failure. See §5 for exact copy.
- `couple.createSpace(title:)` (the "Skip" and "Continue" paths) is unaffected at
  the view layer — it's a call into `CoupleSpaceService`, whose backing store swap
  is invisible here.

### What stays identical
- Layout: `pairingHero`, `titleBlock`, `nameField`, `inviteCard`, `codeCard`,
  `continueBar` — no structural or visual changes.
- `displayCode` formatting (`7GK-4PB`), `shareMessage` text template, copy-to-
  clipboard buttons and their 1.5s "Copied" flash, `ShareLink` usage.
- Two-button bottom bar behavior: "Create space & invite link" (primary) /
  "Skip — set up the link later" (secondary) before an invite exists; "Continue"
  after.

---

## 2. JoinSpaceView

**File**: `Tweli/Views/Room/JoinSpaceView.swift`

### What changes
- `codeToRedeem` / `isCode` / `normalizedCode` logic (via
  `CloudKitService.normalizePairCode`) moves to the Firebase-backed service but the
  *behavior* — uppercase, strip separators, validate 6-char alphabet — is unchanged
  per R2/R3. Reference the static helper on whatever service replaces
  `CloudKitService` (naming is the API spec's call; this view only needs the same
  function signature).
- `pastedURL` handling changes meaningfully: today, pasting the iCloud share URL
  calls `UIApplication.shared.open(url)` and relies on the OS routing back into the
  app via `userDidAcceptCloudKitShareWith` (CKShare acceptance flow, handled outside
  this view). Under Firebase there's no OS-mediated share acceptance — per R3 the
  link itself encodes the pair code. So `pastedURL` should be re-derived as "extract
  `code` query param from any pasted `https://` URL," and route through the *same*
  `codeToRedeem` → `app.joinWithCode(code)` path as a typed code or `tweli://` deep
  link. Net effect: **all three input shapes (typed code, `tweli://join?code=`,
  `https://…?code=`) converge on one redemption path** instead of two (code-redeem
  vs. OS-share-accept). This is a simplification, not a new state — the
  `matchedPreview` / `errorCard` / `joinBar` UI is unaffected because `isValid`,
  `app.joinError`, and `app.redeemingCode` are still the only three signals it reads.
- `matchedPreview` copy currently branches on `isCode` ("Code looks good…" vs
  "Looks like a valid invite link…"). Since both code and link now redeem through
  the identical code-lookup call, this copy can stay as-is (it's describing *input
  shape* to the user, not backend path) — no change required, flagged only so the
  implementer doesn't "fix" it into one string.

### What stays identical
- `header`, `codeField` (with Paste button), `matchedPreview`, `errorCard` layout.
- `onChange(of: input)` clearing `app.joinError`, `onAppear` clearing stale errors.
- Button state machine: disabled until `isValid`, "Finding your space…" while
  `app.redeemingCode`, dimmed at 0.5 opacity when invalid.

---

## 3. JoinConfirmView

**File**: `Tweli/Views/Room/JoinConfirmView.swift`

### What changes
- `invite: PendingInvite` currently wraps `CKShare.Metadata` and derives
  `spaceTitle` / `inviterName` by parsing CloudKit share title strings and iCloud
  identity name components (`Tweli/Models/PendingInvite.swift`). Under Firebase,
  `PendingInvite` becomes a plain struct carrying `spaceTitle: String` and
  `inviterName: String` (and whatever id the join call needs) read directly off the
  Firestore pair-code/space documents — no more string-parsing a share title or
  falling back through `PersonNameComponentsFormatter`. **This view's body reads
  `invite.spaceTitle` / `invite.inviterName` exactly as it does today** — the
  reshape is invisible here as long as those two properties keep their names and
  non-empty fallback behavior (today: `"your shared space"` / `"Your partner"`).
  Flagging this so whoever reshapes `PendingInvite` doesn't silently drop the
  fallback strings — they're load-bearing for the empty/degraded case (e.g. inviter
  has no display name set yet).
- `app.confirmPendingJoin()` swaps `cloud.acceptShare(invite.metadata)` (CKShare
  accept) for a Firestore transaction that atomically adds the joiner's uid to
  `memberUids` (R2: max 2, no takeover). The view doesn't touch this directly — it
  only reacts to the `Bool` return, exactly as today.
- **New failure mode to cover in the transaction's error path** (not visible pre-
  migration because CloudKit's share-accept doesn't race): the atomic max-2-members
  join can fail because the space is already full (partner already joined from
  another device, or a stale/reused invite). `joinFailed` already exists as a state
  — reuse it, but the generic copy ("Couldn't join right now. Check your connection
  and try again.") is misleading for a "space is full" failure. See §5 for the
  split copy.

### What stays identical
- Full layout: pairing-motif avatars, title/subtitle block, description line,
  `PrimaryButton` / "Not now" bottom stack, `presentationDetents`,
  `interactiveDismissDisabled(joining)`.
- `joining` / `joinFailed` state machine and button label transitions
  ("Join space" → "Joining…" → "Try again" on failure).

---

## 4. SettingsView

**File**: `Tweli/Views/Settings/SettingsView.swift`

### What changes
- `row("icloud.fill", "iCloud sync", "On (mock)", .twAccent2)` (line 19) is
  CloudKit-specific in both icon and label and must be replaced. Recommended:
  `row("checkmark.icloud.fill" → "arrow.triangle.2.circlepath", "Sync", <status>,
  .twAccent2)` where `<status>` reflects real connection state instead of the
  literal string `"On (mock)"` (which was already a placeholder, not real status).
  Status values: `"Connected"` (space exists + Firestore listener active),
  `"Offline"` (Firestore's built-in offline persistence is serving cached data —
  R4), `"Not connected"` (no space yet). This turns a dead placeholder row into a
  real, if minimal, status indicator — small scope-add but it's the one row in this
  screen that's *unconditionally* wrong post-migration (it literally says iCloud).
- `Button("Leave shared space", role: .destructive) { couple.disconnect() }` — copy
  and destructive styling unchanged. Under Firebase, `disconnect()` is **local-only**:
  it detaches listeners and clears local state (role, cached spaceId, pair code) via
  `FirebaseService.reset()`, exactly as database.md §8 specifies. The security rules
  intentionally forbid removing a member or deleting the space (`memberUids` is
  frozen after join; `allow delete: if false`), so no remote write is attempted —
  the space and its data remain intact for the partner. No new confirmation step is
  in scope for MVP (matches today's no-confirmation behavior) — flagged as an
  Assumption below since leaving a shared space is normally a "confirm first"
  action.
- `Button("Sign out", ...)` calls `couple.disconnect()` then `auth.signOut()` — under
  R1, `auth.signOut()` now also tears down the Firebase Auth session (in addition to
  whatever Sign in with Apple / keychain cleanup it does today). No UI change.

### What stays identical
- Every other row: Partner, Notifications, Personalization, Widgets, About sections.
- Section ordering, `Form` styling, footer text ("Signed in as … via Apple.").

---

## 5. States, loading, error, empty — copy table

Reuse the existing `PairCodeError` friendly-copy voice (short, second-person,
actionable, no jargon/error codes). One error case is retired outright per the
migration's stated goal.

| Flow | State | Trigger | Copy | Notes |
|---|---|---|---|---|
| Create space | Loading | Firestore space+code write in flight | Button: "Creating link…" (unchanged) | Same `preparingShare` boolean |
| Create space | Error — network | Write fails, no connectivity | "Couldn't create the invite link. Check your connection and try again." | Replaces today's CKError network branch |
| Create space | Error — generic write failure | Any other Firestore write error | "Something went wrong creating your space. Try again in a moment." | Replaces today's generic `error.localizedDescription` catch-all; avoid surfacing raw Firestore error strings to the user |
| Create space | **Retired** | — | — | iCloud storage-full (`quotaExceeded`), `noAccount`, `restricted`, `couldNotDetermine`, `temporarilyUnavailable` — none of these are reachable states anymore. Do not port them. |
| Create space | Empty (pre-write) | Before first tap | Existing helper text: "Tap "Create space & invite link" below…" (unchanged) | |
| Join space | Loading | Redeeming code | Button: "Finding your space…" (unchanged) | Same `app.redeemingCode` |
| Join space | Error — not found | Code doesn't resolve to a pair-code doc | "That code wasn't found. Double-check it, or ask your partner for a fresh one." | Reused verbatim (`PairCodeError.notFound`) |
| Join space | Error — expired | `expiresAt` (48h) has passed | "That code has expired. Ask your partner to create a new invite." | Reused verbatim (`PairCodeError.expired`) |
| Join space | Error — malformed link | Pasted URL/deep link has no valid `code` param | "This invite looks broken. Ask your partner to create a new one." | Reused verbatim (`PairCodeError.badShareURL`), now covers malformed links generically since there's no separate share-URL object to validate |
| Join space | Error — network | Lookup fails, no connectivity | "Couldn't check the code right now. Check your connection and try again." | Reused verbatim (`PairCodeError.network`) |
| Join space | **Retired** | — | — | `shareURLNotReady` ("The invite link isn't ready yet…") — no longer possible once invite links are generated synchronously (R3) |
| Join confirm | Loading | Joining | Button: "Joining…" (unchanged) | |
| Join confirm | Error — generic | Transaction fails, non-full-space reason | "Couldn't join right now. Check your connection and try again." | Existing copy, unchanged |
| Join confirm | **Error — space full (new)** | Atomic join finds `memberUids.count == 2` already | "This space already has two people. Ask your partner to send you a fresh invite." | New case surfaced by Firestore's atomic max-2 rule (R2) — CloudKit's share-accept flow couldn't race this way, so today's UI has no equivalent copy |
| Home (owner) | Waiting | `awaitingPartner` (space created, nobody joined yet) | Existing "Waiting for your partner to join" banner (unchanged) | Now driven by a Firestore listener on `memberUids` instead of polling `acceptedParticipantName()` |
| Settings | Sync status | n/a | "Connected" / "Offline" / "Not connected" | New values, replaces `"On (mock)"` — see §4 |

---

## 6. Intentionally unchanged (do not touch)

- All visual design tokens: `Color.twAccent`, `.twAccent2`, `.twSuccess`, `.twWarn`,
  gradients, corner radii, spacing constants, `tweliEyebrow()` styling.
- `PrimaryButton` component and its enabled/disabled/loading visual states.
- Navigation structure: `navigationTitle`, `.navigationBarTitleDisplayMode(.inline)`,
  `presentationDetents` on `JoinConfirmView`.
- The pair-code alphabet, formatting (`7GK-4PB`), and normalization rules (R2/R3 —
  unchanged from today's `CloudKitService.normalizePairCode`).
- `ShareLink`-based native share sheet usage in `CreateSpaceView` (still the right
  call — `UIActivityViewController` wrapped in `.sheet` is explicitly avoided per
  the existing code comment, and that constraint has nothing to do with the backend).
- Copy-to-clipboard interaction pattern (1.5s "Copied" flash) on both the link and
  the code.
- `HomeView`'s `waitingBanner` visual treatment (icon, colors, layout) — only its
  data source changes (§5).

---

## 7. Accessibility identifiers (for verification)

None exist in the codebase today (checked — zero `.accessibilityIdentifier` usages
project-wide), so this is a new convention for this feature, scoped to what
verification needs to drive the invite flow without relying on visible text (which
this doc is actively changing). Suggested identifiers, `tweli.<view>.<element>`:

- `tweli.createSpace.nameField`
- `tweli.createSpace.createInviteButton`
- `tweli.createSpace.skipButton`
- `tweli.createSpace.continueButton`
- `tweli.createSpace.inviteLinkText`
- `tweli.createSpace.pairCodeText`
- `tweli.createSpace.errorLabel`
- `tweli.joinSpace.codeField`
- `tweli.joinSpace.joinButton`
- `tweli.joinSpace.errorLabel`
- `tweli.joinSpace.matchedPreview`
- `tweli.joinConfirm.joinButton`
- `tweli.joinConfirm.notNowButton`
- `tweli.joinConfirm.errorLabel`
- `tweli.settings.syncStatusRow`
- `tweli.settings.leaveSpaceButton`
- `tweli.settings.signOutButton`

---

## Assumptions

- **[Settings sync status]** Added a real 3-state status ("Connected"/"Offline"/"Not
  connected") to replace the dead `"On (mock)"` placeholder, rather than leaving it
  hardcoded. Reason: the row is unconditionally wrong post-migration (says
  "iCloud"); minimal real status is a near-zero-cost fix that removes a guaranteed
  visual bug. No AskUserQuestion — score ~4 (aesthetic/copy only), silently defaulted
  per rubric.
- **[Leave-space confirmation]** Kept "Leave shared space" as a direct destructive
  action with no confirmation dialog, matching today's behavior exactly, even though
  a second-guess confirmation would be more typical for a destructive multi-user
  action. Reason: out of scope for a backend-swap feature — changing confirmation
  UX is a product decision, not implied by CloudKit→Firebase parity (R6: "cutover,
  not dual-run," not "redesign"). Flagging for a future product pass, not this one.
- **[Invite link format]** Assumed the Firebase invite link can be the same
  `tweli://join?code=XXXXXX` deep-link scheme already used today, or an
  `https://tweli.app/join?code=XXXXXX` universal link — either way it carries the
  code as a query param and `JoinSpaceView` extracts it identically. Left the exact
  domain/scheme choice to the API/DB spec since it's a backend routing decision, not
  a UI one; the UI only needs "one query param named `code`" to hold true.
- **[Space-full error copy]** Wrote new copy for the "space already has two people"
  case since it has no CloudKit-era equivalent to reuse. Kept it in the same
  friendly voice as `PairCodeError` (second-person, actionable, no jargon).
