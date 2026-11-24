const {initializeApp} = require("firebase-admin/app");
const {
  FieldValue,
  GeoPoint,
  getFirestore,
} = require("firebase-admin/firestore");
const {setGlobalOptions} = require("firebase-functions");
const {HttpsError, onCall} = require("firebase-functions/v2/https");

initializeApp();
setGlobalOptions({maxInstances: 10});

const EARTH_RADIUS_METERS = 6371000;
const CAFE_VISIT_TYPES = new Set([
  "cafe",
  "café",
  "cafe_location",
  "cafe_stop",
  "cafe_visit",
]);
const CAFE_WALK_TYPES = new Set([
  "cafe_walk",
  "cafe_walking",
  "walk_to_cafe",
]);
const RUN_TYPES = new Set(["run", "running"]);

/**
 * Validates a finite, non-negative numeric evidence value.
 * @param {*} value Evidence value.
 * @param {string} field Evidence field name.
 * @return {number} Validated value.
 */
function requiredNonNegativeNumber(value, field) {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    throw new HttpsError(
        "invalid-argument",
        `${field} must be a finite, non-negative number.`,
    );
  }
  return value;
}

/**
 * Validates a non-negative integer evidence value.
 * @param {*} value Evidence value.
 * @param {string} field Evidence field name.
 * @return {number} Validated value.
 */
function requiredNonNegativeInteger(value, field) {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new HttpsError(
        "invalid-argument",
        `${field} must be a non-negative integer.`,
    );
  }
  return value;
}

/**
 * Validates an optional numeric evidence value.
 * @param {!Object} evidence Submitted evidence.
 * @param {string} field Evidence field name.
 * @return {(number|undefined)} Validated value, if supplied.
 */
function optionalNonNegativeNumber(evidence, field) {
  return evidence[field] === undefined ?
    undefined :
    requiredNonNegativeNumber(evidence[field], field);
}

/**
 * Validates an optional integer evidence value.
 * @param {!Object} evidence Submitted evidence.
 * @param {string} field Evidence field name.
 * @return {(number|undefined)} Validated value, if supplied.
 */
function optionalNonNegativeInteger(evidence, field) {
  return evidence[field] === undefined ?
    undefined :
    requiredNonNegativeInteger(evidence[field], field);
}

/**
 * Reads café coordinates from Firestore's GeoPoint or map representation.
 * @param {*} location Location value from Firestore.
 * @return {*} Latitude and longitude, or null if unsupported.
 */
function getCafeCoordinates(location) {
  if (location instanceof GeoPoint) {
    return {latitude: location.latitude, longitude: location.longitude};
  }
  if (location && typeof location === "object") {
    return {
      latitude: location.latitude,
      longitude: location.longitude,
    };
  }
  return null;
}

/**
 * Validates that a coordinate is finite and within geographic bounds.
 * @param {*} value Coordinate value.
 * @param {string} field Coordinate name for error messages.
 * @param {number} minimum Inclusive lower bound.
 * @param {number} maximum Inclusive upper bound.
 * @return {number} Validated coordinate.
 */
function validateCoordinate(value, field, minimum, maximum) {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new HttpsError("failed-precondition", `Quest ${field} is invalid.`);
  }
  return value;
}

/**
 * Validates a positive numeric quest requirement.
 * @param {*} value Requirement value.
 * @param {string} field Requirement name for error messages.
 * @return {number} Validated requirement.
 */
function validatePositiveRequirement(value, field) {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
    throw new HttpsError(
        "failed-precondition",
        `Quest ${field} must be a finite, positive number.`,
    );
  }
  return value;
}

/**
 * Validates a positive integer quest requirement.
 * @param {*} value Requirement value.
 * @param {string} field Requirement name for error messages.
 * @return {number} Validated requirement.
 */
function validatePositiveIntegerRequirement(value, field) {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new HttpsError(
        "failed-precondition",
        `Quest ${field} must be a positive integer.`,
    );
  }
  return value;
}

/**
 * Calculates great-circle distance between two coordinate pairs.
 * @param {number} latitudeA First latitude.
 * @param {number} longitudeA First longitude.
 * @param {number} latitudeB Second latitude.
 * @param {number} longitudeB Second longitude.
 * @return {number} Distance in meters.
 */
