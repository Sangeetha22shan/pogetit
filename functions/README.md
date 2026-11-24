# Quest validation function

`validateQuest` is an authenticated callable function. It reads quest targets,
the café location and reward from `/quests/{questId}`. Supported `type` values
are `cafe_visit`, `cafe_walk`, `run`, and `running`. Café quests require a
Firestore GeoPoint in `cafeLocation` and a positive `targetRadiusMeters`.
Walking café quests also require positive `targetDistanceMeters`; running
quests require positive `targetDistanceMeters` and `targetSteps`.

Run the integration tests from the repository root:

```powershell
firebase emulators:exec --only auth,firestore,functions --project demo-pogetit "npm --prefix functions run test:emulator"
```

The function records both successful and unmet-requirement validation attempts.
Quest completion, profile XP increments, and successful validation records are
committed in a Firestore transaction. Firestore security rules remain
client-restrictive; the Admin SDK writes are performed only by the function.

## Prototype evidence limitations

Submitted GPS coordinates, accumulated GPS distance, and Health Connect step
counts are client-provided evidence. The function validates their shape,
thresholds, and café geofence, but cannot independently prove that device
sensors produced them or prevent a modified client from forging them. Emulator
tests verify backend behavior, not sensor authenticity. Production-grade
anti-spoofing would require additional trusted evidence or risk controls; XP
from this prototype should not be treated as fraud-proof.
