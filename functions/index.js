const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

admin.initializeApp();

const smtpConfig = functions.config().smtp || {};
const approvalsConfig = functions.config().approvals || {};

const DEFAULT_ADMIN_EMAIL = 'thaiseamonster@gmail.com';

let transporter = null;
if (smtpConfig.host) {
  transporter = nodemailer.createTransport({
    host: smtpConfig.host,
    port: Number(smtpConfig.port || 587),
    secure: (smtpConfig.secure || 'false') === 'true',
    auth: smtpConfig.user
      ? {
          user: smtpConfig.user,
          pass: smtpConfig.pass,
        }
      : undefined,
  });
}

const approvalsCollection = admin.firestore().collection('approval_requests');

function getBaseUrl() {
  if (approvalsConfig.baseurl) {
    return approvalsConfig.baseurl;
  }
  const project = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || '';
  const location = approvalsConfig.location || 'us-central1';
  return `https://${location}-${project}.cloudfunctions.net`;
}

function adminRecipient() {
  return approvalsConfig.recipient || DEFAULT_ADMIN_EMAIL;
}

function senderAddress() {
  return approvalsConfig.sender || adminRecipient();
}

async function sendMail(message) {
  if (!transporter) {
    console.warn('SMTP transporter not configured; skipping email send.');
    return;
  }
  await transporter.sendMail(message);
}

exports.requestClinicApproval = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  if (!adminRecipient()) {
    throw new functions.https.HttpsError('failed-precondition', 'Recipient email not configured.');
  }

  const uid = context.auth.uid;
  const clinicId = data.clinicId;
  const clinicName = data.clinicName;
  const userName = data.userName;
  const userEmail = data.userEmail;

  if (!clinicId || !clinicName || !userName || !userEmail) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing clinic or user information.');
  }

  const approveToken = crypto.randomBytes(32).toString('hex');
  const rejectToken = crypto.randomBytes(32).toString('hex');
  const createdAt = admin.firestore.FieldValue.serverTimestamp();

  await approvalsCollection.doc(uid).set({
    clinicId,
    clinicName,
    userName,
    userEmail,
    status: 'pending',
    approveToken,
    rejectToken,
    createdAt,
  });

  const baseUrl = getBaseUrl();
  const approveUrl = `${baseUrl}/approveClinicRequest?token=${approveToken}`;
  const rejectUrl = `${baseUrl}/rejectClinicRequest?token=${rejectToken}`;

  const htmlBody = `
    <p>New MyDent sign-up request</p>
    <ul>
      <li>Name: <strong>${userName}</strong></li>
      <li>Email: <a href="mailto:${userEmail}">${userEmail}</a></li>
      <li>Clinic: ${clinicName}</li>
      <li>Clinic ID: ${clinicId}</li>
    </ul>
    <p>Please choose an action:</p>
    <p>
      <a href="${approveUrl}">Approve</a> |
      <a href="${rejectUrl}">Reject</a>
    </p>
    <p>If the buttons above do not work, copy the links below:</p>
    <p>${approveUrl}</p>
    <p>${rejectUrl}</p>
  `;

  await sendMail({
    from: senderAddress(),
    to: adminRecipient(),
    subject: '[MyDent] New sign-up pending approval',
    html: htmlBody,
  });

  return { success: true };
});

async function fetchRequestByToken(tokenField, tokenValue) {
  const snapshot = await approvalsCollection.where(tokenField, '==', tokenValue).limit(1).get();
  if (snapshot.empty) {
    return null;
  }
  const doc = snapshot.docs[0];
  return { id: doc.id, data: doc.data() };
}

