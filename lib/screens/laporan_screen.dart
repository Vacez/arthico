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
  String _chartRange = '1 Bulan';
  String _selectedReportType = 'Ringkasan'; // 'Ringkasan', 'Neraca', 'Laba Rugi', 'Buku Besar', 'Arus Kas'
  bool _showAllTransactions = false;
  late Stream<QuerySnapshot> _goalsStream;
  late Stream<QuerySnapshot> _transactionsStream;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _goalsStream = _dbService.getGoals();
    _transactionsStream = _dbService.getAllTransactions();
  }

  @override
  void didUpdateWidget(covariant LaporanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != oldWidget.initialDate) {
      setState(() {
        _selectedDate = widget.initialDate ?? DateTime.now();
      });
    }
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
          stream: _transactionsStream,
          builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Err: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                double income = 0;
                double expense = 0;
                double cumulativeBalance = 0;
                List<BarChartGroupData> chartData = [];
                List<String> chartLabels = [];

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

                  if (_chartRange == '1 Bulan') {
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
                    chartData = [1, 2, 3, 4, 5].map((week) {
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
                            label: BarChartRodLabel(
                              show: inc > 0,
                              text: _formatShortAmount(inc),
                              style: TextStyle(color: theme.textPrimary, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                          BarChartRodData(
                            toY: exp,
                            color: Colors.red,
                            width: 8,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            label: BarChartRodLabel(
                              show: exp > 0,
                              text: _formatShortAmount(exp),
                              style: TextStyle(color: theme.textPrimary, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      );
                    }).toList();
                    
                    income = weeklyIncome.values.fold(0, (p, e) => p + e);
                    expense = weeklyExpense.values.fold(0, (p, e) => p + e);
                  } else {
                    // 3 Bulan or 1 Tahun
                    int numMonths = _chartRange == '3 Bulan' ? 3 : 12;
                    List<DateTime> months = [];
                    for (int i = numMonths - 1; i >= 0; i--) {
                      int year = _selectedDate.year;
                      int month = _selectedDate.month - i;
                      while (month <= 0) {
                        month += 12;
                        year -= 1;
                      }
                      months.add(DateTime(year, month, 1));
                    }
                    
                    Map<String, double> monthlyIncome = {};
                    Map<String, double> monthlyExpense = {};
                    for (var m in months) {
                      String key = DateFormat('MMM yy').format(m);
                      monthlyIncome[key] = 0;
                      monthlyExpense[key] = 0;
                      chartLabels.add(DateFormat('MMM yy').format(m));
                    }
                    
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final timestamp = data['timestamp'] as Timestamp?;
                      if (timestamp == null) continue;
                      DateTime date = timestamp.toDate();
                      
                      for (var m in months) {
                        if (date.month == m.month && date.year == m.year) {
                          String key = DateFormat('MMM yy').format(m);
                          double amt = (data['amount'] ?? 0).toDouble();
                          if (data['type'] == 'Pemasukan') {
                            monthlyIncome[key] = (monthlyIncome[key] ?? 0) + amt;
                          } else {
                            monthlyExpense[key] = (monthlyExpense[key] ?? 0) + amt;
                          }
                          break;
                        }
                      }
                    }
                    
                    for (int i = 0; i < months.length; i++) {
                      String key = DateFormat('MMM yy').format(months[i]);
                      double inc = monthlyIncome[key] ?? 0;
                      double exp = monthlyExpense[key] ?? 0;
                      chartData.add(
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: inc,
                              color: Colors.blue,
                              width: numMonths == 3 ? 12 : 6,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              label: BarChartRodLabel(
                                show: inc > 0,
                                text: _formatShortAmount(inc),
                                style: TextStyle(color: theme.textPrimary, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                            BarChartRodData(
                              toY: exp,
                              color: Colors.red,
                              width: numMonths == 3 ? 12 : 6,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              label: BarChartRodLabel(
                                show: exp > 0,
                                text: _formatShortAmount(exp),
                                style: TextStyle(color: theme.textPrimary, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    // Sisa Keuangan card should still show selected month's totals
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
                                       _actionButton('PDF', const Color(0xFFEF4444), () => _showExportPeriodDialog('PDF')),
                                       const SizedBox(width: 8),
                                       _actionButton('Excel', const Color(0xFF10B981), () => _showExportPeriodDialog('Excel')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildCurrentReportContent(
                              snapshot,
                              chartData,
                              chartLabels,
                              income,
                              expense,
                              cumulativeBalance,
                              totalSavings,
                              goalsList,
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

  Widget _buildChartArea(List<BarChartGroupData> chartData, List<String> chartLabels) {
    final theme = Provider.of<ThemeProvider>(context);
    bool isMobile = MediaQuery.of(context).size.width < 700;

    double maxVal = 0;
    for (var group in chartData) {
      for (var rod in group.barRods) {
        if (rod.toY > maxVal) {
          maxVal = rod.toY;
        }
      }
    }
    double calculatedMaxY = maxVal > 0 ? maxVal * 1.25 : 1000;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insights, color: theme.accent, size: 16),
                  const SizedBox(width: 8),
                  Text('Grafik Keuangan', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _chartRange = '1 Bulan'),
                    child: _toggleItem('1 Bln', _chartRange == '1 Bulan'),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _chartRange = '3 Bulan'),
                    child: _toggleItem('3 Bln', _chartRange == '3 Bulan'),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _chartRange = '1 Tahun'),
                    child: _toggleItem('1 Thn', _chartRange == '1 Tahun'),
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
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: _chartRange == '1 Tahun' ? 500 : (MediaQuery.of(context).size.width - (isMobile ? 56 : 100)),
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: calculatedMaxY,
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
                                  if (_chartRange == '1 Bulan') {
                                    int week = value.toInt();
                                    if (week >= 1 && week <= 5) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text('Mgg $week', style: TextStyle(color: theme.textSecondary, fontSize: 9)),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  } else {
                                    int idx = value.toInt();
                                    if (idx >= 0 && idx < chartLabels.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(chartLabels[idx], style: TextStyle(color: theme.textSecondary, fontSize: 8)),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  }
                                },
                              ),
                            ),
                          ),
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
              _chartLegend('Pemasukan', Colors.blue),
              const SizedBox(width: 20),
              _chartLegend('Pengeluaran', Colors.red),
            ],
          ),
        ],
      ),
    );
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

  Widget _toggleItem(String label, bool active) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? theme.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: active ? Colors.white : theme.textSecondary, fontSize: 11)),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showDetailTransaksiModal(context),
              icon: const Icon(Icons.analytics, size: 16, color: Colors.white),
              label: const Text('Lihat Detail Pengeluaran', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailTransaksiModal(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: StreamBuilder<QuerySnapshot>(
            stream: _dbService.getAllTransactions(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              Map<String, double> categorySums = {};
              String largestExpenseNote = '-';
              double largestExpenseAmount = 0;

              Map<int, double> weeklyExpense = {};
              final DateTime startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
              final DateTime endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);

              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final ts = data['timestamp'] as Timestamp?;
                if (ts == null) continue;
                DateTime d = ts.toDate();
                double amt = (data['amount'] ?? 0).toDouble();

                if (data['type'] == 'Pengeluaran' && _isWithinRange(d, startDate, endDate)) {
                  String cat = data['category'] ?? 'Lainnya';
                  categorySums[cat] = (categorySums[cat] ?? 0) + amt;

                  if (amt > largestExpenseAmount) {
                    largestExpenseAmount = amt;
                    largestExpenseNote = (data['note'] != null && data['note'].toString().trim().isNotEmpty)
                        ? data['note']
                        : cat;
                  }

                  int weekNum = ((d.day - 1) ~/ 7) + 1;
                  if (weekNum > 5) weekNum = 5;
                  weeklyExpense[weekNum] = (weeklyExpense[weekNum] ?? 0) + amt;
                }
              }

              List<PieChartSectionData> pieSections = [];
              int i = 0;
              final List<Color> colors = [
                const Color(0xFF818CF8),
                const Color(0xFFF472B6),
                const Color(0xFF34D399),
                const Color(0xFFFBBF24),
                const Color(0xFF60A5FA),
                const Color(0xFFA78BFA),
              ];

              categorySums.forEach((cat, sum) {
                pieSections.add(
                  PieChartSectionData(
                    value: sum,
                    title: '',
                    color: colors[i % colors.length],
                    radius: 35,
                    showTitle: false,
                  ),
                );
                i++;
              });

              List<BarChartGroupData> expenseBarGroups = [];
              double maxExp = 0;

              for (int w = 1; w <= 5; w++) {
                double exp = weeklyExpense[w] ?? 0;
                if (exp > maxExp) maxExp = exp;
                expenseBarGroups.add(
                  BarChartGroupData(
                    x: w,
                    barRods: [
                      BarChartRodData(
                        toY: exp,
                        color: Colors.red,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        label: BarChartRodLabel(
                          show: exp > 0,
                          text: _formatShortAmount(exp),
                          style: TextStyle(color: theme.textPrimary, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }

              double calculatedMaxY = maxExp > 0 ? maxExp * 1.25 : 1000;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Detail Transaksi & Analisis', style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: Icon(Icons.close, color: theme.textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Analisis Kebiasaan Keuangan
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.isDark ? const Color(0xFF0F172A) : theme.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.psychology, color: Color(0xFFF472B6)),
                              const SizedBox(width: 8),
                              Text('Analisis Kebiasaan Keuangan', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (categorySums.isEmpty)
                            Center(child: Text('Belum ada pengeluaran dicatat periode ini.', style: TextStyle(color: theme.textMuted)))
                          else
                            Row(
                              children: [
                                SizedBox(
                                  height: 100,
                                  width: 100,
                                  child: PieChart(
                                    PieChartData(
                                      sections: pieSections,
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
                                      Text('Pengeluaran Terbesar:', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(largestExpenseNote, style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                      Text(currencyFormatter.format(largestExpenseAmount), style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),
                                      Text('Distribusi Kategori:', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: categorySums.keys.take(4).toList().asMap().entries.map((e) {
                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[e.key % colors.length], shape: BoxShape.circle)),
                                              const SizedBox(width: 4),
                                              Text(e.value, style: TextStyle(color: theme.textMuted, fontSize: 10)),
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
                    ),

                    const SizedBox(height: 24),

                    // Grafik Batang Pengeluaran Saja
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.isDark ? const Color(0xFF0F172A) : theme.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bar_chart, color: Colors.redAccent),
                              const SizedBox(width: 8),
                              Text('Grafik Pengeluaran', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 180,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: calculatedMaxY,
                                barGroups: expenseBarGroups,
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (double value, TitleMeta meta) {
                                        int week = value.toInt();
                                        if (week >= 1 && week <= 5) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text('Mgg $week', style: TextStyle(color: theme.textSecondary, fontSize: 9)),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
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
    return text.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }

  bool _isWithinRange(DateTime date, DateTime start, DateTime end) {
    return !date.isBefore(start) && !date.isAfter(end);
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

  void _showExportPeriodDialog(String format) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    bool isCustom = false;
    DateTime customStart = DateTime(_selectedDate.year, _selectedDate.month, 1);
    DateTime customEnd = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Pilih Periode ($format)', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<bool>(
                    value: false,
                    groupValue: isCustom,
                    title: Text('Bulan Saat Ini (${DateFormat('MMMM yyyy').format(_selectedDate)})', style: TextStyle(color: theme.textPrimary)),
                    activeColor: theme.accent,
                    onChanged: (val) => setDialogState(() => isCustom = val!),
                  ),
                  RadioListTile<bool>(
                    value: true,
                    groupValue: isCustom,
                    title: Text('Periode Kustom', style: TextStyle(color: theme.textPrimary)),
                    activeColor: theme.accent,
                    onChanged: (val) => setDialogState(() => isCustom = val!),
                  ),
                  if (isCustom) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final DateTimeRange? picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: DateTimeRange(start: customStart, end: customEnd),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme(
                                  brightness: theme.isDark ? Brightness.dark : Brightness.light,
                                  primary: theme.accent,
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
                          setDialogState(() {
                            customStart = picked.start;
                            customEnd = picked.end;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: theme.inputBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${DateFormat('dd/MM/yyyy').format(customStart)} - ${DateFormat('dd/MM/yyyy').format(customEnd)}',
                              style: TextStyle(color: theme.textPrimary, fontSize: 13),
                            ),
                            Icon(Icons.calendar_today, size: 16, color: theme.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                  onPressed: () {
                    Navigator.pop(context);
                    if (isCustom) {
                      final DateTime endOfDay = DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59);
                      if (format == 'PDF') {
                        _exportPdf(customStartDate: customStart, customEndDate: endOfDay);
                      } else {
                        _exportExcel(customStartDate: customStart, customEndDate: endOfDay);
                      }
                    } else {
                      if (format == 'PDF') {
                        _exportPdf();
                      } else {
                        _exportExcel();
                      }
                    }
                  },
                  child: const Text('Cetak', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportPdf({DateTime? customStartDate, DateTime? customEndDate}) async {
    final pdf = pw.Document();
    final String uid = _dbService.uid;

    final DateTime startDate = customStartDate ?? DateTime(_selectedDate.year, _selectedDate.month, 1);
    final DateTime endDate = customEndDate ?? DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
    final String formattedPeriod = customStartDate != null
        ? "${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}"
        : DateFormat('MMMM yyyy').format(_selectedDate);

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
    final transactionsSnapshot = await _dbService.getAllTransactionsOnce();

    List<List<String>> transactionsData = [];
    double totalIncome = 0;
    double totalExpense = 0;

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
        
        if (_isWithinRange(date, startDate, endDate)) {
          final isIncome = data['type'] == 'Pemasukan';
          final double amt = (data['amount'] ?? 0).toDouble();
          if (isIncome) {
            totalIncome += amt;
          } else {
            totalExpense += amt;
          }

          final category = _sanitizeForPdf(data['category'] ?? '-');
          final note = _sanitizeForPdf(data['note'] ?? '');
          final type = data['type'] ?? '-';
          final amountFormatted = (isIncome ? '' : '-') + currencyFormatter.format(amt);
          
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
          pw.Text('Periode: $formattedPeriod', style: pw.TextStyle(font: pw.Font.helveticaOblique(), fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 20),
          if (transactionsData.isEmpty)
            pw.Text('Tidak ada transaksi pada periode ini.', style: const pw.TextStyle(fontSize: 12))
          else ...[
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
            pw.SizedBox(height: 15),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.TableHelper.fromTextArray(
                  headers: ['Ringkasan', 'Jumlah'],
                  data: [
                    ['Total Pemasukan', currencyFormatter.format(totalIncome)],
                    ['Total Pengeluaran', currencyFormatter.format(totalExpense)],
                    ['Sisa Uang', currencyFormatter.format(totalIncome - totalExpense)],
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellAlignments: {
                    1: pw.Alignment.centerRight,
                  },
                ),
              ],
            ),
          ],
        ];
      },
    ));

    if (kIsWeb) {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'laporan_${_selectedReportType.toLowerCase()}.pdf');
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }
  }

  Future<void> _exportExcel({DateTime? customStartDate, DateTime? customEndDate}) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel["Sheet1"];
    
    final String uid = _dbService.uid;

    final DateTime startDate = customStartDate ?? DateTime(_selectedDate.year, _selectedDate.month, 1);
    final DateTime endDate = customEndDate ?? DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
    final String formattedPeriod = customStartDate != null
        ? "${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}"
        : DateFormat('MMMM yyyy').format(_selectedDate);

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

    final transactionsSnapshot = await _dbService.getAllTransactionsOnce();

    sheet.appendRow(["LAPORAN KEUANGAN RINGKASAN"]);
    sheet.appendRow(["Saudara/i", userName]);
    sheet.appendRow(["Periode:", formattedPeriod]);
    sheet.appendRow([]);
    sheet.appendRow(["Tanggal", "Kategori", "Keterangan", "Tipe", "Jumlah"]);
    
    double totalIncome = 0;
    double totalExpense = 0;

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
        if (_isWithinRange(date, startDate, endDate)) {
          final isIncome = data['type'] == 'Pemasukan';
          final double amt = (data['amount'] ?? 0).toDouble();
          if (isIncome) {
            totalIncome += amt;
          } else {
            totalExpense += amt;
          }

          sheet.appendRow([
            DateFormat('dd/MM/yyyy').format(date),
            data['category'] ?? '-',
            data['note'] ?? '',
            data['type'] ?? '-',
            (isIncome ? '' : '-') + currencyFormatter.format(amt),
          ]);
        }
      }
    }

    sheet.appendRow([]);
    sheet.appendRow(["", "", "", "Total Pemasukan:", currencyFormatter.format(totalIncome)]);
    sheet.appendRow(["", "", "", "Total Pengeluaran:", currencyFormatter.format(totalExpense)]);
    sheet.appendRow(["", "", "", "Sisa Uang:", currencyFormatter.format(totalIncome - totalExpense)]);

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

  Widget _buildCurrentReportContent(
    AsyncSnapshot<QuerySnapshot> snapshot,
    List<BarChartGroupData> chartData,
    List<String> chartLabels,
    double income,
    double expense,
    double cumulativeBalance,
    double totalSavings,
    List<QueryDocumentSnapshot> goalsList,
    bool isMobile,
  ) {
    return Column(
      children: [
        isMobile
             ? Column(
                 children: [
                   _buildChartArea(chartData, chartLabels),
                   const SizedBox(height: 24),
                   _buildSisaKeuangan(income, expense, cumulativeBalance, totalSavings),
                 ],
               )
             : Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Expanded(flex: 2, child: _buildChartArea(chartData, chartLabels)),
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
