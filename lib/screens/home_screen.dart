import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'dart:convert';

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
  final DatabaseService _dbService = DatabaseService();
  final User? user = FirebaseAuth.instance.currentUser;
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  
  int _activeScreenIndex = 0;

  // Cached Stream variables to prevent rebuilds
  late Stream<DocumentSnapshot> _userDataStream;
  late Stream<QuerySnapshot> _allTransactionsStream;
  late Stream<QuerySnapshot> _fixedExpensesStream;
  late Stream<QuerySnapshot> _recentTransactionsStream;

  // Form State
  String _selectedType = 'Pengeluaran';
  String _selectedCategory = 'Makan';
  String _selectedAllocation = 'Sekunder';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;
  DateTime _selectedDate = DateTime.now();
  DateTime _transactionDate = DateTime.now();
  String _chartFilter = 'Mingguan';

  List<String> _expenseCategories = ['Makan', 'Transport', 'Belanja', 'Hiburan', 'Lainnya'];
  List<String> _incomeCategories = ['Gaji', 'Bonus', 'Investasi', 'Hibah', 'Lainnya'];

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _activeScreenIndex);
    _userDataStream = _dbService.getUserData();
    _allTransactionsStream = _dbService.getAllTransactions();
    _fixedExpensesStream = _dbService.getFixedExpenses();
    _recentTransactionsStream = _dbService.getRecentTransactions();
    _listenToCategories();
    _dbService.checkAndProcessAutoPayments();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _listenToCategories() {
    _dbService.getCategories().listen((snap) {
      if (mounted) {
        final List<String> customCategories = snap.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['name'] ?? '').toString();
        }).where((name) => name.isNotEmpty).toList();

        setState(() {
          _expenseCategories.clear();
          _expenseCategories.addAll(['Makan', 'Transport', 'Belanja', 'Hiburan', 'Lainnya']);
          for (var cat in customCategories) {
            if (!_expenseCategories.contains(cat)) {
              _expenseCategories.add(cat);
            }
          }

          _incomeCategories.clear();
          _incomeCategories.addAll(['Gaji', 'Bonus', 'Investasi', 'Hibah', 'Lainnya']);
          for (var cat in customCategories) {
            if (!_incomeCategories.contains(cat)) {
              _incomeCategories.add(cat);
            }
          }

          final currentCategories = _selectedType == 'Pengeluaran' ? _expenseCategories : _incomeCategories;
          if (!currentCategories.contains(_selectedCategory)) {
            _selectedCategory = currentCategories.first;
          }
        });
      }
    });
  }

  void _showAddCategorySheet() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    String newName = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: formKey,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tambah Kategori Baru',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  style: TextStyle(color: theme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Nama Kategori',
                    labelStyle: TextStyle(color: theme.textSecondary),
                    fillColor: theme.inputBg,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                  onSaved: (v) => newName = v!.trim(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
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
                      onPressed: () async {
                        if (formKey.currentState?.validate() ?? false) {
                          formKey.currentState?.save();
                          final res = await _dbService.addCategory(name: newName);
                          if (res['success']) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Kategori berhasil ditambahkan!'), backgroundColor: Colors.green),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('❌ Gagal: ${res['error']}'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
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
      body: SafeArea(
        child: Column(
          children: [
            _buildNavbar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _activeScreenIndex = index;
                  });
                },
                children: [
                  _KeepAliveWrapper(child: SingleChildScrollView(child: _buildDashboardContent())),
                  _KeepAliveWrapper(child: SingleChildScrollView(child: GoalsScreen())),
                  _KeepAliveWrapper(child: SingleChildScrollView(child: LaporanScreen(initialDate: _selectedDate))),
                  _KeepAliveWrapper(child: ProfileScreen(onNavigateToDashboard: () => _goToPage(0))),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  void _goToPage(int index) {
    setState(() {
      _activeScreenIndex = index;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildDashboardContent() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _dbService.getUserData(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return Center(child: Text('Error: ${userSnapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        double balance = 0;
        double minBalanceReserve = 0;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final data = userSnapshot.data!.data() as Map<String, dynamic>?;
          balance = (data?['balance'] ?? 0).toDouble();
          minBalanceReserve = (data?['minBalanceReserve'] ?? data?['monthlyBudget'] ?? 0).toDouble();
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
              _buildMonthlyBudgetCard(minBalanceReserve, balance),
            ],
          ),
        );
      }
    );
  }

  Widget _buildNavbar() {
    final theme = Provider.of<ThemeProvider>(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.navBg,
        border: Border(bottom: BorderSide(color: theme.navBorder, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.accent, width: 1.5),
                  image: const DecorationImage(
                    image: AssetImage('assets/logo.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Arthico',
                style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Theme toggle button
              GestureDetector(
                onTap: () => theme.toggleTheme(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: theme.isDark ? const Color(0xFFFBBF24) : const Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              StreamBuilder<DocumentSnapshot>(
                stream: _userDataStream,
                builder: (context, snapshot) {
                  String? photoUrl;
                  String displayName = user?.displayName ?? 'User';
                  
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    if (data != null) {
                      photoUrl = data['photoUrl'];
                      displayName = data['name'] ?? displayName;
                    }
                  }

                  return GestureDetector(
                    onTap: () => _goToPage(3),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF10B981),
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? MemoryImage(base64Decode(photoUrl))
                          : null,
                      child: photoUrl != null && photoUrl.isNotEmpty
                          ? null
                          : Text(
                              displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'A',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final theme = Provider.of<ThemeProvider>(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.isDark ? const Color(0xFF1E293B).withOpacity(0.9) : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: theme.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomNavItem(Icons.grid_view_rounded, _activeScreenIndex == 0, 0),
              _bottomNavItem(Icons.track_changes_rounded, _activeScreenIndex == 1, 1),
              _bottomNavItem(Icons.bar_chart_rounded, _activeScreenIndex == 2, 2),
              _bottomNavItem(Icons.person_rounded, _activeScreenIndex == 3, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, bool isActive, int index) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return GestureDetector(
      onTap: () => _goToPage(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? const Color(0xFF10B981) : Colors.transparent,
          boxShadow: isActive 
              ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 12, spreadRadius: 2, offset: const Offset(0, 4))]
              : null,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : (theme.isDark ? Colors.white38 : Colors.black38),
          size: 24,
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
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textPrimary),
            children: [
              const TextSpan(text: 'Halo, '),
              TextSpan(
                text: user?.displayName ?? 'User',
                style: TextStyle(color: theme.accent),
              ),
            ],
          ),
        ),
        Text(
          'Pantau kesehatan finansial Anda hari ini.',
          style: TextStyle(color: theme.textSecondary, fontSize: 14),
        ),
      ],
    );
  }

  Widget _headerDatePicker() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final DateTime now = DateTime.now();
    final bool isToday = _selectedDate.day == now.day &&
        _selectedDate.month == now.month &&
        _selectedDate.year == now.year;
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
        if (picked != null && picked != _selectedDate) {
          setState(() {
            _selectedDate = picked;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 16, color: theme.textSecondary),
            const SizedBox(width: 8),
            Text(
              isToday ? 'Hari Ini' : DateFormat('dd MMM yyyy').format(_selectedDate),
              style: TextStyle(color: theme.textPrimary),
            ),
            Icon(Icons.arrow_drop_down, color: theme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(double totalBalance) {
    return StreamBuilder<QuerySnapshot>(
      stream: _allTransactionsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Err: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 10));
        
        double income = 0;
        double expense = 0;
        double displayBalance = totalBalance;

        final DateTime now = DateTime.now();
        final bool isToday = _selectedDate.day == now.day &&
            _selectedDate.month == now.month &&
            _selectedDate.year == now.year;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            if (timestamp == null) continue;
            DateTime date = timestamp.toDate();
            double amt = (data['amount'] ?? 0).toDouble();

            if (isToday) {
              if (data['type'] == 'Pemasukan') {
                income += amt;
              } else {
                expense += amt;
              }
            } else {
              if (date.day == _selectedDate.day &&
                  date.month == _selectedDate.month &&
                  date.year == _selectedDate.year) {
                if (data['type'] == 'Pemasukan') {
                  income += amt;
                } else {
                  expense += amt;
                }
              }
            }
          }
          if (!isToday) {
            displayBalance = income - expense;
          }
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _summaryCard('Total Pemasukan', currencyFormatter.format(income), isToday ? 'Seluruh dana masuk' : 'Dana masuk tanggal ini', Icons.arrow_upward, Colors.orange),
              const SizedBox(width: 16),
              _summaryCard('Total Pengeluaran', currencyFormatter.format(expense), isToday ? 'Seluruh dana keluar' : 'Dana keluar tanggal ini', Icons.arrow_downward, Colors.green),
              const SizedBox(width: 16),
              _balanceCard(displayBalance),
              const SizedBox(width: 16),
              _analysisCard(income, expense),
            ],
          ),
        );
      }
    );
  }

  Widget _summaryCard(String title, String amount, String subtitle, IconData icon, Color iconColor) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      width: isMobile ? MediaQuery.of(context).size.width * 0.7 : 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(amount, style: TextStyle(color: theme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: theme.textMuted, fontSize: 12)),
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
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return StreamBuilder<QuerySnapshot>(
      stream: _fixedExpensesStream,
      builder: (context, snapshot) {
        double totalBeban = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            if (!(doc['isPaid'] ?? false)) {
              totalBeban += (doc['amount'] ?? 0).toDouble();
            }
          }
        }

        double sisaBolehJajan = (totalIncome - totalExpense) - totalBeban;

        return Container(
          width: isMobile ? MediaQuery.of(context).size.width * 0.7 : 240,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.security, color: Colors.blueAccent, size: 16),
                  const SizedBox(width: 8),
                  Text('Analisis Sisa Aman', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
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
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: theme.textMuted, fontSize: 10)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTransactionForm() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    bool isSmallScreen = MediaQuery.of(context).size.width < 800;
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        color: theme.card,
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
                    children: [
                      Text('Catat Transaksi Baru', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Input harianmu.', style: TextStyle(color: theme.textMuted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: _showAddCategorySheet,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('+ Kategori', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
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
                  _formDatePicker('Tanggal', _transactionDate, fieldWidth, () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _transactionDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
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
                    if (picked != null && picked != _transactionDate) {
                      setState(() {
                        _transactionDate = picked;
                      });
                    }
                  }),
                  _formInputWidget('Nominal (Rp)', _amountController, fieldWidth, TextInputType.number),
                  SizedBox(
                    width: fieldWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('', style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isSaving ? null : _saveTransaction,
                              child: _isSaving 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Simpan Transaksi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Keterangan', style: TextStyle(color: theme.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            style: TextStyle(color: theme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Contoh: Beli sarapan',
              hintStyle: TextStyle(color: theme.textMuted),
              fillColor: theme.inputBg,
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
      customTimestamp: _transactionDate,
    );
    
    if (result['success']) {
      setState(() {
        _isSaving = false;
        _amountController.clear();
        _noteController.clear();
        _transactionDate = DateTime.now();
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
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.inputBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                dropdownColor: theme.card,
                style: TextStyle(color: theme.textPrimary),
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

  Widget _formDatePicker(String label, DateTime value, double width, VoidCallback onTap) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.inputBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(value),
                    style: TextStyle(color: theme.textPrimary),
                  ),
                  Icon(Icons.calendar_today, size: 16, color: theme.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formInputWidget(String label, TextEditingController controller, double width, TextInputType type) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
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
              Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 14)),
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
                    decoration: BoxDecoration(color: theme.border, borderRadius: BorderRadius.circular(4)),
                    child: Text(e, style: TextStyle(color: theme.textMuted, fontSize: 10)),
                  ),
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: type,
            style: TextStyle(color: theme.textPrimary),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: theme.textMuted),
              fillColor: theme.inputBg,
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
    final theme = Provider.of<ThemeProvider>(context);
    return StreamBuilder<QuerySnapshot>(
      stream: _allTransactionsStream,
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
          double incVal = incomeMap[key] ?? 0;
          double expVal = expenseMap[key] ?? 0;
          barGroups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: incVal,
                  color: const Color(0xFF3B82F6),
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  label: BarChartRodLabel(
                    show: incVal > 0,
                    text: _formatShortAmount(incVal),
                    style: TextStyle(color: theme.textPrimary, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
                BarChartRodData(
                  toY: expVal,
                  color: const Color(0xFFEF4444),
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  label: BarChartRodLabel(
                    show: expVal > 0,
                    text: _formatShortAmount(expVal),
                    style: TextStyle(color: theme.textPrimary, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Text(
                    _chartFilter == 'Mingguan' ? 'Trend 7 Hari Terakhir' : 'Trend Bulanan ${DateFormat('MMM yyyy').format(_selectedDate)}', 
                    style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  _buildToggleFilter(),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 200,
                width: double.infinity,
                child: !snapshot.hasData 
                  ? const Center(child: CircularProgressIndicator())
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _calculateMaxY(incomeMap, expenseMap),
                        barGroups: barGroups,
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: theme.isDark ? Colors.white10 : Colors.black12, strokeWidth: 1)),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                if (val.toInt() < 0 || val.toInt() >= labels.length) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(labels[val.toInt()], style: TextStyle(color: theme.textMuted, fontSize: 9)),
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
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      decoration: BoxDecoration(
        color: theme.isDark ? const Color(0xFF0F172A) : theme.inputBg,
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
    final theme = Provider.of<ThemeProvider>(context, listen: false);
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
          style: TextStyle(color: isActive ? Colors.white : theme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }

  double _calculateMaxY(Map<String, double> inc, Map<String, double> exp) {
    double maxVal = 0;
    inc.forEach((k, v) => maxVal = v > maxVal ? v : maxVal);
    exp.forEach((k, v) => maxVal = v > maxVal ? v : maxVal);
    return maxVal == 0 ? 100000 : maxVal * 1.25;
  }

  String _formatShortAmount(double value) {
    if (value == 0) return '0';
    if (value >= 1000000000) {
      double res = value / 1000000000;
      return '${res.toStringAsFixed(res % 1 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000000) {
      double res = value / 1000000;
      return '${res.toStringAsFixed(res % 1 == 0 ? 0 : 1)}jt';
    }
    if (value >= 1000) {
      double res = value / 1000;
      return '${res.toStringAsFixed(res % 1 == 0 ? 0 : 1)}rb';
    }
    return value.toStringAsFixed(0);
  }

  Widget _chartLegend(String label, Color color) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final theme = Provider.of<ThemeProvider>(context);
    final DateTime now = DateTime.now();
    final bool isToday = _selectedDate.day == now.day &&
        _selectedDate.month == now.month &&
        _selectedDate.year == now.year;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isToday ? 'Aktivitas Terbaru' : 'Aktivitas Tanggal Ini', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _recentTransactionsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Err: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 10)));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = data['timestamp'] as Timestamp?;
                if (timestamp == null) return false;
                DateTime date = timestamp.toDate();
                if (isToday) {
                  return date.month == _selectedDate.month && date.year == _selectedDate.year;
                } else {
                  return date.day == _selectedDate.day &&
                      date.month == _selectedDate.month &&
                      date.year == _selectedDate.year;
                }
              }).toList();

              if (docs.isEmpty) {
                return Center(child: Text('Belum ada transaksi', style: TextStyle(color: theme.textMuted)));
              }
              return Column(
                children: docs.take(5).map((doc) {
                  bool isIncome = doc['type'] == 'Pemasukan';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: isIncome ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: isIncome ? Colors.orange : Colors.green, size: 16),
                    ),
                    title: Text(doc['category'], style: TextStyle(color: theme.textPrimary, fontSize: 14)),
                    subtitle: Text(doc['note'] ?? '', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    trailing: Text(
                      (isIncome ? '' : '- ') + currencyFormatter.format(doc['amount']),
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

  Widget _buildMonthlyBudgetCard(double minBalanceReserve, double currentBalance) {
    final theme = Provider.of<ThemeProvider>(context);

    double availableToSpend = currentBalance - minBalanceReserve;
    double progress = currentBalance > 0 
        ? ((currentBalance - minBalanceReserve) / currentBalance).clamp(0.0, 1.0) 
        : 0.0;

    Color statusColor = const Color(0xFF10B981);
    if (availableToSpend <= 0) {
      statusColor = Colors.redAccent;
    } else if (availableToSpend < minBalanceReserve * 0.5) {
      statusColor = Colors.orangeAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 10),
              Text(
                'Keuangan Bulan Ini / Budget',
                style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: theme.accent, size: 20),
                tooltip: 'Atur Minimal Budget',
                onPressed: () => _showSetBudgetDialog(minBalanceReserve),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (minBalanceReserve <= 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text('Belum ada batas minimal saldo yang diatur.', style: TextStyle(color: theme.textMuted, fontSize: 13)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showSetBudgetDialog(minBalanceReserve),
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text('Atur Minimal Budget', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Minimal Budget (Batas Saldo)', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(currencyFormatter.format(minBalanceReserve), style: const TextStyle(color: Color(0xFF6366F1), fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Sisa Boleh Dipakai', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormatter.format(availableToSpend > 0 ? availableToSpend : 0),
                      style: TextStyle(color: statusColor, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                color: statusColor,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  availableToSpend > 0 ? 'Saldo dalam batas aman' : 'Batas minimal saldo tercapai!',
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Saldo Harus Tersisa: ${currencyFormatter.format(minBalanceReserve)}',
                  style: TextStyle(color: theme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showSetBudgetDialog(double currentReserve) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final TextEditingController reserveController = TextEditingController(
      text: currentReserve > 0 ? currentReserve.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Atur Minimal Budget (Batas Saldo)', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tentukan nominal saldo minimal yang harus selalu tersisa. Transaksi akan otomatis ditolak jika menyebabkan saldo berkurang di bawah batas ini:', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: reserveController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: theme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Batas Saldo Minimal (Rp)',
                  labelStyle: TextStyle(color: theme.textSecondary),
                  hintText: 'Contoh: 100000',
                  hintStyle: TextStyle(color: theme.textMuted),
                  fillColor: theme.inputBg,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  prefixText: 'Rp ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: TextStyle(color: theme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                double newReserve = double.tryParse(reserveController.text.trim()) ?? 0;
                Navigator.pop(context);
                await _dbService.updateUserPreference('minBalanceReserve', newReserve);
                await _dbService.updateUserPreference('monthlyBudget', newReserve);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Batas saldo minimal berhasil diatur: ${currencyFormatter.format(newReserve)}')),
                  );
                }
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
