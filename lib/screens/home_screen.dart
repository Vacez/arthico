import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

import '../services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'atur_list_screen.dart';
import 'goals_screen.dart';
import 'laporan_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final User? user = FirebaseAuth.instance.currentUser;
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  
  int _activeScreenIndex = 0;

  // Form State
  String _selectedType = 'Pengeluaran';
  String _selectedCategory = 'Makan';
  String _selectedAllocation = 'Sekunder';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;
  DateTime _selectedDate = DateTime.now();
  String _chartFilter = 'Mingguan';

  final List<String> _expenseCategories = ['Makan', 'Transport', 'Belanja', 'Hiburan', 'Lainnya'];
  final List<String> _incomeCategories = ['Gaji', 'Bonus', 'Investasi', 'Hibah', 'Lainnya'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            _buildNavbar(),
            Expanded(
              child: SingleChildScrollView(
                child: _buildActiveScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveScreen() {
    switch (_activeScreenIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return GoalsScreen();
      case 2:
        return LaporanScreen(initialDate: _selectedDate);
      case 3:
        return ProfileScreen();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _dbService.getUserData(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return Center(child: Text('Error: ${userSnapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        double balance = 0;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final data = userSnapshot.data!.data() as Map<String, dynamic>?;
          balance = (data?['balance'] ?? 0).toDouble();
        }

        bool isMobile = MediaQuery.of(context).size.width < 600;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildSummaryCards(balance),
              const SizedBox(height: 24),
              _buildTransactionForm(),
              const SizedBox(height: 24),
              _buildAnalyticsArea(),
              const SizedBox(height: 24),
              _buildHabitBanner(),
            ],
          ),
        );
      }
    );
  }

  Widget _buildNavbar() {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet, color: Color(0xFF818CF8), size: 24),
              if (!isMobile) ...[
                const SizedBox(width: 8),
                const Text(
                  'Arthico',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _navItem(isMobile ? 'Home' : 'Dashboard', Icons.home, _activeScreenIndex == 0, 0),
                  _navItem('Goals', Icons.track_changes, _activeScreenIndex == 1, 1),
                  _navItem('Laporan', Icons.bar_chart, _activeScreenIndex == 2, 2),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _activeScreenIndex = 3),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF10B981),
              child: Text(user?.displayName?.substring(0, 1).toUpperCase() ?? 'A',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(String label, IconData icon, bool isActive, int index) {
    return GestureDetector(
      onTap: () => setState(() => _activeScreenIndex = index),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return isMobile 
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerGreeting(),
            const SizedBox(height: 16),
            _headerDatePicker(),
          ],
        )
      : Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _headerGreeting(),
            _headerDatePicker(),
          ],
        );
  }

  Widget _headerGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            children: [
              const TextSpan(text: 'Halo, '),
              TextSpan(
                text: user?.displayName ?? 'User',
                style: const TextStyle(color: Color(0xFF818CF8)),
              ),
            ],
          ),
        ),
        const Text(
          'Pantau kesehatan finansial Anda hari ini.',
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
      ],
    );
  }

  Widget _headerDatePicker() {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF818CF8),
                  onPrimary: Colors.white,
                  surface: Color(0xFF1E293B),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null && picked != _selectedDate) {
          setState(() {
            _selectedDate = picked;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Colors.white60),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMM yyyy').format(_selectedDate),
              style: const TextStyle(color: Colors.white),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white60),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(double totalBalance) {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getAllTransactions(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Err: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 10));
        
        double income = 0;
        double expense = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            if (timestamp == null) continue;

            DateTime date = timestamp.toDate();
            // FILTER BY MONTH AND YEAR
            if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
              double amt = (data['amount'] ?? 0).toDouble();
              if (data['type'] == 'Pemasukan') {
                income += amt;
              } else {
                expense += amt;
              }
            }
          }
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _summaryCard('Total Pemasukan', currencyFormatter.format(income), 'Seluruh dana masuk', Icons.arrow_upward, Colors.orange),
              const SizedBox(width: 16),
              _summaryCard('Total Pengeluaran', currencyFormatter.format(expense), 'Seluruh dana keluar', Icons.arrow_downward, Colors.green),
              const SizedBox(width: 16),
              _balanceCard(totalBalance),
              const SizedBox(width: 16),
              _analysisCard(income, expense),
            ],
          ),
        );
      }
    );
  }

  Widget _summaryCard(String title, String amount, String subtitle, IconData icon, Color iconColor) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      width: isMobile ? MediaQuery.of(context).size.width * 0.7 : 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(amount, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _balanceCard(double balance) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      width: isMobile ? MediaQuery.of(context).size.width * 0.8 : 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Saldo Gabungan', style: TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(height: 8),
          Text(currencyFormatter.format(balance), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _subBalance('Sekunder', currencyFormatter.format(balance), Colors.green),
              const SizedBox(width: 16),
              _subBalance('Primer', 'Rp 0', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _subBalance(String label, String amount, Color color) {
    return Row(
      children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            Text(amount, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _analysisCard(double totalIncome, double totalExpense) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getFixedExpenses(),
      builder: (context, snapshot) {
        double totalBeban = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            if (!(doc['isPaid'] ?? false)) {
              totalBeban += (doc['amount'] ?? 0).toDouble();
            }
          }
        }

        // Sisa aman = Pemasukan - Pengeluaran - Beban Pokok yang belum dibayar
        // Namun biasanya sisa aman dihitung dari (Pemasukan - Pengeluaran) - Beban Pokok
        double sisaBolehJajan = (totalIncome - totalExpense) - totalBeban;

        return Container(
          width: isMobile ? MediaQuery.of(context).size.width * 0.7 : 240,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.security, color: Colors.blueAccent, size: 16),
                  SizedBox(width: 8),
                  Text('Analisis Sisa Aman', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              _rowText('Beban Pokok (List):', currencyFormatter.format(totalBeban), Colors.redAccent),
              const SizedBox(height: 4),
              _rowText('Sisa Boleh Jajan:', currencyFormatter.format(sisaBolehJajan > 0 ? sisaBolehJajan : 0), sisaBolehJajan > 0 ? Colors.greenAccent : Colors.redAccent),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AturListScreen()),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.settings, size: 14, color: Colors.white),
                      SizedBox(width: 8),
                      Text('ATUR LIST', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _rowText(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTransactionForm() {
    bool isSmallScreen = MediaQuery.of(context).size.width < 800;
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars, color: Colors.orangeAccent),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Catat Transaksi Baru', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Input harianmu.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('+ Kategori', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              double fieldWidth = constraints.maxWidth < 600 ? constraints.maxWidth : (constraints.maxWidth - 32) / 3;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _formDropdown('Jenis', _selectedType, fieldWidth, ['Pengeluaran', 'Pemasukan'], (val) {
                    setState(() {
                      _selectedType = val!;
                      _selectedCategory = _selectedType == 'Pengeluaran' 
                          ? _expenseCategories[0] 
                          : _incomeCategories[0];
                    });
                  }),
                  _formDropdown(
                    'Kategori', 
                    _selectedCategory, 
                    fieldWidth, 
                    _selectedType == 'Pengeluaran' ? _expenseCategories : _incomeCategories, 
                    (val) => setState(() => _selectedCategory = val!)
                  ),
                  _formDropdown('Alokasi Dana', _selectedAllocation, fieldWidth, ['Sekunder', 'Primer'], (val) => setState(() => _selectedAllocation = val!)),
                  _formInputWidget('Nominal (Rp)', _amountController, constraints.maxWidth < 600 ? constraints.maxWidth : constraints.maxWidth * 0.6, TextInputType.number),
                  SizedBox(
                    width: constraints.maxWidth < 600 ? constraints.maxWidth : constraints.maxWidth * 0.35,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSaving ? null : _saveTransaction,
                        child: _isSaving 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Simpan Transaksi', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Keterangan', style: TextStyle(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Contoh: Beli sarapan',
              hintStyle: const TextStyle(color: Colors.white24),
              fillColor: const Color(0xFF0F172A),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  void _saveTransaction() async {
    if (_amountController.text.isEmpty) return;
    
    setState(() => _isSaving = true);
    
    double amount = double.tryParse(_amountController.text) ?? 0;
    
    Map<String, dynamic> result = await _dbService.addTransaction(
      type: _selectedType,
      category: _selectedCategory,
      allocation: _selectedAllocation,
      amount: amount,
      note: _noteController.text,
    );
    
    if (result['success']) {
      setState(() {
        _isSaving = false;
        _amountController.clear();
        _noteController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Transaksi berhasil disimpan!'), backgroundColor: Colors.green),
      );
    } else {
      setState(() => _isSaving = false);
      String errorMsg = result['error'].toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Gagal: $errorMsg'), 
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _formDropdown(String label, String value, double width, List<String> items, Function(String?) onChanged) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                isExpanded: true,
                items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formInputWidget(String label, TextEditingController controller, double width, TextInputType type) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 14)),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: ['50k', '100k', '500k'].map((e) => GestureDetector(
                  onTap: () {
                    int val = int.parse(e.replaceAll('k', '')) * 1000;
                    controller.text = val.toString();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                    child: Text(e, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ),
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: type,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: const TextStyle(color: Colors.white24),
              fillColor: const Color(0xFF0F172A),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsArea() {
    bool isMobile = MediaQuery.of(context).size.width < 900;
    return isMobile 
      ? Column(
          children: [
            _buildChartArea(),
            const SizedBox(height: 24),
            _buildRecentActivity(),
          ],
        )
      : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildChartArea()),
            const SizedBox(width: 24),
            Expanded(flex: 1, child: _buildRecentActivity()),
          ],
        );
  }

  Widget _buildChartArea() {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getAllTransactions(),
      builder: (context, snapshot) {
        List<BarChartGroupData> barGroups = [];
        Map<String, double> incomeMap = {};
        Map<String, double> expenseMap = {};
        List<String> labels = [];

        if (_chartFilter == 'Mingguan') {
          // Last 7 days from TODAY
          DateTime now = DateTime.now();
          for (int i = 0; i < 7; i++) {
            DateTime d = now.subtract(Duration(days: 6 - i));
            String key = DateFormat('dd/MM').format(d);
            labels.add(key);
            incomeMap[key] = 0;
            expenseMap[key] = 0;
          }

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = data['timestamp'] as Timestamp?;
              if (ts == null) continue;
              DateTime d = ts.toDate();
              String key = DateFormat('dd/MM').format(d);
              if (incomeMap.containsKey(key)) {
                double amt = (data['amount'] ?? 0).toDouble();
                if (data['type'] == 'Pemasukan') incomeMap[key] = incomeMap[key]! + amt;
                else expenseMap[key] = expenseMap[key]! + amt;
              }
            }
          }
        } else {
          // Bulanan: Show weeks of the selected month
          labels = ['Minggu 1', 'Minggu 2', 'Minggu 3', 'Minggu 4', 'Minggu 5'];
          for (var l in labels) {
            incomeMap[l] = 0;
            expenseMap[l] = 0;
          }

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = data['timestamp'] as Timestamp?;
              if (ts == null) continue;
              DateTime d = ts.toDate();
              if (d.month == _selectedDate.month && d.year == _selectedDate.year) {
                double amt = (data['amount'] ?? 0).toDouble();
                int weekNum = ((d.day - 1) ~/ 7) + 1;
                String key = 'Minggu ${weekNum > 5 ? 5 : weekNum}';
                if (data['type'] == 'Pemasukan') incomeMap[key] = (incomeMap[key] ?? 0) + amt;
                else expenseMap[key] = (expenseMap[key] ?? 0) + amt;
              }
            }
          }
        }

        for (int i = 0; i < labels.length; i++) {
          String key = labels[i];
          barGroups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: incomeMap[key] ?? 0,
                  color: const Color(0xFF3B82F6),
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: expenseMap[key] ?? 0,
                  color: const Color(0xFFEF4444),
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   Text(
                    _chartFilter == 'Mingguan' ? 'Trend 7 Hari Terakhir' : 'Trend Bulanan ${DateFormat('MMM yyyy').format(_selectedDate)}', 
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                  const Spacer(),
                  _buildToggleFilter(),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 200,
                width: double.infinity,
                child: snapshot.connectionState == ConnectionState.waiting 
                  ? const Center(child: CircularProgressIndicator())
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _calculateMaxY(incomeMap, expenseMap),
                        barGroups: barGroups,
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: Colors.white10, strokeWidth: 1)),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                if (val.toInt() >= labels.length) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(labels[val.toInt()], style: const TextStyle(color: Colors.white38, fontSize: 9)),
                                );
                              }
                            ),
                          ),
                        ),
                      ),
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _chartLegend('Pemasukan', const Color(0xFF3B82F6)),
                  const SizedBox(width: 20),
                  _chartLegend('Pengeluaran', const Color(0xFFEF4444)),
                ],
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildToggleFilter() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _filterBtn('Mingguan'),
          _filterBtn('Bulanan'),
        ],
      ),
    );
  }

  Widget _filterBtn(String label) {
    bool isActive = _chartFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _chartFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label, 
          style: TextStyle(color: isActive ? Colors.white : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }

  double _calculateMaxY(Map<String, double> inc, Map<String, double> exp) {
    double maxVal = 0;
    inc.forEach((k, v) => maxVal = v > maxVal ? v : maxVal);
    exp.forEach((k, v) => maxVal = v > maxVal ? v : maxVal);
    return maxVal == 0 ? 100000 : maxVal * 1.2;
  }

  Widget _chartLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aktivitas Terbaru', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _dbService.getRecentTransactions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Belum ada transaksi', style: TextStyle(color: Colors.white38)));
              }
              return Column(
                children: snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final timestamp = data['timestamp'] as Timestamp?;
                  if (timestamp == null) return false;
                  DateTime date = timestamp.toDate();
                  return date.month == _selectedDate.month && date.year == _selectedDate.year;
                }).take(5).map((doc) {
                  bool isIncome = doc['type'] == 'Pemasukan';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: isIncome ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: isIncome ? Colors.orange : Colors.green, size: 16),
                    ),
                    title: Text(doc['category'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(doc['note'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    trailing: Text(
                      currencyFormatter.format(doc['amount']),
                      style: TextStyle(color: isIncome ? Colors.orange : Colors.green, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              );
            }
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HistoryScreen(initialDate: _selectedDate)),
                );
              },
              child: const Text('Lihat semua transaksi', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitBanner() {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getAllTransactions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        Map<String, double> categorySums = {};
        String largestExpenseNote = '';
        double largestExpenseAmount = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['timestamp'] as Timestamp?;
          if (ts == null) continue;
          DateTime d = ts.toDate();

          if (d.month == _selectedDate.month && d.year == _selectedDate.year && data['type'] == 'Pengeluaran') {
            double amt = (data['amount'] ?? 0).toDouble();
            String cat = data['category'] ?? 'Lainnya';
            categorySums[cat] = (categorySums[cat] ?? 0) + amt;

            if (amt > largestExpenseAmount) {
              largestExpenseAmount = amt;
              largestExpenseNote = data['note'] ?? cat;
            }
          }
        }

        if (categorySums.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text('Belum ada pengeluaran dicatat bulan ini.', style: TextStyle(color: Colors.white38))),
          );
        }

        List<PieChartSectionData> sections = [];
        int i = 0;
        final List<Color> colors = [const Color(0xFF818CF8), const Color(0xFFF472B6), const Color(0xFF34D399), const Color(0xFFFBBF24), const Color(0xFF60A5FA)];
        
        categorySums.forEach((cat, sum) {
          sections.add(
            PieChartSectionData(
              value: sum,
              title: '', // Hide title in sections
              color: colors[i % colors.length],
              radius: 40,
              showTitle: false,
            )
          );
          i++;
        });

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology, color: Color(0xFFF472B6)),
                  SizedBox(width: 8),
                  Text('Analisis Kebiasaan Keuangan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                   SizedBox(
                    height: 100,
                    width: 100,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 30,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pengeluaran Terbesar:', style: TextStyle(color: Colors.white60, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(largestExpenseNote, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        Text(currencyFormatter.format(largestExpenseAmount), style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        const Text('Distribusi Kategori:', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: categorySums.keys.take(3).toList().asMap().entries.map((e) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[e.key % colors.length], shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text(e.value, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }
}
