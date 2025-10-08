import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company.dart';

class CompanyService {
  final CollectionReference<Map<String, dynamic>> _col = FirebaseFirestore
      .instance
      .collection('companies');

  /// يعرض كل الشركات مرتبة بالاسم
  Stream<List<Company>> streamAll({int limit = 50}) {
    return _col
        .orderBy('companyName')
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Company.fromMap(d.id, d.data())).toList(),
        );
  }

  /// بحث prefix مطابق لأوّل الحروف في companyName
  Stream<List<Company>> searchByName(String q, {int limit = 50}) {
    final query = q.trim();
    if (query.isEmpty) return streamAll(limit: limit);
    final end = '$query\uf8ff';
    return _col
        .orderBy('companyName')
        .startAt([query])
        .endAt([end])
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Company.fromMap(d.id, d.data())).toList(),
        );
  }

  /// (اختياري) قراءة شركة وحده بالآي دي
  Future<Company?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Company.fromMap(doc.id, doc.data()!);
  }
}
