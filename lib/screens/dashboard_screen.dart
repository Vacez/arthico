import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _db = DatabaseService();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final snap = await _db.getCategories().first;
    setState(() {
      _categories = snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
    });
  }

  void _showAddCategorySheet() {
    final _formKey = GlobalKey<FormState>();
    String newName = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Tambah Kategori', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Nama Kategori'),
                  validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                  onSaved: (v) => newName = v!.trim(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState?.validate() ?? false) {
                    _formKey.currentState?.save();
                    await _db.addCategory(name: newName);
                    Navigator.of(context).pop();
                    _loadCategories();
                  }
                },
                child: const Text('Simpan'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _categories.isEmpty
            ? const Center(child: Text('Tidak ada kategori.', style: TextStyle(color: Colors.white70)))
            : Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _categories.map((doc) {
                  final data = doc.data();
                  final name = data['name'] ?? '-';
                  return Chip(
                    label: Text(name, style: const TextStyle(color: Colors.white)),
                    backgroundColor: const Color(0xFF0F172A),
                  );
                }).toList(),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF10B981),
        onPressed: _showAddCategorySheet,
        tooltip: 'Tambah Kategori',
        child: const Icon(Icons.add),
      ),
    );
  }
}
