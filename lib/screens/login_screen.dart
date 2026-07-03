import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  String email = '';
  String password = '';
  String error = '';
  bool loading = false;
  bool _obscurePassword = true;

  void _showForgotPasswordDialog(BuildContext context, {String initialEmail = ''}) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final emailController = TextEditingController(text: initialEmail);
    final dialogFormKey = GlobalKey<FormState>();
    bool dialogLoading = false;
    String dialogError = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.lock_reset, color: theme.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Reset Kata Sandi',
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Masukkan email Anda untuk menerima tautan pemulihan kata sandi.',
                      style: TextStyle(color: theme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: emailController,
                      style: TextStyle(color: theme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'email@gmail.com',
                        hintStyle: TextStyle(color: theme.textMuted),
                        fillColor: theme.inputBg,
                        filled: true,
                        prefixIcon: Icon(Icons.email_outlined, color: theme.textMuted),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.accent, width: 2),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Masukkan email';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                          return 'Format email tidak valid';
                        }
                        return null;
                      },
                    ),
                    if (dialogError.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogLoading ? null : () => Navigator.pop(context),
                  child: Text('Batal', style: TextStyle(color: theme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: dialogLoading
                      ? null
                      : () async {
                          if (dialogFormKey.currentState!.validate()) {
                            setDialogState(() {
                              dialogLoading = true;
                              dialogError = '';
                            });
                            final res = await _auth.sendPasswordResetEmail(emailController.text.trim());
                            if (res['success'] == true) {
                              if (mounted) {
                                Navigator.pop(context); // Close input dialog
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: theme.card,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Row(
                                      children: [
                                        const Icon(Icons.mark_email_read_outlined, color: Colors.green),
                                        const SizedBox(width: 8),
                                        Text('Email Terkirim', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    content: Text(
                                      'Tautan reset kata sandi telah dikirim ke email Anda. Silakan periksa inbox/spam email Anda.',
                                      style: TextStyle(color: theme.textSecondary),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('OK', style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() {
                                dialogLoading = false;
                                dialogError = res['error'] ?? 'Gagal mengirim email reset.';
                              });
                            }
                          }
                        },
                  child: dialogLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Kirim Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.bg, // Extra Dark Navy Background
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: theme.card, // Card color
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
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
                    const SizedBox(height: 24.0),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 28.0,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimary,
                        ),
                        children: const [
                          TextSpan(text: 'Masuk ke '),
                          TextSpan(
                            text: 'Arthico',
                            style: TextStyle(color: Color(0xFF818CF8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      'Kelola keuanganmu dengan arthico 💎',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 14.0,
                      ),
                    ),
                    const SizedBox(height: 40.0),
                    // Email Field
                    TextFormField(
                      style: TextStyle(color: theme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'test@gmail.com',
                        hintStyle: TextStyle(color: theme.textMuted),
                        fillColor: theme.inputBg,
                        filled: true,
                        prefixIcon: Icon(Icons.email_outlined, color: theme.textMuted),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF818CF8), width: 2),
                        ),
                      ),
                      validator: (val) => val!.isEmpty ? 'Masukkan email' : null,
                      onChanged: (val) => setState(() => email = val),
                    ),
                    const SizedBox(height: 16.0),
                    // Password Field
                    TextFormField(
                      style: TextStyle(color: theme.textPrimary),
                      decoration: InputDecoration(
                        hintText: '••••••',
                        hintStyle: TextStyle(color: theme.textMuted),
                        fillColor: theme.inputBg,
                        filled: true,
                        prefixIcon: Icon(Icons.lock_outline, color: theme.textMuted),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: theme.textMuted,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF818CF8), width: 2),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (val) => val!.isEmpty ? 'Masukkan password' : null,
                      onChanged: (val) => setState(() => password = val),
                    ),
                    const SizedBox(height: 10.0),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => _showForgotPasswordDialog(context, initialEmail: email),
                        child: Text(
                          'Lupa Kata Sandi?',
                          style: TextStyle(
                            color: theme.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    // Gradient Button
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
                        onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                loading = true;
                                error = '';
                              });
                              Map<String, dynamic> result = await _auth.signIn(email.trim(), password);
                              if (result['user'] == null) {
                                setState(() {
                                  error = result['error'] ?? 'Gagal login.';
                                  loading = false;
                                });
                              }
                              // Success is handled by AuthWrapper stream in main.dart
                            }
                        },
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Masuk Sekarang',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                     if (error.isNotEmpty) ...[
                      const SizedBox(height: 12.0),
                      Text(
                        error,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13.0),
                        textAlign: TextAlign.center,
                      ),
                      if (error.toLowerCase().contains('salah') || 
                          error.toLowerCase().contains('tidak ditemukan') || 
                          error.toLowerCase().contains('kredensial') || 
                          error.toLowerCase().contains('gagal')) ...[
                        const SizedBox(height: 8.0),
                        GestureDetector(
                          onTap: () => _showForgotPasswordDialog(context, initialEmail: email),
                          child: Text(
                            'Lupa Kata Sandi?',
                            style: TextStyle(
                              color: theme.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0,
                              decoration: TextDecoration.underline,
                              decorationColor: theme.accent,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 24.0),
                    Row(
                      children: [
                        Expanded(child: Divider(color: theme.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('ATAU', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                        ),
                        Expanded(child: Divider(color: theme.border)),
                      ],
                    ),
                    const SizedBox(height: 24.0),
                    // Google Sign In Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: theme.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(Icons.g_mobiledata, color: theme.textPrimary, size: 28),
                      label: Text(
                        'Lanjutkan dengan Google',
                        style: TextStyle(color: theme.textPrimary, fontSize: 16),
                      ),
                      onPressed: () async {
                        setState(() {
                          loading = true;
                          error = '';
                        });
                        Map<String, dynamic> result = await _auth.signInWithGoogle();
                        if (result['user'] == null) {
                          if (mounted) {
                            setState(() {
                              error = result['error'] ?? 'Gagal login.';
                              loading = false;
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 32.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Belum punya akun? ', style: TextStyle(color: theme.textSecondary)),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RegisterScreen()),
                            );
                          },
                          child: const Text(
                            'Daftar disini',
                            style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
