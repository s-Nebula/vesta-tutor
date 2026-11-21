import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _ensureUserDocument(
    User user, {
    String? username,
  }) async {
    final ref = _db.collection('users').doc(user.uid);
    final snapshot = await ref.get();

    final data = <String, dynamic>{
      'uid': user.uid,
      'email': user.email?.trim().toLowerCase(),
      'role': 'tutor',
    };

    if (!snapshot.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    if (username != null && username.trim().isNotEmpty) {
      data['username'] = username.trim();
      data['username_lower'] = username.trim().toLowerCase();
    }

    await ref.set(data, SetOptions(merge: true));
  }

  Future<UserCredential> register(
    String email,
    String password,
    String username,
  ) async {
    try {
      final normalizedUsername = username.trim();
      final normalizedEmail = email.trim();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('No se pudo crear la cuenta.');
      }

      await _ensureUserDocument(user, username: normalizedUsername);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e.code));
    }
  }

  Future<UserCredential> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        await _ensureUserDocument(credential.user!);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e.code));
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception('Google no devolvió credenciales de autenticación.');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);

      if (result.user != null) {
        await _ensureUserDocument(
          result.user!,
          username: googleUser.displayName,
        );
      }
      return result.user != null;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e.code));
    } catch (e) {
      throw Exception('No se pudo iniciar sesión con Google: $e');
    }
  }

  Future<bool> signInWithGitHub() async {
    try {
      final result = await _auth.signInWithProvider(
        GithubAuthProvider(),
      );
      if (result.user != null) {
        await _ensureUserDocument(result.user!);
      }
      return result.user != null;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e.code));
    } catch (e) {
      throw Exception('No se pudo iniciar sesión con GitHub: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e.code));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  String _handleAuthError(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
        return 'Correo o contraseña incorrectos.';
      case 'user-not-found':
        return 'No existe una cuenta con este correo.';
      case 'email-already-in-use':
        return 'Este correo ya está registrado.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'too-many-requests':
        return 'Demasiados intentos. Inténtalo más tarde.';
      case 'network-request-failed':
        return 'Error de conexión. Comprueba tu internet.';
      case 'operation-not-allowed':
        return 'Este método de inicio de sesión no está habilitado en Firebase.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'account-exists-with-different-credential':
        return 'Ya existe una cuenta con este correo usando otro método de acceso.';
      case 'credential-already-in-use':
        return 'Estas credenciales ya están vinculadas a otra cuenta.';
      default:
        return 'Error de autenticación ($code).';
    }
  }
}
