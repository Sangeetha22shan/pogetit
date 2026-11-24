const assert = require("node:assert/strict");
const {after, test} = require("node:test");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {GeoPoint, getFirestore} =
  require("firebase-admin/firestore");

const projectId = "demo-pogetit";
process.env.GCLOUD_PROJECT = projectId;
process.env.FIREBASE_CONFIG = JSON.stringify({projectId});
const authEmulatorHost = process.env.FIREBASE_AUTH_EMULATOR_HOST ||
  "127.0.0.1:9099";
const functionsEmulatorHost = process.env.FUNCTIONS_EMULATOR_HOST ||
  "127.0.0.1:5001";
const app = initializeApp({projectId}, "validate-quest-emulator-tests");
const db = getFirestore(app);
const authSignUpUrl =
  `http://${authEmulatorHost}/identitytoolkit.googleapis.com/v1/` +
  "accounts:signUp?key=fake-api-key";
const callableUrl =
  `http://${functionsEmulatorHost}/${projectId}/us-central1/validateQuest`;

/**
 * Creates an anonymous account through the Authentication emulator.
 * @return {Promise<Object>} The emulator account credentials.
 */
async function createAnonymousUser() {
  const response = await fetch(authSignUpUrl, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({returnSecureToken: true}),
  });
  const body = await response.json();
  assert.equal(response.ok, true, JSON.stringify(body));
  return body;
}

/**
 * Seeds quest requirements and user-owned documents in Firestore emulator.
 * @param {string} userId Authenticated user ID.
 * @param {string} questId Quest document ID.
 * @param {!Object} quest Quest requirement data.
 * @param {!Object=} userQuest Optional user quest overrides.
 * @return {Promise<void>} Resolves after seeding the documents.
 */
async function seedQuest(userId, questId, quest, userQuest = {}) {
  const userRef = db.collection("users").doc(userId);
  await Promise.all([
    db.collection("quests").doc(questId).set(quest),
    userRef.collection("quests").doc(questId).set({
      status: "ongoing",
      progress: 0,
      distance: 0,
      steps: 0,
      ...userQuest,
    }),
    userRef.collection("profile").doc("summary").set({
      totalXP: 0,
      completedQuests: 0,
    }),
  ]);
}

/**
 * Invokes the callable using the Firebase callable HTTP protocol.
 * @param {?string} idToken Auth emulator ID token, if authenticated.
 * @param {!Object} data Callable request data.
 * @return {Promise<Object>} HTTP status and parsed callable response.
 */
async function callValidateQuest(idToken, data) {
  const headers = {"Content-Type": "application/json"};
  if (idToken) headers.Authorization = `Bearer ${idToken}`;
  const response = await fetch(callableUrl, {
    method: "POST",
    headers,
    body: JSON.stringify({data}),
  });
  return {status: response.status, body: await response.json()};
}

/**
 * Seeds a standard running quest for validation test cases.
 * @param {string} userId Authenticated user ID.
 * @param {string} questId Quest document ID.
 * @param {!Object=} overrides Optional quest and user quest overrides.
 * @return {Promise<void>} Resolves after seeding the documents.
 */
async function createRunningQuest(userId, questId, overrides = {}) {
  await seedQuest(userId, questId, {
    type: "running",
    targetDistanceMeters: 1000,
    targetSteps: 1200,
    rewardXP: 100,
    isActive: true,
    ...overrides.quest,
  }, overrides.userQuest);
}

after(async () => {
  await deleteApp(app);
});

test(
    "valid café visit completes atomically and awards configured XP",
    async () => {
      const {localId, idToken} = await createAnonymousUser();
      await seedQuest(localId, "CAFE-01", {
        type: "cafe",
        cafeLocation: new GeoPoint(11.0168, 76.9558),
        targetRadiusMeters: 50,
        rewardXP: 80,
        isActive: true,
      });

      const result = await callValidateQuest(idToken, {
        questId: "CAFE-01",
        evidence: {latitude: 11.0168, longitude: 76.9558},
      });

      assert.equal(result.status, 200);
      assert.deepEqual(result.body.result, {
        success: true,
        rewardXP: 80,
        distanceToCafeMeters: 0,
      });
      const userQuest = await db.collection("users").doc(localId)
          .collection("quests").doc("CAFE-01").get();
      const profile = await db.collection("users").doc(localId)
          .collection("profile").doc("summary").get();
      const records = await db.collection("users").doc(localId)
          .collection("validationRecords").get();
      assert.equal(userQuest.data().status, "completed");
      assert.equal(userQuest.data().progress, 1);
      assert.ok(userQuest.data().completedAt);
      assert.equal(profile.data().totalXP, 80);
      assert.equal(profile.data().completedQuests, 1);
      assert.equal(records.size, 1);
      assert.equal(records.docs[0].data().result.success, true);
    },
);

test(
    "café geofence fields identify a visit despite an unknown type",
    async () => {
      const {localId, idToken} = await createAnonymousUser();
      await seedQuest(localId, "CAFE-UNKNOWN-TYPE", {
        type: "coffee_stop",
        cafeLocation: new GeoPoint(0, 0),
        targetRadiusMeters: 50,
        rewardXP: 80,
        isActive: true,
      },
      );

      const result = await callValidateQuest(idToken, {
        questId: "CAFE-UNKNOWN-TYPE",
        evidence: {latitude: 0, longitude: 0},
      });

      assert.equal(result.body.result.success, true);
      assert.equal(result.body.result.rewardXP, 80);
    });

