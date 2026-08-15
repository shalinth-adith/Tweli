//
//  Tweli Cloud Functions — partner push notifications.
//
//  The iOS client writes every shared item as a "thin payload" document at
//  spaces/{spaceId}/{type}/{itemId} with { payload: <JSON>, authorUid, updatedAt }.
//  It also stores each device's FCM token on the space doc under fcmTokens[uid].
//
//  This one function reacts to those writes: it works out who authored the
//  change, finds the OTHER member of the space, and sends them an FCM push.
//  No client change is required — everything it needs is already on disk.
//
//  Types handled: moods, reminders, pings, countdowns, letters, virtualDates.
//  locations are intentionally ignored (they update constantly = notification spam).
//

const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");

initializeApp();
// Collocate with the Firestore database (asia-south1 / Mumbai) so the trigger
// and function run in the same region — no cross-region hop, lower latency.
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

// Mirror of PartnerMood.label (Tweli/Models/Enums.swift). Keep in sync if you
// add a mood case on the client.
const MOOD_LABELS = {
  missingYou: "Missing you",
  excitedToMeet: "Excited to meet",
  calm: "Calm",
  content: "Content",
  overwhelmed: "Overwhelmed",
  lowEnergy: "Low energy",
  thinkingOfYou: "Thinking of you",
  needCall: "Need a call",
  needSpace: "Need space",
};

exports.notifyPartnerOnItemWrite = onDocumentWritten(
  "spaces/{spaceId}/{type}/{itemId}",
  async (event) => {
    const { spaceId, type } = event.params;
    if (type === "locations") return; // too noisy to notify on

    const after = event.data && event.data.after;
    if (!after || !after.exists) return; // deletion — nothing to announce

    const before = event.data.before;
    const isCreate = !before || !before.exists;

    const afterData = after.data() || {};
    const beforeData = before && before.exists ? before.data() : {};

    const notif = buildNotification(type, afterData, beforeData, isCreate);
    if (!notif) return; // this particular change isn't worth a push

    const authorUid = afterData.authorUid;
    if (!authorUid) return; // pre-authorUid legacy doc — can't tell who to notify

    // Find the recipient (the member who is NOT the author) and their token.
    const db = getFirestore();
    const spaceSnap = await db.doc(`spaces/${spaceId}`).get();
    if (!spaceSnap.exists) return;

    const space = spaceSnap.data() || {};
    const members = Array.isArray(space.memberUids) ? space.memberUids : [];
    const recipientUid = members.find((u) => u !== authorUid);
    if (!recipientUid) return; // partner hasn't joined yet

    const token = (space.fcmTokens || {})[recipientUid];
    if (!token) return; // recipient has no registered device

    const names = space.memberNames || {};
    const authorName = (names[authorUid] || "Your partner").trim() || "Your partner";

    // Quiet hours: if it's night where the RECIPIENT is, deliver silently — the
    // banner still lands on their lock screen, but with no sound and a "passive"
    // interruption level so it never buzzes or wakes the screen. They see it when
    // they wake. Requires memberTimezones[recipientUid]; without it we assume day.
    // Comp V3: the recipient's own switches decide whether this type is sent at
    // all, and their own quiet window replaces the constants below. Absent prefs
    // fall back to those constants, so anyone who never opened the screen keeps
    // exactly the behaviour they had.
    const prefs = ((space.notificationPrefs || {})[recipientUid]) || {};
    if (!wantsType(prefs, type)) {
      console.log(`push skipped by preference: ${type} -> ${recipientUid}`);
      return;
    }

    const recipientTz = (space.memberTimezones || {})[recipientUid];
    const quiet = isQuietHour(recipientTz, prefs);

    // `notif.silent` is the comps' own rule for two kinds of push: a completion
    // echo (RA5) and a mood change (RA8). Both arrive without sound or badge
    // even outside quiet hours — they are news, not demands.
    const hush = quiet || notif.silent === true;
    const aps = hush
      ? { "mutable-content": 1, "interruption-level": "passive" } // no sound key
      : { sound: "default", "mutable-content": 1 };
    // The category is what gives a pulled-open notification its buttons
    // (RA3/RA6/RA7/RA8/RA9). Without it iOS shows the text and nothing else.
    if (notif.category) aps.category = notif.category;

    const message = {
      token,
      notification: {
        title: notif.title(authorName),
        body: notif.body,
      },
      apns: { payload: { aps } },
      // The client's didReceiveRemoteNotification uses this to nudge a sync /
      // deep-link to the right tab.
      data: { type: String(type), spaceId: String(spaceId), quiet: String(quiet) },
    };

    try {
      await getMessaging().send(message);
      console.log(`push sent: ${type} → ${recipientUid}`);
    } catch (err) {
      const code = err && err.code;
      // Prune a dead token so we stop retrying it every write.
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token" ||
        code === "messaging/invalid-argument"
      ) {
        await db
          .doc(`spaces/${spaceId}`)
          .update({ [`fcmTokens.${recipientUid}`]: FieldValue.delete() })
          .catch(() => {});
      }
      console.error(`push failed (${type}):`, code, err && err.message);
    }
  }
);

