import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getAllTransactions(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Err: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        double income = 0;
        double expense = 0;
        List<BarChartGroupData> chartData = [];

        if (snapshot.hasData) {
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

        double sisa = income - expense;
        bool isMobile = MediaQuery.of(context).size.width < 700;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
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
                            const Icon(Icons.bar_chart, color: Color(0xFF818CF8)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Laporan Keuangan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(DateFormat('MMM yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white38, fontSize: 11)),
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
                                  );
                                  if (picked != null) setState(() => _selectedDate = picked);
                                },
                                child: _filterDropdown(DateFormat('MMM yyyy').format(_selectedDate)),
                              ),
                              const SizedBox(width: 8),
                              _actionButton('PDF', const Color(0xFFEF4444)),
                              const SizedBox(width: 8),
                              _actionButton('Excel', const Color(0xFF10B981)),
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
                            _buildSisaKeuangan(income, expense, sisa),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: _buildChartArea(chartData)),
                            const SizedBox(width: 24),
                            Expanded(flex: 1, child: _buildSisaKeuangan(income, expense, sisa)),
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
      }
    );
  }

  Widget _filterDropdown(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
          const Icon(Icons.arrow_drop_down, color: Colors.white38, size: 16),
        ],
      ),
    );
  }

  Widget _datePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: const [
          Icon(Icons.calendar_month, color: Colors.white38, size: 16),
          SizedBox(width: 8),
          Text('mm / dd / yyyy', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildChartArea(List<BarChartGroupData> chartData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: Color(0xFF818CF8), size: 16),
              const SizedBox(width: 8),
              const Text('Grafik Keuangan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              _toggleItem('Mingguan', true),
              _toggleItem('Bulanan', false),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: chartData.isEmpty 
              ? Center(child: Icon(Icons.show_chart, color: Colors.white10, size: 100))
              : BarChart(
                  BarChartData(
                    barGroups: chartData,
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(show: false),
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
      child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white38, fontSize: 12)),
    );
  }

  Widget _buildSisaKeuangan(double income, double expense, double sisa) {
    double progress = income > 0 ? (sisa / income).clamp(0, 1) : 0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          const Text('SISA KEUANGAN', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Text(currencyFormatter.format(sisa), style: TextStyle(color: sisa >= 0 ? const Color(0xFF10B981) : Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Tersisa ${(progress * 100).toStringAsFixed(0)}% dari pemasukan', style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progress, backgroundColor: Colors.white12, color: sisa >= 0 ? const Color(0xFF10B981) : Colors.redAccent, minHeight: 4),
          const SizedBox(height: 24),
          _reportRow(Icons.arrow_upward, 'Pemasukan', currencyFormatter.format(income), Colors.blue),
          const SizedBox(height: 12),
          _reportRow(Icons.arrow_downward, 'Pengeluaran', currencyFormatter.format(expense), Colors.red),
          const SizedBox(height: 12),
          _reportRow(Icons.account_balance_wallet, 'Total Tabungan', 'Rp 0', Colors.indigo),
        ],
      ),
    );
  }

  Widget _reportRow(IconData icon, String label, String value, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRincianTransaksi(AsyncSnapshot<QuerySnapshot> snapshot) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.list, color: Colors.white60, size: 20),
              SizedBox(width: 8),
              Text('Rincian Transaksi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            const Text('Tidak ada data transaksi', style: TextStyle(color: Colors.white38))
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
                  title: Text(data['category'] ?? '-', style: const TextStyle(color: Colors.white)),
                  subtitle: Text(data['note'] ?? '', style: const TextStyle(color: Colors.white60)),
                  trailing: Text(currencyFormatter.format(data['amount'] ?? 0), style: TextStyle(color: isIncome ? Colors.blue : Colors.red, fontWeight: FontWeight.bold)),
                );
              },
            ),
        ],
      ),
    );
  }
}
