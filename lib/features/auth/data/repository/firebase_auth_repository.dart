import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hscode_auditor/features/auth/domain/repository/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<User?> get userChanges => _auth.userChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<UserCredential?> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (userCredential.user != null) {
      final String uid = userCredential.user!.uid;
      await userCredential.user?.updateDisplayName(fullName);

      await _firestore.collection('users').doc(uid).set({
        'fullName': fullName,
        'email': email.trim(),
        'uid': uid,
        'hasAcceptedTerms': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      await _auth.signOut();
    }
    return userCredential;
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<bool> hasAcceptedTerms(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['hasAcceptedTerms'] ?? false;
  }

  @override
  Future<void> acceptTerms(String uid) async {
    await _firestore.collection('users').doc(uid).set(
      {'hasAcceptedTerms': true},
      SetOptions(merge: true),
    );
  }
}
