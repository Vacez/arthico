import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getGoals(),
      builder: (context, goalsSnapshot) {
        double totalSavings = 0;
        if (goalsSnapshot.hasData) {
          for (var doc in goalsSnapshot.data!.docs) {
            totalSavings += (doc['currentAmount'] ?? 0).toDouble();
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _dbService.getAllTransactions(),
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
                // Weekly aggregation within the selected month
                Map<int, double> weeklyIncome = {};
                Map<int, double> weeklyExpense = {};
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final timestamp = data['timestamp'] as Timestamp?;
                  if (timestamp == null) continue;
                  DateTime date = timestamp.toDate();
                  if (date.month == _selectedDate.month && date.year == _selectedDate.year) {
                    int weekOfMonth = ((date.day - 1) ~/ 7) + 1; // 1-5
                    double amt = (data['amount'] ?? 0).toDouble();
                    if (data['type'] == 'Pemasukan') {
                      weeklyIncome[weekOfMonth] = (weeklyIncome[weekOfMonth] ?? 0) + amt;
                    } else {
                      weeklyExpense[weekOfMonth] = (weeklyExpense[weekOfMonth] ?? 0) + amt;
                    }
                  }
                }
                // Build chart data for each week
                chartData = weeklyIncome.keys.map((week) {
                  double inc = weeklyIncome[week] ?? 0;
                  double exp = weeklyExpense[week] ?? 0;
                  return BarChartGroupData(
                    x: week,
                    barRods: [
                      BarChartRodData(toY: inc, color: Colors.blue, width: 12),
                      BarChartRodData(toY: exp, color: Colors.red, width: 12),
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
                                      if (picked != null) setState(() => _selectedDate = picked);
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildRincianTransaksi(snapshot),
                ],
              ),
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
                      barGroups: chartData,
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              switch (value.toInt()) {
                                case 0:
                                  return Text('Pemasukan', style: TextStyle(color: theme.textSecondary, fontSize: 10));
                                case 1:
                                  return Text('Pengeluaran', style: TextStyle(color: theme.textSecondary, fontSize: 10));
                                default:
                                  return const SizedBox.shrink();
                              }
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      groupsSpace: 30,
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
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            Text('Tidak ada data transaksi', style: TextStyle(color: theme.textMuted))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = data['timestamp'] as Timestamp?;
                if (timestamp == null) return const SizedBox.shrink();
                
                DateTime date = timestamp.toDate();
                if (date.month != _selectedDate.month || date.year != _selectedDate.year) {
                  return const SizedBox.shrink();
                }

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
    
    // Fetch transactions
    final snapshot = await _dbService.getAllTransactionsOnce();
    List<List<String>> transactionsData = [];
    
    if (snapshot.docs.isNotEmpty) {
      // Sort transactions oldest to newest
      final docs = List<QueryDocumentSnapshot>.from(snapshot.docs);
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
        
        // Filter by period (same month and year)
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
          pw.Text('Periode: ${DateFormat('MMMM yyyy').format(_selectedDate)}', style: const pw.TextStyle(fontSize: 14)),
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
                4: pw.Alignment.centerRight, // Align amount column to right
              },
            ),
        ];
      },
    ));

    // Conditional handling for web vs mobile/desktop
    if (kIsWeb) {
      // On web, sharePdf triggers a download dialog
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'laporan.pdf');
    } else {
      // On mobile/desktop, open print preview
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }
  }

  Future<void> _exportExcel() async {
    var excel = Excel.createExcel();
    Sheet sheet = excel["Sheet1"];
    // Header row
    sheet.appendRow(["Tanggal", "Kategori", "Keterangan", "Tipe", "Jumlah"]);
    // Fetch transactions
    final snapshot = await _dbService.getAllTransactionsOnce();
    if (snapshot.docs.isNotEmpty) {
      // Sort transactions oldest to newest
      final docs = List<QueryDocumentSnapshot>.from(snapshot.docs);
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
        // Filter by period
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
    final bytes = Uint8List.fromList(excel.encode()!);
    if (kIsWeb) {
      // Use file_saver to trigger a download in the browser
      await FileSaver.instance.saveFile(name: 'laporan', bytes: bytes, ext: 'xlsx');
    } else {
      final output = await getTemporaryDirectory();
      final filePath = "${output.path}/laporan.xlsx";
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Laporan Excel');
    }
  }
}
