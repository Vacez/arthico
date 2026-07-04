import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_saver/file_saver.dart';
import 'dart:io';

class LaporanScreen extends StatefulWidget {
  final DateTime? initialDate;
  const LaporanScreen({super.key, this.initialDate});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  final DatabaseService _dbService = DatabaseService();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  late DateTime _selectedDate;
  final GlobalKey _chartKey = GlobalKey();
  bool _isWeekly = false; // true for weekly view, false for monthly
  String _selectedReportType = 'Ringkasan'; // 'Ringkasan', 'Neraca', 'Laba Rugi', 'Buku Besar', 'Arus Kas'
  bool _showAllTransactions = false;
  late Stream<QuerySnapshot> _goalsStream;
  late Stream<QuerySnapshot> _fixedExpensesStream;
  late Stream<QuerySnapshot> _transactionsStream;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _goalsStream = _dbService.getGoals();
    _fixedExpensesStream = _dbService.getFixedExpenses();
    _transactionsStream = _dbService.getAllTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    
    return StreamBuilder<QuerySnapshot>(
      stream: _goalsStream,
      builder: (context, goalsSnapshot) {
        double totalSavings = 0;
        List<QueryDocumentSnapshot> goalsList = [];
        if (goalsSnapshot.hasData) {
          goalsList = goalsSnapshot.data!.docs;
          for (var doc in goalsList) {
            totalSavings += (doc['currentAmount'] ?? 0).toDouble();
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _fixedExpensesStream,
          builder: (context, fixedExpensesSnapshot) {
            List<QueryDocumentSnapshot> fixedExpensesList = [];
            if (fixedExpensesSnapshot.hasData) {
              fixedExpensesList = fixedExpensesSnapshot.data!.docs;
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _transactionsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Err: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                double income = 0;
                double expense = 0;
                double cumulativeBalance = 0;
                List<BarChartGroupData> chartData = [];

                if (snapshot.hasData) {
                  // Calculate cumulativeBalance up to the end of the selected month
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = data['timestamp'] as Timestamp?;
                    if (timestamp == null) continue;
                    DateTime date = timestamp.toDate();
                    
                    double amt = (data['amount'] ?? 0).toDouble();
                    bool isIncome = data['type'] == 'Pemasukan';
                    
                    if (date.year < _selectedDate.year || (date.year == _selectedDate.year && date.month <= _selectedDate.month)) {
                      if (isIncome) {
                        cumulativeBalance += amt;
                      } else {
                        cumulativeBalance -= amt;
                      }
                    }
                  }

                  // Aggregate data based on selected period
                  if (_isWeekly) {
                    // Weekly aggregation within the selected month (initialize 5 weeks)
                    Map<int, double> weeklyIncome = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
                    Map<int, double> weeklyExpense = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final timestamp = data['timestamp'] as Timestamp?;
                      if (timestamp == null) continue;
                      DateTime date = timestamp.toDate();
                      if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
                        int weekOfMonth = ((date.day - 1) ~/ 7) + 1; // 1-5
                        if (weekOfMonth > 5) weekOfMonth = 5;
                        double amt = (data['amount'] ?? 0).toDouble();
                        if (data['type'] == 'Pemasukan') {
                          weeklyIncome[weekOfMonth] = (weeklyIncome[weekOfMonth] ?? 0) + amt;
                        } else {
                          weeklyExpense[weekOfMonth] = (weeklyExpense[weekOfMonth] ?? 0) + amt;
                        }
                      }
                    }
                    // Build chart data for each week sequentially (x goes from 1 to 5)
                    List<int> sortedWeeks = [1, 2, 3, 4, 5];
                    chartData = sortedWeeks.map((week) {
                      double inc = weeklyIncome[week] ?? 0;
                      double exp = weeklyExpense[week] ?? 0;
                      return BarChartGroupData(
                        x: week,
                        barRods: [
                          BarChartRodData(
                            toY: inc, 
                            color: Colors.blue, 
                            width: 8,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                          BarChartRodData(
                            toY: exp, 
                            color: Colors.red, 
                            width: 8,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList();
                    // Sum totals for display
                    income = weeklyIncome.values.fold(0, (p, e) => p + e);
                    expense = weeklyExpense.values.fold(0, (p, e) => p + e);
                  } else {
                    // Existing monthly aggregation
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final timestamp = data['timestamp'] as Timestamp?;
                      if (timestamp == null) continue;
                      DateTime date = timestamp.toDate();
                      if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
                        double amt = (data['amount'] ?? 0).toDouble();
                        if (data['type'] == 'Pemasukan') {
                          income += amt;
                        } else {
                          expense += amt;
                        }
                      }
                    }
                    chartData = [
                      BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: income, color: Colors.blue, width: 20)]),
                      BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: expense, color: Colors.red, width: 20)]),
                    ];
                  }
                }

                bool isMobile = MediaQuery.of(context).size.width < 700;

                return Padding(
                  padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isMobile ? 16 : 24),
                        decoration: BoxDecoration(
                          color: theme.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bar_chart, color: theme.accent),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Laporan Keuangan', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                        Text(DateFormat('MMM yyyy').format(_selectedDate), style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                                      ],
                                    ),
                                  ],
                                ),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      GestureDetector(
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
                                          if (picked != null) {
                                            setState(() {
                                              _selectedDate = picked;
                                              _showAllTransactions = false;
                                            });
                                          }
                                        },
                                        child: _filterDropdown(DateFormat('MMM yyyy').format(_selectedDate)),
                                      ),
                                      const SizedBox(width: 8),
                                      _actionButton('PDF', const Color(0xFFEF4444), () => _exportPdf()),
                                      const SizedBox(width: 8),
                                      _actionButton('Excel', const Color(0xFF10B981), () => _exportExcel()),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildReportTypeSelector(),
                            const SizedBox(height: 20),
                            _buildCurrentReportContent(
                              snapshot,
                              chartData,
                              income,
                              expense,
                              cumulativeBalance,
                              totalSavings,
                              goalsList,
                              fixedExpensesList,
                              isMobile,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _togglePeriod(bool weekly) {
    setState(() {
      _isWeekly = weekly;
    });
  }

  Widget _filterDropdown(String value) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.isDark ? const Color(0xFF0F172A) : theme.inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Text(value, style: TextStyle(color: theme.textPrimary, fontSize: 12)),
          Icon(Icons.arrow_drop_down, color: theme.textSecondary, size: 16),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildChartArea(List<BarChartGroupData> chartData) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.isDark ? Colors.black12 : theme.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: theme.accent, size: 16),
              const SizedBox(width: 8),
              Text('Grafik Keuangan', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
              const Spacer(),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _togglePeriod(true),
                    child: _toggleItem('Mingguan', _isWeekly),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _togglePeriod(false),
                    child: _toggleItem('Bulanan', !_isWeekly),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          RepaintBoundary(
            key: _chartKey,
            child: SizedBox(
              height: 200,
              child: chartData.isEmpty 
                ? Center(child: Icon(Icons.show_chart, color: theme.textMuted, size: 100))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      barGroups: chartData,
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (_isWeekly) {
                                int week = value.toInt();
                                if (week >= 1 && week <= 5) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text('Mgg $week', style: TextStyle(color: theme.textSecondary, fontSize: 9)),
                                  );
                                }
                                return const SizedBox.shrink();
                              } else {
                                switch (value.toInt()) {
                                  case 0:
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text('Pemasukan', style: TextStyle(color: theme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
                                    );
                                  case 1:
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text('Pengeluaran', style: TextStyle(color: theme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
                                    );
                                  default:
                                    return const SizedBox.shrink();
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleItem(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF6366F1) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.grey, fontSize: 12)),
    );
  }

  Widget _buildSisaKeuangan(double income, double expense, double sisa, double totalSavings) {
    double monthlySisa = income - expense;
    double progress = income > 0 ? (monthlySisa / income).clamp(0, 1) : 0;
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.isDark ? Colors.black12 : theme.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          Text('SISA KEUANGAN', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Text(currencyFormatter.format(sisa), style: TextStyle(color: sisa >= 0 ? const Color(0xFF10B981) : Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Tersisa ${(progress * 100).toStringAsFixed(0)}% dari pemasukan bulan ini', style: TextStyle(color: theme.textMuted, fontSize: 10)),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progress, backgroundColor: theme.border, color: monthlySisa >= 0 ? const Color(0xFF10B981) : Colors.redAccent, minHeight: 4),
          const SizedBox(height: 24),
          _reportRow(Icons.arrow_upward, 'Pemasukan', currencyFormatter.format(income), Colors.blue),
          const SizedBox(height: 12),
          _reportRow(Icons.arrow_downward, 'Pengeluaran', currencyFormatter.format(expense), Colors.red),
          const SizedBox(height: 12),
          _reportRow(Icons.account_balance_wallet, 'Total Tabungan', currencyFormatter.format(totalSavings), Colors.indigo),
        ],
      ),
    );
  }

  Widget _reportRow(IconData icon, String label, String value, Color iconColor) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.isDark ? const Color(0xFF0F172A) : theme.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
          const Spacer(),
          Text(value, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRincianTransaksi(AsyncSnapshot<QuerySnapshot> snapshot) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    
    final allTransactions = snapshot.data?.docs ?? [];
    final filteredTransactions = allTransactions.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp == null) return false;
      final date = timestamp.toDate();
      return date.month == _selectedDate.month && date.year == _selectedDate.year;
    }).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.list, color: theme.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text('Rincian Transaksi', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredTransactions.isEmpty)
            Text('Tidak ada data transaksi', style: TextStyle(color: theme.textMuted))
          else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _showAllTransactions
                  ? filteredTransactions.length
                  : (filteredTransactions.length > 3 ? 3 : filteredTransactions.length),
              itemBuilder: (context, index) {
                var doc = filteredTransactions[index];
                final data = doc.data() as Map<String, dynamic>;
                bool isIncome = data['type'] == 'Pemasukan';
                return ListTile(
                  leading: Icon(isIncome ? Icons.add_circle : Icons.remove_circle, color: isIncome ? Colors.blue : Colors.red),
                  title: Text(data['category'] ?? '-', style: TextStyle(color: theme.textPrimary)),
                  subtitle: Text(data['note'] ?? '', style: TextStyle(color: theme.textSecondary)),
                  trailing: Text(
                    (isIncome ? '' : '- ') + currencyFormatter.format(data['amount'] ?? 0),
                    style: TextStyle(color: isIncome ? Colors.blue : Colors.red, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
            if (filteredTransactions.length > 3) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAllTransactions = !_showAllTransactions;
                  });
                },
                icon: Icon(
                  _showAllTransactions ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: const Color(0xFF3B82F6),
                ),
                label: Text(
                  _showAllTransactions ? 'Tutup Rincian' : 'Lihat Seluruh Rincian Transaksi',
                  style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _sanitizeForPdf(String text) {
    // Keep only printable ASCII characters (between space 32 and tilde 126) to prevent PDF Unicode crashes
    return text.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final String uid = _dbService.uid;

    // Fetch user name
    String userName = 'User';
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        userName = userDoc.data()?['name'] ?? userName;
      }
    } catch (_) {}
    if (userName == 'User') {
      try {
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser != null && authUser.displayName != null && authUser.displayName!.isNotEmpty) {
          userName = authUser.displayName!;
        }
      } catch (_) {}
    }
    
    // Fetch data
    final goalsSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).collection('goals').get();
    final fixedExpensesSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).collection('fixed_expenses').get();
    final transactionsSnapshot = await _dbService.getAllTransactionsOnce();

    String formatCurrencyPdf(double val) {
      return 'Rp ' + NumberFormat.decimalPattern('id').format(val.toInt());
    }

    final pdfNeracaRow = (String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(child: pw.Text(label, style: const pw.TextStyle(fontSize: 8))),
            pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      );
    };

    final pdfNeracaSubtotalRow = (String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
          ),
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
              pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );
    };

    final pdfNeracaTotalRow = (String label, String value) {
      return pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.black, width: 0.8),
            bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
          ),
        ),
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
            pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );
    };

    final pdfArusKasRow = (String label, double value) {
      final isNegative = value < 0;
      final formattedVal = (isNegative ? '-' : '') + formatCurrencyPdf(value.abs());
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(child: pw.Text(label, style: const pw.TextStyle(fontSize: 8))),
            pw.Text(formattedVal, style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      );
    };

    final pdfArusKasHeaderBlock = (String title) {
      return pw.Container(
        width: double.infinity,
        color: PdfColor.fromHex('#EEF2F6'), // Soft gray-blue background
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
        child: pw.Text(title, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
      );
    };

    final pdfArusKasSubtotalRow = (String label, double value) {
      final isNegative = value < 0;
      final formattedVal = (isNegative ? '-' : '') + formatCurrencyPdf(value.abs());
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
          ),
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
              pw.Text(formattedVal, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );
    };

    final pdfArusKasTotalBlock = (String label, double value, {required bool isStart}) {
      final isNegative = value < 0;
      final formattedVal = (isNegative ? '-' : '') + formatCurrencyPdf(value.abs());
      final bgColor = isStart ? PdfColor.fromHex('#DBEAFE') : PdfColor.fromHex('#D1FAE5'); // blue100 vs green100
      final textColor = isStart ? PdfColor.fromHex('#1E3A8A') : PdfColor.fromHex('#064E3B'); // blue900 vs green900
      
      return pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 6),
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textColor))),
            pw.Text(formattedVal, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textColor)),
          ],
        ),
      );
    };

    if (_selectedReportType == 'Neraca') {
      // ----------------------------------------------------
      // NERACA PDF
      // ----------------------------------------------------
      double cashBalance = 0;
      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp == null) continue;
        DateTime date = timestamp.toDate();
        double amt = (data['amount'] ?? 0).toDouble();
        bool isIncome = data['type'] == 'Pemasukan';
        if (date.year < _selectedDate.year || (date.year == _selectedDate.year && date.month <= _selectedDate.month)) {
          if (isIncome) cashBalance += amt; else cashBalance -= amt;
        }
      }
      
      double totalGoalsAmount = goalsSnapshot.docs.fold(0, (sum, doc) => sum + ((doc.data()['currentAmount'] ?? 0) as num).toDouble());
      double shortTermLiabilities = fixedExpensesSnapshot.docs
          .where((doc) => !(doc.data()['isPaid'] ?? false) && ((doc.data()['tenorMonths'] ?? 0) as num).toInt() < 1)
          .fold(0, (sum, doc) => sum + ((doc.data()['amount'] ?? 0) as num).toDouble());
      double longTermLiabilities = fixedExpensesSnapshot.docs
          .where((doc) => !(doc.data()['isPaid'] ?? false) && ((doc.data()['tenorMonths'] ?? 0) as num).toInt() >= 1)
          .fold(0, (sum, doc) => sum + ((doc.data()['amount'] ?? 0) as num).toDouble());
      
      double personalHouse = 0;
      double personalCar = 0;
      double carLoan = longTermLiabilities;
      
      double totalLiquid = cashBalance;
      double totalInvest = totalGoalsAmount;
      double totalPersonal = personalHouse + personalCar;
      double totalAssets = totalLiquid + totalInvest + totalPersonal;
      
      double totalShort = shortTermLiabilities;
      double totalLong = carLoan;
      double totalLiabilities = totalShort + totalLong;
      double netWorth = totalAssets - totalLiabilities;

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('LAPORAN NERACA KEUANGAN', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
                  pw.SizedBox(height: 4),
                  pw.Text('Saudara/i $userName', style: pw.TextStyle(font: pw.Font.timesBoldItalic(), fontSize: 11.5, color: PdfColors.grey900)),
                  pw.Text('Per ${DateFormat('dd MMMM yyyy').format(_selectedDate)}', style: pw.TextStyle(font: pw.Font.helveticaOblique(), fontSize: 9.5, color: PdfColors.grey600)),
                  pw.Text('(dalam Rupiah)', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey500)),
                ],
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 15),
            
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // LEFT COLUMN: ASET
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Aset Banner
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#10B981'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text('ASET', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                      pw.SizedBox(height: 10),
                      
                      // Kas / Setara Kas
                      pw.Text('Kas & Setara Kas', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColor.fromHex('#1F2937'))),
                      pw.SizedBox(height: 4),
                      pdfNeracaRow('Kas Utama / Saldo Dompet', formatCurrencyPdf(cashBalance)),
                      pdfNeracaSubtotalRow('Total Kas & Setara Kas', formatCurrencyPdf(totalLiquid)),
                      pw.SizedBox(height: 10),
                      
                      // Aset Investasi
                      pw.Text('Aset Investasi', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColor.fromHex('#1F2937'))),
                      pw.SizedBox(height: 4),
                      if (goalsSnapshot.docs.isEmpty)
                        pdfNeracaRow('Tidak ada tujuan tabungan', formatCurrencyPdf(0))
                      else
                        ...goalsSnapshot.docs.map((doc) {
                          final title = _sanitizeForPdf(doc.data()['title'] ?? 'Tabungan');
                          final amount = ((doc.data()['currentAmount'] ?? 0) as num).toDouble();
                          return pdfNeracaRow('Tabungan: $title', formatCurrencyPdf(amount));
                        }),
                      pdfNeracaSubtotalRow('Total Aset Investasi', formatCurrencyPdf(totalInvest)),
                      pw.SizedBox(height: 10),
                      
                      // Total Aset
                      pw.SizedBox(height: 10),
                      pdfNeracaTotalRow('TOTAL ASET', formatCurrencyPdf(totalAssets)),
                    ],
                  ),
                ),
                
                pw.SizedBox(width: 24),
                
                // RIGHT COLUMN: KEWAJIBAN & EKUITAS
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Kewajiban Banner
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#EF4444'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text('KEWAJIBAN & EKUITAS', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                      pw.SizedBox(height: 10),
                      
                      // Kewajiban Jangka Pendek
                      pw.Text('Kewajiban Jangka Pendek', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColor.fromHex('#1F2937'))),
                      pw.SizedBox(height: 4),
                      pdfNeracaRow('Kebutuhan Jk. Pendek', formatCurrencyPdf(shortTermLiabilities)),
                      pdfNeracaSubtotalRow('Total Kewajiban Jangka Pendek', formatCurrencyPdf(totalShort)),
                      pw.SizedBox(height: 10),
                      
                      // Kewajiban Jangka Panjang
                      pw.Text('Kewajiban Jangka Panjang', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColor.fromHex('#1F2937'))),
                      pw.SizedBox(height: 4),
                      pdfNeracaRow('Kebutuhan Jk. Panjang', formatCurrencyPdf(carLoan)),
                      pdfNeracaSubtotalRow('Total Kewajiban Jangka Panjang', formatCurrencyPdf(totalLong)),
                      pdfNeracaSubtotalRow('Total Kewajiban', formatCurrencyPdf(totalLiabilities)),
                      pw.SizedBox(height: 10),
                      
                      // Kekayaan Bersih
                      pw.Text('Kekayaan Bersih', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColor.fromHex('#1F2937'))),
                      pw.SizedBox(height: 4),
                      pdfNeracaRow('Nilai Kekayaan Bersih (Ekuitas)', formatCurrencyPdf(netWorth)),
                      pw.SizedBox(height: 20),
                      
                      // Total Kewajiban & Ekuitas
                      pdfNeracaTotalRow('TOTAL HUTANG & KEKAYAAN BERSIH', formatCurrencyPdf(totalAssets)),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ));

    } else if (_selectedReportType == 'Laba Rugi') {
      // ----------------------------------------------------
      // LABA RUGI PDF
      // ----------------------------------------------------
      Map<String, double> incomeByCat = {};
      Map<String, double> expenseByCat = {};
      double totalIncome = 0;
      double totalExpense = 0;

      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp == null) continue;
        DateTime date = timestamp.toDate();

        if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
          double amt = (data['amount'] ?? 0).toDouble();
          String type = data['type'] ?? '';
          String cat = _sanitizeForPdf(data['category'] ?? 'Lainnya');

          if (type == 'Pemasukan') {
            incomeByCat[cat] = (incomeByCat[cat] ?? 0) + amt;
            totalIncome += amt;
          } else {
            expenseByCat[cat] = (expenseByCat[cat] ?? 0) + amt;
            totalExpense += amt;
          }
        }
      }

      double netProfit = totalIncome - totalExpense;

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('LAPORAN LABA RUGI', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Saudara/i $userName', style: pw.TextStyle(font: pw.Font.timesBoldItalic(), fontSize: 11.5, color: PdfColors.grey900)),
                  pw.Text('Periode: ${DateFormat('MMMM yyyy').format(_selectedDate)}', style: pw.TextStyle(font: pw.Font.helveticaOblique(), fontSize: 9.5, color: PdfColors.grey600)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 10),
            
            pw.Text('PENDAPATAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blue)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Kategori Pendapatan', 'Jumlah (Rp)'],
              data: [
                ...incomeByCat.entries.map((e) => [e.key, formatCurrencyPdf(e.value)]),
                ['Total Pendapatan', formatCurrencyPdf(totalIncome)],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: {1: pw.Alignment.centerRight},
            ),
            pw.SizedBox(height: 20),

            pw.Text('PENGELUARAN / BEBAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.red)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Kategori Pengeluaran', 'Jumlah (Rp)'],
              data: [
                ...expenseByCat.entries.map((e) => [e.key, formatCurrencyPdf(e.value)]),
                ['Total Pengeluaran', formatCurrencyPdf(totalExpense)],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: {1: pw.Alignment.centerRight},
            ),
            pw.SizedBox(height: 25),

            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
                color: netProfit >= 0 ? PdfColors.green100 : PdfColors.red100,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(netProfit >= 0 ? 'LABA BERSIH' : 'RUGI BERSIH', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text(formatCurrencyPdf(netProfit), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ];
        },
      ));

    } else if (_selectedReportType == 'Buku Besar') {
      // ----------------------------------------------------
      // BUKU BESAR PDF
      // ----------------------------------------------------
      Map<String, List<Map<String, dynamic>>> transactionsByCat = {};
      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp == null) continue;
        DateTime date = timestamp.toDate();

        if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
          String cat = _sanitizeForPdf(data['category'] ?? 'Lainnya');
          if (!transactionsByCat.containsKey(cat)) {
            transactionsByCat[cat] = [];
          }
          transactionsByCat[cat]!.add({
            'date': date,
            'type': data['type'],
            'amount': (data['amount'] ?? 0).toDouble(),
            'note': _sanitizeForPdf(data['note'] ?? ''),
          });
        }
      }

      transactionsByCat.forEach((key, list) {
        list.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      });

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('BUKU BESAR KEUANGAN', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Saudara/i $userName', style: pw.TextStyle(font: pw.Font.timesBoldItalic(), fontSize: 11.5, color: PdfColors.grey900)),
                  pw.Text('Periode: ${DateFormat('MMMM yyyy').format(_selectedDate)}', style: pw.TextStyle(font: pw.Font.helveticaOblique(), fontSize: 9.5, color: PdfColors.grey600)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 10),

            if (transactionsByCat.isEmpty)
              pw.Text('Tidak ada transaksi pada periode ini.', style: const pw.TextStyle(fontSize: 12))
            else
              ...transactionsByCat.entries.map((entry) {
                String cat = entry.key;
                var txList = entry.value;

                double totalDebet = txList.where((tx) => tx['type'] == 'Pemasukan').fold(0, (sum, tx) => sum + (tx['amount'] as double));
                double totalKredit = txList.where((tx) => tx['type'] == 'Pengeluaran').fold(0, (sum, tx) => sum + (tx['amount'] as double));

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Kategori: $cat (Debet: ${formatCurrencyPdf(totalDebet)} | Kredit: ${formatCurrencyPdf(totalKredit)})', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo)),
                    pw.SizedBox(height: 5),
                    pw.TableHelper.fromTextArray(
                      headers: ['Tanggal', 'Keterangan', 'Debet (+)', 'Kredit (-)'],
                      data: txList.map((tx) {
                        bool isIncome = tx['type'] == 'Pemasukan';
                        double amount = tx['amount'] as double;
                        return [
                          DateFormat('dd/MM/yyyy').format(tx['date'] as DateTime),
                          tx['note'] as String,
                          isIncome ? formatCurrencyPdf(amount) : '-',
                          !isIncome ? formatCurrencyPdf(amount) : '-',
                        ];
                      }).toList(),
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                      cellStyle: const pw.TextStyle(fontSize: 7),
                      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      cellAlignments: {
                        2: pw.Alignment.centerRight,
                        3: pw.Alignment.centerRight,
                      },
                    ),
                    pw.SizedBox(height: 15),
                  ],
                );
              }),
          ];
        },
      ));

    } else if (_selectedReportType == 'Arus Kas') {
      // ----------------------------------------------------
      // ARUS KAS PDF
      // ----------------------------------------------------
      double flowOperasiIn = 0;
      double flowOperasiOut = 0;
      double flowInvestasiIn = 0;
      double flowInvestasiOut = 0;
      double flowPendanaanIn = 0;
      double flowPendanaanOut = 0;
      double cumulativeBalance = 0;

      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp == null) continue;
        DateTime date = timestamp.toDate();

        double amt = (data['amount'] ?? 0).toDouble();
        bool isIncome = data['type'] == 'Pemasukan';

        // Cumulative balance up to selected month end
        if (date.year < _selectedDate.year || (date.year == _selectedDate.year && date.month <= _selectedDate.month)) {
          if (isIncome) cumulativeBalance += amt; else cumulativeBalance -= amt;
        }

        if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
          String cat = data['category'] ?? 'Lainnya';

          if (cat == 'Tabungan' || cat == 'Investasi' || cat == 'Emas' || cat == 'Saham' || cat == 'Goals') {
            if (isIncome) flowInvestasiIn += amt; else flowInvestasiOut += amt;
          } else if (cat == 'Hutang' || cat == 'Pinjaman' || cat == 'Modal' || cat == 'Cicilan' || cat == 'Kredit') {
            if (isIncome) flowPendanaanIn += amt; else flowPendanaanOut += amt;
          } else {
            if (isIncome) flowOperasiIn += amt; else flowOperasiOut += amt;
          }
        }
      }

      double netOperasi = flowOperasiIn - flowOperasiOut;
      double netInvestasi = flowInvestasiIn - flowInvestasiOut;
      double netPendanaan = flowPendanaanIn - flowPendanaanOut;
      double netFlow = netOperasi + netInvestasi + netPendanaan;
      double saldoAkhir = cumulativeBalance;
      double saldoAwal = saldoAkhir - netFlow;

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('LAPORAN ARUS KAS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
                  pw.SizedBox(height: 4),
                  pw.Text('Saudara/i $userName', style: pw.TextStyle(font: pw.Font.timesBoldItalic(), fontSize: 11.5, color: PdfColors.grey900)),
                  pw.Text('Periode: ${DateFormat('MMMM yyyy').format(_selectedDate)}', style: pw.TextStyle(font: pw.Font.helveticaOblique(), fontSize: 9.5, color: PdfColors.grey600)),
                ],
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            pdfArusKasTotalBlock('SALDO AWAL KAS', saldoAwal, isStart: true),
            pw.SizedBox(height: 5),

            // A. OPERATING
            pdfArusKasHeaderBlock('A. Arus Kas Dari Aktivitas Operasi'),
            if (flowOperasiIn > 0) pdfArusKasRow('Penerimaan Kas (Pendapatan)', flowOperasiIn),
            if (flowOperasiOut > 0) pdfArusKasRow('Pengeluaran Kas (Beban Operasional)', -flowOperasiOut),
            if (flowOperasiIn == 0 && flowOperasiOut == 0) pdfArusKasRow('Tidak ada aktivitas operasi', 0),
            pdfArusKasSubtotalRow('Jumlah Kas Bersih dari Aktivitas Operasi', netOperasi),

            // B. INVESTING
            pdfArusKasHeaderBlock('B. Arus Kas Dari Aktivitas Investasi'),
            if (flowInvestasiIn > 0) pdfArusKasRow('Penerimaan Investasi/Tabungan', flowInvestasiIn),
            if (flowInvestasiOut > 0) pdfArusKasRow('Penempatan Investasi/Tabungan', -flowInvestasiOut),
            if (flowInvestasiIn == 0 && flowInvestasiOut == 0) pdfArusKasRow('Tidak ada aktivitas investasi', 0),
            pdfArusKasSubtotalRow('Jumlah Kas Bersih dari Aktivitas Investasi', netInvestasi),

            // C. FINANCING
            pdfArusKasHeaderBlock('C. Arus Kas Dari Aktivitas Pendanaan'),
            if (flowPendanaanIn > 0) pdfArusKasRow('Penerimaan Pinjaman/Modal', flowPendanaanIn),
            if (flowPendanaanOut > 0) pdfArusKasRow('Pelunasan Pinjaman/Hutang/Cicilan', -flowPendanaanOut),
            if (flowPendanaanIn == 0 && flowPendanaanOut == 0) pdfArusKasRow('Tidak ada aktivitas pendanaan', 0),
            pdfArusKasSubtotalRow('Jumlah Kas Bersih dari Aktivitas Pendanaan', netPendanaan),

            pw.SizedBox(height: 15),
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.SizedBox(height: 5),

            // NET FLOW & END BALANCE
            pdfArusKasSubtotalRow('KENAIKAN / (PENURUNAN) KAS BERSIH (A+B+C)', netFlow),
            pdfArusKasTotalBlock('SALDO AKHIR KAS', saldoAkhir, isStart: false),
          ];
        },
      ));

    } else {
      // ----------------------------------------------------
      // RINGKASAN PDF (DEFAULT)
      // ----------------------------------------------------
      List<List<String>> transactionsData = [];
      if (transactionsSnapshot.docs.isNotEmpty) {
        final docs = List<QueryDocumentSnapshot>.from(transactionsSnapshot.docs);
        docs.sort((a, b) {
          final tsA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final tsB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (tsA == null || tsB == null) return 0;
          return tsA.compareTo(tsB);
        });

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp == null) continue;
          DateTime date = timestamp.toDate();
          
          if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
            final isIncome = data['type'] == 'Pemasukan';
            final category = _sanitizeForPdf(data['category'] ?? '-');
            final note = _sanitizeForPdf(data['note'] ?? '');
            final type = data['type'] ?? '-';
            final amountFormatted = (isIncome ? '' : '-') + currencyFormatter.format(data['amount'] ?? 0);
            
            transactionsData.add([
              DateFormat('dd/MM/yyyy').format(date),
              category,
              note,
              type,
              amountFormatted,
            ]);
          }
        }
      }

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Laporan Keuangan', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Saudara/i $userName', style: pw.TextStyle(font: pw.Font.timesBoldItalic(), fontSize: 12, color: PdfColors.grey900)),
            pw.Text('Periode: ${DateFormat('MMMM yyyy').format(_selectedDate)}', style: pw.TextStyle(font: pw.Font.helveticaOblique(), fontSize: 10, color: PdfColors.grey600)),
            pw.SizedBox(height: 20),
            if (transactionsData.isEmpty)
              pw.Text('Tidak ada transaksi pada periode ini.', style: const pw.TextStyle(fontSize: 12))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Tanggal', 'Kategori', 'Keterangan', 'Tipe', 'Jumlah'],
                data: transactionsData,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  4: pw.Alignment.centerRight,
                },
              ),
          ];
        },
      ));
    }

    // Save and layout PDF
    if (kIsWeb) {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'laporan_${_selectedReportType.toLowerCase()}.pdf');
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }
  }

  Future<void> _exportExcel() async {
    var excel = Excel.createExcel();
    Sheet sheet = excel["Sheet1"];
    
    final String uid = _dbService.uid;

    // Fetch user name
    String userName = 'User';
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        userName = userDoc.data()?['name'] ?? userName;
      }
    } catch (_) {}
    if (userName == 'User') {
      try {
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser != null && authUser.displayName != null && authUser.displayName!.isNotEmpty) {
          userName = authUser.displayName!;
        }
      } catch (_) {}
    }

    final goalsSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).collection('goals').get();
    final fixedExpensesSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).collection('fixed_expenses').get();
    final transactionsSnapshot = await _dbService.getAllTransactionsOnce();

    if (_selectedReportType == 'Neraca') {
      // ----------------------------------------------------
      // EXCEL: NERACA
      // ----------------------------------------------------
      double cashBalance = 0;
      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp == null) continue;
        DateTime date = timestamp.toDate();
        double amt = (data['amount'] ?? 0).toDouble();
        bool isIncome = data['type'] == 'Pemasukan';
        if (date.year < _selectedDate.year || (date.year == _selectedDate.year && date.month <= _selectedDate.month)) {
          if (isIncome) cashBalance += amt; else cashBalance -= amt;
        }
      }

      double totalGoalsAmount = goalsSnapshot.docs.fold(0, (sum, doc) => sum + ((doc.data()['currentAmount'] ?? 0) as num).toDouble());
      double shortTermLiabilities = fixedExpensesSnapshot.docs
          .where((doc) => !(doc.data()['isPaid'] ?? false) && ((doc.data()['tenorMonths'] ?? 0) as num).toInt() < 1)
          .fold(0, (sum, doc) => sum + ((doc.data()['amount'] ?? 0) as num).toDouble());
      double longTermLiabilities = fixedExpensesSnapshot.docs
          .where((doc) => !(doc.data()['isPaid'] ?? false) && ((doc.data()['tenorMonths'] ?? 0) as num).toInt() >= 1)
          .fold(0, (sum, doc) => sum + ((doc.data()['amount'] ?? 0) as num).toDouble());

      double personalHouse = 0;
      double personalCar = 0;
      double carLoan = longTermLiabilities;

      double totalAssets = cashBalance + totalGoalsAmount + personalHouse + personalCar;
      double totalLiabilities = shortTermLiabilities + carLoan;
      double netWorth = totalAssets - totalLiabilities;

      sheet.appendRow(["LAPORAN NERACA KEUANGAN"]);
      sheet.appendRow(["Saudara/i", userName]);
      sheet.appendRow(["Per:", DateFormat('dd MMMM yyyy').format(_selectedDate)]);
      sheet.appendRow([]);
      sheet.appendRow(["ASET", "NILAI", "KEWAJIBAN & EKUITAS", "NILAI"]);
      
      sheet.appendRow(["Kas / Setara Kas", "", "Kewajiban Jangka Pendek", ""]);
      sheet.appendRow(["  Kas Utama / Saldo Dompet", cashBalance, "  Kebutuhan Jk. Pendek", shortTermLiabilities]);
      sheet.appendRow(["Total Kas & Setara Kas", cashBalance, "Total Kewajiban Jk. Pendek", shortTermLiabilities]);
      sheet.appendRow([]);
      sheet.appendRow(["Aset Investasi", "", "Kewajiban Jangka Panjang", ""]);
      
      for (var doc in goalsSnapshot.docs) {
        sheet.appendRow(["  Tabungan: ${doc.data()['title']}", doc.data()['currentAmount'] ?? 0, "", ""]);
      }
      
      sheet.appendRow(["Total Aset Investasi", totalGoalsAmount, "  Kebutuhan Jk. Panjang", carLoan]);
      sheet.appendRow(["", "", "Total Kewajiban Jk. Panjang", carLoan]);
      sheet.appendRow(["", "", "TOTAL KEWAJIBAN", totalLiabilities]);
      sheet.appendRow(["", "", "KEKAYAAN BERSIH", ""]);
      sheet.appendRow(["", "", "  Nilai Kekayaan Bersih (Ekuitas)", netWorth]);
      sheet.appendRow([]);
      sheet.appendRow(["TOTAL ASET", totalAssets, "TOTAL HUTANG & KEKAYAAN BERSIH", totalAssets]);

    } else if (_selectedReportType == 'Laba Rugi') {
      // ----------------------------------------------------
      // EXCEL: LABA RUGI
      // ----------------------------------------------------
      Map<String, double> incomeByCat = {};
      Map<String, double> expenseByCat = {};
      double totalIncome = 0;
      double totalExpense = 0;

      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp == null) continue;
        DateTime date = timestamp.toDate();

        if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
          double amt = (data['amount'] ?? 0).toDouble();
          String type = data['type'] ?? '';
          String cat = data['category'] ?? 'Lainnya';

          if (type == 'Pemasukan') {
            incomeByCat[cat] = (incomeByCat[cat] ?? 0) + amt;
            totalIncome += amt;
          } else {
            expenseByCat[cat] = (expenseByCat[cat] ?? 0) + amt;
            totalExpense += amt;
          }
        }
      }

      sheet.appendRow(["LAPORAN LABA RUGI"]);
      sheet.appendRow(["Saudara/i", userName]);
      sheet.appendRow(["Periode:", DateFormat('MMMM yyyy').format(_selectedDate)]);
      sheet.appendRow([]);
      sheet.appendRow(["PENDAPATAN", "JUMLAH"]);
      incomeByCat.forEach((cat, amt) {
        sheet.appendRow([cat, amt]);
      });
      sheet.appendRow(["Total Pendapatan", totalIncome]);
      sheet.appendRow([]);
      sheet.appendRow(["PENGELUARAN / BEBAN", "JUMLAH"]);
      expenseByCat.forEach((cat, amt) {
        sheet.appendRow([cat, amt]);
      });
      sheet.appendRow(["Total Pengeluaran", totalExpense]);
      sheet.appendRow([]);
      sheet.appendRow([totalIncome - totalExpense >= 0 ? "LABA BERSIH" : "RUGI BERSIH", totalIncome - totalExpense]);

    } else if (_selectedReportType == 'Buku Besar') {
      // ----------------------------------------------------
      // EXCEL: BUKU BESAR
      // ----------------------------------------------------
      Map<String, List<Map<String, dynamic>>> transactionsByCat = {};
      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp == null) continue;
        DateTime date = timestamp.toDate();

        if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
          String cat = data['category'] ?? 'Lainnya';
          if (!transactionsByCat.containsKey(cat)) {
            transactionsByCat[cat] = [];
          }
          transactionsByCat[cat]!.add({
            'date': date,
            'type': data['type'],
            'amount': (data['amount'] ?? 0).toDouble(),
            'note': data['note'] ?? '',
          });
        }
      }

      sheet.appendRow(["LAPORAN BUKU BESAR KEUANGAN"]);
      sheet.appendRow(["Saudara/i", userName]);
      sheet.appendRow(["Periode:", DateFormat('MMMM yyyy').format(_selectedDate)]);
      sheet.appendRow([]);

      transactionsByCat.forEach((cat, txList) {
        txList.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
        sheet.appendRow(["Akun/Kategori:", cat]);
        sheet.appendRow(["Tanggal", "Keterangan", "Debet (+)", "Kredit (-)"]);
        for (var tx in txList) {
          bool isIncome = tx['type'] == 'Pemasukan';
          sheet.appendRow([
            DateFormat('dd/MM/yyyy').format(tx['date'] as DateTime),
            tx['note'],
            isIncome ? tx['amount'] : "-",
            !isIncome ? tx['amount'] : "-",
          ]);
        }
        sheet.appendRow([]);
      });

    } else if (_selectedReportType == 'Arus Kas') {
      // ----------------------------------------------------
      // EXCEL: ARUS KAS
      // ----------------------------------------------------
      double flowOperasiIn = 0;
      double flowOperasiOut = 0;
      double flowInvestasiIn = 0;
      double flowInvestasiOut = 0;
      double flowPendanaanIn = 0;
      double flowPendanaanOut = 0;
      double cumulativeBalance = 0;

      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp == null) continue;
        DateTime date = timestamp.toDate();

        double amt = (data['amount'] ?? 0).toDouble();
        bool isIncome = data['type'] == 'Pemasukan';

        if (date.year < _selectedDate.year || (date.year == _selectedDate.year && date.month <= _selectedDate.month)) {
          if (isIncome) cumulativeBalance += amt; else cumulativeBalance -= amt;
        }

        if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
          String cat = data['category'] ?? 'Lainnya';

          if (cat == 'Tabungan' || cat == 'Investasi' || cat == 'Emas' || cat == 'Saham' || cat == 'Goals') {
            if (isIncome) flowInvestasiIn += amt; else flowInvestasiOut += amt;
          } else if (cat == 'Hutang' || cat == 'Pinjaman' || cat == 'Modal' || cat == 'Cicilan' || cat == 'Kredit') {
            if (isIncome) flowPendanaanIn += amt; else flowPendanaanOut += amt;
          } else {
            if (isIncome) flowOperasiIn += amt; else flowOperasiOut += amt;
          }
        }
      }

      double netOperasi = flowOperasiIn - flowOperasiOut;
      double netInvestasi = flowInvestasiIn - flowInvestasiOut;
      double netPendanaan = flowPendanaanIn - flowPendanaanOut;
      double netFlow = netOperasi + netInvestasi + netPendanaan;
      double saldoAkhir = cumulativeBalance;
      double saldoAwal = saldoAkhir - netFlow;

      sheet.appendRow(["LAPORAN ARUS KAS"]);
      sheet.appendRow(["Saudara/i", userName]);
      sheet.appendRow(["Periode:", DateFormat('MMMM yyyy').format(_selectedDate)]);
      sheet.appendRow([]);
      sheet.appendRow(["Aktivitas Aliran Kas", "Nominal (Rp)"]);
      sheet.appendRow(["SALDO AWAL KAS", saldoAwal]);
      sheet.appendRow([]);
      sheet.appendRow(["A. Arus Kas Dari Aktivitas Operasi", ""]);
      sheet.appendRow(["  Penerimaan Kas (Pendapatan)", flowOperasiIn]);
      sheet.appendRow(["  Pengeluaran Kas (Beban Operasional)", -flowOperasiOut]);
      sheet.appendRow(["Jumlah Kas Bersih dari Aktivitas Operasi", netOperasi]);
      sheet.appendRow([]);
      sheet.appendRow(["B. Arus Kas Dari Aktivitas Investasi", ""]);
      sheet.appendRow(["  Penerimaan Investasi/Tabungan", flowInvestasiIn]);
      sheet.appendRow(["  Penempatan Investasi/Tabungan", -flowInvestasiOut]);
      sheet.appendRow(["Jumlah Kas Bersih dari Aktivitas Investasi", netInvestasi]);
      sheet.appendRow([]);
      sheet.appendRow(["C. Arus Kas Dari Aktivitas Pendanaan", ""]);
      sheet.appendRow(["  Penerimaan Pinjaman/Modal", flowPendanaanIn]);
      sheet.appendRow(["  Pelunasan Pinjaman/Hutang/Cicilan", -flowPendanaanOut]);
      sheet.appendRow(["Jumlah Kas Bersih dari Aktivitas Pendanaan", netPendanaan]);
      sheet.appendRow([]);
      sheet.appendRow(["KENAIKAN / (PENURUNAN) KAS BERSIH", netFlow]);
      sheet.appendRow(["SALDO AKHIR KAS", saldoAkhir]);

    } else {
      // ----------------------------------------------------
      // EXCEL: RINGKASAN (DEFAULT)
      // ----------------------------------------------------
      sheet.appendRow(["LAPORAN KEUANGAN RINGKASAN"]);
      sheet.appendRow(["Saudara/i", userName]);
      sheet.appendRow(["Periode:", DateFormat('MMMM yyyy').format(_selectedDate)]);
      sheet.appendRow([]);
      sheet.appendRow(["Tanggal", "Kategori", "Keterangan", "Tipe", "Jumlah"]);
      if (transactionsSnapshot.docs.isNotEmpty) {
        final docs = List<QueryDocumentSnapshot>.from(transactionsSnapshot.docs);
        docs.sort((a, b) {
          final tsA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final tsB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (tsA == null || tsB == null) return 0;
          return tsA.compareTo(tsB);
        });

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp == null) continue;
          DateTime date = timestamp.toDate();
          if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
            final isIncome = data['type'] == 'Pemasukan';
            sheet.appendRow([
              DateFormat('dd/MM/yyyy').format(date),
              data['category'] ?? '-',
              data['note'] ?? '',
              data['type'] ?? '-',
              (isIncome ? '' : '-') + currencyFormatter.format(data['amount'] ?? 0),
            ]);
          }
        }
      }
    }

    final bytes = Uint8List.fromList(excel.encode()!);
    final String filename = "laporan_${_selectedReportType.toLowerCase()}";
    
    if (kIsWeb) {
      await FileSaver.instance.saveFile(name: filename, bytes: bytes, ext: 'xlsx');
    } else {
      final output = await getTemporaryDirectory();
      final filePath = "${output.path}/$filename.xlsx";
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Laporan Excel $_selectedReportType');
    }
  }

  Widget _buildReportTypeSelector() {
    final theme = Provider.of<ThemeProvider>(context);
    final reportTypes = [
      {'id': 'Ringkasan', 'label': 'Ringkasan', 'icon': Icons.summarize_outlined},
      {'id': 'Neraca', 'label': 'Neraca', 'icon': Icons.account_balance_outlined},
      {'id': 'Laba Rugi', 'label': 'Laba Rugi', 'icon': Icons.analytics_outlined},
      {'id': 'Buku Besar', 'label': 'Buku Besar', 'icon': Icons.menu_book_outlined},
      {'id': 'Arus Kas', 'label': 'Arus Kas', 'icon': Icons.swap_horiz_outlined},
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: reportTypes.length,
        itemBuilder: (context, index) {
          final type = reportTypes[index];
          final isSelected = _selectedReportType == type['id'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedReportType = type['id'] as String;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : (theme.isDark ? const Color(0xFF1E293B) : theme.inputBg),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.transparent : theme.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    type['icon'] as IconData,
                    color: isSelected ? Colors.white : theme.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    type['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : theme.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentReportContent(
    AsyncSnapshot<QuerySnapshot> snapshot,
    List<BarChartGroupData> chartData,
    double income,
    double expense,
    double cumulativeBalance,
    double totalSavings,
    List<QueryDocumentSnapshot> goalsList,
    List<QueryDocumentSnapshot> fixedExpensesList,
    bool isMobile,
  ) {
    switch (_selectedReportType) {
      case 'Neraca':
        return _buildNeracaView(cumulativeBalance, goalsList, fixedExpensesList);
      case 'Laba Rugi':
        return _buildLabaRugiView(snapshot.data?.docs ?? []);
      case 'Buku Besar':
        return _buildBukuBesarView(snapshot.data?.docs ?? []);
      case 'Arus Kas':
        return _buildArusKasView(snapshot.data?.docs ?? [], cumulativeBalance);
      case 'Ringkasan':
      default:
        return Column(
          children: [
            isMobile
                ? Column(
                    children: [
                      _buildChartArea(chartData),
                      const SizedBox(height: 24),
                      _buildSisaKeuangan(income, expense, cumulativeBalance, totalSavings),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildChartArea(chartData)),
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: _buildSisaKeuangan(income, expense, cumulativeBalance, totalSavings)),
                    ],
                  ),
            const SizedBox(height: 24),
            _buildRincianTransaksi(snapshot),
          ],
        );
    }
  }

  Widget _buildNeracaView(double sisa, List<QueryDocumentSnapshot> goalsList, List<QueryDocumentSnapshot> fixedExpensesList) {
    final theme = Provider.of<ThemeProvider>(context);

    // Real assets
    double cashBalance = sisa;
    double totalGoalsAmount = goalsList.fold(0, (sum, doc) => sum + ((doc['currentAmount'] ?? 0) as num).toDouble());
    
    // Real short-term liabilities (only unpaid/PENDING fixed expenses and tenor < 1)
    double shortTermLiabilities = fixedExpensesList
        .where((doc) => !(doc['isPaid'] ?? false) && ((doc['tenorMonths'] ?? 0) as num).toInt() < 1)
        .fold(0, (sum, doc) => sum + ((doc['amount'] ?? 0) as num).toDouble());

    // Real long-term liabilities (only unpaid/PENDING fixed expenses and tenor >= 1)
    double longTermLiabilities = fixedExpensesList
        .where((doc) => !(doc['isPaid'] ?? false) && ((doc['tenorMonths'] ?? 0) as num).toInt() >= 1)
        .fold(0, (sum, doc) => sum + ((doc['amount'] ?? 0) as num).toDouble());

    // Mock assets (for traditional neraca balance matching layout)
    double personalHouse = 0;
    double personalCar = 0;
    
    // Mock long-term liabilities
    double carLoan = longTermLiabilities;
    double mortgage = 0;

    double totalLiquidAssets = cashBalance;
    double totalInvestments = totalGoalsAmount;
    double totalPersonalAssets = personalHouse + personalCar;
    double totalAssets = totalLiquidAssets + totalInvestments + totalPersonalAssets;

    double totalShortTerm = shortTermLiabilities; // remove mock CC
    double totalLongTerm = carLoan; // which is longTermLiabilities
    double totalLiabilities = totalShortTerm + totalLongTerm;
    double netWorth = totalAssets - totalLiabilities;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Text('LAPORAN NERACA KEUANGAN', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Per ${DateFormat('dd MMMM yyyy').format(_selectedDate)}', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                Text('(dalam Rupiah)', style: TextStyle(color: theme.textMuted, fontSize: 10, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Two Column Layout
          MediaQuery.of(context).size.width < 750
              ? Column(
                  children: [
                    _buildNeracaAsetSection(cashBalance, goalsList, totalLiquidAssets, totalInvestments, totalPersonalAssets, totalAssets),
                    const SizedBox(height: 24),
                    _buildNeracaPasivaSection(shortTermLiabilities, carLoan, mortgage, totalShortTerm, totalLongTerm, totalLiabilities, netWorth, totalAssets),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildNeracaAsetSection(cashBalance, goalsList, totalLiquidAssets, totalInvestments, totalPersonalAssets, totalAssets),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: _buildNeracaPasivaSection(shortTermLiabilities, carLoan, mortgage, totalShortTerm, totalLongTerm, totalLiabilities, netWorth, totalAssets),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildNeracaAsetSection(double cashBalance, List<QueryDocumentSnapshot> goalsList, double totalLiquid, double totalInvest, double totalPersonal, double totalAssets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          color: const Color(0xFF10B981),
          child: const Text('ASET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(height: 12),
        // Liquid Assets
        const Text('Kas / Setara Kas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, decoration: TextDecoration.underline)),
        const SizedBox(height: 4),
        _neracaRow('Kas Utama / Saldo Dompet', cashBalance),
        _neracaSubtotalRow('Total Kas / Setara Kas', totalLiquid),
        const SizedBox(height: 12),
        // Investments
        const Text('Aset Investasi / Tabungan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, decoration: TextDecoration.underline)),
        const SizedBox(height: 4),
        if (goalsList.isEmpty)
          _neracaRow('Tidak ada tujuan tabungan', 0)
        else
          ...goalsList.map((doc) => _neracaRow('Tabungan: ${doc['title']}', ((doc['currentAmount'] ?? 0) as num).toDouble())),
        _neracaSubtotalRow('Total Aset Investasi', totalInvest),
        const SizedBox(height: 12),
        const SizedBox(height: 20),
        _neracaTotalRow('TOTAL ASET', totalAssets),
      ],
    );
  }

  Widget _buildNeracaPasivaSection(double shortTermFixed, double carLoan, double mortgage, double totalShort, double totalLong, double totalLiab, double netWorth, double totalAssetsAndNetWorth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          color: const Color(0xFFEF4444),
          child: const Text('KEWAJIBAN & KEKAYAAN BERSIH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(height: 12),
        // Short-term Liabilities
        const Text('Kewajiban Jangka Pendek', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, decoration: TextDecoration.underline)),
        const SizedBox(height: 4),
        _neracaRow('Kebutuhan Jk. Pendek', shortTermFixed),
        _neracaSubtotalRow('Total Kewajiban Jangka Pendek', totalShort),
        const SizedBox(height: 12),
        // Long-term Liabilities
        const Text('Kewajiban Jangka Panjang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, decoration: TextDecoration.underline)),
        const SizedBox(height: 4),
        _neracaRow('Kebutuhan Jk. Panjang', carLoan),
        _nerSubtotalRow('Total Kewajiban Jangka Panjang', totalLong),
        const SizedBox(height: 12),
        _nerSubtotalRow('Total Hutang / Kewajiban', totalLiab),
        const SizedBox(height: 16),
        // Net Worth
        const Text('Kekayaan Bersih', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, decoration: TextDecoration.underline)),
        const SizedBox(height: 4),
        _neracaRow('Nilai Kekayaan Bersih (Ekuitas)', netWorth),
        const SizedBox(height: 24),
        _neracaTotalRow('TOTAL HUTANG & KEKAYAAN BERSIH', totalAssetsAndNetWorth),
      ],
    );
  }

  Widget _neracaRow(String label, double value) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 11))),
          Text(currencyFormatter.format(value), style: TextStyle(color: theme.textPrimary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _neracaSubtotalRow(String label, double value) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold))),
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey, width: 1))),
            child: Text(currencyFormatter.format(value), style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _nerSubtotalRow(String label, double value) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold))),
          Text(currencyFormatter.format(value), style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _neracaTotalRow(String label, double value) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey, width: 1),
          bottom: BorderSide(color: Colors.grey, width: 2),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold))),
          Text(currencyFormatter.format(value), style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLabaRugiView(List<QueryDocumentSnapshot> transactions) {
    final theme = Provider.of<ThemeProvider>(context);

    // Grouping
    Map<String, double> incomeByCat = {};
    Map<String, double> expenseByCat = {};

    double totalIncome = 0;
    double totalExpense = 0;

    for (var doc in transactions) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp == null) continue;
      DateTime date = timestamp.toDate();

      if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
        double amt = (data['amount'] ?? 0).toDouble();
        String type = data['type'] ?? '';
        String cat = data['category'] ?? 'Lainnya';

        if (type == 'Pemasukan') {
          incomeByCat[cat] = (incomeByCat[cat] ?? 0) + amt;
          totalIncome += amt;
        } else {
          expenseByCat[cat] = (expenseByCat[cat] ?? 0) + amt;
          totalExpense += amt;
        }
      }
    }

    double netProfit = totalIncome - totalExpense;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Text('LAPORAN LABA RUGI', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Periode: ${DateFormat('MMMM yyyy').format(_selectedDate)}', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 1. PENDAPATAN (INCOME)
          Text('PENDAPATAN', style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          if (incomeByCat.isEmpty)
            _neracaRow('Tidak ada pendapatan', 0)
          else
            ...incomeByCat.entries.map((e) => _neracaRow(e.key, e.value)),
          _neracaSubtotalRow('Total Pendapatan', totalIncome),
          const SizedBox(height: 24),

          // 2. BEBAN / PENGELUARAN (EXPENSES)
          Text('BEBAN & PENGELUARAN', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          if (expenseByCat.isEmpty)
            _neracaRow('Tidak ada pengeluaran', 0)
          else
            ...expenseByCat.entries.map((e) => _neracaRow(e.key, e.value)),
          _neracaSubtotalRow('Total Beban / Pengeluaran', totalExpense),
          const SizedBox(height: 24),

          // 3. LABA / RUGI BERSIH (NET INCOME)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: netProfit >= 0 ? const Color(0xFF10B981).withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: netProfit >= 0 ? const Color(0xFF10B981).withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Text(
                  netProfit >= 0 ? 'LABA BERSIH' : 'RUGI BERSIH',
                  style: TextStyle(
                    color: netProfit >= 0 ? const Color(0xFF10B981) : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  currencyFormatter.format(netProfit),
                  style: TextStyle(
                    color: netProfit >= 0 ? const Color(0xFF10B981) : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBukuBesarView(List<QueryDocumentSnapshot> transactions) {
    final theme = Provider.of<ThemeProvider>(context);

    // Group transactions by category
    Map<String, List<Map<String, dynamic>>> transactionsByCat = {};

    for (var doc in transactions) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp == null) continue;
      DateTime date = timestamp.toDate();

      if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
        String cat = data['category'] ?? 'Lainnya';
        if (!transactionsByCat.containsKey(cat)) {
          transactionsByCat[cat] = [];
        }
        transactionsByCat[cat]!.add({
          'id': doc.id,
          'date': date,
          'type': data['type'],
          'amount': (data['amount'] ?? 0).toDouble(),
          'note': data['note'] ?? '',
        });
      }
    }

    // Sort transactions inside each category by date ascending
    transactionsByCat.forEach((key, list) {
      list.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    });

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Text('BUKU BESAR KEUANGAN', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Periode: ${DateFormat('MMMM yyyy').format(_selectedDate)}', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),

          if (transactionsByCat.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text('Tidak ada data transaksi', style: TextStyle(color: theme.textMuted)),
              ),
            )
          else
            ...transactionsByCat.entries.map((entry) {
              String cat = entry.key;
              var txList = entry.value;

              double totalDebet = txList.where((tx) => tx['type'] == 'Pemasukan').fold(0, (sum, tx) => sum + (tx['amount'] as double));
              double totalKredit = txList.where((tx) => tx['type'] == 'Pengeluaran').fold(0, (sum, tx) => sum + (tx['amount'] as double));

              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.isDark ? Colors.black12 : theme.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Title
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.accent.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        border: Border(bottom: BorderSide(color: theme.border)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_open, color: theme.accent, size: 16),
                          const SizedBox(width: 8),
                          Text('Akun/Kategori: $cat', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                          const Spacer(),
                          Text(
                            'D: ${currencyFormatter.format(totalDebet)} | K: ${currencyFormatter.format(totalKredit)}',
                            style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    // Table Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text('Tanggal', style: TextStyle(color: theme.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                          Expanded(flex: 4, child: Text('Keterangan', style: TextStyle(color: theme.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                          Expanded(flex: 3, child: Text('Debet (+)', style: TextStyle(color: theme.textMuted, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                          Expanded(flex: 3, child: Text('Kredit (-)', style: TextStyle(color: theme.textMuted, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Transactions List
                    ...txList.map((tx) {
                      bool isIncome = tx['type'] == 'Pemasukan';
                      double amount = tx['amount'] as double;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(DateFormat('dd/MM/yyyy').format(tx['date'] as DateTime), style: TextStyle(color: theme.textSecondary, fontSize: 10)),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(tx['note'] as String, style: TextStyle(color: theme.textPrimary, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(isIncome ? currencyFormatter.format(amount) : '-', style: TextStyle(color: isIncome ? Colors.blue : theme.textSecondary, fontSize: 10), textAlign: TextAlign.right),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(!isIncome ? currencyFormatter.format(amount) : '-', style: TextStyle(color: !isIncome ? Colors.red : theme.textSecondary, fontSize: 10), textAlign: TextAlign.right),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildArusKasView(List<QueryDocumentSnapshot> transactions, double cumulativeBalance) {
    final theme = Provider.of<ThemeProvider>(context);

    double flowOperasiIn = 0;
    double flowOperasiOut = 0;
    double flowInvestasiIn = 0;
    double flowInvestasiOut = 0;
    double flowPendanaanIn = 0;
    double flowPendanaanOut = 0;

    for (var doc in transactions) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp == null) continue;
      DateTime date = timestamp.toDate();

      if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
        double amt = (data['amount'] ?? 0).toDouble();
        String type = data['type'] ?? '';
        String cat = data['category'] ?? 'Lainnya';

        // Classification
        if (cat == 'Tabungan' || cat == 'Investasi' || cat == 'Emas' || cat == 'Saham' || cat == 'Goals') {
          if (type == 'Pemasukan') {
            flowInvestasiIn += amt;
          } else {
            flowInvestasiOut += amt;
          }
        } else if (cat == 'Hutang' || cat == 'Pinjaman' || cat == 'Modal' || cat == 'Cicilan' || cat == 'Kredit') {
          if (type == 'Pemasukan') {
            flowPendanaanIn += amt;
          } else {
            flowPendanaanOut += amt;
          }
        } else {
          // Default to Operating
          if (type == 'Pemasukan') {
            flowOperasiIn += amt;
          } else {
            flowOperasiOut += amt;
          }
        }
      }
    }

    double netOperasi = flowOperasiIn - flowOperasiOut;
    double netInvestasi = flowInvestasiIn - flowInvestasiOut;
    double netPendanaan = flowPendanaanIn - flowPendanaanOut;
    double netFlow = netOperasi + netInvestasi + netPendanaan;

    // Saldo Akhir Kas = cumulativeBalance at the end of the selected month
    double saldoAkhir = cumulativeBalance;
    // Saldo Awal Kas = Saldo Akhir - Net Flow of the month
    double saldoAwal = saldoAkhir - netFlow;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Text('LAPORAN ARUS KAS', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Periode: ${DateFormat('MMMM yyyy').format(_selectedDate)}', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Saldo Awal
          _arusKasTotalRow('SALDO AWAL KAS', saldoAwal, isBold: true),
          const SizedBox(height: 16),

          // A. OPERATING FLOW
          Text('A. Arus Kas Dari Aktivitas Operasi', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          if (flowOperasiIn > 0) _arusKasRow('Penerimaan Kas (Pendapatan)', flowOperasiIn),
          if (flowOperasiOut > 0) _arusKasRow('Pengeluaran Kas (Beban Operasional)', -flowOperasiOut),
          _arusKasSubtotalRow('Jumlah Kas Bersih dari Aktivitas Operasi', netOperasi),
          const SizedBox(height: 16),

          // B. INVESTING FLOW
          Text('B. Arus Kas Dari Aktivitas Investasi', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          if (flowInvestasiIn > 0) _arusKasRow('Penerimaan Investasi/Tabungan', flowInvestasiIn),
          if (flowInvestasiOut > 0) _arusKasRow('Penempatan Investasi/Tabungan', -flowInvestasiOut),
          _arusKasSubtotalRow('Jumlah Kas Bersih dari Aktivitas Investasi', netInvestasi),
          const SizedBox(height: 16),

          // C. FINANCING FLOW
          Text('C. Arus Kas Dari Aktivitas Pendanaan', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          if (flowPendanaanIn > 0) _arusKasRow('Penerimaan Pinjaman/Modal', flowPendanaanIn),
          if (flowPendanaanOut > 0) _arusKasRow('Pelunasan Pinjaman/Hutang/Cicilan', -flowPendanaanOut),
          _arusKasSubtotalRow('Jumlah Kas Bersih dari Aktivitas Pendanaan', netPendanaan),
          const SizedBox(height: 20),

          // Net Movement
          _arusKasTotalRow('KENAIKAN / (PENURUNAN) KAS BERSIH (A+B+C)', netFlow),
          const SizedBox(height: 12),
          _arusKasTotalRow('SALDO AKHIR KAS', saldoAkhir, isBold: true, underline: true),
        ],
      ),
    );
  }

  Widget _arusKasRow(String label, double value) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 11))),
          Text(
            (value >= 0 ? '' : '-') + currencyFormatter.format(value.abs()),
            style: TextStyle(color: theme.textPrimary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _arusKasSubtotalRow(String label, double value) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold))),
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey, width: 1))),
            child: Text(
              (value >= 0 ? '' : '-') + currencyFormatter.format(value.abs()),
              style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arusKasTotalRow(String label, double value, {bool isBold = false, bool underline = false}) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: isBold ? (theme.isDark ? Colors.white10 : Colors.grey.withOpacity(0.05)) : null,
        border: underline
            ? const Border(
                top: BorderSide(color: Colors.grey, width: 1),
                bottom: BorderSide(color: Colors.grey, width: 2),
              )
            : const Border(
                top: BorderSide(color: Colors.grey, width: 1),
                bottom: BorderSide(color: Colors.grey, width: 1),
              ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold))),
          Text(
            (value >= 0 ? '' : '-') + currencyFormatter.format(value.abs()),
            style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
