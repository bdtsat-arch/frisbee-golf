import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '64929332234-7ue0krvsuad7rlnqucqrukph01b5ajsc.apps.googleusercontent.com',
  );
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// The currently signed-in Firebase user, or null.
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google and return the Firebase [UserCredential].
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Google sign-in error: $e');
      }
      rethrow;
    }
  }

  /// Check the Firestore `allowlist` collection to see if [email] is permitted.
  /// The allowlist collection should have documents whose document ID or
  /// `email` field matches the user's email.
  Future<bool> isAllowlisted(String email) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      if (kDebugMode) {
        debugPrint('Checking allowlist for: "$normalizedEmail"');
      }

      final query = await _db
          .collection('allowlist')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (kDebugMode) {
        debugPrint('Allowlist query returned ${query.docs.length} docs');
        for (final doc in query.docs) {
          debugPrint('  doc ${doc.id}: ${doc.data()}');
        }
      }

      return query.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Allowlist check error: $e');
      }
      return false;
    }
  }

  /// Sign the user out of both Firebase and Google.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
