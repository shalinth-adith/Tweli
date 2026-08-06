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
    const recipientTz = (space.memberTimezones || {})[recipientUid];
    const quiet = isQuietHour(recipientTz);

    const aps = quiet
      ? { "mutable-content": 1, "interruption-level": "passive" } // no sound key
      : { sound: "default", "mutable-content": 1 };

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

function isQuietHour(tzId) {
  const h = localHour(tzId);
  if (h === null) return false;
  return h >= QUIET_START || h < QUIET_END;
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
      const label = (MOOD_LABELS[p.mood] || "a new mood").toLowerCase();
      const body = trimmed(p.note, "Tap to see how they're feeling.");
      return { title: (name) => `${name} feels ${label}`, body };
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
        return {
          title: (name) => `New reminder from ${name}`,
          body: trimmed(p.title, "A little something to remember 💗"),
        };
      }
      // On edits, only announce a completion (false → true).
      const pb = parsePayload(beforeData);
      if (!pb.isCompleted && p.isCompleted) {
        return {
          title: (name) => `✓ ${name} completed a reminder`,
          body: trimmed(p.title, "a reminder"),
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
      // Announce the letter exists; keep the message itself private until opened.
      return {
        title: (name) => `${name} wrote you a letter 💌`,
        body: trimmed(p.title, "Open when…"),
      };
    }

    case "virtualDates": {
      if (!isCreate) return null;
      return {
        title: (name) => `${name} planned a date`,
        body: trimmed(p.title, "A little something to look forward to 💞"),
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

  const db = getFirestore();
  const summary = { spacesTouched: 0, spacesDeleted: 0, itemsDeleted: 0, codesDeleted: 0 };

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
