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
  if (dryRun) {
    // Count with pagination using documentId cursor to avoid infinite loop
    const { FieldPath } = admin.firestore;
    let total = 0;
    let last = null;
    while (true) {
      let q = colRef.orderBy(FieldPath.documentId()).limit(batchSize);
      if (last) q = q.startAfter(last);
      const snap = await q.get();
      if (snap.empty) break;
      total += snap.size;
      last = snap.docs[snap.docs.length - 1].id;
      console.log(`  - would delete ${snap.size} docs from ${label} (scanned ${total})`);
    }
    return total;
  }

  // Real deletion: delete in batches until empty
  let total = 0;
  while (true) {
    const snap = await colRef.limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
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

  // Extra: clean orphaned subcollections that may remain under root when parent doc was removed earlier
  console.log('  scanning for orphaned subcollections under root patients/...');
  // treatments
  let removedOrphans = 0;
  const treatCg = await db.collectionGroup('treatments').get();
  for (const d of treatCg.docs) {
    const path = d.ref.path; // e.g., patients/{id}/treatments/{tid} or clinics/{cid}/patients/{id}/treatments/{tid}
    if (path.startsWith('patients/')) {
      if (dryRun) {
        removedOrphans++;
      } else {
        await d.ref.delete();
        removedOrphans++;
      }
    }
  }
  if (removedOrphans) console.log(`  ${dryRun ? 'would delete' : 'deleted'} ${removedOrphans} orphan treatment docs under root`);

  // medical_images
  removedOrphans = 0;
  const imgCg = await db.collectionGroup('medical_images').get();
  for (const d of imgCg.docs) {
    const path = d.ref.path;
    if (path.startsWith('patients/')) {
      if (dryRun) {
        removedOrphans++;
      } else {
        await d.ref.delete();
        removedOrphans++;
      }
    }
  }
  if (removedOrphans) console.log(`  ${dryRun ? 'would delete' : 'deleted'} ${removedOrphans} orphan medical_images docs under root`);
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
  // Support both treatment_master and treatments_master (some projects use plural)
  let totalTreatment = 0;
  totalTreatment += await deleteCollection(db, db.collection('treatment_master'), { dryRun, label: 'treatment_master' });
  totalTreatment += await deleteCollection(db, db.collection('treatments_master'), { dryRun, label: 'treatments_master' });
  console.log(`  done: prefix=${totalPrefix}, treatment=${totalTreatment}${dryRun ? ' (dry-run)' : ''}`);
}

