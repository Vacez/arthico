import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // --- TRANSACTIONS ---

  // Add a new transaction
  Future<Map<String, dynamic>> addTransaction({
    required String type,
    required String category,
    required String allocation,
    required double amount,
    required String note,
  }) async {
    try {
      if (uid.isEmpty) return {'success': false, 'error': 'User ID is empty.'};
      
      DocumentReference userRef = _db.collection('users').doc(uid);
      
      // 1. Get current balance first
      DocumentSnapshot userSnap = await userRef.get();
      double currentBalance = 0;
      if (userSnap.exists && userSnap.data() != null) {
        currentBalance = ((userSnap.data() as Map<String, dynamic>)['balance'] ?? 0).toDouble();
      }

      // 2. Add transaction record
      await userRef.collection('transactions').add({
        'type': type,
        'category': category,
        'allocation': allocation,
        'amount': amount,
        'note': note,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Update balance
      double newBalance = type == 'Pemasukan' 
          ? currentBalance + amount 
          : currentBalance - amount;
          
      await userRef.set({
        'balance': newBalance,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
      
      DocumentReference userRef = _db.collection('users').doc(uid);
      DocumentSnapshot userSnap = await userRef.get();
      double balance = 0;
      if (userSnap.exists && userSnap.data() != null) {
        balance = ((userSnap.data() as Map<String, dynamic>)['balance'] ?? 0).toDouble();
      }
      
      // Revert balance: if it was income, subtract it. If it was expense, add it back.
      double newBalance = type == 'Pemasukan' ? balance - amount : balance + amount;
      
      await userRef.update({'balance': newBalance});
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

  // --- FIXED EXPENSES (KEBUTUHAN WAJIB) ---

  // Add a new fixed expense
  Future<void> addFixedExpense({
    required String title,
    required double amount,
  }) async {
    await _db.collection('users').doc(uid).collection('fixed_expenses').add({
      'title': title,
      'amount': amount,
      'isPaid': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Update fixed expense
  Future<void> updateFixedExpense(String id, String title, double amount) async {
    await _db.collection('users').doc(uid).collection('fixed_expenses').doc(id).update({
      'title': title,
      'amount': amount,
    });
  }

  // Delete fixed expense
  Future<void> deleteFixedExpense(String id) async {
    await _db.collection('users').doc(uid).collection('fixed_expenses').doc(id).delete();
  }

  // Toggle paid status (simple state toggle)
  Future<void> toggleFixedExpenseStatus(String id, bool currentStatus) async {
    await _db.collection('users').doc(uid).collection('fixed_expenses').doc(id).update({
      'isPaid': !currentStatus,
    });
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
      await userRef.collection('transactions').add({
        'type': 'Pengeluaran',
        'category': 'Tabungan',
        'allocation': 'Primer',
        'amount': amount,
        'note': 'Menabung untuk: $goalTitle',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Update User Balance
      await userRef.update({
        'balance': currentBalance - amount,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'error': null};
    } catch (e) {
      print("❌ SAVING ERROR: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  // Stream of user profile (for balance etc)
  Stream<DocumentSnapshot> getUserData() {
    return _db.collection('users').doc(uid).snapshots();
  }

  // Update specific user preference
  Future<void> updateUserPreference(String key, dynamic value) async {
    await _db.collection('users').doc(uid).set({
      key: value,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