// ---------------------------------------------------------------------------

// Quiet hours = recipient-local 22:00–07:59. Returns false if we can't resolve
// their timezone (fail open: better a rare late buzz than a silently-swallowed
// notification).
const QUIET_START = 22; // 10pm
const QUIET_END = 8; //  8am

function isQuietHour(tzId, prefs) {
  const h = localHour(tzId);
  if (h === null) return false;
  const start = Number.isInteger(prefs && prefs.quietStart) ? prefs.quietStart : QUIET_START;
  const end = Number.isInteger(prefs && prefs.quietEnd) ? prefs.quietEnd : QUIET_END;
  if (start === end) return false;                       // empty window
  return start > end ? (h >= start || h < end)           // crosses midnight
    : (h >= start && h < end);
}

// Maps a Firestore subcollection to the V3 switch that governs it. An unknown
// type is allowed through: silence should be something the user chose, never a
// side effect of adding a new item type and forgetting to map it.
const TYPE_SWITCH = {
  moods: "moods",
  letters: "letters",
  reminders: "reminders",
  countdowns: "countdownMilestones",
  pings: "moods",            // a nudge is the same "from her" channel as a mood
  virtualDates: "reminders",  // a planned date is a Tweli nudge, not her voice
};

function wantsType(prefs, type) {
  const key = TYPE_SWITCH[type];
  if (!key) return true;
  return prefs[key] !== false;   // default ON when unset
}

/** Current hour (0–23) in the given IANA timezone, or null if unresolved. */
function localHour(tzId) {
  if (!tzId || typeof tzId !== "string") return null;
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: tzId,
      hour: "2-digit",
      hourCycle: "h23",
    }).formatToParts(new Date());
    const hourPart = parts.find((p) => p.type === "hour");
    const h = hourPart ? parseInt(hourPart.value, 10) : NaN;
    return Number.isNaN(h) ? null : h % 24;
  } catch (_e) {
    return null; // invalid identifier
  }
}

function parsePayload(data) {
  try {
    return data && data.payload ? JSON.parse(data.payload) : {};
  } catch (_e) {
    return {};
  }
}

function trimmed(s, fallback) {
  const t = typeof s === "string" ? s.trim() : "";
  return t.length ? t : fallback;
}

/**
 * Returns { title: (authorName) => string, body: string } for changes worth a
 * push, or null to stay silent (e.g. a routine edit, or a reminder someone
 * assigned only to themselves).
 */
