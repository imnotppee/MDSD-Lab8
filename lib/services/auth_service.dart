import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static Future<void>? _googleInitialization;
  static const _googleScopes = <String>[
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ];

  Future<void> signUp({required String email, required String password}) async {
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw Exception(_messageFor(error));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw Exception(_messageFor(error));
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (error) {
      throw Exception(_messageFor(error));
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await (_googleInitialization ??= _googleSignIn.initialize());

      final googleUser = await _googleSignIn.authenticate(
        scopeHint: _googleScopes,
      );
      final googleAuth = googleUser.authentication;
      final authorization = await googleUser.authorizationClient
          .authorizationForScopes(_googleScopes);

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: authorization?.accessToken,
      );
      await _firebaseAuth.signInWithCredential(credential);
    } on GoogleSignInException catch (error) {
      debugPrint('Google Sign-In error: ${error.code} ${error.description}');
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw Exception('ยกเลิกการเข้าสู่ระบบด้วย Google');
      }
      throw Exception('เข้าสู่ระบบด้วย Google ไม่สำเร็จ กรุณาลองใหม่');
    } on FirebaseAuthException catch (error) {
      throw Exception(_messageFor(error));
    }
  }

  String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกสมัครสมาชิกแล้ว';
      case 'weak-password':
        return 'รหัสผ่านสั้นหรือคาดเดาง่ายเกินไป กรุณาใช้รหัสผ่านอย่างน้อย 6 ตัวอักษร';
      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'user-disabled':
        return 'บัญชีนี้ถูกระงับการใช้งาน';
      case 'too-many-requests':
        return 'ลองหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่';
      case 'network-request-failed':
        return 'ไม่สามารถเชื่อมต่อเครือข่ายได้ กรุณาตรวจสอบอินเทอร์เน็ต';
      default:
        return 'เกิดข้อผิดพลาดในการยืนยันตัวตน กรุณาลองใหม่';
    }
  }
}
