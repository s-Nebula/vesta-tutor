const crypto = require("crypto");
const admin = require("firebase-admin");
const { FieldValue, Timestamp } = require("firebase-admin/firestore");

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

admin.initializeApp();

const db = admin.firestore();

const CHILDREN = "children";
const INVITATIONS = "parent_invitations";
const PAIRING_CODES = "pairing_codes";

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  return request.auth.uid;
}

function requireParent(request) {
  const uid = requireAuth(request);

  if (request.auth.token.firebase?.sign_in_provider === "anonymous") {
    throw new HttpsError(
      "permission-denied",
      "Esta operación requiere una cuenta de padre o tutor."
    );
  }

  return uid;
}

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function generatePairingCode() {
  return crypto.randomBytes(5).toString("hex").toUpperCase();
}



async function verifyParent(childId, uid) {
  const childRef = db.collection(CHILDREN).doc(childId);
  const childSnap = await childRef.get();

  if (!childSnap.exists) {
    throw new HttpsError("not-found", "Perfil del menor no encontrado.");
  }

  const child = childSnap.data();

  if (!Array.isArray(child.parentIds) || !child.parentIds.includes(uid)) {
    throw new HttpsError(
      "permission-denied",
      "No tienes permisos para administrar este perfil."
    );
  }

  return { childRef, child };
}

// Crea un perfil compartido y un código de vinculación.

exports.createChild = onCall(async (request) => {
  const uid = requireParent(request);
  const nombre = String(request.data?.nombre || "").trim();
  const edad = Number(request.data?.edad);
  const color = Number(request.data?.color);

  if (!nombre || nombre.length > 80) {
    throw new HttpsError("invalid-argument", "Nombre no válido.");
  }
  if (!Number.isInteger(edad) || edad < 0 || edad > 18) {
    throw new HttpsError("invalid-argument", "Edad no válida.");
  }
  if (!Number.isSafeInteger(color) || color < 0 || color > 0xFFFFFFFF) {
    throw new HttpsError("invalid-argument", "Color no válido.");
  }

  const childRef = db.collection(CHILDREN).doc();

  for (let attempt = 0; attempt < 10; attempt++) {
    const pairingCode = generatePairingCode();
    const codeRef = db.collection(PAIRING_CODES).doc(pairingCode);

    const created = await db.runTransaction(async (transaction) => {
      const codeSnap = await transaction.get(codeRef);
      if (codeSnap.exists) return false;

      transaction.create(codeRef, {
        childId: childRef.id,
        status: "available",
        createdAt: FieldValue.serverTimestamp(),
      });

      transaction.create(childRef, {
        nombre,
        edad,
        color,
        status: "esperando_vinculacion",
        pairingCode,
        deviceId: null,
        deviceUid: null,
        parentIds: [uid],
        createdAt: FieldValue.serverTimestamp(),
        linkedAt: null,
      });

      return true;
    });

    if (created) return { childId: childRef.id, pairingCode };
  }

  throw new HttpsError(
    "internal",
    "No se pudo generar un código de vinculación único."
  );
});

// Vincula un dispositivo Tracker autenticado anónimamente.

