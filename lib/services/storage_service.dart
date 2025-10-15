// lib/services/storage_service.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

import 'authService.dart';

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
