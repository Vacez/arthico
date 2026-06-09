import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import 'package:intl/intl.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  void _showAddGoalDialog() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tambah Goal Baru', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: TextStyle(color: theme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nama Goal',
                labelStyle: TextStyle(color: theme.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accent, width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: theme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Target Nominal (Rp)',
                labelStyle: TextStyle(color: theme.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accent, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal', style: TextStyle(color: theme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (titleController.text.isNotEmpty && amountController.text.isNotEmpty) {
                await _dbService.addGoal(
                  title: titleController.text,
                  targetAmount: double.parse(amountController.text),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showNabungDialog(String goalId, String goalTitle) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Nabung: $goalTitle', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Masukkan nominal yang ingin ditabung dari saldo Anda.', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(color: theme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nominal (Rp)',
                labelStyle: TextStyle(color: theme.textSecondary),
                prefixText: 'Rp ',
                prefixStyle: TextStyle(color: theme.textPrimary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accent, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal', style: TextStyle(color: theme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              if (amountController.text.isNotEmpty) {
                double amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0) return;

                final res = await _dbService.savingToGoal(
                  goalId: goalId,
                  amount: amount,
                  goalTitle: goalTitle,
                );

                Navigator.pop(context);

                if (res['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Berhasil menabung ke $goalTitle'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Gagal: ${res['error']}'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Nabung Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    final theme = Provider.of<ThemeProvider>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.all(isMobile ? 12 : 24),
          padding: EdgeInsets.all(isMobile ? 16 : 32),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.border),
          ),
          child: Column(
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
                      Icon(Icons.track_changes, color: theme.textSecondary),
                      const SizedBox(width: 12),
                      Text(
                        'Goals / Tabungan',
                        style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: _showAddGoalDialog,
                      child: const Text('+ Tambah Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              StreamBuilder<QuerySnapshot>(
                stream: _dbService.getGoals(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Belum ada goals. Klik "Tambah Goal" untuk mulai menabung 💰',
                        style: TextStyle(color: theme.textMuted, fontSize: 14),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      double target = (doc['targetAmount'] ?? 0).toDouble();
                      double current = (doc['currentAmount'] ?? 0).toDouble();
                      double progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0;
                      String title = doc['title'] ?? 'Goal';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Terisi: ${currencyFormatter.format(current)} dari ${currencyFormatter.format(target)}',
                                        style: TextStyle(color: theme.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                                  ),
                                  child: TextButton.icon(
                                    onPressed: () => _showNabungDialog(doc.id, title),
                                    icon: const Icon(Icons.add, size: 16, color: Color(0xFF10B981)),
                                    label: const Text('Nabung', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Stack(
                              children: [
                                Container(
                                  height: 10,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: theme.isDark ? Colors.white10 : Colors.black12,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  height: 10,
                                  width: (MediaQuery.of(context).size.width - (isMobile ? 80 : 120)) * progress,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFF6366F1)]),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${(progress * 100).toStringAsFixed(1)}% Tercapai', style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                                if (progress >= 1.0)
                                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