exports.linkDevice = onCall(async (request) => {
  const uid = requireAuth(request);

  if (request.auth.token.firebase?.sign_in_provider !== "anonymous") {
    throw new HttpsError(
      "permission-denied",
      "La vinculación requiere una sesión de dispositivo."
    );
  }

  const code = String(request.data?.pairingCode || "").trim().toUpperCase();
  if (!/^[A-F0-9]{10}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Código no válido.");
  }

  const codeRef = db.collection(PAIRING_CODES).doc(code);
  const initialReservation = await codeRef.get();

  if (!initialReservation.exists ||
      initialReservation.data().status !== "available") {
    throw new HttpsError(
      "not-found",
      "Código incorrecto, inexistente o ya utilizado."
    );
  }

  const childId = initialReservation.data().childId;
  const childRef = db.collection(CHILDREN).doc(childId);
  const deviceRef = db.collection("devices").doc(uid);

  await db.runTransaction(async (transaction) => {
    const reservationSnap = await transaction.get(codeRef);
    const childSnap = await transaction.get(childRef);
    const deviceSnap = await transaction.get(deviceRef);

    if (!reservationSnap.exists ||
        reservationSnap.data().status !== "available" ||
        reservationSnap.data().childId !== childId) {
      throw new HttpsError(
        "failed-precondition",
        "El código ya fue utilizado o no está disponible."
      );
    }

    if (!childSnap.exists) {
      throw new HttpsError("not-found", "Perfil no encontrado.");
    }

    const child = childSnap.data();
    if (child.pairingCode !== code ||
        child.status !== "esperando_vinculacion") {
      throw new HttpsError(
        "failed-precondition",
        "Este perfil ya tiene un dispositivo vinculado o el código ha cambiado."
      );
    }

    if (deviceSnap.exists && deviceSnap.data().status === "vinculado") {
      throw new HttpsError(
        "failed-precondition",
        "Este dispositivo ya está vinculado a otro perfil."
      );
    }

    transaction.update(childRef, {
      status: "vinculado",
      deviceId: uid,
      deviceUid: uid,
      linkedAt: FieldValue.serverTimestamp(),
    });

    transaction.set(deviceRef, {
      childId,
      deviceUid: uid,
      status: "vinculado",
      linkedAt: FieldValue.serverTimestamp(),
    });

    transaction.update(codeRef, {
      status: "consumed",
      consumedBy: uid,
      consumedAt: FieldValue.serverTimestamp(),
    });
  });

  return { childId, status: "vinculado" };
});

// Desvincula el dispositivo desde cualquiera de los padres.

