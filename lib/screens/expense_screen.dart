import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';

class ExpenseScreen extends StatefulWidget {
  @override
  _ExpenseScreenState createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color kPrimary = Color(0xFF0F6E56);
  static const Color kAccent = Color(0xFF1D9E75);
  static const Color kBg = Color(0xFFE1F5EE);
  static const Color kDark = Color(0xFF085041);

  String _selectedPeriod = 'Harian';
  DateTime _selectedDate = DateTime.now();

  static const List<Map<String, dynamic>> kCategories = [
    {'key': 'pakan', 'label': 'Pakan', 'icon': Icons.grass_outlined, 'color': Color(0xFF4CAF50)},
    {'key': 'obat', 'label': 'Obat & Vitamin', 'icon': Icons.medication_outlined, 'color': Color(0xFF2196F3)},
    {'key': 'operasional', 'label': 'Operasional', 'icon': Icons.build_outlined, 'color': Color(0xFFFF9800)},
    {'key': 'lainnya', 'label': 'Lainnya', 'icon': Icons.more_horiz, 'color': Color(0xFF9E9E9E)},
  ];

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Map<String, dynamic> _getCategoryMeta(String key) {
    return kCategories.firstWhere(
      (c) => c['key'] == key,
      orElse: () => kCategories.last,
    );
  }

  Map<String, DateTime> _getDateRange() {
    DateTime startDate, endDate;
    switch (_selectedPeriod) {
      case 'Harian':
        startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        endDate = startDate.add(const Duration(days: 1));
        break;
      case 'Bulanan':
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
        break;
      case 'Tahunan':
        startDate = DateTime(_selectedDate.year, 1, 1);
        endDate = DateTime(_selectedDate.year + 1, 1, 1);
        break;
      default:
        startDate = DateTime.now();
        endDate = startDate.add(const Duration(days: 1));
    }
    return {'start': startDate, 'end': endDate};
  }

