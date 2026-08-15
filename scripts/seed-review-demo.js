#!/usr/bin/env node
/**
 * seed-review-demo.js — build the spaces App Review joins.
 *
 * Tweli offers Sign in with Apple and nothing else, so there is no username /
 * password pair to hand App Store Connect. Instead a reviewer signs in with
 * their own Apple ID and redeems a demo invite code, which drops them into a
 * space that already has a partner and real content in it. That exercises the
 * genuine redemption path — no reviewer-only backdoor in the shipping app.
 *
 * A space holds exactly two people (enforced in a transaction AND in
 * firestore.rules), so each code can only ever be used once. We therefore seed
 * several identical spaces and list every code in the review notes: if one is
 * taken, the reviewer moves to the next.
 *
 * Usage, from the repo root:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json node scripts/seed-review-demo.js
 *   ... --reset     tear the demo spaces down and rebuild them (before resubmitting)
 *   ... --status    print what currently exists, change nothing
 *
 * Everything it writes is namespaced under the `review-demo-` uid prefix and the
 * REVW#### codes, so a reset can never touch a real couple's space.
 */

const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));

// ---------------------------------------------------------------------------
// Swift wire format. Items are stored as { payload: <JSON string>, ... } where
// payload is the model run through a stock Swift JSONEncoder. Two details that
// are easy to get wrong and fail silently:
//   - Date uses .deferredToDate: seconds since 2001-01-01Z, NOT the Unix epoch.
//   - UUID encodes as an UPPERCASE string.
// ---------------------------------------------------------------------------
const APPLE_EPOCH_OFFSET = 978307200; // seconds between 1970-01-01 and 2001-01-01

/** JS Date -> the Double a Swift `Date` decodes from. */
const swiftDate = (d) => d.getTime() / 1000 - APPLE_EPOCH_OFFSET;

/** Deterministic uppercase UUID, so re-running the seed overwrites rather than duplicates. */
function uuid(seed) {
  const hex = require("crypto").createHash("sha1").update(seed).digest("hex");
  return [
    hex.slice(0, 8), hex.slice(8, 12),
    "4" + hex.slice(13, 16),
    ((parseInt(hex[16], 16) & 0x3) | 0x8).toString(16) + hex.slice(17, 20),
    hex.slice(20, 32),
  ].join("-").toUpperCase();
}

const daysFromNow = (n) => new Date(Date.now() + n * 86400000);
const daysAgo = (n) => new Date(Date.now() - n * 86400000);

// ---------------------------------------------------------------------------
// The demo couple. Codes use the app's own alphabet: four letters (no I/L/O)
// then four digits, stored without the display hyphen.
// ---------------------------------------------------------------------------
// Six characters, matching FirebaseService.codeLength and every real code.
const CODES = ["RVW201", "RVW202", "RVW203"];
const PARTNER_NAME = "Anaya";
const PARTNER_TZ = "Asia/Dubai";
const SPACE_TITLE = "Our space";
// Abu Dhabi, city-level — matches what the app itself stores (coarse accuracy).
const PARTNER_LAT = 24.45;
const PARTNER_LON = 54.38;
const DAYS_TOGETHER = 284;

const ITEM_TYPES = ["reminders", "countdowns", "letters", "virtualDates", "moods", "pings", "locations"];

/** Every seeded document for one space, keyed by subcollection. */
function contentFor(spaceUuid, partnerUuid) {
  const now = new Date();
  return {
    moods: [{
      id: uuid(spaceUuid + ":mood"),
      body: {
        userId: partnerUuid,
        mood: "missingYou",
        note: "Long day at the studio. Wish you were here for the walk home.",
        updatedAt: swiftDate(new Date(now.getTime() - 40 * 60000)),
      },
    }],
    locations: [{
      id: uuid(spaceUuid + ":loc"),
      body: {
        userId: partnerUuid,
        latitude: PARTNER_LAT,
        longitude: PARTNER_LON,
        cityLabel: "Abu Dhabi",
        timeZoneId: PARTNER_TZ,
        updatedAt: swiftDate(new Date(now.getTime() - 90 * 60000)),
      },
    }],
    letters: [
      {
        id: uuid(spaceUuid + ":letter1"),
        body: {
          title: "Open when you miss me",
          message: "Then read this twice. I kept the ticket stub from the airport — " +
                   "it is in the blue book on my desk. Forty-one days.",
          createdBy: partnerUuid,
          coupleSpaceId: spaceUuid,
          isOpened: false,
          createdAt: swiftDate(daysAgo(6)),
        },
      },
      {
        id: uuid(spaceUuid + ":letter2"),
        body: {
          title: "Open when you land",
          message: "You made it. Go straight to the window seat at the cafe and " +
                   "text me what you can see.",
          createdBy: partnerUuid,
          coupleSpaceId: spaceUuid,
          unlockDate: swiftDate(daysFromNow(41)),
          isOpened: false,
          createdAt: swiftDate(daysAgo(3)),
        },
      },
    ],
    reminders: [
      {
        id: uuid(spaceUuid + ":rem1"),
        body: {
          title: "Call before her stand-up",
          note: "She is three and a half hours ahead.",
          createdBy: partnerUuid,
          assignedTo: "both",
          coupleSpaceId: spaceUuid,
          reminderDate: swiftDate(new Date(now.getTime() + 5 * 3600000)),
          repeatType: "weekly",
          visibility: "shared",
          priority: "important",
          status: "pending",
          isCompleted: false,
          createdAt: swiftDate(daysAgo(12)),
          updatedAt: swiftDate(daysAgo(12)),
          authorTimezone: PARTNER_TZ,
        },
      },
      {
        id: uuid(spaceUuid + ":rem2"),
        body: {
          title: "Renew the passport",
          note: "",
          createdBy: partnerUuid,
          assignedTo: "partner",
          coupleSpaceId: spaceUuid,
          reminderDate: swiftDate(daysFromNow(9)),
          repeatType: "none",
          visibility: "shared",
          priority: "normal",
          status: "pending",
          isCompleted: false,
          createdAt: swiftDate(daysAgo(4)),
          updatedAt: swiftDate(daysAgo(4)),
          authorTimezone: PARTNER_TZ,
        },
      },
    ],
    countdowns: [{
      id: uuid(spaceUuid + ":cd1"),
      body: {
        title: "She flies in",
        targetDate: swiftDate(daysFromNow(41)),
        note: "Terminal 3, just before midnight.",
        category: "meeting",
        isPinned: true,
        createdBy: partnerUuid,
        coupleSpaceId: spaceUuid,
        createdAt: swiftDate(daysAgo(20)),
      },
    }],
  };
}

