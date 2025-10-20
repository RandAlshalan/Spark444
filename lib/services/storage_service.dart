// lib/services/storage_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

import 'authService.dart';
import '../models/document_group.dart';

// Represents a file stored in Firebase
class StoredFile {
  final String id;
  final String name;
  final String url;
  final String storagePath;
  final DateTime? uploadedAt;

  const StoredFile({
    required this.id,
    required this.name,
    required this.url,
    required this.storagePath,
    required this.uploadedAt,
  });
}

class StorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_storage.FirebaseStorage _storage =
      firebase_storage.FirebaseStorage.instance;

  String _inferContentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  // ===== DOCUMENT GROUP METHODS =====

  /// Creates the default "Untitled" group for a student if it doesn't exist
  Future<String> ensureDefaultGroup(String uid) async {
    final groupsRef = _firestore
        .collection(AuthService.kStudentCol)
        .doc(uid)
        .collection('documentGroups');

    final existingGroups = await groupsRef
        .where('title', isEqualTo: 'Untitled')
        .limit(1)
        .get();

    if (existingGroups.docs.isNotEmpty) {
      return existingGroups.docs.first.id;
    }

    final docRef = await groupsRef.add({
      'title': 'Untitled',
      'createdAt': FieldValue.serverTimestamp(),
      'order': 0,
    });

    return docRef.id;
  }

  /// Gets all document groups for a student
  Future<List<DocumentGroup>> getDocumentGroups(String uid) async {
    final snapshot = await _firestore
        .collection(AuthService.kStudentCol)
        .doc(uid)
        .collection('documentGroups')
        .orderBy('order', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => DocumentGroup.fromFirestore(doc))
        .toList();
  }

  /// Creates a new document group
  Future<String> createDocumentGroup({
    required String uid,
    required String title,
  }) async {
    // Get the highest order number
    final snapshot = await _firestore
        .collection(AuthService.kStudentCol)
        .doc(uid)
        .collection('documentGroups')
        .orderBy('order', descending: true)
        .limit(1)
        .get();

    final maxOrder = snapshot.docs.isEmpty
        ? 0
        : (snapshot.docs.first.data()['order'] as int? ?? 0);

    final docRef = await _firestore
        .collection(AuthService.kStudentCol)
        .doc(uid)
        .collection('documentGroups')
        .add({
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
      'order': maxOrder + 1,
    });

    return docRef.id;
  }

  /// Updates the order of document groups
  Future<void> updateGroupOrder({
    required String uid,
    required List<DocumentGroup> groups,
  }) async {
    final batch = _firestore.batch();

    for (var i = 0; i < groups.length; i++) {
      final docRef = _firestore
          .collection(AuthService.kStudentCol)
          .doc(uid)
          .collection('documentGroups')
          .doc(groups[i].id);

      batch.update(docRef, {'order': i});
    }

    await batch.commit();
  }

  /// Deletes a document group and all its documents
  Future<void> deleteDocumentGroup({
    required String uid,
    required String groupId,
  }) async {
    // Get all files in this group
    final files = await getFilesInGroup(uid, groupId);

    // Delete all files in the group
    for (final file in files) {
      await _storage.ref(file.storagePath).delete();
    }

    // Delete all file documents in the subcollection
    final docsSnapshot = await _firestore
        .collection(AuthService.kStudentCol)
        .doc(uid)
        .collection('documentGroups')
        .doc(groupId)
        .collection('files')
        .get();

    for (final doc in docsSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete the group itself
    await _firestore
        .collection(AuthService.kStudentCol)
        .doc(uid)
        .collection('documentGroups')
        .doc(groupId)
        .delete();
  }

  /// Gets files in a specific group
  Future<List<StoredFile>> getFilesInGroup(String uid, String groupId) async {
    final snapshot = await _firestore
        .collection(AuthService.kStudentCol)
        .doc(uid)
        .collection('documentGroups')
        .doc(groupId)
        .collection('files')
        .orderBy('uploadedAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) => StoredFile(
            id: doc.id,
            name: doc.data()['name'] as String? ?? 'File',
            url: doc.data()['url'] as String,
            storagePath: doc.data()['storagePath'] as String,
            uploadedAt: (doc.data()['uploadedAt'] as Timestamp?)?.toDate(),
          ),
        )
        .toList();
  }

  // Generic method to get a list of files from a sub-collection
  Future<List<StoredFile>> getFiles(String uid, String collection) async {
    final snapshot = await _firestore
        .collection(AuthService.kStudentCol)
        .doc(uid)
        .collection(collection)
        .orderBy('uploadedAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) => StoredFile(
            id: doc.id,
            name: doc.data()['name'] as String? ?? 'File',
            url: doc.data()['url'] as String,
            storagePath: doc.data()['storagePath'] as String,
            uploadedAt: (doc.data()['uploadedAt'] as Timestamp?)?.toDate(),
          ),
        )
        .toList();
  }

  // Upload file to a specific document group
  Future<void> uploadFileToGroup({
    required String uid,
    required String groupId,
    required PlatformFile file,
  }) async {
    if (file.bytes == null) {
      throw Exception('Failed to read the selected file.');
    }

    final path =
        'students/$uid/documentGroups/$groupId/${DateTime.now().microsecondsSinceEpoch}_${file.name}';

    final ref = _storage.ref().child(path);
    await ref.putData(
      file.bytes!,
      firebase_storage.SettableMetadata(
        contentType: _inferContentType(file.extension),
      ),
    );
    final url = await ref.getDownloadURL();

    await _firestore
        .collection(AuthService.kStudentCol)
        .doc(uid)
        .collection('documentGroups')
        .doc(groupId)
        .collection('files')
        .add({
      'name': file.name,
      'url': url,
      'storagePath': path,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete file from a specific group
  Future<void> deleteFileFromGroup({
    required String uid,
    required String groupId,
    required StoredFile file,
  }) async {
    // Delete from Firebase Storage
    await _storage.ref(file.storagePath).delete();

    // Delete from Firestore
    await _firestore
        .collection(AuthService.kStudentCol)
        .doc(uid)
        .collection('documentGroups')
        .doc(groupId)
        .collection('files')
        .doc(file.id)
        .delete();
  }

  // Generic method to upload a file and create its record
  Future<void> uploadFile({
    required String uid,
    required String collection, // 'documents' or 'resumes'
    required PlatformFile file,
  }) async {
    if (file.bytes == null) {
      throw Exception('Failed to read the selected file.');
    }

    final path =
        'students/$uid/$collection/${DateTime.now().microsecondsSinceEpoch}_${file.name}';

    final ref = _storage.ref().child(path);
    await ref.putData(
      file.bytes!,
      firebase_storage.SettableMetadata(
        contentType: _inferContentType(file.extension),
      ),
    );
    final url = await ref.getDownloadURL();

    await _firestore
        .collection(AuthService.kStudentCol)
        .doc(uid)
        .collection(collection)
        .add({
          'name': file.name,
          'url': url,
          'storagePath': path,
          'uploadedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> uploadFiles({
    required String uid,
    required String collection,
    required List<PlatformFile> files,
  }) async {
    for (final file in files) {
      await uploadFile(uid: uid, collection: collection, file: file);
    }
  }

  // Generic method to delete a file and its record
  Future<void> deleteFile({
    required String uid,
    required String collection,
    required StoredFile file,
  }) async {
    // Delete from Firebase Storage
    await _storage.ref(file.storagePath).delete();

    // Delete from Firestore
    await _firestore
        .collection(AuthService.kStudentCol)
        .doc(uid)
        .collection(collection)
        .doc(file.id)
        .delete();
  }
}
