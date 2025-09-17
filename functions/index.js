const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.setClinicClaim = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const uid = context.auth.uid;

  let clinicId;
  try {
    const userDoc = await admin.firestore().doc(`users/${uid}`).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('failed-precondition', 'User profile not found.');
    }
    clinicId = userDoc.get('clinicId');
  } catch (error) {
    console.error('Failed to load user profile for claims', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('unknown', 'Unable to read user profile.');
  }

  if (typeof clinicId !== 'string' || clinicId.trim().length === 0) {
    throw new functions.https.HttpsError('failed-precondition', 'clinicId is missing on profile.');
  }

  const sanitizedClinicId = clinicId.trim();

  try {
    const currentClaims = (await admin.auth().getUser(uid)).customClaims || {};
    if (currentClaims.clinicId !== sanitizedClinicId) {
      await admin.auth().setCustomUserClaims(uid, {
        ...currentClaims,
        clinicId: sanitizedClinicId,
      });
    }

    await admin.firestore().doc(`users/${uid}`).set(
      {
        lastClaimsRefresh: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  } catch (error) {
    console.error('Failed to update custom claims', error);
    throw new functions.https.HttpsError('unknown', 'Unable to update custom claims.');
  }

  return { clinicId: sanitizedClinicId };
});
