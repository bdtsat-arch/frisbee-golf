import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import '../history_view.dart';
import '../main.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String uid;

  FirestoreService({required this.uid});

  // User-scoped Games subcollection: users/{uid}/games
  CollectionReference<Map<String, dynamic>> get _gamesCollection =>
      _db.collection('users').doc(uid).collection('games');

  // User-scoped Courses subcollection: users/{uid}/courses
  CollectionReference<Map<String, dynamic>> get _coursesCollection =>
      _db.collection('users').doc(uid).collection('courses');

  /// Validate course data before saving
  void _validateCourse(SavedCourse course) {
    if (course.name.trim().isEmpty) {
      throw ArgumentError('Course name cannot be empty');
    }
    if (course.name.length > 200) {
      throw ArgumentError('Course name is too long (max 200 characters)');
    }
    if (course.numHoles < 1 || course.numHoles > 27) {
      throw ArgumentError('Number of holes must be between 1 and 27');
    }
    if (course.parValues.length != course.numHoles) {
      throw ArgumentError('Par values count must match number of holes');
    }
    if (course.distanceValues.length != course.numHoles) {
      throw ArgumentError('Distance values count must match number of holes');
    }
    if (course.holeMapImages.length != course.numHoles) {
      throw ArgumentError('Hole map images count must match number of holes');
    }
    if (course.teeSignImages.length != course.numHoles) {
      throw ArgumentError('Tee sign images count must match number of holes');
    }
    for (final par in course.parValues) {
      if (par < 1 || par > 10) {
        throw ArgumentError('Par values must be between 1 and 10');
      }
    }
    for (final distance in course.distanceValues) {
      if (distance < 0 || distance > 1000) {
        throw ArgumentError('Distance values must be between 0 and 1000 meters');
      }
    }
  }

  /// Validate game data before saving
  void _validateGame(GameHistory game) {
    if (game.playerNames.isEmpty) {
      throw ArgumentError('Game must have at least one player');
    }
    if (game.scores.isEmpty) {
      throw ArgumentError('Game must have score data');
    }
    if (game.scores.any((playerScores) => playerScores.isEmpty)) {
      throw ArgumentError('All players must have at least one score');
    }
  }

  Future<String> saveGame(GameHistory game) async {
    try {
      _validateGame(game);
      final docRef = await _gamesCollection.add(game.toJson());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Game validation error: $e');
      }
      rethrow;
    }
  }

  bool _isRemoteImageRef(String? value) {
    if (value == null || value.isEmpty) return false;
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Future<String?> _uploadImageIfNeeded({
    required String? imageRef,
    required String courseKey,
    required String imageType,
    required int holeIndex,
  }) async {
    if (imageRef == null || imageRef.isEmpty) {
      return null;
    }

    if (_isRemoteImageRef(imageRef)) {
      return imageRef;
    }

    try {
      final bytes = base64Decode(imageRef);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${holeIndex + 1}.jpg';
      final ref = _storage
          .ref()
          .child('users/$uid/courses/$courseKey/$imageType/$fileName');

      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await ref.getDownloadURL();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Image upload failed ($imageType hole ${holeIndex + 1}): $e');
      }
      return imageRef;
    }
  }

  Future<SavedCourse> _persistCourseImages(SavedCourse course) async {
    final courseKey =
        course.id ?? 'tmp_${DateTime.now().millisecondsSinceEpoch}';

    final uploadedHoleMaps = <String?>[];
    for (int i = 0; i < course.holeMapImages.length; i++) {
      uploadedHoleMaps.add(
        await _uploadImageIfNeeded(
          imageRef: course.holeMapImages[i],
          courseKey: courseKey,
          imageType: 'hole_map',
          holeIndex: i,
        ),
      );
    }

    final uploadedTeeSigns = <String?>[];
    for (int i = 0; i < course.teeSignImages.length; i++) {
      uploadedTeeSigns.add(
        await _uploadImageIfNeeded(
          imageRef: course.teeSignImages[i],
          courseKey: courseKey,
          imageType: 'tee_sign',
          holeIndex: i,
        ),
      );
    }

    return SavedCourse(
      id: course.id,
      name: course.name,
      numHoles: course.numHoles,
      parValues: course.parValues,
      distanceValues: course.distanceValues,
      holeMapImages: uploadedHoleMaps,
      teeSignImages: uploadedTeeSigns,
    );
  }

  Stream<List<GameHistory>> getGames() {
    return _gamesCollection
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GameHistory.fromJson(doc.data(), id: doc.id))
          .toList();
    });
  }

  Future<void> saveCourse(SavedCourse course) async {
    try {
      final preparedCourse = await _persistCourseImages(course);
      _validateCourse(preparedCourse);
      await _coursesCollection.add(preparedCourse.toJson());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Course validation error: $e');
      }
      rethrow;
    }
  }

  Stream<List<SavedCourse>> getCourses() {
    return _coursesCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => SavedCourse.fromJson(doc.data(), id: doc.id))
          .toList();
    });
  }

  Future<void> deleteGame(String id) async {
    await _gamesCollection.doc(id).delete();
  }
  
  Future<void> updateCourse(SavedCourse course) async {
    try {
      final preparedCourse = await _persistCourseImages(course);
      _validateCourse(preparedCourse);
      if (course.id != null) {
        await _coursesCollection.doc(course.id).set(preparedCourse.toJson());
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Course update validation error: $e');
      }
      rethrow;
    }
  }

  Future<void> updateGame(String id, GameHistory game) async {
    try {
      _validateGame(game);
      await _gamesCollection.doc(id).set(game.toJson());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Game update validation error: $e');
      }
      rethrow;
    }
  }
}