function haversineDistanceMeters(
    latitudeA,
    longitudeA,
    latitudeB,
    longitudeB,
) {
  const toRadians = (degrees) => degrees * Math.PI / 180;
  const latitudeDelta = toRadians(latitudeB - latitudeA);
  const longitudeDelta = toRadians(longitudeB - longitudeA);
  const haversine =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(toRadians(latitudeA)) *
    Math.cos(toRadians(latitudeB)) *
    Math.sin(longitudeDelta / 2) ** 2;
  return 2 * EARTH_RADIUS_METERS *
    Math.asin(Math.sqrt(Math.min(1, haversine)));
}

/**
 * Reads and validates requirements from a quest document.
 * @param {!Object} quest Quest document data.
 * @return {!Object} Validated quest requirements.
 */
function getValidationRequirements(quest) {
  if (typeof quest.type !== "string") {
    throw new HttpsError("failed-precondition", "Quest type is missing.");
  }
  const type = quest.type.trim().toLowerCase().replace(/-/g, "_");

  if (CAFE_VISIT_TYPES.has(type) || CAFE_WALK_TYPES.has(type)) {
    const validationType = CAFE_WALK_TYPES.has(type) ?
      "cafe_walk" :
      "cafe_visit";
    const targetRadiusMeters = validatePositiveRequirement(
        quest.targetRadiusMeters,
        "targetRadiusMeters",
    );
    const location = getCafeCoordinates(quest.cafeLocation);
    if (!location) {
      throw new HttpsError(
          "failed-precondition",
          "Quest café location is missing or invalid.",
      );
    }

    const cafeLatitude = validateCoordinate(
        location.latitude,
        "café latitude",
        -90,
        90,
    );
    const cafeLongitude = validateCoordinate(
        location.longitude,
        "café longitude",
        -180,
        180,
    );
    const targetDistanceMeters = validationType === "cafe_walk" ?
      validatePositiveRequirement(
          quest.targetDistanceMeters,
          "targetDistanceMeters",
      ) :
      0;
    return {
      type: validationType,
      targetRadiusMeters,
      cafeLatitude,
      cafeLongitude,
      targetDistanceMeters,
      targetSteps: 0,
    };
  }

  if (RUN_TYPES.has(type)) {
    return {
      type,
      targetDistanceMeters: validatePositiveRequirement(
          quest.targetDistanceMeters,
          "targetDistanceMeters",
      ),
      targetSteps: validatePositiveIntegerRequirement(
          quest.targetSteps,
          "targetSteps",
      ),
    };
  }

  throw new HttpsError(
      "failed-precondition",
      `Quest type "${quest.type}" is not supported for validation.`,
  );
}

/**
 * Validates submitted evidence and returns supported evidence fields.
 * @param {*} evidence Submitted evidence.
 * @param {!Object} requirements Validated quest requirements.
 * @return {!Object} Sanitized evidence values.
 */
function prepareEvidence(evidence, requirements) {
  if (!evidence || typeof evidence !== "object" || Array.isArray(evidence)) {
    throw new HttpsError("invalid-argument", "Evidence must be an object.");
  }

  const suppliedDistance = optionalNonNegativeNumber(evidence, "distance");
  const suppliedSteps = optionalNonNegativeInteger(evidence, "steps");
  const prepared = {
    distance: suppliedDistance === undefined ? 0 : suppliedDistance,
    steps: suppliedSteps === undefined ? 0 : suppliedSteps,
  };

  if (requirements.type === "run" || requirements.type === "running") {
    prepared.distance = requiredNonNegativeNumber(
        evidence.distance,
        "distance",
    );
    prepared.steps = requiredNonNegativeInteger(evidence.steps, "steps");
  }

  if (requirements.type === "cafe_walk") {
    prepared.distance = requiredNonNegativeNumber(
        evidence.distance,
        "distance",
    );
  }

  if (
    requirements.type === "cafe_visit" ||
    requirements.type === "cafe_walk"
  ) {
    prepared.latitude = validateCoordinate(
        evidence.latitude,
        "submittedLatitude",
        -90,
        90,
    );
    prepared.longitude = validateCoordinate(
        evidence.longitude,
        "submittedLongitude",
        -180,
        180,
    );
  }

  return prepared;
}

