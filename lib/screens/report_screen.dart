import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportScreen extends StatefulWidget {
  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedPeriod = 'Harian';
  DateTime _selectedDate = DateTime.now();

  static const Color kPrimary = Color(0xFF0F6E56);
  static const Color kAccent = Color(0xFF1D9E75);
  static const Color kBg = Color(0xFFE1F5EE);
  static const Color kDark = Color(0xFF085041);

  // ✅ Helper lokal — tidak perlu import currency_formatter.dart
  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildPeriodSelector()),
            SliverToBoxAdapter(child: _buildSummary()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Detail Order',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: kDark,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: Divider(thickness: 1, color: Colors.grey[200])),
            _buildOrdersSliver(),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.date_range, color: kPrimary),
              const SizedBox(width: 8),
              Text(
                'Periode Laporan:',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kPrimary,
                ),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: _selectedPeriod,
                items: ['Harian', 'Bulanan', 'Tahunan'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: GoogleFonts.poppins()),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedPeriod = v!),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF9FE1CB)),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 20, color: kPrimary),
                  const SizedBox(width: 8),
                  Text(
                    _getDateText(),
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _calculateFinancials(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: kPrimary)),
          );
        }
        if (!snapshot.hasData) return const SizedBox();

        final data = snapshot.data!;
        final totalKg = data['totalKg'] as double;
        final omset = data['omset'] as double;
        final unpaidTotal = data['unpaidTotal'] as double;
        final totalOrders = data['totalOrders'] as int;
        final totalExpenses = data['totalExpenses'] as double;
        final grossRevenue = omset + unpaidTotal;
        final netProfit = grossRevenue - totalExpenses;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row: Total Order & Total Terjual
              Row(
                children: [
                  Expanded(
                    child: _summaryCard('Total Order', '$totalOrders',
                        Icons.receipt_long, Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      'Total Terjual',
                      '${totalKg % 1 == 0 ? totalKg.toInt() : totalKg.toStringAsFixed(1)} kg',
                      Icons.scale,
                      kAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row: Omset & Pengeluaran
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      'Total Omset',
                      'Rp ${_formatCurrency(grossRevenue)}',
                      Icons.account_balance_wallet,
                      kPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      'Total Pengeluaran',
                      'Rp ${_formatCurrency(totalExpenses)}',
                      Icons.money_off,
                      Colors.red[600]!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Laba Bersih — full width highlight card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: netProfit >= 0 ? kPrimary : Colors.red[700],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(
                      netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Laba Bersih',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${netProfit < 0 ? '-' : ''}Rp ${_formatCurrency(netProfit.abs())}',
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Omset Rp ${_formatCurrency(grossRevenue)} - Pengeluaran Rp ${_formatCurrency(totalExpenses)}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.white60),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildOrdersSliver() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getOrdersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: kPrimary),
              ),
            ),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Belum ada order pada periode ini',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildOrderCard(docs[index]),
            childCount: docs.length,
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final dt = DateTime.parse(data['dateTime']);
    final kg = (data['kg'] ?? 0).toDouble();
    final pricePerKg = (data['pricePerKg'] ?? 0).toDouble();
    final total = (data['total'] ?? 0).toDouble();
    final isPaid = data['isPaid'] as bool? ?? false;
    final buyerName = data['buyerName'] ?? '-';

    final dateStr =
        '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(buyerName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dateStr,
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text('Rp ${_formatCurrency(total)}',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: kPrimary, fontSize: 14)),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPaid ? kAccent : Colors.orange[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPaid ? '✓ Lunas' : 'Belum',
              style: GoogleFonts.poppins(
                color: isPaid ? Colors.white : Colors.orange[800],
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Jumlah',
                      '${kg % 1 == 0 ? kg.toInt() : kg.toStringAsFixed(1)} kg'),
                  _detailRow('Harga/kg', 'Rp ${_formatCurrency(pricePerKg)}'),
                  const Divider(height: 16),
                  _detailRow('Total', 'Rp ${_formatCurrency(total)}',
                      isBold: true, valueColor: kPrimary),
                  _detailRow('Status', isPaid ? '✅ Lunas' : '⏳ Belum Lunas',
                      valueColor: isPaid ? Colors.green[700] : Colors.orange[700]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
          Text(value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: valueColor,
              )),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getOrdersStream() {
    final range = _getDateRange();
    return _firestore
        .collection('orders')
        .where('dateTime', isGreaterThanOrEqualTo: range['start']!.toIso8601String())
        .where('dateTime', isLessThan: range['end']!.toIso8601String())
        .orderBy('dateTime', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>> _calculateFinancials() async {
    final range = _getDateRange();

    // Fetch orders
    final ordersSnap = await _firestore
        .collection('orders')
        .where('dateTime', isGreaterThanOrEqualTo: range['start']!.toIso8601String())
        .where('dateTime', isLessThan: range['end']!.toIso8601String())
        .get();

    int totalOrders = ordersSnap.docs.length;
    double totalKg = 0;
    double omset = 0;
    double unpaidTotal = 0;

    for (var doc in ordersSnap.docs) {
      final data = doc.data();
      final kg = (data['kg'] ?? 0).toDouble();
      final total = (data['total'] ?? 0).toDouble();
      final isPaid = data['isPaid'] as bool? ?? false;
      totalKg += kg;
      if (isPaid) {
        omset += total;
      } else {
        unpaidTotal += total;
      }
    }

    // Fetch expenses
    final expensesSnap = await _firestore
        .collection('expenses')
        .where('dateTime', isGreaterThanOrEqualTo: range['start']!.toIso8601String())
        .where('dateTime', isLessThan: range['end']!.toIso8601String())
        .get();

    double totalExpenses = expensesSnap.docs.fold(0.0, (sum, doc) {
      return sum + ((doc.data()['amount'] ?? 0) as num).toDouble();
    });

    return {
      'totalOrders': totalOrders,
      'totalKg': totalKg,
      'omset': omset,
      'unpaidTotal': unpaidTotal,
      'totalExpenses': totalExpenses,
    };
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
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
          'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
        ];
        return '${months[_selectedDate.month - 1]} ${_selectedDate.year}';
      case 'Tahunan':
        return '${_selectedDate.year}';
      default:
        return '';
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    if (_selectedPeriod == 'Harian') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        builder: (context, child) => Theme(
          data: Theme.of(context)
              .copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)),
          child: child!,
        ),
      );
      if (picked != null) setState(() => _selectedDate = picked);
    } else if (_selectedPeriod == 'Bulanan') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        selectableDayPredicate: (date) => date.day == 1,
        builder: (context, child) => Theme(
          data: Theme.of(context)
              .copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)),
          child: child!,
        ),
      );
      if (picked != null) {
        setState(() => _selectedDate = DateTime(picked.year, picked.month, 1));
      }
    } else if (_selectedPeriod == 'Tahunan') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        selectableDayPredicate: (date) => date.day == 1 && date.month == 1,
        builder: (context, child) => Theme(
          data: Theme.of(context)
              .copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)),
          child: child!,
        ),
      );
      if (picked != null) {
        setState(() => _selectedDate = DateTime(picked.year, 1, 1));
      }
    }
  }
}