import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  final DateTime? initialDate;
  const HistoryScreen({super.key, this.initialDate});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  void _showEditTransactionDialog(String id, Map<String, dynamic> data) {
    final amountController = TextEditingController(text: data['amount'].toString());
    final noteController = TextEditingController(text: data['note'] ?? '');

    String selectedType = data['type'] ?? 'Pengeluaran';
    String selectedCategory = data['category'] ?? 'Lainnya';
    String selectedAllocation = data['allocation'] ?? 'Sekunder';

    final List<String> expenseCategories = ['Makan', 'Transport', 'Belanja', 'Hiburan', 'Lainnya'];
    final List<String> incomeCategories = ['Gaji', 'Bonus', 'Investasi', 'Hibah', 'Lainnya'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Edit Transaksi', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDropdown('Jenis', selectedType, ['Pemasukan', 'Pengeluaran'], (val) {
                  setDialogState(() {
                    selectedType = val!;
                    selectedCategory = selectedType == 'Pengeluaran' ? expenseCategories[0] : incomeCategories[0];
                  });
                }),
                _buildDropdown('Kategori', selectedCategory, selectedType == 'Pengeluaran' ? expenseCategories : incomeCategories, (val) {
                  setDialogState(() => selectedCategory = val!);
                }),
                _buildDropdown('Alokasi', selectedAllocation, ['Sekunder', 'Primer'], (val) {
                  setDialogState(() => selectedAllocation = val!);
                }),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nominal', 
                    labelStyle: TextStyle(color: Colors.white60),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
                TextField(
                  controller: noteController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Keterangan', 
                    labelStyle: TextStyle(color: Colors.white60),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
              onPressed: () async {
                double newAmount = double.tryParse(amountController.text) ?? 0;
                await _dbService.updateTransaction(
                  id: id,
                  oldAmount: (data['amount'] ?? 0).toDouble(),
                  oldType: data['type'],
                  newAmount: newAmount,
                  newType: selectedType,
                  category: selectedCategory,
                  allocation: selectedAllocation,
                  note: noteController.text,
                );
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Theme(
          data: Theme.of(context).copyWith(canvasColor: const Color(0xFF1E293B)),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: Container(height: 1, color: Colors.white24),
            style: const TextStyle(color: Colors.white),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Histori Transaksi', style: TextStyle(color: Colors.white, fontSize: 16)),
            Text(DateFormat('MMMM yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Color(0xFF818CF8)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dbService.getAllTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          var allDocs = snapshot.data?.docs ?? [];
          var docs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['timestamp'] as Timestamp?;
            if (ts == null) return false;
            DateTime d = ts.toDate();
            return d.month == _selectedDate.month && d.year == _selectedDate.year;
          }).toList();

          if (docs.isEmpty) return const Center(child: Text('Tidak ada transaksi di bulan ini', style: TextStyle(color: Colors.white38)));

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;
              bool isIncome = data['type'] == 'Pemasukan';
              DateTime date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isIncome ? Colors.blue.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    child: Icon(isIncome ? Icons.trending_up : Icons.trending_down, 
                      color: isIncome ? Colors.blue : Colors.red, size: 20),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(data['category'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(currencyFormatter.format(data['amount']), 
                        style: TextStyle(color: isIncome ? Colors.blueAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(data['note'] ?? '-', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 10, color: Colors.white24),
                          const SizedBox(width: 4),
                          Text(DateFormat('dd MMM yyyy, HH:mm').format(date), 
                            style: const TextStyle(color: Colors.white24, fontSize: 10)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: data['allocation'] == 'Primer' ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(data['allocation'] ?? 'Sekunder', 
                              style: TextStyle(color: data['allocation'] == 'Primer' ? Colors.orange : Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Row(
                        children: [Icon(Icons.edit, size: 16, color: Colors.white), SizedBox(width: 8), Text('Edit', style: TextStyle(color: Colors.white))],
                      )),
                      const PopupMenuItem(value: 'hapus', child: Row(
                        children: [Icon(Icons.delete, size: 16, color: Colors.redAccent), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.redAccent))],
                      )),
                    ],
                    onSelected: (val) async {
                      if (val == 'edit') {
                        _showEditTransactionDialog(doc.id, data);
                      } else if (val == 'hapus') {
                        bool? confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1E293B),
                            title: const Text('Hapus Transaksi?', style: TextStyle(color: Colors.white)),
                            content: const Text('Saldo Anda akan dikembalikan secara otomatis.', style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true), 
                                child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _dbService.deleteTransaction(doc.id, data);
                        }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