test("insufficient running distance is rejected and recorded", async () => {
  const {localId, idToken} = await createAnonymousUser();
  await createRunningQuest(localId, "RUN-DISTANCE");

  const result = await callValidateQuest(idToken, {
    questId: "RUN-DISTANCE",
    evidence: {distance: 999, steps: 1200},
  });

  assert.deepEqual(result.body.result, {
    success: false,
    failures: ["insufficient-distance"],
  });
  const userQuest = await db.collection("users").doc(localId)
      .collection("quests").doc("RUN-DISTANCE").get();
  const profile = await db.collection("users").doc(localId)
      .collection("profile").doc("summary").get();
  const records = await db.collection("users").doc(localId)
      .collection("validationRecords").get();
  assert.equal(userQuest.data().status, "ongoing");
  assert.equal(profile.data().totalXP, 0);
  assert.equal(records.size, 1);
});

test("insufficient running steps are rejected", async () => {
  const {localId, idToken} = await createAnonymousUser();
  await createRunningQuest(localId, "RUN-STEPS");

  const result = await callValidateQuest(idToken, {
    questId: "RUN-STEPS",
    evidence: {distance: 1000, steps: 1199},
  });

  assert.deepEqual(result.body.result, {
    success: false,
    failures: ["insufficient-steps"],
  });
  const profile = await db.collection("users").doc(localId)
      .collection("profile").doc("summary").get();
  assert.equal(profile.data().totalXP, 0);
});

test("café visit outside its configured geofence is rejected", async () => {
  const {localId, idToken} = await createAnonymousUser();
  await seedQuest(localId, "CAFE-GEOFENCE", {
    type: "cafe_visit",
    cafeLocation: new GeoPoint(11.0168, 76.9558),
    targetRadiusMeters: 50,
    rewardXP: 80,
    isActive: true,
  });

  const result = await callValidateQuest(idToken, {
    questId: "CAFE-GEOFENCE",
    evidence: {latitude: 11.02, longitude: 76.96},
  });

  assert.deepEqual(result.body.result, {
    success: false,
    failures: ["outside-café-radius"],
  });
  const profile = await db.collection("users").doc(localId)
      .collection("profile").doc("summary").get();
  assert.equal(profile.data().totalXP, 0);
});

test("unauthenticated requests are rejected", async () => {
  const result = await callValidateQuest(null, {
    questId: "CAFE-01",
    evidence: {latitude: 0, longitude: 0},
  });

  assert.equal(result.status, 401);
  assert.equal(result.body.error.status, "UNAUTHENTICATED");
});

test("repeated completion cannot award XP twice", async () => {
  const {localId, idToken} = await createAnonymousUser();
  await seedQuest(localId, "CAFE-DUPLICATE", {
    type: "cafe_visit",
    cafeLocation: new GeoPoint(0, 0),
    targetRadiusMeters: 50,
    rewardXP: 80,
    isActive: true,
  });
  const request = {
    questId: "CAFE-DUPLICATE",
    evidence: {latitude: 0, longitude: 0},
  };

  const first = await callValidateQuest(idToken, request);
  const second = await callValidateQuest(idToken, request);

  assert.equal(first.body.result.success, true);
  assert.deepEqual(second.body.result, {
    success: false,
    alreadyCompleted: true,
  });
  const profile = await db.collection("users").doc(localId)
      .collection("profile").doc("summary").get();
  const records = await db.collection("users").doc(localId)
      .collection("validationRecords").get();
  assert.equal(profile.data().totalXP, 80);
  assert.equal(profile.data().completedQuests, 1);
  assert.equal(records.size, 2);
});

test("café walking quest requires distance and café proximity", async () => {
  const {localId, idToken} = await createAnonymousUser();
  await seedQuest(localId, "CAFE-WALK", {
    type: "cafe_walk",
    cafeLocation: new GeoPoint(0, 0),
    targetDistanceMeters: 500,
    targetRadiusMeters: 50,
    rewardXP: 120,
    isActive: true,
  });

  const result = await callValidateQuest(idToken, {
    questId: "CAFE-WALK",
    evidence: {
      distance: 500,
      latitude: 0,
      longitude: 0,
    },
  });

  assert.equal(result.body.result.success, true);
  const userQuest = await db.collection("users").doc(localId)
      .collection("quests").doc("CAFE-WALK").get();
  assert.equal(userQuest.data().distance, 500);
  assert.equal(userQuest.data().steps, 0);
});

test("invalid validation evidence is rejected", async () => {
  const {localId, idToken} = await createAnonymousUser();
  await createRunningQuest(localId, "RUN-INVALID");

  const result = await callValidateQuest(idToken, {
    questId: "RUN-INVALID",
    evidence: {distance: -1, steps: 1200},
  });

  assert.equal(result.status, 400);
  assert.equal(result.body.error.status, "INVALID_ARGUMENT");
});
