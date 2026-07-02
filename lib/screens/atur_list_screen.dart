import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import 'package:intl/intl.dart';

class AturListScreen extends StatefulWidget {
  const AturListScreen({super.key});

  @override
  State<AturListScreen> createState() => _AturListScreenState();
}

class _AturListScreenState extends State<AturListScreen> {
  final DatabaseService _dbService = DatabaseService();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String? _editingId;
  int _selectedTenorMonths = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _titleController.clear();
      _amountController.clear();
      _editingId = null;
      _selectedTenorMonths = 0;
    });
  }

  Future<void> _saveExpense() async {
    if (_titleController.text.isEmpty || _amountController.text.isEmpty) return;

    double amount = double.tryParse(_amountController.text) ?? 0;
    
    if (_editingId == null) {
      await _dbService.addFixedExpense(
        title: _titleController.text,
        amount: amount,
        tenorMonths: _selectedTenorMonths,
      );
    } else {
      await _dbService.updateFixedExpense(
        _editingId!,
        _titleController.text,
        amount,
        _selectedTenorMonths,
      );
    }
    _resetForm();
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.navBg,
        elevation: 0,
        title: Text('Atur List Kebutuhan', style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: theme.navBorder, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        child: Column(
          children: [
            // Form Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_editingId == null ? 'Tambah Kebutuhan' : 'Edit Kebutuhan', 
                    style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _titleController,
                    style: TextStyle(color: theme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nama Kebutuhan',
                      labelStyle: TextStyle(color: theme.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accent, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: theme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Estimasi Biaya (Rp)',
                      labelStyle: TextStyle(color: theme.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accent, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _selectedTenorMonths,
                    dropdownColor: theme.card,
                    style: TextStyle(color: theme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Tenor / Jangka Waktu',
                      labelStyle: TextStyle(color: theme.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accent, width: 2)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Kurang dari 1 bulan (Jangka Pendek)')),
                      DropdownMenuItem(value: 1, child: Text('1 Bulan (Jangka Panjang)')),
                      DropdownMenuItem(value: 3, child: Text('3 Bulan (Jangka Panjang)')),
                      DropdownMenuItem(value: 6, child: Text('6 Bulan (Jangka Panjang)')),
                      DropdownMenuItem(value: 12, child: Text('12 Bulan (Jangka Panjang)')),
                      DropdownMenuItem(value: 24, child: Text('24 Bulan (Jangka Panjang)')),
                      DropdownMenuItem(value: 36, child: Text('36 Bulan atau lebih (Jangka Panjang)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedTenorMonths = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _saveExpense,
                        child: Text(_editingId == null ? 'Simpan Kebutuhan' : 'Simpan Perubahan', 
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ),
                  if (_editingId != null)
                    Center(
                      child: TextButton(
                        onPressed: _resetForm,
                        child: Text('Batal Edit', style: TextStyle(color: theme.textMuted)),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // List Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daftar Kewajiban', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // Table Header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text('DESKRIPSI', style: TextStyle(color: theme.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('NOMINAL', style: TextStyle(color: theme.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('AKSI', style: TextStyle(color: theme.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),

                  StreamBuilder<QuerySnapshot>(
                    stream: _dbService.getFixedExpenses(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      double totalBeban = 0;
                      var docs = snapshot.data!.docs;
                      
                      for (var doc in docs) {
                        if (!(doc['isPaid'] ?? false)) {
                          totalBeban += (doc['amount'] ?? 0).toDouble();
                        }
                      }

                      return Column(
                        children: [
                          ...docs.map((doc) {
                            String id = doc.id;
                            String title = doc['title'] ?? '';
                            double amount = (doc['amount'] ?? 0).toDouble();
                            bool isPaid = doc['isPaid'] ?? false;
                            int tenor = 0;
                            try {
                              tenor = ((doc['tenorMonths'] ?? 0) as num).toInt();
                            } catch (_) {}

                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: theme.border)),
                              ),
                              child: Row(
                                children: [
                                  // Deskripsi
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: isPaid ? Colors.green : Colors.orange,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(isPaid ? 'LUNAS' : 'PENDING', 
                                                  style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                            Text(
                                              tenor == 0 ? '• Jk. Pendek' : '• Tenor: $tenor Bln',
                                              style: TextStyle(color: theme.textSecondary, fontSize: 9),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Nominal
                                  Expanded(
                                    flex: 2,
                                    child: Text(currencyFormatter.format(amount), 
                                      style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ),
                                  // Aksi
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () async {
                                            if (!isPaid) {
                                              // Jika belum bayar, lakukan proses bayar yang memotong saldo
                                              final res = await _dbService.payFixedExpense(
                                                id: id,
                                                title: title,
                                                amount: amount,
                                              );
                                              if (res['success'] != true && mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('❌ Gagal bayar: ${res['error']}'), backgroundColor: Colors.red),
                                                );
                                              }
                                            } else {
                                              // Jika sudah lunas, hanya ubah status balik ke pending (tanpa refund otomatis)
                                              await _dbService.toggleFixedExpenseStatus(id, isPaid);
                                            }
                                          },
                                          child: Text(isPaid ? 'PENDING' : 'LUNAS', 
                                            style: TextStyle(color: isPaid ? Colors.orange : Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 8),
                                         GestureDetector(
                                           onTap: () {
                                             setState(() {
                                               _editingId = id;
                                               _titleController.text = title;
                                               _amountController.text = amount.toString();
                                               _selectedTenorMonths = tenor;
                                             });
                                           },
                                          child: const Text('Edit', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _dbService.deleteFixedExpense(id),
                                          child: const Text('Hapus', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // Total Beban Footer
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text('TOTAL BEBAN (PENDING)', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                                Text(currencyFormatter.format(totalBeban), 
                                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