// ---------------------------------------------------------------------------

async function tearDown(db, spaceId) {
  for (const type of ITEM_TYPES) {
    const snap = await db.collection("spaces").doc(spaceId).collection(type).get();
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    if (snap.size) await batch.commit();
  }
  await db.collection("spaces").doc(spaceId).delete();
}

async function seedOne(db, index) {
  const code = CODES[index];
  const partnerUid = `review-demo-partner-${index + 1}`;
  const partnerUuid = uuid(code + ":partner");
  const spaceRef = db.collection("spaces").doc(`review-demo-space-${index + 1}`);
  const spaceUuid = uuid(code + ":space");

  await spaceRef.set({
    title: SPACE_TITLE,
    ownerUid: partnerUid,
    memberUids: [partnerUid],
    memberNames: { [partnerUid]: PARTNER_NAME },
    memberTimezones: { [partnerUid]: PARTNER_TZ },
    createdAt: admin.firestore.Timestamp.fromDate(daysAgo(DAYS_TOGETHER)),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const content = contentFor(spaceUuid, partnerUuid);
  let count = 0;
  for (const [type, items] of Object.entries(content)) {
    for (const item of items) {
      await spaceRef.collection(type).doc(item.id).set({
        payload: JSON.stringify({ id: item.id, ...item.body }),
        authorUid: partnerUid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        schemaVersion: 1,
      });
      count += 1;
    }
  }

  // Ten years out: review rounds should never hit an expired demo code.
  await db.collection("pairCodes").doc(code).set({
    spaceId: spaceRef.id,
    spaceTitle: SPACE_TITLE,
    createdBy: partnerUid,
    createdByName: PARTNER_NAME,
    expiresAt: admin.firestore.Timestamp.fromDate(daysFromNow(3650)),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { code, spaceId: spaceRef.id, items: count };
}

async function status(db) {
  console.log("Demo space status\n");
  for (let i = 0; i < CODES.length; i += 1) {
    const id = `review-demo-space-${i + 1}`;
    const snap = await db.collection("spaces").doc(id).get();
    if (!snap.exists) {
      console.log(`  ${CODES[i]}  MISSING — run without --status to seed`);
      continue;
    }
    const members = snap.data().memberUids || [];
    const free = members.length < 2;
    console.log(`  ${CODES[i]}  ${free ? "OPEN  — a reviewer can join" : "TAKEN — already has two members"}` +
                `  (${members.length}/2)`);
  }
  console.log("\nA TAKEN space needs --reset before the next submission.");
}

async function main() {
  const args = process.argv.slice(2);
  admin.initializeApp({ projectId: "tweli-9a99e" });
  const db = admin.firestore();

  if (args.includes("--status")) {
    await status(db);
    return;
  }

  if (args.includes("--reset")) {
    console.log("Removing existing demo spaces...");
    for (let i = 0; i < CODES.length; i += 1) {
      await tearDown(db, `review-demo-space-${i + 1}`);
      await db.collection("pairCodes").doc(CODES[i]).delete();
    }
  }

  console.log("Seeding demo spaces...\n");
  for (let i = 0; i < CODES.length; i += 1) {
    const r = await seedOne(db, i);
    const display = `${r.code.slice(0, 3)}-${r.code.slice(3)}`;
    console.log(`  ${display}  ->  ${r.spaceId}  (${r.items} items, partner "${PARTNER_NAME}")`);
  }

  console.log("\nDone. Put these codes in the App Review notes:");
  console.log("  " + CODES.map((c) => `${c.slice(0, 3)}-${c.slice(3)}`).join("   "));
}

main().then(() => process.exit(0)).catch((err) => {
  console.error("\nSeed failed:", err && err.message ? err.message : err);
  process.exit(1);
});