  String _getDateText() {
    switch (_selectedPeriod) {
      case 'Harian':
        return '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
      case 'Bulanan':
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
        return '${months[_selectedDate.month - 1]} ${_selectedDate.year}';
      case 'Tahunan':
        return '${_selectedDate.year}';
      default:
        return '';
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        switch (_selectedPeriod) {
          case 'Bulanan':
            _selectedDate = DateTime(picked.year, picked.month, 1);
            break;
          case 'Tahunan':
            _selectedDate = DateTime(picked.year, 1, 1);
            break;
          default:
            _selectedDate = picked;
        }
      });
    }
  }

  // ✅ Konfirmasi hapus dengan swipe — fix overflow, pakai Flexible
  Future<bool?> _confirmDelete(BuildContext context, String description) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            // ✅ Flexible supaya tidak overflow
            Flexible(
              child: Text(
                'Hapus Pengeluaran',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: kDark),
              ),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
            children: [
              const TextSpan(text: 'Hapus catatan '),
              TextSpan(
                text: '"$description"',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const TextSpan(text: '?\n\nData tidak bisa dikembalikan.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: Text('Hapus', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[500],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    String selectedCategory = 'pakan';
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.add_card, color: kPrimary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Catat Pengeluaran',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.bold, color: kDark),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kategori',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kCategories.map((cat) {
                      final isSelected = selectedCategory == cat['key'];
                      final color = cat['color'] as Color;
                      return GestureDetector(
                        onTap: () => setDialog(() => selectedCategory = cat['key']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withOpacity(0.15) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? color : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cat['icon'] as IconData,
                                  size: 14, color: isSelected ? color : Colors.grey[500]),
                              const SizedBox(width: 5),
                              Text(
                                cat['label'],
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? color : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Keterangan',
                      hintText: 'Contoh: Pakan 50 kg dari toko X',
                      prefixIcon: const Icon(Icons.notes, color: kAccent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kPrimary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialog(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nominal',
                      prefixText: 'Rp ',
                      prefixIcon: const Icon(Icons.attach_money, color: kAccent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kPrimary, width: 2),
                      ),
                    ),
                  ),
                  if ((double.tryParse(amountCtrl.text) ?? 0) > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          Text('Total Pengeluaran',
                              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            'Rp ${_formatCurrency(double.tryParse(amountCtrl.text) ?? 0)}',
                            style: GoogleFonts.poppins(
                                color: Colors.red[700], fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey[600])),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (descCtrl.text.trim().isEmpty || amount <= 0) return;
                  await _firestore.collection('expenses').add({
                    'category': selectedCategory,
                    'description': descCtrl.text.trim(),
                    'amount': amount,
                    'dateTime': DateTime.now().toIso8601String(),
                  });
                  if (mounted) Navigator.pop(ctx);
                },
                child: Text('Simpan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _expensesStream() {
    final range = _getDateRange();
    return _firestore
        .collection('expenses')
        .where('dateTime', isGreaterThanOrEqualTo: range['start']!.toIso8601String())
        .where('dateTime', isLessThan: range['end']!.toIso8601String())
        .orderBy('dateTime', descending: true)
        .snapshots();
  }

  Future<Map<String, double>> _getCategorySummary() async {
    final range = _getDateRange();
    final snap = await _firestore
        .collection('expenses')
        .where('dateTime', isGreaterThanOrEqualTo: range['start']!.toIso8601String())
        .where('dateTime', isLessThan: range['end']!.toIso8601String())
        .get();

    final Map<String, double> totals = {};
    for (final cat in kCategories) {
      totals[cat['key']] = 0;
    }
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final cat = data['category'] ?? 'lainnya';
      final amount = (data['amount'] ?? 0).toDouble();
      totals[cat] = (totals[cat] ?? 0) + amount;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildPeriodSelector()),
            SliverToBoxAdapter(child: _buildSummarySection()),
            SliverToBoxAdapter(child: _buildCategoryBreakdown()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Riwayat Pengeluaran',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.bold, color: kDark),
                ),
              ),
            ),
            SliverToBoxAdapter(child: Divider(thickness: 1, color: Colors.grey[200])),
            _buildExpenseSliver(),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Catat Pengeluaran',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range, color: kPrimary),
          const SizedBox(width: 8),
          Text('Periode:',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.bold, color: kPrimary)),
          const Spacer(),
          DropdownButton<String>(
            value: _selectedPeriod,
            items: ['Harian', 'Bulanan', 'Tahunan'].map((v) {
              return DropdownMenuItem(value: v, child: Text(v, style: GoogleFonts.poppins()));
            }).toList(),
            onChanged: (v) => setState(() => _selectedPeriod = v!),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF9FE1CB)),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: kPrimary),
                  const SizedBox(width: 6),
                  Text(_getDateText(),
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return FutureBuilder<Map<String, double>>(
      future: _getCategorySummary(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: kPrimary)),
          );
        }
        final totals = snapshot.data!;
        final grandTotal = totals.values.fold(0.0, (a, b) => a + b);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.red[600],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Icon(Icons.money_off, color: Colors.white, size: 28),
                const SizedBox(height: 6),
                Text('Total Pengeluaran',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  'Rp ${_formatCurrency(grandTotal)}',
                  style: GoogleFonts.poppins(
                      fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryBreakdown() {
    return FutureBuilder<Map<String, double>>(
      future: _getCategorySummary(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final totals = snapshot.data!;
        final grandTotal = totals.values.fold(0.0, (a, b) => a + b);
        if (grandTotal == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Breakdown Kategori',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.bold, color: kDark)),
              const SizedBox(height: 10),
              ...kCategories.map((cat) {
                final amount = totals[cat['key']] ?? 0;
                if (amount == 0) return const SizedBox.shrink();
                final percent = grandTotal > 0 ? amount / grandTotal : 0.0;
                final color = cat['color'] as Color;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(cat['icon'] as IconData, size: 14, color: color),
                          const SizedBox(width: 6),
                          Text(cat['label'],
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                          const Spacer(),
                          Text('Rp ${_formatCurrency(amount)}',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                          const SizedBox(width: 6),
                          Text('${(percent * 100).toStringAsFixed(0)}%',
                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          backgroundColor: color.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpenseSliver() {
    return StreamBuilder<QuerySnapshot>(
      stream: _expensesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: kPrimary)),
            ),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return SliverToBoxAdapter(child: _emptyState());
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _buildExpenseCard(docs[i]),
            childCount: docs.length,
          ),
        );
      },
    );
  }

  Widget _buildExpenseCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final category = data['category'] ?? 'lainnya';
    final description = data['description'] ?? '-';
    final amount = (data['amount'] ?? 0).toDouble();
    final dt = DateTime.parse(data['dateTime']);
    final dateStr =
        '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    final meta = _getCategoryMeta(category);
    final color = meta['color'] as Color;

    // ✅ Swipe kiri untuk hapus
    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, description),
      onDismissed: (_) async {
        await _firestore.collection('expenses').doc(doc.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pengeluaran "$description" dihapus',
                  style: GoogleFonts.poppins()),
              backgroundColor: Colors.red[400],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      },
      // ✅ Background merah saat digeser
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_forever, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text('Hapus',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(meta['icon'] as IconData, color: color, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(meta['label'],
                              style: GoogleFonts.poppins(
                                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(description,
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600, color: kDark),
                        overflow: TextOverflow.ellipsis),
                    Text(dateStr,
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
                    // ✅ Hint swipe
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.swipe_left, size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Text('Geser kiri untuk hapus',
                            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400])),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '- Rp ${_formatCurrency(amount)}',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Belum ada pengeluaran',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500])),
          Text('pada periode ini',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }
}