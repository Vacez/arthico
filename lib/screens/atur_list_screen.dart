import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
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
    });
  }

  Future<void> _saveExpense() async {
    if (_titleController.text.isEmpty || _amountController.text.isEmpty) return;

    double amount = double.tryParse(_amountController.text) ?? 0;
    
    if (_editingId == null) {
      await _dbService.addFixedExpense(
        title: _titleController.text,
        amount: amount,
      );
    } else {
      await _dbService.updateFixedExpense(
        _editingId!,
        _titleController.text,
        amount,
      );
    }
    _resetForm();
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Atur List Kebutuhan', style: TextStyle(color: Colors.white, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_editingId == null ? 'Tambah Kebutuhan' : 'Edit Kebutuhan', 
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nama Kebutuhan',
                      labelStyle: TextStyle(color: Colors.white60),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Estimasi Biaya (Rp)',
                      labelStyle: TextStyle(color: Colors.white60),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saveExpense,
                      child: Text(_editingId == null ? 'Simpan Kebutuhan' : 'Simpan Perubahan', 
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (_editingId != null)
                    Center(
                      child: TextButton(
                        onPressed: _resetForm,
                        child: const Text('Batal Edit', style: TextStyle(color: Colors.white38)),
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
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Daftar Kewajiban', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // Table Header
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text('DESKRIPSI', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('NOMINAL', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('AKSI', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
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

                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.white10)),
                              ),
                              child: Row(
                                children: [
                                  // Deskripsi
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Row(
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
                                      ],
                                    ),
                                  ),
                                  // Nominal
                                  Expanded(
                                    flex: 2,
                                    child: Text(currencyFormatter.format(amount), 
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
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
                                const Expanded(child: Text('TOTAL BEBAN (PENDING)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
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
