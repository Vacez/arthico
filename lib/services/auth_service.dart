import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up with email & password
  Future<Map<String, dynamic>> signUp(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      User? user = result.user;
      
      // Update display name
      await user?.updateDisplayName(name);
      
      // CREATE DOCUMENT IN FIRESTORE "users"
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).set({
        'uid': user?.uid,
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'balance': 0,
      });
      
      return {'user': user, 'error': null};
    } on FirebaseAuthException catch (e) {
      String message = 'Terjadi kesalahan';
      if (e.code == 'email-already-in-white') {
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

  // Sign in with email & password
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return {'user': result.user, 'error': null};
    } on FirebaseAuthException catch (e) {
      String message = 'Gagal login';
      if (e.code == 'user-not-found') {
        message = 'Pengguna tidak ditemukan';
      } else if (e.code == 'wrong-password') {
        message = 'Password salah';
      } else if (e.code == 'operation-not-allowed') {
        message = 'Fitur login belum diaktifkan di Console';
      }
      return {'user': null, 'error': message + ' (${e.code})'};
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
