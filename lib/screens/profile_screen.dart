import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final User? user = FirebaseAuth.instance.currentUser;
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _showEditProfileDialog() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Profil', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _nameController,
          style: TextStyle(color: theme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Nama Lengkap',
            labelStyle: TextStyle(color: theme.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.border)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accent, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final res = await _auth.updateProfile(_nameController.text);
              if (res['success']) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Profil berhasil diperbarui!'), backgroundColor: Colors.green),
                );
                setState(() {}); // Refresh UI
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Gagal: ${res['error']}'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Ubah Password', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              style: TextStyle(color: theme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Password Saat Ini',
                labelStyle: TextStyle(color: theme.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accent, width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              style: TextStyle(color: theme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Password Baru',
                labelStyle: TextStyle(color: theme.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accent, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (_currentPasswordController.text.isEmpty || _newPasswordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Isi semua field!'), backgroundColor: Colors.orange),
                );
                return;
              }
              final res = await _auth.changePassword(
                _currentPasswordController.text,
                _newPasswordController.text,
              );
              if (res['success']) {
                Navigator.pop(context);
                _currentPasswordController.clear();
                _newPasswordController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Password berhasil diubah!'), backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Gagal: ${res['error']}'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Ubah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _dbService.getUserData(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) return Center(child: Text('Error: ${userSnapshot.error}', style: const TextStyle(color: Colors.red)));
        if (userSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        double balance = 0;
        String displayName = user?.displayName ?? 'User';
        bool emailNotif = true;
        bool autoLogout = false;

        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final data = userSnapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            balance = (data['balance'] ?? 0).toDouble();
            displayName = data['name'] ?? displayName;
            emailNotif = data['emailNotifications'] ?? true;
            autoLogout = data['autoLogout'] ?? false;
          }
        }

        bool isMobile = MediaQuery.of(context).size.width < 800;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: isMobile 
            ? Column(
                children: [
                  _buildUserProfileCard(balance, displayName, isMobile),
                  const SizedBox(height: 24),
                  _buildRiwayatTransaksi(),
                  const SizedBox(height: 24),
                  _buildPreferensiKeamanan(emailNotif, autoLogout),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserProfileCard(balance, displayName, isMobile),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        _buildRiwayatTransaksi(),
                        const SizedBox(height: 24),
                        _buildPreferensiKeamanan(emailNotif, autoLogout),
                      ],
                    ),
                  ),
                ],
              ),
        );
      },
    );
  }

  Widget _buildUserProfileCard(double balance, String displayName, bool isMobile) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      width: isMobile ? double.infinity : 300,
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF10B981)]),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.card,
                  child: Text(
                    displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'A',
                    style: TextStyle(fontSize: 40, color: theme.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const CircleAvatar(
                radius: 12,
                backgroundColor: Color(0xFF10B981),
                child: Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(displayName, style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(user?.email ?? 'email@gmail.com', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Text('MEMBER ID #5', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 32),
          Text('Total Saldo', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
          Text(currencyFormatter.format(balance), style: TextStyle(color: theme.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 48),
          _profileButton(Icons.person, 'Edit Profil', const Color(0xFF6366F1), onTap: _showEditProfileDialog),
          const SizedBox(height: 12),
          _profileButton(Icons.vpn_key, 'Ubah Password', theme.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), textAndIconColor: theme.textPrimary, onTap: _showChangePasswordDialog),
          const SizedBox(height: 12),
          _profileButton(Icons.logout, 'Logout', const Color(0xFFEF4444).withOpacity(0.2), isLogout: true, onTap: () => _auth.signOut()),
        ],
      ),
    );
  }

  Widget _profileButton(IconData icon, String label, Color color, {bool isLogout = false, Color? textAndIconColor, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isLogout ? Colors.redAccent : (textAndIconColor ?? Colors.white)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isLogout ? Colors.redAccent : (textAndIconColor ?? Colors.white), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildRiwayatTransaksi() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: theme.textSecondary),
              const SizedBox(width: 12),
              Text('Riwayat Transaksi', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              const Text('Lihat Dashboard >', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 24),
          StreamBuilder<QuerySnapshot>(
            stream: _dbService.getRecentTransactions(limit: 5),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Text('Belum ada aktivitas transaksi.', style: TextStyle(color: theme.textMuted));
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  bool isIncome = doc['type'] == 'Pemasukan';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(doc['category'], style: TextStyle(color: theme.textPrimary, fontSize: 14)),
                    subtitle: Text(doc['note'] ?? '', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    trailing: Text(
                      (isIncome ? '' : '- ') + currencyFormatter.format(doc['amount']),
                      style: TextStyle(color: isIncome ? Colors.blue : Colors.red, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreferensiKeamanan(bool emailNotif, bool autoLogout) {
    final theme = Provider.of<ThemeProvider>(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: theme.textSecondary),
              const SizedBox(width: 12),
              Text('Preferensi Keamanan', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          _switchRow(
            'Notifikasi Aplikasi', 
            'Dapatkan update aktivitas keuangan langsung di handphone', 
            emailNotif,
            (val) => _dbService.updateUserPreference('emailNotifications', val),
          ),
          const Divider(color: Colors.white12, height: 32),
          _switchRow(
            'Autologout', 
            'Logout otomatis setelah 30 menit inaktif', 
            autoLogout,
            (val) => _dbService.updateUserPreference('autoLogout', val),
          ),
          const Divider(color: Colors.white12, height: 32),
          _switchRow(
            'Mode Gelap', 
            'Aktifkan tampilan mode gelap atau terang', 
            theme.isDark,
            (val) => theme.toggleTheme(),
          ),
        ],
      ),
    );
  }

  Widget _switchRow(String title, String subtitle, bool val, Function(bool) onChanged) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
              Text(subtitle, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
            ],
          ),
        ),
        Switch(
          value: val, 
          onChanged: onChanged, 
          activeColor: const Color(0xFF3B82F6),
        ),
      ],
    );
  }
}
