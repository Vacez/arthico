import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  String name = '';
  String email = '';
  String phone = '';
  String otpMethod = 'email';
  String password = '';
  String error = '';
  bool loading = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.bg,
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
                          TextSpan(text: 'Buat Akun '),
                          TextSpan(
                            text: 'Arthico',
                            style: TextStyle(color: Color(0xFF818CF8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      'Mulai kelola keuanganmu hari ini 💰',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 14.0,
                      ),
                    ),
                    const SizedBox(height: 40.0),
                    // Name Field
                    TextFormField(
                      style: TextStyle(color: theme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Nama lengkap',
                        hintStyle: TextStyle(color: theme.textMuted),
                        fillColor: theme.inputBg,
                        filled: true,
                        prefixIcon: Icon(Icons.person_outline, color: theme.textMuted),
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
                      validator: (val) => val!.isEmpty ? 'Masukkan nama lengkap' : null,
                      onChanged: (val) => setState(() => name = val),
                    ),
                    const SizedBox(height: 16.0),
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
                    // Phone Field
                    TextFormField(
                      style: TextStyle(color: theme.textPrimary),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: '081234567890',
                        hintStyle: TextStyle(color: theme.textMuted),
                        fillColor: theme.inputBg,
                        filled: true,
                        prefixIcon: Icon(Icons.phone_outlined, color: theme.textMuted),
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
                      validator: (val) => val!.isEmpty ? 'Masukkan nomor telepon' : null,
                      onChanged: (val) => setState(() => phone = val),
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
                      validator: (val) => val!.length < 6 ? 'Password minimal 6 karakter' : null,
                      onChanged: (val) => setState(() => password = val),
                    ),
                    const SizedBox(height: 24.0),
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
                              
                              try {
                                final res = await _auth.signUp(email, password, name);
                                if (res['user'] != null) {
                                  setState(() { loading = false; });
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✅ Registrasi berhasil! Tautan verifikasi telah dikirim ke email Anda.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } else {
                                  setState(() {
                                    error = res['error'] ?? 'Registrasi gagal.';
                                    loading = false;
                                  });
                                }
                              } catch (e) {
                                setState(() {
                                  error = e.toString();
                                  loading = false;
                                });
                              }
                            }
                        },
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Daftar Sekarang',
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
                    ],
                    const SizedBox(height: 32.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Sudah punya akun? ', style: TextStyle(color: theme.textSecondary)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Masuk disini',
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
