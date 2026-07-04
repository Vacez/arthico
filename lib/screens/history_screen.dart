import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
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
  String _filterRange = 'Bulanan'; // Options: 'Bulanan', '7hari', '30hari'

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  void _showEditTransactionDialog(String id, Map<String, dynamic> data) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
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
          backgroundColor: theme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Transaksi', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
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
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Nominal', 
                    labelStyle: TextStyle(color: theme.textSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.border)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accent, width: 2)),
                  ),
                ),
                TextField(
                  controller: noteController,
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Keterangan', 
                    labelStyle: TextStyle(color: theme.textSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.border)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accent, width: 2)),
                  ),
                ),
              ],
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
              child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
        Theme(
          data: Theme.of(context).copyWith(canvasColor: theme.card),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: Container(height: 1, color: theme.border),
            style: TextStyle(color: theme.textPrimary),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('Bulanan', 'Bulanan'),
            const SizedBox(width: 8),
            _filterChip('7 Hari Terakhir', '7hari'),
            const SizedBox(width: 8),
            _filterChip('30 Hari Terakhir', '30hari'),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final theme = Provider.of<ThemeProvider>(context);
    bool isSelected = _filterRange == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterRange = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.accent : theme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? theme.accent : theme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.navBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Histori Transaksi', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              _filterRange == '7hari'
                  ? '7 Hari Terakhir'
                  : _filterRange == '30hari'
                      ? '30 Hari Terakhir'
                      : DateFormat('MMMM yyyy').format(_selectedDate),
              style: TextStyle(color: theme.textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month, color: theme.accent),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme(
                        brightness: theme.isDark ? Brightness.dark : Brightness.light,
                        primary: const Color(0xFF818CF8),
                        onPrimary: Colors.white,
                        surface: theme.card,
                        onSurface: theme.textPrimary,
                        secondary: theme.accent,
                        onSecondary: Colors.white,
                        error: Colors.red,
                        onError: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _filterRange = 'Bulanan';
                  _selectedDate = picked;
                });
              }
            },
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: theme.navBorder, height: 1),
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _dbService.getAllTransactions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                var allDocs = snapshot.data?.docs ?? [];
                var docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final ts = data['timestamp'] as Timestamp?;
                  if (ts == null) return false;
                  DateTime d = ts.toDate();
                  
                  if (_filterRange == '7hari') {
                    final limitDate = DateTime.now().subtract(const Duration(days: 7));
                    return d.isAfter(limitDate);
                  } else if (_filterRange == '30hari') {
                    final limitDate = DateTime.now().subtract(const Duration(days: 30));
                    return d.isAfter(limitDate);
                  } else {
                    return d.month == _selectedDate.month && d.year == _selectedDate.year;
                  }
                }).toList();

                if (docs.isEmpty) {
                  String emptyText = 'Tidak ada transaksi di bulan ini';
                  if (_filterRange == '7hari') {
                    emptyText = 'Tidak ada transaksi dalam 7 hari terakhir';
                  } else if (_filterRange == '30hari') {
                    emptyText = 'Tidak ada transaksi dalam 30 hari terakhir';
                  }
                  return Center(child: Text(emptyText, style: TextStyle(color: theme.textMuted)));
                }

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
                  color: theme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.border),
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
                      Text(data['category'], style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        (isIncome ? '' : '- ') + currencyFormatter.format(data['amount']), 
                        style: TextStyle(color: isIncome ? Colors.blueAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(data['note'] ?? '-', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 10, color: theme.textMuted),
                          const SizedBox(width: 4),
                          Text(DateFormat('dd MMM yyyy, HH:mm').format(date), 
                            style: TextStyle(color: theme.textMuted, fontSize: 10)),
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
                    icon: Icon(Icons.more_vert, color: theme.textSecondary, size: 20),
                    color: theme.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'edit', child: Row(
                        children: [Icon(Icons.edit, size: 16, color: theme.textPrimary), const SizedBox(width: 8), Text('Edit', style: TextStyle(color: theme.textPrimary))],
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
                            backgroundColor: theme.card,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text('Hapus Transaksi?', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
                            content: Text('Saldo Anda akan dikembalikan secara otomatis.', style: TextStyle(color: theme.textSecondary)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal', style: TextStyle(color: theme.textSecondary))),
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
    ),
  ],
),
    );
  }
}