exports.validateQuest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in is required.");
  }

  const {questId, evidence} = request.data || {};
  if (typeof questId !== "string" || questId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "questId is required.");
  }

  const userId = request.auth.uid;
  const db = getFirestore();
  const questRef = db.collection("quests").doc(questId);
  const userQuestRef = db.collection("users").doc(userId)
      .collection("quests").doc(questId);
  const profileRef = db.collection("users").doc(userId)
      .collection("profile").doc("summary");
  const validationRef = db.collection("users").doc(userId)
      .collection("validationRecords").doc();

  return db.runTransaction(async (transaction) => {
    const [questSnapshot, userQuestSnapshot, profileSnapshot] =
      await Promise.all([
        transaction.get(questRef),
        transaction.get(userQuestRef),
        transaction.get(profileRef),
      ]);

    if (!questSnapshot.exists) {
      throw new HttpsError("not-found", "Quest was not found.");
    }
    const quest = questSnapshot.data();
    if (quest.isActive !== true) {
      throw new HttpsError("failed-precondition", "Quest is not active.");
    }

    const requirements = getValidationRequirements(quest);
    const preparedEvidence = prepareEvidence(evidence, requirements);
    const userQuest = userQuestSnapshot.data();
    if (!userQuestSnapshot.exists) {
      throw new HttpsError(
          "failed-precondition",
          "User quest has not been accepted.",
      );
    }

    const validationTimestamp = FieldValue.serverTimestamp();
    if (userQuest.status === "completed") {
      transaction.create(validationRef, {
        questId,
        evidence: preparedEvidence,
        result: {success: false, code: "already-completed"},
        validatedAt: validationTimestamp,
      });
      return {success: false, alreadyCompleted: true};
    }
    if (userQuest.status !== "ongoing") {
      throw new HttpsError(
          "failed-precondition",
          "Only ongoing quests can be validated.",
      );
    }

    const failures = [];
    let distanceToCafeMeters;
    if (
      requirements.type === "cafe_visit" ||
      requirements.type === "cafe_walk"
    ) {
      distanceToCafeMeters = haversineDistanceMeters(
          preparedEvidence.latitude,
          preparedEvidence.longitude,
          requirements.cafeLatitude,
          requirements.cafeLongitude,
      );
      if (distanceToCafeMeters > requirements.targetRadiusMeters) {
        failures.push("outside-café-radius");
      }
    }
    if (requirements.targetDistanceMeters > 0 &&
        preparedEvidence.distance < requirements.targetDistanceMeters) {
      failures.push("insufficient-distance");
    }
    if (requirements.targetSteps > 0 &&
        preparedEvidence.steps < requirements.targetSteps) {
      failures.push("insufficient-steps");
    }

    const validationEvidence = {
      ...preparedEvidence,
      ...(distanceToCafeMeters === undefined ? {} : {distanceToCafeMeters}),
    };
    if (failures.length > 0) {
      transaction.create(validationRef, {
        questId,
        evidence: validationEvidence,
        result: {success: false, failures},
        validatedAt: validationTimestamp,
      });
      return {success: false, failures};
    }

    if (!Number.isSafeInteger(quest.rewardXP) || quest.rewardXP <= 0) {
      throw new HttpsError(
          "failed-precondition",
          "Quest rewardXP must be a positive integer.",
      );
    }
    const profile = profileSnapshot.data() || {};
    const totalXP = profile.totalXP === undefined ? 0 : profile.totalXP;
    const completedQuests = profile.completedQuests === undefined ?
      0 :
      profile.completedQuests;
    if (!Number.isSafeInteger(totalXP) || totalXP < 0 ||
        !Number.isSafeInteger(completedQuests) || completedQuests < 0) {
      throw new HttpsError(
          "failed-precondition",
          "User profile reward totals are invalid.",
      );
    }
    if (!Number.isSafeInteger(totalXP + quest.rewardXP) ||
        !Number.isSafeInteger(completedQuests + 1)) {
      throw new HttpsError(
          "failed-precondition",
          "User profile reward totals exceed the supported range.",
      );
    }

    transaction.update(userQuestRef, {
      status: "completed",
      progress: 1.0,
      distance: preparedEvidence.distance,
      steps: preparedEvidence.steps,
      completedAt: validationTimestamp,
    });
    transaction.set(profileRef, {
      totalXP: totalXP + quest.rewardXP,
      completedQuests: completedQuests + 1,
    }, {merge: true});
    transaction.create(validationRef, {
      questId,
      evidence: validationEvidence,
      result: {
        success: true,
        rewardXP: quest.rewardXP,
      },
      validatedAt: validationTimestamp,
    });

    return {
      success: true,
      rewardXP: quest.rewardXP,
      distanceToCafeMeters: distanceToCafeMeters === undefined ?
        null :
        distanceToCafeMeters,
    };
  });
});
