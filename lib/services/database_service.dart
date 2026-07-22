import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // --- CATEGORIES ---
  // Add a new category for the current user
  Future<Map<String, dynamic>> addCategory({required String name}) async {
    try {
      if (uid.isEmpty) return {'success': false, 'error': 'User ID is empty.'};
      DocumentReference userRef = _db.collection('users').doc(uid);
      await userRef.collection('categories').add({'name': name, 'createdAt': FieldValue.serverTimestamp()});
      return {'success': true, 'error': null};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Stream of categories for the current user
  Stream<QuerySnapshot> getCategories() {
    return _db.collection('users').doc(uid).collection('categories').orderBy('createdAt', descending: false).snapshots();
  }

  // Update a category name
  Future<Map<String, dynamic>> updateCategory({required String categoryId, required String newName}) async {
    try {
      if (uid.isEmpty) return {'success': false, 'error': 'User ID is empty.'};
      await _db.collection('users').doc(uid).collection('categories').doc(categoryId).update({'name': newName});
      return {'success': true, 'error': null};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Delete a category
  Future<Map<String, dynamic>> deleteCategory({required String categoryId}) async {
    try {
      if (uid.isEmpty) return {'success': false, 'error': 'User ID is empty.'};
      await _db.collection('users').doc(uid).collection('categories').doc(categoryId).delete();
      return {'success': true, 'error': null};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }


  // Add a new transaction
  Future<Map<String, dynamic>> addTransaction({
    required String type,
    required String category,
    required String allocation,
    required double amount,
    required String note,
    DateTime? customTimestamp,
  }) async {
    try {
      if (uid.isEmpty) return {'success': false, 'error': 'User ID is empty.'};
      
      DocumentReference userRef = _db.collection('users').doc(uid);
      
      // 1. Get current balance first
      DocumentSnapshot userSnap = await userRef.get();
      double currentBalance = 0;
      double minBalanceReserve = 0;
      if (userSnap.exists && userSnap.data() != null) {
        final userData = userSnap.data() as Map<String, dynamic>;
        currentBalance = (userData['balance'] ?? 0).toDouble();
        minBalanceReserve = (userData['minBalanceReserve'] ?? userData['monthlyBudget'] ?? 0).toDouble();
      }

      if (type != 'Pemasukan' && (currentBalance - amount) < minBalanceReserve) {
        final NumberFormat fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
        return {
          'success': false,
          'error': 'Transaksi dibatalkan. Saldo Anda harus tersisa minimal ${fmt.format(minBalanceReserve)}.'
        };
      }

      // 2. Add transaction record
      DocumentReference docRef = await userRef.collection('transactions').add({
        'type': type,
        'category': category,
        'allocation': allocation,
        'amount': amount,
        'note': note,
        'timestamp': customTimestamp != null
            ? Timestamp.fromDate(customTimestamp)
            : FieldValue.serverTimestamp(),
      });

      // 3. Update balance
      double newBalance = type == 'Pemasukan' 
          ? currentBalance + amount 
          : currentBalance - amount;
          
      await userRef.set({
        'balance': newBalance,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Trigger notification
      try {
        final notifId = NotificationService.instance.getUniqueId(docRef.id);
        final title = type == 'Pemasukan' ? '📈 Pemasukan Baru' : '📉 Pengeluaran Baru';
        final body = 'Rp ${amount.toStringAsFixed(0)} - $category (${note.isNotEmpty ? note : "Tanpa catatan"})';
        await NotificationService.instance.showInstantNotification(
          id: notifId,
          title: title,
          body: body,
        );
      } catch (notifErr) {
        print("Error showing notification: $notifErr");
      }

      return {'success': true, 'error': null};
    } catch (e) {
      print("❌ FIREBASE ERROR: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  // Stream of latest transactions
  Stream<QuerySnapshot> getRecentTransactions({int limit = 5}) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  // Delete a transaction and revert balance change
  Future<Map<String, dynamic>> deleteTransaction(String transactionId, Map<String, dynamic> transData) async {
    try {
      if (uid.isEmpty) return {'success': false, 'error': 'User ID is missing'};
      
      double amount = (transData['amount'] ?? 0).toDouble();
      String type = transData['type'] ?? 'Pengeluaran';
      String category = transData['category'] ?? '';
      String? goalId = transData['goalId'];
      
      DocumentReference userRef = _db.collection('users').doc(uid);
      DocumentSnapshot userSnap = await userRef.get();
      double balance = 0;
      if (userSnap.exists && userSnap.data() != null) {
        balance = ((userSnap.data() as Map<String, dynamic>)['balance'] ?? 0).toDouble();
      }
      
      // Revert balance: if it was income, subtract it. If it was expense, add it back.
      double newBalance = type == 'Pemasukan' ? balance - amount : balance + amount;
      
      if (newBalance < 0) {
        return {'success': false, 'error': 'Saldo tidak mencukupi.'};
      }
      
      await userRef.update({'balance': newBalance});

      // If it was a savings transaction to a goal, subtract the amount from the goal
      if (category == 'Tabungan') {
        if (goalId != null && goalId.isNotEmpty) {
          DocumentReference goalRef = userRef.collection('goals').doc(goalId);
          DocumentSnapshot goalSnap = await goalRef.get();
          if (goalSnap.exists) {
            double currentGoalAmount = (goalSnap.get('currentAmount') ?? 0).toDouble();
            double newGoalAmount = currentGoalAmount - amount;
            if (newGoalAmount < 0) newGoalAmount = 0;
            await goalRef.update({
              'currentAmount': newGoalAmount,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          }
        } else {
          // Fallback: match by note
          String note = transData['note'] ?? '';
          if (note.startsWith('Menabung untuk: ')) {
            String goalTitle = note.replaceFirst('Menabung untuk: ', '');
            QuerySnapshot goalSnaps = await userRef.collection('goals').where('title', isEqualTo: goalTitle).limit(1).get();
            if (goalSnaps.docs.isNotEmpty) {
              var doc = goalSnaps.docs.first;
              double currentGoalAmount = (doc['currentAmount'] ?? 0).toDouble();
              double newGoalAmount = currentGoalAmount - amount;
              if (newGoalAmount < 0) newGoalAmount = 0;
              await doc.reference.update({
                'currentAmount': newGoalAmount,
                'lastUpdated': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }
      
      await userRef.collection('transactions').doc(transactionId).delete();
      
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Update a transaction and adjust balance
  Future<Map<String, dynamic>> updateTransaction({
    required String id,
    required double oldAmount,
    required String oldType,
    required double newAmount,
    required String newType,
    required String category,
    required String allocation,
    required String note,
  }) async {
    try {
      if (uid.isEmpty) return {'success': false, 'error': 'User ID is missing'};
      
      DocumentReference userRef = _db.collection('users').doc(uid);
      DocumentSnapshot userSnap = await userRef.get();
      double balance = 0;
      if (userSnap.exists && userSnap.data() != null) {
        balance = ((userSnap.data() as Map<String, dynamic>)['balance'] ?? 0).toDouble();
      }
      
      // 1. Revert old amount
      double balanceAfterRevert = oldType == 'Pemasukan' ? balance - oldAmount : balance + oldAmount;
      
      // 2. Apply new amount
      double finalBalance = newType == 'Pemasukan' ? balanceAfterRevert + newAmount : balanceAfterRevert - newAmount;
      
      double minBalanceReserve = 0;
      if (userSnap.exists && userSnap.data() != null) {
        final userData = userSnap.data() as Map<String, dynamic>;
        minBalanceReserve = (userData['minBalanceReserve'] ?? userData['monthlyBudget'] ?? 0).toDouble();
      }
      
      if (finalBalance < minBalanceReserve) {
        final NumberFormat fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
        return {
          'success': false,
          'error': 'Transaksi dibatalkan. Saldo Anda harus tersisa minimal ${fmt.format(minBalanceReserve)}.'
        };
      }
      
      await userRef.update({'balance': finalBalance});
      await userRef.collection('transactions').doc(id).update({
        'type': newType,
        'category': category,
        'allocation': allocation,
        'amount': newAmount,
        'note': note,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Stream of all transactions (for Laporan)
  Stream<QuerySnapshot> getAllTransactions() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Future of all transactions (for Excel Export)
  Future<QuerySnapshot> getAllTransactionsOnce() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .get();
  }

  // --- FIXED EXPENSES (KEBUTUHAN WAJIB) ---

  // Add a new fixed expense
  Future<void> addFixedExpense({
    required String title,
    required double amount,
    required DateTime dueDate,
    int tenorMonths = 0,
  }) async {
    DocumentReference docRef = await _db.collection('users').doc(uid).collection('fixed_expenses').add({
      'title': title,
      'amount': amount,
      'isPaid': false,
      'tenorMonths': tenorMonths,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Schedule notification for due date at 08:00 AM
    try {
      final notifId = NotificationService.instance.getUniqueId(docRef.id);
      final notifTime = DateTime(dueDate.year, dueDate.month, dueDate.day, 8, 0, 0);
      await NotificationService.instance.scheduleNotification(
        id: notifId,
        title: '⚠️ Pengingat Jatuh Tempo',
        body: 'Tagihan "$title" sebesar Rp ${amount.toStringAsFixed(0)} jatuh tempo hari ini.',
        scheduledDate: notifTime,
      );
    } catch (e) {
      print("Error scheduling notification in addFixedExpense: $e");
    }
  }

  // Update fixed expense
  Future<void> updateFixedExpense(
    String id,
    String title,
    double amount,
    int tenorMonths,
    DateTime dueDate,
  ) async {
    await _db.collection('users').doc(uid).collection('fixed_expenses').doc(id).update({
      'title': title,
      'amount': amount,
      'tenorMonths': tenorMonths,
      'dueDate': Timestamp.fromDate(dueDate),
    });

    // Reschedule/update notification
    try {
      final notifId = NotificationService.instance.getUniqueId(id);
      final notifTime = DateTime(dueDate.year, dueDate.month, dueDate.day, 8, 0, 0);
      await NotificationService.instance.scheduleNotification(
        id: notifId,
        title: '⚠️ Pengingat Jatuh Tempo',
        body: 'Tagihan "$title" sebesar Rp ${amount.toStringAsFixed(0)} jatuh tempo hari ini.',
        scheduledDate: notifTime,
      );
    } catch (e) {
      print("Error rescheduling notification in updateFixedExpense: $e");
    }
  }

  // Delete fixed expense
  Future<void> deleteFixedExpense(String id) async {
    await _db.collection('users').doc(uid).collection('fixed_expenses').doc(id).delete();

    // Cancel scheduled notification
    try {
      final notifId = NotificationService.instance.getUniqueId(id);
      await NotificationService.instance.cancelNotification(notifId);
    } catch (e) {
      print("Error cancelling notification in deleteFixedExpense: $e");
    }
  }

  // Toggle paid status (simple state toggle)
  Future<void> toggleFixedExpenseStatus(String id, bool currentStatus) async {
    bool newStatus = !currentStatus;
    await _db.collection('users').doc(uid).collection('fixed_expenses').doc(id).update({
      'isPaid': newStatus,
    });

    // Handle scheduling/cancelling notification based on payment status
    try {
      final notifId = NotificationService.instance.getUniqueId(id);
      if (newStatus) {
        // Cancel notification
        await NotificationService.instance.cancelNotification(notifId);
      } else {
        // Reschedule notification by querying the doc details
        DocumentSnapshot doc = await _db.collection('users').doc(uid).collection('fixed_expenses').doc(id).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          final String title = data['title'] ?? '';
          final double amount = (data['amount'] ?? 0).toDouble();
          if (data['dueDate'] != null) {
            final DateTime dueDate = (data['dueDate'] as Timestamp).toDate();
            final notifTime = DateTime(dueDate.year, dueDate.month, dueDate.day, 8, 0, 0);
            await NotificationService.instance.scheduleNotification(
              id: notifId,
              title: '⚠️ Pengingat Jatuh Tempo',
              body: 'Tagihan "$title" sebesar Rp ${amount.toStringAsFixed(0)} jatuh tempo hari ini.',
              scheduledDate: notifTime,
            );
          }
        }
      }
    } catch (e) {
      print("Error updating notification in toggleFixedExpenseStatus: $e");
    }
  }

  // Pay fixed expense (with financial impact)
  Future<Map<String, dynamic>> payFixedExpense({
    required String id,
    required String title,
    required double amount,
  }) async {
    try {
      if (uid.isEmpty) return {'success': false, 'error': 'User ID is empty.'};

      DocumentReference userRef = _db.collection('users').doc(uid);
      
      // Get current balance
      DocumentSnapshot userSnap = await userRef.get();
      double currentBalance = 0;
      if (userSnap.exists && userSnap.data() != null) {
        currentBalance = ((userSnap.data() as Map<String, dynamic>)['balance'] ?? 0).toDouble();
      }

      if (currentBalance < amount) {
        return {'success': false, 'error': 'Saldo tidak mencukupi.'};
      }

      // 1. Mark as Paid
      await userRef.collection('fixed_expenses').doc(id).update({
        'isPaid': true,
        'paidAt': FieldValue.serverTimestamp(),
      });

      // 2. Add Transaction Record
      await userRef.collection('transactions').add({
        'type': 'Pengeluaran',
        'category': 'Beban Pokok',
        'allocation': 'Primer',
        'amount': amount,
        'note': 'Bayar: $title',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Update Balance
      await userRef.update({
        'balance': currentBalance - amount,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Trigger notification & cancel scheduled due date notification
      try {
        final notifId = NotificationService.instance.getUniqueId(id);
        // Cancel scheduled notification since it is paid
        await NotificationService.instance.cancelNotification(notifId);

        // Show instant notification of payment
        await NotificationService.instance.showInstantNotification(
          id: notifId + 1, // different ID to avoid conflict
          title: '✅ Pembayaran Sukses',
          body: 'Tagihan "$title" sebesar Rp ${amount.toStringAsFixed(0)} telah berhasil dibayar.',
        );
      } catch (notifErr) {
        print("Error with notification in payFixedExpense: $notifErr");
      }

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Stream of fixed expenses
  Stream<QuerySnapshot> getFixedExpenses() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('fixed_expenses')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Check and process auto-payments for due fixed expenses
  Future<void> checkAndProcessAutoPayments() async {
    try {
      if (uid.isEmpty) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 23, 59, 59); // end of today

      final userRef = _db.collection('users').doc(uid);
      final expensesQuery = await userRef
          .collection('fixed_expenses')
          .where('isPaid', isEqualTo: false)
          .get();

      for (var doc in expensesQuery.docs) {
        final data = doc.data();
        if (data['dueDate'] == null) continue;

        final DateTime dueDate = (data['dueDate'] as Timestamp).toDate();

        // If due date is on or before today
        if (dueDate.isBefore(today) || dueDate.isAtSameMomentAs(today)) {
          final String title = data['title'] ?? '';
          final double amount = (data['amount'] ?? 0).toDouble();
          int tenor = 0;
          try {
            tenor = ((data['tenorMonths'] ?? 0) as num).toInt();
          } catch (_) {}

          // 1. Process payment (deduct balance and record transaction)
          // Get current balance
          final userSnap = await userRef.get();
          double currentBalance = 0;
          if (userSnap.exists && userSnap.data() != null) {
            currentBalance = ((userSnap.data() as Map<String, dynamic>)['balance'] ?? 0).toDouble();
          }

          if (currentBalance < amount) {
            // Skip payment and show notification of failure
            try {
              final notifId = NotificationService.instance.getUniqueId(doc.id);
              await NotificationService.instance.showInstantNotification(
                id: notifId + 3, // different ID to avoid conflict
                title: '❌ Auto-Debet Gagal',
                body: 'Tagihan "$title" sebesar Rp ${amount.toStringAsFixed(0)} gagal dibayar otomatis karena saldo tidak mencukupi.',
              );
            } catch (e) {
              print("Error showing auto-payment failure notification: $e");
            }
            continue;
          }

          // Deduct balance
          double newBalance = currentBalance - amount;
          await userRef.set({
            'balance': newBalance,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Record transaction
          String note = 'Auto-Bayar: $title';
          if (tenor > 0) {
            note += ' (Tenor sisa: ${tenor - 1} bln)';
          }
          await userRef.collection('transactions').add({
            'type': 'Pengeluaran',
            'category': 'Beban Pokok',
            'allocation': 'Primer',
            'amount': amount,
            'note': note,
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Trigger instant notification for auto-payment
          try {
            final notifId = NotificationService.instance.getUniqueId(doc.id);
            await NotificationService.instance.showInstantNotification(
              id: notifId + 2, // avoid conflict with scheduled ID
              title: '🤖 Auto-Debet Sukses',
              body: 'Tagihan "$title" sebesar Rp ${amount.toStringAsFixed(0)} berhasil dibayar secara otomatis.',
            );
          } catch (e) {
            print("Error showing auto-payment notification: $e");
          }

          // 2. Handle Tenor / Recurring
          if (tenor > 1) {
            // Move due date to next month
            int nextYear = dueDate.year;
            int nextMonth = dueDate.month + 1;
            if (nextMonth > 12) {
              nextMonth = 1;
              nextYear += 1;
            }
            // clamp day to valid days in that month (e.g. 31st of November -> 30th of November)
            int lastDay = DateTime(nextYear, nextMonth + 1, 0).day;
            int nextDay = dueDate.day > lastDay ? lastDay : dueDate.day;
            DateTime nextDueDate = DateTime(nextYear, nextMonth, nextDay, dueDate.hour, dueDate.minute, dueDate.second);

            await doc.reference.update({
              'tenorMonths': tenor - 1,
              'dueDate': Timestamp.fromDate(nextDueDate),
            });

            // Reschedule notification for next month
            try {
              final notifId = NotificationService.instance.getUniqueId(doc.id);
              final notifTime = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day, 8, 0, 0);
              await NotificationService.instance.scheduleNotification(
                id: notifId,
                title: '⚠️ Pengingat Jatuh Tempo',
                body: 'Tagihan "$title" sebesar Rp ${amount.toStringAsFixed(0)} jatuh tempo hari ini.',
                scheduledDate: notifTime,
              );
            } catch (e) {
              print("Error rescheduling recurring notification: $e");
            }
          } else {
            // tenor is 1 or 0, so mark as paid
            await doc.reference.update({
              'isPaid': true,
              'tenorMonths': 0,
            });

            // Cancel notification
            try {
              final notifId = NotificationService.instance.getUniqueId(doc.id);
              await NotificationService.instance.cancelNotification(notifId);
            } catch (e) {
              print("Error cancelling notification after final payment: $e");
            }
          }
        }
      }
    } catch (e) {
      print("❌ AUTO PAYMENT ERROR: $e");
    }
  }

  // --- GOALS ---

  // Add a new goal
  Future<void> addGoal({
    required String title,
    required double targetAmount,
  }) async {
    await _db.collection('users').doc(uid).collection('goals').add({
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Stream of goals
  Stream<QuerySnapshot> getGoals() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('goals')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Save money to a specific goal
  Future<Map<String, dynamic>> savingToGoal({
    required String goalId,
    required double amount,
    required String goalTitle,
  }) async {
    try {
      if (uid.isEmpty) return {'success': false, 'error': 'User ID is empty.'};

      DocumentReference userRef = _db.collection('users').doc(uid);
      DocumentReference goalRef = userRef.collection('goals').doc(goalId);

      // We use sequential awaits to avoid transaction errors in Web SDK
      DocumentSnapshot userSnap = await userRef.get();
      if (!userSnap.exists) return {'success': false, 'error': 'User document not found.'};
      
      double currentBalance = (userSnap.get('balance') ?? 0).toDouble();
      if (currentBalance < amount) {
        return {'success': false, 'error': 'Saldo tidak mencukupi untuk menabung.'};
      }

      // 1. Update Goal Amount
      DocumentSnapshot goalSnap = await goalRef.get();
      double currentGoalAmount = (goalSnap.get('currentAmount') ?? 0).toDouble();
      
      await goalRef.update({
        'currentAmount': currentGoalAmount + amount,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // 2. Add as a transaction record (Type: Pengeluaran for balance, but tagged as Tabungan)
      DocumentReference docRef = await userRef.collection('transactions').add({
        'type': 'Pengeluaran',
        'category': 'Tabungan',
        'allocation': 'Primer',
        'amount': amount,
        'note': 'Menabung untuk: $goalTitle',
        'timestamp': FieldValue.serverTimestamp(),
        'goalId': goalId,
      });

      // 3. Update User Balance
      await userRef.update({
        'balance': currentBalance - amount,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Trigger notification
      try {
        final notifId = NotificationService.instance.getUniqueId(docRef.id);
        await NotificationService.instance.showInstantNotification(
          id: notifId,
          title: '💰 Berhasil Menabung',
          body: 'Berhasil menabung Rp ${amount.toStringAsFixed(0)} untuk "$goalTitle"',
        );
      } catch (notifErr) {
        print("Error showing notification: $notifErr");
      }

      return {'success': true, 'error': null};
    } catch (e) {
      print("❌ SAVING ERROR: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  // Update a goal's title and target amount
  Future<Map<String, dynamic>> updateGoal({
    required String goalId,
    required String title,
    required double targetAmount,
  }) async {
    try {
      if (uid.isEmpty) return {'success': false, 'error': 'User ID is empty.'};
      await _db.collection('users').doc(uid).collection('goals').doc(goalId).update({
        'title': title,
        'targetAmount': targetAmount,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return {'success': true, 'error': null};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Delete a goal
  Future<Map<String, dynamic>> deleteGoal(String goalId) async {
    try {
      if (uid.isEmpty) return {'success': false, 'error': 'User ID is empty.'};
      await _db.collection('users').doc(uid).collection('goals').doc(goalId).delete();
      return {'success': true, 'error': null};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Stream of user profile (for balance etc)
  Stream<DocumentSnapshot> getUserData() {
    String currentUid = uid;
    if (currentUid.isEmpty) {
      currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    }
    return _db.collection('users').doc(currentUid).snapshots();
  }

  // Update specific user preference
  Future<void> updateUserPreference(String key, dynamic value) async {
    await _db.collection('users').doc(uid).set({
      key: value,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Update user profile picture (base64 string)
  Future<Map<String, dynamic>> updateProfilePhoto(String base64Image) async {
    try {
      if (uid.isEmpty) return {'success': false, 'error': 'User ID is empty.'};
      DocumentReference userRef = _db.collection('users').doc(uid);
      await userRef.set({
        'photoUrl': base64Image,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