exports.unlinkDevice = onCall(async (request) => {
  const uid = requireParent(request);
  const childId = String(request.data?.childId || "").trim();

  if (!childId) {
    throw new HttpsError("invalid-argument", "Falta childId.");
  }

  const childRef = db.collection(CHILDREN).doc(childId);

  for (let attempt = 0; attempt < 10; attempt++) {
    const pairingCode = generatePairingCode();
    const codeRef = db.collection(PAIRING_CODES).doc(pairingCode);

    const unlinked = await db.runTransaction(async (transaction) => {
      const childSnap = await transaction.get(childRef);
      const codeSnap = await transaction.get(codeRef);

      if (codeSnap.exists) return false;

      if (!childSnap.exists) {
        throw new HttpsError("not-found", "Perfil no encontrado.");
      }

      const child = childSnap.data();
      if (!Array.isArray(child.parentIds) ||
          !child.parentIds.includes(uid)) {
        throw new HttpsError("permission-denied", "Acceso denegado.");
      }

      if (child.status !== "vinculado" || !child.deviceUid) {
        throw new HttpsError(
          "failed-precondition",
          "Este perfil no tiene un dispositivo vinculado."
        );
      }

      const oldDeviceUid = child.deviceUid;

      transaction.create(codeRef, {
        childId,
        status: "available",
        createdAt: FieldValue.serverTimestamp(),
      });

      transaction.update(childRef, {
        status: "esperando_vinculacion",
        pairingCode,
        deviceId: null,
        deviceUid: null,
        linkedAt: null,
        unlinkedAt: FieldValue.serverTimestamp(),
      });

      if (oldDeviceUid) {
        transaction.set(
          db.collection("devices").doc(oldDeviceUid),
          {
            status: "desvinculado",
            childId: null,
            unlinkedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      transaction.set(
        db.collection("telemetria").doc(childId),
        {
          status: "inactivo",
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return true;
    });

    if (unlinked) return { success: true, pairingCode };
  }

  throw new HttpsError(
    "internal",
    "No se pudo generar un nuevo código de vinculación."
  );
});

// Invita a un segundo padre o tutor.
exports.createParentInvitation = onCall(async (request) => {
  const uid = requireParent(request);
  const childId = String(request.data?.childId || "").trim();
  const email = normalizeEmail(request.data?.email);

  if (!childId || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "Datos de invitación no válidos.");
  }

  const inviter = await admin.auth().getUser(uid);
  if (normalizeEmail(inviter.email) === email) {
    throw new HttpsError(
      "invalid-argument",
      "No puedes invitar tu propia cuenta."
    );
  }

  const existingUser = await db
    .collection("users")
    .where("email", "==", email)
    .limit(1)
    .get();

  const existingUid = existingUser.empty ? null : existingUser.docs[0].id;
  const childRef = db.collection(CHILDREN).doc(childId);
  const invitationRef = db.collection(INVITATIONS).doc();

  await db.runTransaction(async (transaction) => {
    const childSnap = await transaction.get(childRef);

    if (!childSnap.exists) {
      throw new HttpsError("not-found", "Perfil no encontrado.");
    }

    const child = childSnap.data();
    const parentIds = Array.isArray(child.parentIds) ? child.parentIds : [];

    if (!parentIds.includes(uid)) {
      throw new HttpsError(
        "permission-denied",
        "No tienes acceso a este perfil."
      );
    }

    if (parentIds.length >= 2) {
      throw new HttpsError(
        "failed-precondition",
        "Este perfil ya tiene dos padres vinculados."
      );
    }

    if (existingUid && parentIds.includes(existingUid)) {
      throw new HttpsError(
        "already-exists",
        "Esta cuenta ya administra el perfil."
      );
    }

    const pendingQuery = db
      .collection(INVITATIONS)
      .where("childId", "==", childId);

    const pendingSnap = await transaction.get(pendingQuery);
    const now = Date.now();

    for (const doc of pendingSnap.docs) {
      const invitation = doc.data();

      if (invitation.status !== "pending") continue;

      const expiration = invitation.expiresAt?.toMillis?.() || 0;

      if (expiration > now) {
        if (invitation.invitedEmailLower === email) {
          throw new HttpsError(
            "already-exists",
            "Ya existe una invitación pendiente para este correo."
          );
        }
        continue;
      }

      transaction.update(doc.ref, { status: "expired" });
    }

    transaction.create(invitationRef, {
      childId,
      invitedEmail: email,
      invitedEmailLower: email,
      invitedBy: uid,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(now + 24 * 60 * 60 * 1000),
      acceptedBy: null,
      acceptedAt: null,
    });

    // Fuerza conflicto entre solicitudes concurrentes sobre el mismo perfil.
    transaction.update(childRef, {
      invitationUpdatedAt: FieldValue.serverTimestamp(),
    });
  });

  return {
    invitationId: invitationRef.id,
    expiresInHours: 24,
    emailSent: false,
  };
});
// Acepta una invitación desde la cuenta destinataria.


exports.acceptParentInvitation = onCall(async (request) => {
  const uid = requireParent(request);
  const invitationId = String(request.data?.invitationId || "").trim();

  if (!invitationId) {
    throw new HttpsError("invalid-argument", "Falta invitationId.");
  }

  const invitationRef = db.collection(INVITATIONS).doc(invitationId);

  const result = await db.runTransaction(async (transaction) => {
    const invitationSnap = await transaction.get(invitationRef);

    if (!invitationSnap.exists) {
      throw new HttpsError("not-found", "Invitación no encontrada.");
    }

    const invitation = invitationSnap.data();
    const email = normalizeEmail(request.auth.token.email);

    if (!email || email !== invitation.invitedEmailLower) {
      throw new HttpsError(
        "permission-denied",
        "Debes iniciar sesión con el correo invitado."
      );
    }

    if (invitation.status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        "La invitación ya no está disponible."
      );
    }

    const expiration = invitation.expiresAt?.toMillis?.();
    if (!expiration || expiration <= Date.now()) {
      transaction.update(invitationRef, { status: "expired" });
      return { expired: true };
    }

    const childRef = db.collection(CHILDREN).doc(invitation.childId);
    const childSnap = await transaction.get(childRef);

    if (!childSnap.exists) {
      throw new HttpsError("not-found", "Perfil del menor no encontrado.");
    }

    const child = childSnap.data();

    if (!child.parentIds?.includes(invitation.invitedBy)) {
      throw new HttpsError(
        "failed-precondition",
        "El padre que envió la invitación ya no administra el perfil."
      );
    }

    if (child.parentIds.includes(uid)) {
      throw new HttpsError("already-exists", "Ya administras este perfil.");
    }

    if (child.parentIds.length >= 2) {
      throw new HttpsError(
        "failed-precondition",
        "El perfil ya tiene dos administradores."
      );
    }

    transaction.update(childRef, {
      parentIds: FieldValue.arrayUnion(uid),
    });

    transaction.update(invitationRef, {
      status: "accepted",
      acceptedBy: uid,
      acceptedAt: FieldValue.serverTimestamp(),
    });

    return { expired: false };
  });

  if (result.expired) {
    throw new HttpsError(
      "deadline-exceeded",
      "La invitación ha caducado."
    );
  }

  return { success: true };
});

// Revoca una invitación pendiente.
exports.revokeParentInvitation = onCall(async (request) => {
  const uid = requireParent(request);
  const invitationId = String(request.data?.invitationId || "").trim();

  if (!invitationId) {
    throw new HttpsError("invalid-argument", "Falta invitationId.");
  }

  const invitationRef = db.collection(INVITATIONS).doc(invitationId);

  const result = await db.runTransaction(async (transaction) => {
    const invitationSnap = await transaction.get(invitationRef);

    if (!invitationSnap.exists) {
      throw new HttpsError("not-found", "Invitación no encontrada.");
    }

    const invitation = invitationSnap.data();
    const childRef = db.collection(CHILDREN).doc(invitation.childId);
    const childSnap = await transaction.get(childRef);

    if (!childSnap.exists) {
      throw new HttpsError("not-found", "Perfil del menor no encontrado.");
    }

    const child = childSnap.data();

    if (!Array.isArray(child.parentIds) || !child.parentIds.includes(uid)) {
      throw new HttpsError("permission-denied", "Acceso denegado.");
    }

    if (invitation.status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        "Solo se pueden revocar invitaciones pendientes."
      );
    }

    const expiration = invitation.expiresAt?.toMillis?.();

    if (!expiration || expiration <= Date.now()) {
      transaction.update(invitationRef, { status: "expired" });
      return { expired: true };
    }

    transaction.update(invitationRef, {
      status: "revoked",
      revokedAt: FieldValue.serverTimestamp(),
      revokedBy: uid,
    });

    return { expired: false };
  });

  if (result.expired) {
    throw new HttpsError("deadline-exceeded", "La invitación ha caducado.");
  }

  return { success: true };
});
// Envía alertas a todos los padres del perfil.
exports.enviarNotificacionAlerta = onDocumentCreated(
  `${CHILDREN}/{childId}/alerts/{alertId}`,
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const alert = snapshot.data();
    const childId = event.params.childId;

    const childSnap = await db.collection(CHILDREN).doc(childId).get();
    if (!childSnap.exists) return;

    const parentIds = childSnap.data().parentIds || [];
    if (parentIds.length === 0) return;

    const tokenSnapshots = await Promise.all(
      parentIds.map((parentId) =>
        db.collection("users")
          .doc(parentId)
          .collection("fcmTokens")
          .get()
      )
    );

    const tokenDocs = tokenSnapshots.flatMap((snapshot) => snapshot.docs);
    const tokens = [...new Set(
      tokenDocs.map((doc) => doc.data().token).filter(Boolean)
    )];

    if (tokens.length === 0) return;

    const title = alert.title || "Incidente detectado";
    const body = alert.subtitle || "Vesta ha registrado una alerta.";
    const type = alert.type || "critical";

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: `🚨 VESTA: ${title}`,
        body,
      },
      data: {
        childId,
        alertId: event.params.alertId,
        type,
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "vesta_alerts",
        },
      },
    });

    const invalidTokens = [];

    response.responses.forEach((result, index) => {
      if (
        !result.success &&
        [
          "messaging/invalid-registration-token",
          "messaging/registration-token-not-registered",
        ].includes(result.error?.code)
      ) {
        invalidTokens.push(tokens[index]);
      }
    });

    if (invalidTokens.length > 0) {
      const batch = db.batch();

      for (const doc of tokenDocs) {
        if (invalidTokens.includes(doc.data().token)) {
          batch.delete(doc.ref);
        }
      }

      await batch.commit();
    }
  }
);
