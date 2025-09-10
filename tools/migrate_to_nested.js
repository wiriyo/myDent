/*
  Firestore migration: root -> clinics/{clinicId}/...
  - Preserves docId
  - Skips if target already exists (unless --overwrite)
  - Supports --dry-run
  - Collections: patients, appointments

  Usage examples:
    node tools/migrate_to_nested.js --project mydentv1 --dry-run
    node tools/migrate_to_nested.js --project mydentv1
    node tools/migrate_to_nested.js --project mydentv1 --overwrite

  Auth:
    - Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON, or
    - Use gcloud: `gcloud auth application-default login`
*/

/* eslint-disable no-console */
const admin = require('firebase-admin');
const fs = require('fs');

function getArg(flag, fallback = undefined) {
  const idx = process.argv.indexOf(flag);
  if (idx !== -1) {
    return process.argv[idx + 1] ?? true;
  }
  return fallback;
}

async function main() {
  const projectId = getArg('--project') || process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  const dryRun = !!getArg('--dry-run', false);
  const overwrite = !!getArg('--overwrite', false);

  if (!admin.apps.length) {
    const keyPath = getArg('--key');
    if (keyPath) {
      const raw = fs.readFileSync(keyPath, 'utf8');
      const creds = JSON.parse(raw);
      admin.initializeApp({
        credential: admin.credential.cert(creds),
        projectId,
        storageBucket: `${projectId}.appspot.com`,
      });
    } else {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId,
        storageBucket: `${projectId}.appspot.com`,
      });
    }
  }
  const db = admin.firestore();

  console.log('Project:', projectId || '(default)');
  console.log('Dry-run:', dryRun);
  console.log('Overwrite if exists:', overwrite);

  const summary = {
    patients: { scanned: 0, migrated: 0, skipped: 0, missingClinic: 0 },
    appointments: { scanned: 0, migrated: 0, skipped: 0, missingClinic: 0 },
  };

  // Helper: set in batches of N operations
  async function commitInChunks(writes, chunkSize = 400) {
    for (let i = 0; i < writes.length; i += chunkSize) {
      const chunk = writes.slice(i, i + chunkSize);
      if (dryRun) continue;
      const batch = db.batch();
      for (const w of chunk) {
        batch.set(w.ref, w.data, { merge: overwrite });
      }
      await batch.commit();
    }
  }

  // 1) patients
  {
    console.log('\n[patients] scanning root collection...');
    const snap = await db.collection('patients').get();
    const writes = [];
    for (const doc of snap.docs) {
      summary.patients.scanned++;
      const data = doc.data() || {};
      const clinicId = data.clinicId;
      if (!clinicId) {
        summary.patients.missingClinic++;
        console.warn(`[patients] ${doc.id} skipped: missing clinicId`);
        continue;
      }
      const targetRef = db.collection('clinics').doc(clinicId).collection('patients').doc(doc.id);
      const targetSnap = await targetRef.get();
      if (targetSnap.exists && !overwrite) {
        summary.patients.skipped++;
        continue;
      }
      const payload = { ...data };
      // ensure clinicId present
      if (!payload.clinicId) payload.clinicId = clinicId;
      writes.push({ ref: targetRef, data: payload });
      summary.patients.migrated++;
    }
    await commitInChunks(writes);
    console.log('[patients] done', summary.patients);
  }

  // 2) appointments
  {
    console.log('\n[appointments] scanning root collection...');
    const snap = await db.collection('appointments').get();
    const writes = [];
    for (const doc of snap.docs) {
      summary.appointments.scanned++;
      const data = doc.data() || {};
      const clinicId = data.clinicId;
      if (!clinicId) {
        summary.appointments.missingClinic++;
        console.warn(`[appointments] ${doc.id} skipped: missing clinicId`);
        continue;
      }
      const targetRef = db.collection('clinics').doc(clinicId).collection('appointments').doc(doc.id);
      const targetSnap = await targetRef.get();
      if (targetSnap.exists && !overwrite) {
        summary.appointments.skipped++;
        continue;
      }
      const payload = { ...data };
      // ensure required fields
      if (!payload.clinicId) payload.clinicId = clinicId;
      if (!payload.appointmentId) payload.appointmentId = doc.id;

      // Backfill minimal searchKeywords if absent
      if (!Array.isArray(payload.searchKeywords)) {
        const set = new Set();
        const patientName = (payload.patientName || '').toString().toLowerCase();
        patientName.split(' ').forEach((w) => w && set.add(w));
        if (payload.hn_number) set.add(String(payload.hn_number).toLowerCase());
        if (payload.patientPhone) set.add(String(payload.patientPhone));
        payload.searchKeywords = Array.from(set);
      }

      writes.push({ ref: targetRef, data: payload });
      summary.appointments.migrated++;
    }
    await commitInChunks(writes);
    console.log('[appointments] done', summary.appointments);
  }

  console.log('\nMigration summary:', JSON.stringify(summary, null, 2));
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
