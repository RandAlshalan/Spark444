import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company.dart';

class CompanyService {
  final CollectionReference<Map<String, dynamic>> _col = FirebaseFirestore
      .instance
      .collection('companies');

  /// list all companies
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

  /// search by name
  Stream<List<Company>> searchByName(String q, {int limit = 50}) {
    final queryLower = q.toLowerCase().trim();
    if (queryLower.isEmpty) return streamAll(limit: limit);

    final end = '$queryLower\uf8ff';
    return _col
        .orderBy('companyNameLower')
        .startAt([queryLower])
        .endAt([end])
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Company.fromMap(d.id, d.data())).toList(),
        );
  }
}