function buildNotification(type, afterData, beforeData, isCreate) {
  const p = parsePayload(afterData);

  switch (type) {
    case "moods": {
      // Notify on create AND update — a changed mood is the whole point.
      // RA8: "Anaya is feeling worn out". Silent and never repeated — one per
      // change — so the category carries no sound and the client presents it
      // without one.
      const label = (MOOD_LABELS[p.mood] || "a new mood").toLowerCase();
      const body = trimmed(p.note, "Tap to see how they're feeling.");
      return {
        title: (name) => `${name} is feeling ${label}`,
        body,
        category: "tweli.mood",
        silent: true,
      };
    }

    case "pings": {
      // p.message already reads e.g. "Shalinth misses you ❤️".
      const body = trimmed(p.message, "is thinking of you");
      return { title: () => "💌 A little love", body };
    }

    case "reminders": {
      // Skip reminders someone kept for themselves.
      if (p.assignedTo === "me") return null;

      if (isCreate) {
        // RA2: "Anaya set a reminder for you".
        return {
          title: (name) => `${name} set a reminder for you`,
          body: trimmed(p.title, "A little something to remember 💗"),
          category: "tweli.reminder",
        };
      }
      // On edits, only announce a completion (false → true).
      const pb = parsePayload(beforeData);
      if (!pb.isCompleted && p.isCompleted) {
        // RA5: "Anaya got it done" — comes back quietly. No sound, no badge.
        return {
          title: (name) => `${name} got it done`,
          body: trimmed(p.title, "a reminder"),
          category: "tweli.completion",
          silent: true,
        };
      }
      return null;
    }

    case "countdowns": {
      if (!isCreate) return null;
      return {
        title: (name) => `${name} started a countdown`,
        body: trimmed(p.title, "Counting down together ⏳"),
      };
    }

    case "letters": {
      if (!isCreate) return null;
      // RA7: a letter NEVER previews on the lock screen. Not the message, and
      // not the "open when…" label either — the comp's body is a fixed
      // "Sealed until you open it." Anyone glancing at the phone learns that a
      // letter arrived and nothing more, which is the point of sealing one.
      return {
        title: (name) => `${name} sent you a letter`,
        body: "Sealed until you open it.",
        category: "tweli.letter",
      };
    }

    case "virtualDates": {
      if (!isCreate) return null;
      // RA9.
      return {
        title: (name) => `${name} planned a date`,
        body: trimmed(p.title, "A little something to look forward to 💞"),
        category: "tweli.date",
      };
    }

    default:
      return null;
  }
}


// ---------------------------------------------------------------------------
// Permanent account deletion (App Store guideline 5.1.1(v)).
//
// Runs server-side for two reasons the client cannot work around:
//   1. Firestore has no recursive delete from a client SDK, and the rules that
//      (correctly) stop you touching a space you have left also stop you
//      cleaning up on the way out.
//   2. Admin `deleteUser` has no "recent login" requirement, so a user whose
//      last sign-in was weeks ago can still delete without a re-auth dance.
//
// What it removes, per the product decision: everything the caller AUTHORED.
// A partner's own letters and reminders survive, and they are told via the
// same `leftBy` marker that drives the "left the space" screen. If the caller
// was alone in the space, the space and all of its contents go too.
//
// Called over plain HTTPS with a Firebase ID token, so the app needs no
// Functions client SDK:
//   POST https://asia-south1-<project>.cloudfunctions.net/deleteAccount
//   Authorization: Bearer <idToken>
// ---------------------------------------------------------------------------

const ITEM_TYPES = [
  "reminders", "countdowns", "letters",
  "virtualDates", "moods", "pings", "locations",
];

/** Deletes every doc a query matches, in batches (Firestore caps at 500/batch). */
async function deleteQueryInBatches(db, query) {
  let removed = 0;
  for (;;) {
    const snap = await query.limit(400).get();
    if (snap.empty) return removed;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    removed += snap.size;
    if (snap.size < 400) return removed;
  }
}

/**
 * Unseals every letter this user wrote so their partner can read them, and
 * leaves them in place. Rewrites the stored payload's unlockDate to now — the
 * client decides "sealed" purely from that field, so clearing it is what
 * actually delivers the letter.
 */
