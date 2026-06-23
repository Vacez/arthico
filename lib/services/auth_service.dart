import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Sign In with Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // Force account selection by signing out of Google first
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return {'user': null, 'error': 'Dibatalkan oleh pengguna'};
      }

      final String email = googleUser.email.trim().toLowerCase();

      // Check if email exists in users collection in Firestore
      final QuerySnapshot query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        // Sign out of Google first to clean up Google Sign-In state
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
        return {
          'user': null,
          'error': 'Email belum terdaftar. Silakan lakukan registrasi terlebih dahulu.'
        };
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // check if user document exists in firestore, if not create
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'balance': 0,
          });
        }
      }

      return {'user': user, 'error': null};
    } catch (e) {
      return {'user': null, 'error': e.toString()};
    }
  }

  // Sign up with email & password
  Future<Map<String, dynamic>> signUp(String email, String password, String name) async {
    try {
      final String normalizedEmail = email.trim().toLowerCase();
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: normalizedEmail, password: password);
      User? user = result.user;
      
      // Update display name
      await user?.updateDisplayName(name);

      // Send verification email link
      await user?.sendEmailVerification();

      // CREATE DOCUMENT IN FIRESTORE "users"
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).set({
        'uid': user?.uid,
        'name': name,
        'email': normalizedEmail,
        'createdAt': FieldValue.serverTimestamp(),
        'balance': 0,
      });
      
      return {'user': user, 'error': null};
    } on FirebaseAuthException catch (e) {
      String message = 'Terjadi kesalahan';
      if (e.code == 'email-already-in-use' || e.code == 'email-already-in-white') {
        message = 'Email sudah terdaftar';
      } else if (e.code == 'weak-password') {
        message = 'Password terlalu lemah';
      } else if (e.code == 'operation-not-allowed') {
        message = 'Fitur pendaftaran belum diaktifkan di Console';
      } else if (e.code == 'configuration-not-found') {
        message = 'Konfigurasi belum diaktifkan di Console';
      }
      return {'user': null, 'error': message + ' (${e.code})'};
    } catch (e) {
      return {'user': null, 'error': e.toString()};
    }
  }

  // Sign up with Phone Auth (links email and password)
  Future<Map<String, dynamic>> signUpWithPhone(PhoneAuthCredential credential, String email, String password, String name) async {
    try {
      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;
      
      if (user != null) {
        final String normalizedEmail = email.trim().toLowerCase();
        // Link email and password
        AuthCredential emailCred = EmailAuthProvider.credential(email: normalizedEmail, password: password);
        await user.linkWithCredential(emailCred);
        
        await user.updateDisplayName(name);

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': normalizedEmail,
          'createdAt': FieldValue.serverTimestamp(),
          'balance': 0,
        });
      }
      return {'user': user, 'error': null};
    } catch (e) {
      return {'user': null, 'error': e.toString()};
    }
  }

  // Sign in with email & password
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      final String normalizedEmail = email.trim().toLowerCase();
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: normalizedEmail, password: password);
      return {'user': result.user, 'error': null};
    } on FirebaseAuthException catch (e) {
      String message = 'Gagal login';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Email atau password salah';
      } else if (e.code == 'invalid-email') {
        message = 'Format email tidak valid';
      } else if (e.code == 'user-disabled') {
        message = 'Akun ini telah dinonaktifkan';
      } else if (e.code == 'operation-not-allowed') {
        message = 'Fitur login dengan email belum diaktifkan di Firebase Console';
      } else {
        message = '$message (${e.message ?? e.code})';
      }
      return {'user': null, 'error': message};
    } catch (e) {
      return {'user': null, 'error': e.toString()};
    }
  }

  // Update display name (Auth & Firestore)
  Future<Map<String, dynamic>> updateProfile(String name) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not found'};

      // 1. Update Auth
      await user.updateDisplayName(name);

      // 2. Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': name,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'error': null};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Change password
  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return {'success': false, 'error': 'User not found'};

      // 1. Re-authenticate (Required for sensitive operations like password change)
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // 2. Update password
      await user.updatePassword(newPassword);

      return {'success': true, 'error': null};
    } on FirebaseAuthException catch (e) {
      String message = 'Gagal mengubah password';
      if (e.code == 'wrong-password') {
        message = 'Password saat ini salah';
      } else if (e.code == 'weak-password') {
        message = 'Password baru terlalu lemah';
      }
      return {'success': false, 'error': message + ' (${e.code})'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Sign out
  Future signOut() async {
    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      return await _auth.signOut();
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // Auth change user stream
  Stream<User?> get user {
    return _auth.authStateChanges();
  }
}
