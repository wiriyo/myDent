/*
  Cleanup legacy data (Firestore root collections + Storage folders)
  - Removes legacy root data that is no longer used after migrating to nested structure
  - Supports dry-run and selective deletion via flags

  Usage examples:
    node tools/cleanup_legacy.js --project mydentv1 --dry-run
    node tools/cleanup_legacy.js --project mydentv1 --delete-root-patients --delete-root-appointments --delete-root-settings --delete-global-masters --delete-legacy-storage --yes

  Auth:
    - Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON with owner/editor rights, or
    - Use gcloud: `gcloud auth application-default login`
*/

/* eslint-disable no-console */
const admin = require('firebase-admin');
const fs = require('fs');

function hasFlag(name) {
  return process.argv.includes(name);
}
function getArg(flag, fallback = undefined) {
  const idx = process.argv.indexOf(flag);
  if (idx !== -1) return process.argv[idx + 1] ?? true;
  return fallback;
}

function getCSVArg(flag) {
  const v = getArg(flag);
  if (!v) return null;
  if (v === true) return [];
  return String(v)
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

async function confirmOrExit(text) {
  if (hasFlag('--yes')) return;
  process.stdout.write(`${text} (type YES to continue): `);
  return new Promise((resolve) => {
    process.stdin.resume();
    process.stdin.setEncoding('utf8');
    process.stdin.once('data', (data) => {
      process.stdin.pause();
      if (data.trim() === 'YES') resolve();
      else {
        console.log('Aborted.');
        process.exit(0);
      }
    });
  });
}

async function deleteCollection(db, colRef, { dryRun, label, batchSize = 400 }) {
  let total = 0;
  while (true) {
    const snap = await colRef.limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    if (!dryRun) await batch.commit();
    total += snap.size;
    console.log(`  - deleted ${snap.size} docs from ${label} (total ${total})`);
  }
  return total;
}

async function deleteDocWithSubcollections(db, docRef, { dryRun, subcollections = [] }) {
  // delete known subcollections then the doc
  for (const sub of subcollections) {
    const subRef = docRef.collection(sub);
    await deleteCollection(db, subRef, { dryRun, label: `${docRef.path}/${sub}` });
  }
  if (!dryRun) await docRef.delete();
}

async function deleteRootPatients(db, { dryRun }) {
  console.log('\n[Firestore] Deleting root patients (+subcollections treatments, medical_images)');
  const patientsRef = db.collection('patients');
  const snap = await patientsRef.get();
  let count = 0;
  for (const doc of snap.docs) {
    await deleteDocWithSubcollections(db, doc.ref, { dryRun, subcollections: ['treatments', 'medical_images'] });
    count++;
    if (count % 100 === 0) console.log(`  processed ${count}/${snap.size}`);
  }
  console.log(`  done: ${count} patients removed${dryRun ? ' (dry-run)' : ''}`);
}

async function deleteRootAppointments(db, { dryRun }) {
  console.log('\n[Firestore] Deleting root appointments');
  const col = db.collection('appointments');
  const total = await deleteCollection(db, col, { dryRun, label: 'appointments' });
  console.log(`  done: ${total} appointments removed${dryRun ? ' (dry-run)' : ''}`);
}

async function deleteRootSettings(db, { dryRun }) {
  console.log('\n[Firestore] Deleting root settings (clinicWorkingHours)');
  const ref = db.collection('settings').doc('clinicWorkingHours');
  const snap = await ref.get();
  if (snap.exists) {
    if (!dryRun) await ref.delete();
    console.log('  removed settings/clinicWorkingHours');
  } else {
    console.log('  nothing to delete');
  }
}

async function deleteGlobalMasters(db, { dryRun }) {
  console.log('\n[Firestore] Deleting global masters (prefix_master, treatment_master)');
  const totalPrefix = await deleteCollection(db, db.collection('prefix_master'), { dryRun, label: 'prefix_master' });
  const totalTreatment = await deleteCollection(db, db.collection('treatment_master'), { dryRun, label: 'treatment_master' });
  console.log(`  done: prefix=${totalPrefix}, treatment=${totalTreatment}${dryRun ? ' (dry-run)' : ''}`);
}

async function deleteLegacyStorage(storage, db, { dryRun, onlyPrefixes = null }) {
  console.log('\n[Storage] Deleting legacy patient folders under medical_images/{patientId}');
  const bucket = storage.bucket();

  // list clinic ids from Firestore to distinguish top-level prefixes
  const clinicsSnap = await db.collection('clinics').get();
  const clinicIds = new Set(clinicsSnap.docs.map((d) => d.id));
  console.log(`  loaded ${clinicIds.size} clinic ids to identify nested folders`);

  // list objects with prefix 'medical_images/'
  // Using @google-cloud/storage via admin SDK under the hood
  const [files] = await bucket.getFiles({ prefix: 'medical_images/' });
  // Also list prefixes by querying bucket.getFiles with auto pagination
  // Build a map of top-level prefixes under medical_images/
  const topLevelPrefixSet = new Set();
  files.forEach((f) => {
    const name = f.name; // e.g., medical_images/patient123/xyz.jpg or medical_images/clinicA/patient123/...
    const parts = name.split('/');
    if (parts.length >= 2) {
      topLevelPrefixSet.add(parts[1]);
    }
  });

  let topLevelPrefixes = Array.from(topLevelPrefixSet);
  if (onlyPrefixes && onlyPrefixes.length) {
    topLevelPrefixes = topLevelPrefixes.filter((p) => onlyPrefixes.includes(p));
    console.log(`  filtered prefixes by --only-prefixes: ${topLevelPrefixes.length} match(es)`);
  }
  let totalDeleted = 0;
  let skipped = 0;

  async function deletePrefixRecursively(prefix) {
    const [toDelete] = await bucket.getFiles({ prefix: `medical_images/${prefix}/` });
    if (toDelete.length === 0) return 0;
    if (dryRun) {
      console.log(`  DRY-RUN: would delete ${toDelete.length} files under medical_images/${prefix}/`);
      return toDelete.length;
    }
    await Promise.allSettled(toDelete.map((f) => f.delete().catch(() => null)));
    console.log(`  deleted ${toDelete.length} files under medical_images/${prefix}/`);
    return toDelete.length;
  }

  for (const prefix of topLevelPrefixes) {
    if (clinicIds.has(prefix)) {
      // nested clinic folder; keep
      skipped++;
      continue;
    }
    // consider legacy patientId folder -> delete
    totalDeleted += await deletePrefixRecursively(prefix);
  }

  console.log(`  Storage cleanup: removed files=${totalDeleted}, skipped clinic folders=${skipped}${dryRun ? ' (dry-run)' : ''}`);
}

async function scanLegacyStorage(storage, db, { samplePerPrefix = 3 }) {
  console.log('\n[Storage] Scan legacy summary under medical_images/ (no deletion)');
  const bucket = storage.bucket();
  const clinicsSnap = await db.collection('clinics').get();
  const clinicIds = new Set(clinicsSnap.docs.map((d) => d.id));
  const [files] = await bucket.getFiles({ prefix: 'medical_images/' });

  const mapCounts = new Map();
  const mapSamples = new Map();
  for (const f of files) {
    const parts = f.name.split('/');
    if (parts.length < 2) continue;
    const top = parts[1];
    mapCounts.set(top, (mapCounts.get(top) || 0) + 1);
    if (!mapSamples.has(top)) mapSamples.set(top, []);
    const arr = mapSamples.get(top);
    if (arr.length < samplePerPrefix) arr.push(f.name);
  }

  const entries = Array.from(mapCounts.entries()).sort((a, b) => b[1] - a[1]);
  console.log(`  found ${entries.length} top-level prefixes`);
  for (const [top, count] of entries) {
    const type = clinicIds.has(top) ? 'KEEP (clinicId)' : 'LEGACY (patientId?)';
    const samples = (mapSamples.get(top) || []).join(', ');
    console.log(`  - ${top}: ${count} files -> ${type}`);
    if (samples) console.log(`      samples: ${samples}`);
  }
}

async function main() {
  const projectId = getArg('--project') || process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  const dryRun = hasFlag('--dry-run') || !hasFlag('--yes');
  const deleteRootPatientsFlag = hasFlag('--delete-root-patients');
  const deleteRootAppointmentsFlag = hasFlag('--delete-root-appointments');
  const deleteRootSettingsFlag = hasFlag('--delete-root-settings');
  const deleteGlobalMastersFlag = hasFlag('--delete-global-masters');
  const deleteLegacyStorageFlag = hasFlag('--delete-legacy-storage');
  const scanLegacyStorageFlag = hasFlag('--scan-legacy-storage');
  const onlyPrefixes = getCSVArg('--only-prefixes');

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
  const storage = admin.storage();

  console.log('Project:', projectId || '(default)');
  console.log('Dry-run:', dryRun);
  console.log('Targets:', {
    deleteRootPatientsFlag,
    deleteRootAppointmentsFlag,
    deleteRootSettingsFlag,
    deleteGlobalMastersFlag,
    deleteLegacyStorageFlag,
  });

  if (scanLegacyStorageFlag) {
    await scanLegacyStorage(storage, db, { samplePerPrefix: 3 });
    console.log('\nScan finished. No deletion performed.');
    process.exit(0);
  }

  const nothingSelected = !deleteRootPatientsFlag && !deleteRootAppointmentsFlag && !deleteRootSettingsFlag && !deleteGlobalMastersFlag && !deleteLegacyStorageFlag;
  if (nothingSelected) {
    console.log('\nNothing selected to delete. Use flags like --delete-root-patients --delete-legacy-storage');
    process.exit(0);
  }

  await confirmOrExit('This will delete legacy data. Make sure you have a backup.');

  if (deleteRootPatientsFlag) {
    await deleteRootPatients(db, { dryRun });
  }

  if (deleteRootAppointmentsFlag) {
    await deleteRootAppointments(db, { dryRun });
  }

  if (deleteRootSettingsFlag) {
    await deleteRootSettings(db, { dryRun });
  }

  if (deleteGlobalMastersFlag) {
    await deleteGlobalMasters(db, { dryRun });
  }

  if (deleteLegacyStorageFlag) {
    await deleteLegacyStorage(storage, db, { dryRun, onlyPrefixes });
  }

  console.log('\nCleanup completed.');
}

main().catch((err) => {
  console.error('Cleanup failed:', err);
  process.exit(1);
});
