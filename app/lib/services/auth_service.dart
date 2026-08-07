import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<String?> get idToken async => _auth.currentUser?.getIdToken();

  Future<UserCredential> signInWithGoogle() async {
    final GoogleAuthProvider googleProvider = GoogleAuthProvider();
    return _auth.signInWithProvider(googleProvider);
  }

  Future<UserCredential> signInWithApple() async {
    final AppleAuthProvider appleProvider = AppleAuthProvider();
    return _auth.signInWithProvider(appleProvider);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
