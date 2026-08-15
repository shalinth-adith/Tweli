# Data hygiene — keeping Firestore small, fast and cheap

Measured on the live `tweli-9a99e` project, 15 August 2026. Numbers, not
guesses — rerun the queries at the bottom before acting on any of it.

## Where the data actually is

```
locations     62 docs   ← 66% of everything, should be 2
letters       10
reminders      9
moods          8        ← should be 2
countdowns     4
virtualDates   1
pings          0
pairCodes      7 total, 4 expired and never removed
```

Two people have produced 62 location records. That single number is the
whole story.

---

## 1. Deterministic document ids for locations and moods

**The problem.** `SharedLocation.id` is a fresh `UUID()` on every capture, and
the Firestore document id is that UUID. So each refresh *appends* rather than
updates. `LocationService.setMyLocation` only updates in place when the local
array already holds a matching record — after a reinstall it does not, so a new
lineage starts.

**The fix.** Key the document by author: `locations/{uid}` instead of
`locations/{randomUUID}`. One document per person, overwritten in place. Same
for `moods`, which is also conceptually "one current value per person".

**Why it matters more than storage.** Firestore bills reads far above storage.
Every listener attach currently reads all 62 documents; with one per person it
reads 2. That happens on every launch, for both people, forever.

It also removes the "8 m apart" bug class at the source. The current fix
(`RecordAuthorship.decode`) reinterprets stale records correctly at read time;
deterministic ids mean stale records never exist.

**Risk.** Touches the sync layer every feature reads through. Needs a migration
for existing rows, or an accepted one-off orphan set the sweep later collects.

---

## 2. Throttle location writes

Accuracy is pinned to `kCLLocationAccuracyKilometer`, so sub-kilometre drift is
noise being persisted. Write only when the fix has moved more than ~1 km, or an
hour has passed, whichever comes first.

Cuts writes, push-function invocations, and battery in one change. Low risk —
it is a guard in `setMyLocation`, not a schema change.

---

## 3. Firestore native TTL — free, no code, do this first

`pairCodes` already carries `expiresAt`, which is exactly the field a TTL policy
consumes. Set a TTL policy on it in the Firebase console and Firestore deletes
expired codes itself: no function, no schedule, no cost.

Four expired codes are sitting there now, and nothing will ever remove them.

`pings` deserve the same treatment — they are ephemeral by design.

Console → Firestore → TTL → add policy on `pairCodes.expiresAt`.

---

## 4. Stop paying for push invocations that do nothing

`notifyPartnerOnItemWrite` matches `spaces/{spaceId}/{type}/{itemId}`, so **every
location write invokes it** purely to hit `if (type === "locations") return;` on
its first line. With hourly refreshes on two devices that is roughly 48 wasted
invocations a day, and it scales linearly with users.

Deploying per-type triggers instead of one wildcard avoids the invocation
entirely rather than returning early from it.

---

## 5. Bound the listeners

Seven live listeners attach per space and stream full history. Letters and
reminders only need what is on screen. A `.limit()` on the initial query would
cut launch-time read cost; the listener still delivers later changes.

---

## 6. Already handled

- **Profile photos never leave the device** (`UserProfile.photoData`), so there
  is no Cloud Storage bill at all.
- **Dead spaces** are swept nightly — fewer than two members, 15 days idle. In
  dry-run until deliberately armed.
- **Leaving** now deletes what you wrote, and the whole space if you were last
  out (`leaveSpace`).

---

## Suggested order

| When | Change | Value | Risk |
|---|---|---|---|
| Today | TTL on `pairCodes`, `pings` | Free, automatic | None — console only |
| Today | 15-day sweep | Done | Dry-run |
| After submission | Deterministic location/mood ids | **Largest** | Sync layer |
| After submission | Location write throttle | Cost + battery | Small |
| Later | Per-type push triggers | Modest | Moderate |
| Later | Bounded listeners | Modest | Moderate |

Items 1, 2 and 4 are deliberately held until after App Review: they modify the
sync layer, and shipping them alongside an unverified release week is a poor
trade for a project whose whole database currently fits in a screenshot.

---

## Rerun the measurements

```bash
node -e '
const admin=require("./functions/node_modules/firebase-admin");
admin.initializeApp({projectId:"tweli-9a99e"});
const db=admin.firestore();
(async()=>{
  let totals={};
  const spaces=await db.collection("spaces").get();
  for (const s of spaces.docs) {
    for (const t of ["reminders","letters","moods","countdowns","locations","pings","virtualDates"]) {
      const c = await s.ref.collection(t).count().get();
      totals[t] = (totals[t]||0) + c.data().count;
    }
  }
  console.log(totals);
})().then(()=>process.exit(0));
'
```