async function deleteLegacyStorage(storage, db, { dryRun, onlyPrefixes = null, bucketName }) {
  console.log('\n[Storage] Deleting legacy patient folders under medical_images/{patientId}');
  const bucket = storage.bucket(bucketName);

  // list clinic ids from Firestore to distinguish top-level prefixes
  const clinicsSnap = await db.collection('clinics').get();
  const clinicIds = new Set(clinicsSnap.docs.map((d) => d.id));
  console.log(`  loaded ${clinicIds.size} clinic ids to identify nested folders`);

  // Fast list top-level prefixes under `medical_images/` using delimiter
  const result = await bucket.getFiles({ prefix: 'medical_images/', delimiter: '/' });
  const apiResponse = result[2] || {};
  const prefixes = (apiResponse.prefixes || [])
    .map((p) => p.replace(/^medical_images\//, '').replace(/\/$/, ''))
    .filter(Boolean);

  let topLevelPrefixes = prefixes;
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

async function scanLegacyStorage(storage, db, { samplePerPrefix = 3, bucketName }) {
  console.log('\n[Storage] Scan legacy summary under medical_images/ (no deletion)');
  const bucket = storage.bucket(bucketName);
  const clinicsSnap = await db.collection('clinics').get();
  const clinicIds = new Set(clinicsSnap.docs.map((d) => d.id));
  const [ , , apiResponse] = await bucket.getFiles({ prefix: 'medical_images/', delimiter: '/' });
  const topLevel = (apiResponse.prefixes || [])
    .map((p) => p.replace(/^medical_images\//, '').replace(/\/$/, ''))
    .filter(Boolean);

  console.log(`  found ${topLevel.length} top-level prefixes under medical_images/`);
  for (const top of topLevel) {
    const type = clinicIds.has(top) ? 'KEEP (clinicId)' : 'LEGACY (patientId?)';
    let sample = '';
    try {
      const [files] = await bucket.getFiles({ prefix: `medical_images/${top}/`, maxResults: samplePerPrefix });
      sample = files.map((f) => f.name).join(', ');
    } catch (_) {}
    console.log(`  - ${top}: ${type}${sample ? `\n      samples: ${sample}` : ''}`);
  }
}

async function main() {
  const projectId = getArg('--project') || process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  const dryRun = hasFlag('--dry-run') || !hasFlag('--yes');
  const bucketName = getArg('--bucket') || `${projectId}.appspot.com`;
  const deleteRootPatientsFlag = hasFlag('--delete-root-patients');
  const deleteRootAppointmentsFlag = hasFlag('--delete-root-appointments');
  const deleteRootSettingsFlag = hasFlag('--delete-root-settings');
  const deleteGlobalMastersFlag = hasFlag('--delete-global-masters');
  const deleteLegacyStorageFlag = hasFlag('--delete-legacy-storage');
  const scanLegacyStorageFlag = hasFlag('--scan-legacy-storage');
  const onlyPrefixes = getCSVArg('--only-prefixes');
  const onlyPrefixesFile = getArg('--only-prefixes-file');
  const exportLegacyPrefixesPath = getArg('--export-legacy-prefixes');

  if (!admin.apps.length) {
    const keyPath = getArg('--key');
    if (keyPath) {
      const raw = fs.readFileSync(keyPath, 'utf8');
      const creds = JSON.parse(raw);
      admin.initializeApp({
        credential: admin.credential.cert(creds),
        projectId,
        storageBucket: bucketName,
      });
    } else {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId,
        storageBucket: bucketName,
      });
    }
  }
  const db = admin.firestore();
  const storage = admin.storage();

  console.log('Project:', projectId || '(default)');
  console.log('Bucket:', bucketName);
  console.log('Dry-run:', dryRun);
  console.log('Targets:', {
    deleteRootPatientsFlag,
    deleteRootAppointmentsFlag,
    deleteRootSettingsFlag,
    deleteGlobalMastersFlag,
    deleteLegacyStorageFlag,
  });

  if (scanLegacyStorageFlag) {
    await scanLegacyStorage(storage, db, { samplePerPrefix: 3, bucketName });
    console.log('\nScan finished. No deletion performed.');
    process.exit(0);
  }

  if (exportLegacyPrefixesPath) {
    // Export non-clinic top-level prefixes to a file (newline separated)
    console.log(`\n[Storage] Exporting legacy (non-clinic) prefixes to ${exportLegacyPrefixesPath}`);
    const clinicsSnap = await db.collection('clinics').get();
    const clinicIds = new Set(clinicsSnap.docs.map((d) => d.id));
    const [ , , apiResponse] = await storage.bucket(bucketName).getFiles({ prefix: 'medical_images/', delimiter: '/' });
    const allTop = (apiResponse.prefixes || [])
      .map((p) => p.replace(/^medical_images\//, '').replace(/\/$/, ''))
      .filter(Boolean);
    const legacyTop = allTop.filter((p) => !clinicIds.has(p));
    fs.writeFileSync(exportLegacyPrefixesPath, legacyTop.join('\n'), 'utf8');
    console.log(`  wrote ${legacyTop.length} legacy prefixes.`);
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

  let prefixesArg = onlyPrefixes;
  if (!prefixesArg && onlyPrefixesFile) {
    const raw = fs.readFileSync(onlyPrefixesFile, 'utf8');
    prefixesArg = raw.split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
  }

  if (deleteLegacyStorageFlag) {
    await deleteLegacyStorage(storage, db, { dryRun, onlyPrefixes: prefixesArg, bucketName });
  }

  console.log('\nCleanup completed.');
}

main().catch((err) => {
  console.error('Cleanup failed:', err);
  process.exit(1);
});
