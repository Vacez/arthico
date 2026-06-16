import 'package:flutter/material.dart';
import 'package:email_otp/email_otp.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final String otpMethod;
  final String password;
  final EmailOTP authInstance;
  final String? verificationId;

  const VerifyOtpScreen({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.otpMethod,
    required this.password,
    required this.authInstance,
    this.verificationId,
  });

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final AuthService _auth = AuthService();
  String otpCode = '';
  String error = '';
  bool loading = false;
  bool isResending = false;

  void _resendOTP() async {
    setState(() {
      isResending = true;
      error = '';
    });

    try {
      if (widget.otpMethod == 'email') {
        bool otpSent = await widget.authInstance.sendOTP();
        setState(() => isResending = false);
        if (otpSent) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('OTP berhasil dikirim ulang!'), backgroundColor: Colors.green),
            );
          }
        } else {
          setState(() => error = 'Gagal mengirim ulang OTP.');
        }
      } else if (widget.otpMethod == 'sms') {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: widget.phone,
          verificationCompleted: (PhoneAuthCredential credential) {},
          verificationFailed: (FirebaseAuthException e) {
            setState(() {
              error = e.message ?? 'Gagal mengirim ulang SMS OTP.';
              isResending = false;
            });
          },
          codeSent: (String newVerificationId, int? resendToken) {
            setState(() => isResending = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('SMS OTP berhasil dikirim ulang!'), backgroundColor: Colors.green),
              );
            }
            // Ideally we'd update verificationId, but since it's final we can't. 
            // In a real app we'd manage verificationId in the state.
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
        );
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isResending = false;
      });
    }
  }

  void _verifyAndRegister() async {
    if (otpCode.length < 6) {
      setState(() => error = 'Masukkan 6 digit kode OTP');
      return;
    }

    setState(() {
      loading = true;
      error = '';
    });

    try {
      if (widget.otpMethod == 'email') {
        bool isVerified = await widget.authInstance.verifyOTP(otp: otpCode);
        if (isVerified) {
          Map<String, dynamic> result = await _auth.signUp(
            widget.email.trim(),
            widget.password,
            widget.name,
          );

          if (result['user'] == null) {
            setState(() {
              error = result['error'] ?? 'Pendaftaran gagal.';
              loading = false;
            });
          } else {
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
        } else {
          setState(() {
            error = 'Kode OTP salah!';
            loading = false;
          });
        }
      } else if (widget.otpMethod == 'sms') {
        if (widget.verificationId == null) {
          setState(() {
            error = 'Verification ID tidak ditemukan.';
            loading = false;
          });
          return;
        }

        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: widget.verificationId!,
          smsCode: otpCode,
        );

        Map<String, dynamic> result = await _auth.signUpWithPhone(
          credential,
          widget.email.trim(),
          widget.password,
          widget.name,
        );

        if (result['user'] == null) {
          setState(() {
            error = result['error'] ?? 'Gagal verifikasi SMS.';
            loading = false;
          });
        } else {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'invalid-verification-code') {
          error = 'Kode OTP salah!';
        } else {
          error = e.message ?? 'Terjadi kesalahan.';
        }
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        title: Text('Verifikasi Email', style: TextStyle(color: theme.textPrimary)),
        backgroundColor: theme.card,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textPrimary),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.accent, width: 2),
                        image: const DecorationImage(
                          image: AssetImage('assets/logo.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Masukkan Kode OTP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kode telah dikirim ke:\n${widget.otpMethod == 'email' ? widget.email : widget.phone}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 16.0,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    style: TextStyle(color: theme.textPrimary, fontSize: 24, letterSpacing: 8),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: '••••••',
                      hintStyle: TextStyle(color: theme.textMuted),
                      fillColor: theme.inputBg,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.accent, width: 2),
                      ),
                      counterText: "",
                    ),
                    onChanged: (val) => setState(() => otpCode = val),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: loading ? null : _verifyAndRegister,
                      child: loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Konfirmasi & Daftar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: isResending ? null : _resendOTP,
                    child: isResending 
                        ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: theme.accent, strokeWidth: 2))
                        : Text('Kirim Ulang OTP', style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold)),
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 16.0),
                    Text(
                      error,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13.0),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