async function approveRequest(requestDoc) {
  const { id: uid, data } = requestDoc;
  if (data.status !== 'pending') {
    return 'This request was already processed';
  }

  const userDoc = await admin.firestore().doc(`users/${uid}`).get();
  if (!userDoc.exists) {
    return 'User profile not found';
  }

  const userData = userDoc.data();
  const clinicId = userData.clinicId;
  const role = userData.role || 'admin';
  const userEmail = data.userEmail;
  const userName = data.userName;
  const clinicName = data.clinicName;

  await admin.firestore().doc(`users/${uid}`).set({
    status: 'approved',
    approvedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.firestore().collection('clinics').doc(clinicId).collection('members').doc(uid).set({
    role,
    addedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.auth().setCustomUserClaims(uid, {
    clinicId,
  });

  await approvalsCollection.doc(uid).set({
    status: 'approved',
    respondedAt: admin.firestore.FieldValue.serverTimestamp(),
    approveToken: admin.firestore.FieldValue.delete(),
    rejectToken: admin.firestore.FieldValue.delete(),
  }, { merge: true });

  if (userEmail) {
    const html = `
      <p>Hello ${userName || userEmail},</p>
      <p>Your MyDent access for <strong>${clinicName}</strong> has been approved.</p>
      <p>You can sign in to the app right away.</p>
    `;

    await sendMail({
      from: senderAddress(),
      to: userEmail,
      subject: '[MyDent] Your account has been approved',
      html,
    });
  }

  return 'Approval recorded successfully';
}

async function rejectRequest(requestDoc) {
  const { id: uid, data } = requestDoc;
  if (data.status !== 'pending') {
    return 'This request was already processed';
  }

  const userDoc = await admin.firestore().doc(`users/${uid}`).get();
  const userEmail = data.userEmail;
  const userName = data.userName;
  const clinicName = data.clinicName;

  await admin.firestore().doc(`users/${uid}`).set({
    status: 'rejected',
    rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await admin.auth().updateUser(uid, { disabled: true }).catch(() => {});

  await approvalsCollection.doc(uid).set({
    status: 'rejected',
    respondedAt: admin.firestore.FieldValue.serverTimestamp(),
    approveToken: admin.firestore.FieldValue.delete(),
    rejectToken: admin.firestore.FieldValue.delete(),
  }, { merge: true });

  if (userEmail) {
    const html = `
      <p>Hello ${userName || userEmail},</p>
      <p>Your MyDent access request for <strong>${clinicName}</strong> was not approved.</p>
      <p>Please contact the administrator if you need more information.</p>
    `;

    await sendMail({
      from: senderAddress(),
      to: userEmail,
      subject: '[MyDent] Your sign-up request was not approved',
      html,
    });
  }

  return 'Rejection recorded successfully';
}

exports.approveClinicRequest = functions.https.onRequest(async (req, res) => {
  const token = req.query.token;
  if (!token) {
    res.status(400).send('Missing token');
    return;
  }
  try {
    const requestDoc = await fetchRequestByToken('approveToken', token);
    if (!requestDoc) {
      res.status(404).send('Approval request not found');
      return;
    }
    const message = await approveRequest(requestDoc);
    res.status(200).send(message);
  } catch (error) {
    console.error('Approve error', error);
    res.status(500).send('Something went wrong. Please try again later.');
  }
});

exports.rejectClinicRequest = functions.https.onRequest(async (req, res) => {
  const token = req.query.token;
  if (!token) {
    res.status(400).send('Missing token');
    return;
  }
  try {
    const requestDoc = await fetchRequestByToken('rejectToken', token);
    if (!requestDoc) {
      res.status(404).send('Approval request not found');
      return;
    }
    const message = await rejectRequest(requestDoc);
    res.status(200).send(message);
  } catch (error) {
    console.error('Reject error', error);
    res.status(500).send('Something went wrong. Please try again later.');
  }
});

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

    await admin.firestore().doc(`users/${uid}`).set({
      lastClaimsRefresh: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  } catch (error) {
    console.error('Failed to update custom claims', error);
    throw new functions.https.HttpsError('unknown', 'Unable to update custom claims.');
  }

  return { clinicId: sanitizedClinicId };
});
