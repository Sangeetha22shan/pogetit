import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/quests/model/quest_model.dart';

class QuestRepository {
  QuestRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<QuestModel>> getQuests() {
    return _firestore
        .collection('quests')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final quests = snapshot.docs
              .map((doc) => QuestModel.fromFirestore(doc.id, doc.data()))
              .toList();
          const preferredOrder = ['RUN-01', 'RUN-02', 'CAFE-01', 'CAFE-02'];
          quests.sort((a, b) {
            final aOrder = preferredOrder.indexOf(a.id);
            final bOrder = preferredOrder.indexOf(b.id);
            final normalizedA = aOrder < 0 ? preferredOrder.length : aOrder;
            final normalizedB = bOrder < 0 ? preferredOrder.length : bOrder;
            return normalizedA != normalizedB
                ? normalizedA.compareTo(normalizedB)
                : a.title.compareTo(b.title);
          });
          return quests;
        });
  }
}