async function unsealLettersBy(db, collection, uid) {
  const snap = await collection.where("authorUid", "==", uid).get();
  if (snap.empty) return 0;

  const batch = db.batch();
  let count = 0;
  const nowIso = new Date().toISOString();
  snap.docs.forEach((doc) => {
    let payload;
    try {
      payload = JSON.parse(doc.data().payload || "{}");
    } catch {
      return;                       // unreadable payload — leave it untouched
    }
    // Only sealed letters need changing; already-open ones simply stay.
    if (payload.unlockDate) {
      payload.unlockDate = nowIso;
      batch.update(doc.ref, { payload: JSON.stringify(payload) });
    }
    count += 1;
  });
  await batch.commit();
  return count;
}

exports.deleteAccount = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Use POST." });
    return;
  }

  // --- Authenticate. The uid comes from a verified token, never from the body,
  // so a caller can only ever delete themselves.
  const header = req.get("Authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) {
    res.status(401).json({ error: "Missing bearer token." });
    return;
  }

  let uid;
  try {
    uid = (await getAuth().verifyIdToken(token)).uid;
  } catch (err) {
    console.error("deleteAccount: bad token:", err && err.message);
    res.status(401).json({ error: "Invalid token." });
    return;
  }

  // Comp W3 "Deliver my sealed letters first": unseal the letters this user
  // wrote and leave them with their partner instead of erasing them. Opt-in —
  // the default remains "everything you authored goes".
  const keepLetters = !!(req.body && req.body.keepLetters);

  const db = getFirestore();
  const summary = {
    spacesTouched: 0, spacesDeleted: 0, itemsDeleted: 0,
    codesDeleted: 0, lettersLeftBehind: 0,
  };

  try {
    // --- Every space this user belongs to (normally exactly one).
    const spaces = await db
      .collection("spaces")
      .where("memberUids", "array-contains", uid)
      .get();

    for (const spaceDoc of spaces.docs) {
      summary.spacesTouched += 1;
      const members = (spaceDoc.data().memberUids || []).filter((u) => u !== uid);
      const alone = members.length === 0;

      for (const type of ITEM_TYPES) {
        const col = spaceDoc.ref.collection(type);

        // Letters are the one thing a user can choose to leave behind — but
        // only when someone is still there to receive them. Alone in the space,
        // there is no one to keep them and they go with everything else.
        if (type === "letters" && keepLetters && !alone) {
          summary.lettersLeftBehind += await unsealLettersBy(db, col, uid);
          continue;
        }

        // Alone: the space dies with them, so take everything. Otherwise take
        // only what this user wrote and leave the partner's records intact.
        const query = alone ? col : col.where("authorUid", "==", uid);
        summary.itemsDeleted += await deleteQueryInBatches(db, query);
      }

      if (alone) {
        await spaceDoc.ref.delete();
        summary.spacesDeleted += 1;
      } else {
        // Same shape the client's "leave" writes, so the remaining partner's
        // listener raises the "left the space" screen rather than silently
        // finding themselves alone.
        await spaceDoc.ref.update({
          memberUids: FieldValue.arrayRemove(uid),
          [`memberNames.${uid}`]: FieldValue.delete(),
          [`fcmTokens.${uid}`]: FieldValue.delete(),
          [`memberTimezones.${uid}`]: FieldValue.delete(),
          // The profile the X1–X6 flow collects. Account deletion promises the
          // user's data is removed — leaving their bio, city and birthday on a
          // space their partner still owns would quietly break that.
          [`memberBios.${uid}`]: FieldValue.delete(),
          [`memberCities.${uid}`]: FieldValue.delete(),
          [`memberBirthdays.${uid}`]: FieldValue.delete(),
          leftBy: uid,
          leftAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }

    // --- Any invite codes they minted, so a stale code can't resurrect them.
    summary.codesDeleted += await deleteQueryInBatches(
      db,
      db.collection("pairCodes").where("createdBy", "==", uid)
    );

    // --- The account itself. Last, so a failure above leaves a user who can
    // still sign in and retry rather than an orphaned pile of data.
    await getAuth().deleteUser(uid);

    console.log(`deleteAccount: ${uid} removed`, summary);
    res.status(200).json({ ok: true, ...summary });
  } catch (err) {
    console.error("deleteAccount failed for", uid, err && err.message);
    res.status(500).json({ error: "Deletion failed. Nothing was partially removed from your account record." });
  }
});

// ---------------------------------------------------------------------------
// Leaving a space, properly.
//
// Leaving used to only edit `memberUids` client-side. Everything the leaver had
// written — reminders, moods, locations — stayed in the space, along with their
// name, and because `allow delete: if false` guards the space document the
// client could never clean up after itself. A space you walked out of therefore
// kept your data forever, and an emptied one lingered as a permanent orphan.
//
// The rule this restores is the one `deleteAccount` already encodes: alone in
// the space, it dies with you; with a partner still there, your records go and
// theirs are untouched. Letters are the single exception, kept for the partner
// per the W1–W3 exit flow — there is someone left to read them.
//
// Server-side because two of the required operations are impossible from the
// client: deleting the space document, and deleting items after you have
// removed yourself from `memberUids` (the item rule requires membership).
// ---------------------------------------------------------------------------
exports.leaveSpace = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Use POST." });
    return;
  }

  const header = req.get("Authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) {
    res.status(401).json({ error: "Missing bearer token." });
    return;
  }

  let uid;
  try {
    uid = (await getAuth().verifyIdToken(token)).uid;
  } catch (err) {
    console.error("leaveSpace: bad token:", err && err.message);
    res.status(401).json({ error: "Invalid token." });
    return;
  }

  const spaceId = req.body && req.body.spaceId;
  if (!spaceId || typeof spaceId !== "string") {
    res.status(400).json({ error: "spaceId required." });
    return;
  }

  const db = getFirestore();
  const ref = db.collection("spaces").doc(spaceId);

  try {
    const snap = await ref.get();
    if (!snap.exists) {
      res.json({ ok: true, alreadyGone: true });
      return;
    }

    const data = snap.data() || {};
    const members = data.memberUids || [];
    // The uid comes from a verified token, so this cannot be used to evict
    // someone else from a space they are in.
    if (!members.includes(uid)) {
      res.status(403).json({ error: "Not a member of that space." });
      return;
    }

    const remaining = members.filter((u) => u !== uid);
    const alone = remaining.length === 0;
    const summary = { itemsDeleted: 0, spaceDeleted: false, lettersLeftBehind: 0 };

    for (const type of ITEM_TYPES) {
      const col = ref.collection(type);
      // Someone is still here, so the letters you sealed for them stay — the
      // exit flow promises exactly that. Alone, there is nobody to keep them.
      if (type === "letters" && !alone) {
        summary.lettersLeftBehind += await unsealLettersBy(db, col, uid);
        continue;
      }
      const query = alone ? col : col.where("authorUid", "==", uid);
      summary.itemsDeleted += await deleteQueryInBatches(db, query);
    }

    if (alone) {
      await ref.delete();
      summary.spaceDeleted = true;
    } else {
      await ref.update({
        memberUids: FieldValue.arrayRemove(uid),
        // The name moves to `leftByName` rather than lingering in memberNames:
        // comp E6 still needs to say who left, and nothing else should keep
        // holding the identity of someone who is gone.
        leftByName: (data.memberNames || {})[uid] || "Your partner",
        [`memberNames.${uid}`]: FieldValue.delete(),
        [`fcmTokens.${uid}`]: FieldValue.delete(),
        [`memberTimezones.${uid}`]: FieldValue.delete(),
        [`memberBios.${uid}`]: FieldValue.delete(),
        [`memberCities.${uid}`]: FieldValue.delete(),
        [`memberBirthdays.${uid}`]: FieldValue.delete(),
        leftBy: uid,
        leftAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    console.log(`leaveSpace: ${uid} left ${spaceId}`, summary);
    res.json({ ok: true, ...summary });
  } catch (err) {
    console.error("leaveSpace failed:", err && err.message);
    res.status(500).json({ error: "Could not leave the space." });
  }
});
