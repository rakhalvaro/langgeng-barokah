import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';

class StockScreen extends StatefulWidget {
  @override
  _StockScreenState createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color kPrimary = Color(0xFF0F6E56);
  static const Color kAccent = Color(0xFF1D9E75);
  static const Color kBg = Color(0xFFE1F5EE);
  static const Color kDark = Color(0xFF085041);

  String _todayId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatKg(double kg) {
    if (kg == kg.truncateToDouble()) return '${kg.toInt()} kg';
    return '${kg.toStringAsFixed(1)} kg';
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<double> _getSoldKgForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _firestore
        .collection('orders')
        .where('dateTime', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('dateTime', isLessThan: end.toIso8601String())
        .get();
    double total = 0.0;
    for (final doc in snap.docs) {
      total += ((doc.data()['kg'] ?? 0) as num).toDouble();
    }
    return total;
  }

  Future<double> _getYesterdayLeftover() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final yId =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final stockDoc =
        await _firestore.collection('daily_stocks').doc(yId).get();
    if (!stockDoc.exists) return 0;

    final stock = DailyStock.fromMap(stockDoc.id, stockDoc.data()!);
    final soldKg = await _getSoldKgForDate(yesterday);
    final leftover = stock.totalAvailable - soldKg;
    return leftover < 0 ? 0 : leftover;
  }

  void _showInputDialog(
    BuildContext context, {
    required String session,
    DailyStock? existing,
  }) async {
    final isMorning = session == 'morning';

    final kgCtrl = TextEditingController(
      text: () {
        if (existing == null) return '';
        final val = isMorning ? existing.morningKg : existing.afternoonKg;
        return val > 0 ? val.toStringAsFixed(1) : '';
      }(),
    );

    double leftover = existing?.previousLeftover ?? 0;
    if (existing == null) {
      leftover = await _getYesterdayLeftover();
    }

    final sessionLabel =
        isMorning ? 'Pagi (± jam 10.00)' : 'Sore (± jam 16.00)';
    final sessionIcon =
        isMorning ? Icons.wb_sunny_outlined : Icons.wb_twilight;
    final isEdit = existing != null &&
        (isMorning ? existing.morningKg > 0 : existing.afternoonKg > 0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isEdit ? Icons.edit : Icons.add_circle,
                color: kPrimary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${isEdit ? 'Edit' : 'Input'} Panen $sessionLabel',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: kDark),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF9FE1CB)),
              ),
              child: Row(
                children: [
                  Icon(Icons.history, color: kAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Sisa kemarin: ${_formatKg(leftover)}',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: kDark,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Jumlah Panen $sessionLabel',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: kgCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0.0',
                suffixText: 'kg',
                prefixIcon: Icon(sessionIcon, color: kAccent),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kPrimary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final kg =
                  double.tryParse(kgCtrl.text.replaceAll(',', '.')) ?? 0;
              final docId = existing?.id ?? _todayId();
              final existingMorning = existing?.morningKg ?? 0;
              final existingAfternoon = existing?.afternoonKg ?? 0;

              await _firestore
                  .collection('daily_stocks')
                  .doc(docId)
                  .set({
                'date': existing?.date.toIso8601String() ??
                    DateTime.now().toIso8601String(),
                'morningKg': isMorning ? kg : existingMorning,
                'afternoonKg': isMorning ? existingAfternoon : kg,
                'previousLeftover': leftover,
              }, SetOptions(merge: true));

              if (mounted) Navigator.pop(ctx);
            },
            child: Text(isEdit ? 'Update' : 'Simpan',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('daily_stocks')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: kPrimary));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data!.docs;
          final stocks = docs
              .map((d) => DailyStock.fromMap(
                  d.id, d.data() as Map<String, dynamic>))
              .toList();

          final todayId = _todayId();
          final todayStock =
              stocks.where((s) => s.id == todayId).firstOrNull;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildTodayCard(todayStock)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Text(
                    'Riwayat Stok',
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: kDark),
                  ),
                ),
              ),
              stocks.isEmpty
                  ? SliverToBoxAdapter(child: _emptyState())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _buildHistoryCard(stocks[i]),
                        childCount: stocks.length,
                      ),
                    ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTodayCard(DailyStock? stock) {
    final now = DateTime.now();
    final hasMorning = (stock?.morningKg ?? 0) > 0;
    final hasAfternoon = (stock?.afternoonKg ?? 0) > 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kPrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Hari Ini',
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 13)),
              Text(_dateLabel(now),
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSessionButton(
                  icon: Icons.wb_sunny_outlined,
                  label: hasMorning ? 'Edit Pagi' : 'Input Pagi',
                  isEdit: hasMorning,
                  onTap: () => _showInputDialog(context,
                      session: 'morning', existing: stock),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSessionButton(
                  icon: Icons.wb_twilight,
                  label: hasAfternoon ? 'Edit Sore' : 'Input Sore',
                  isEdit: hasAfternoon,
                  onTap: () => _showInputDialog(context,
                      session: 'afternoon', existing: stock),
                ),
              ),
            ],
          ),
          if (stock != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _buildMiniStat(Icons.wb_sunny_outlined, 'Pagi',
                        _formatKg(stock.morningKg))),
                const SizedBox(width: 10),
                Expanded(
                    child: _buildMiniStat(Icons.wb_twilight, 'Sore',
                        _formatKg(stock.afternoonKg))),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<double>(
              future: _getSoldKgForDate(now),
              builder: (context, snap) {
                final soldKg = snap.data ?? 0;
                final totalAvailable = stock.totalAvailable;
                final remaining =
                    (totalAvailable - soldKg).clamp(0.0, double.infinity);

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sisa Kemarin',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70, fontSize: 11)),
                                Text(_formatKg(stock.previousLeftover),
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const Icon(Icons.add,
                              color: Colors.white54, size: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Masuk Hari Ini',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70, fontSize: 11)),
                                Text(_formatKg(stock.totalIn),
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                            color: Colors.white.withOpacity(0.3),
                            height: 1),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Tersedia',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70, fontSize: 11)),
                                Text(_formatKg(totalAvailable.toDouble()),
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const Icon(Icons.remove,
                              color: Colors.white54, size: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Terjual',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70, fontSize: 11)),
                                Text(_formatKg(soldKg),
                                    style: GoogleFonts.poppins(
                                        color: soldKg > 0
                                            ? Colors.orangeAccent
                                            : Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                            color: Colors.white.withOpacity(0.3),
                            height: 1),
                      ),
                      Column(
                        children: [
                          Text('Sisa Stok',
                              style: GoogleFonts.poppins(
                                  color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(
                            _formatKg(remaining),
                            style: GoogleFonts.poppins(
                              color: remaining <= 0
                                  ? Colors.redAccent[100]
                                  : Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (remaining <= 0)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('Stok Habis',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            const SizedBox(height: 10),
            Center(
              child: Column(
                children: [
                  Icon(Icons.egg_outlined,
                      color: Colors.white.withOpacity(0.35), size: 40),
                  const SizedBox(height: 6),
                  Text('Belum ada data stok hari ini',
                      style: GoogleFonts.poppins(
                          color: Colors.white60, fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionButton({
    required IconData icon,
    required String label,
    required bool isEdit,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isEdit
              ? Colors.white.withOpacity(0.25)
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: isEdit
              ? Border.all(
                  color: Colors.white.withOpacity(0.5), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isEdit ? Icons.edit : icon,
                color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 11)),
              Text(value,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── History Card: 3 chip ───────────────────────────────────────────────────

  Widget _buildHistoryCard(DailyStock stock) {
    return FutureBuilder<double>(
      future: _getSoldKgForDate(stock.date),
      builder: (context, snap) {
        final soldKg = snap.data ?? 0;
        final remaining =
            (stock.totalAvailable - soldKg).clamp(0.0, double.infinity);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          color: kBg,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_dateLabel(stock.date),
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: kDark)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Sisa: ${_formatKg(remaining)}',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Chip 1 — Sisa Kemarin
                    _historyChipSingle(
                      Icons.history,
                      'Sisa Kemarin',
                      _formatKg(stock.previousLeftover),
                    ),
                    const SizedBox(width: 7),
                    // Chip 2 — Panen Hari Ini (pagi | sore | total)
                    _historyChipPanen(
                      _formatKg(stock.morningKg),
                      _formatKg(stock.afternoonKg),
                      _formatKg(stock.totalIn),
                    ),
                    const SizedBox(width: 7),
                    // Chip 3 — Terjual
                    _historyChipSingle(
                      Icons.local_shipping_outlined,
                      'Terjual',
                      snap.connectionState == ConnectionState.done
                          ? _formatKg(soldKg)
                          : '...',
                      valueColor: soldKg > 0 ? Colors.orange[700] : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Chip tunggal — Sisa Kemarin & Terjual
  Widget _historyChipSingle(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF9FE1CB)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: kAccent),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? kDark),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Chip panen — Pagi + Sore berdampingan + total, flex:2 agar lebar
  Widget _historyChipPanen(String pagi, String sore, String total) {
    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF9FE1CB)),
        ),
        child: Column(
          children: [
            Icon(Icons.egg_outlined, size: 20, color: kAccent),
            const SizedBox(height: 6),
            // Pagi + Sore berdampingan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text('Pagi',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey[500])),
                    Text(pagi,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: kDark)),
                  ],
                ),
                Text('+',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w600)),
                Column(
                  children: [
                    Text('Sore',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey[500])),
                    Text(sore,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: kDark)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Divider(height: 1, color: const Color(0xFF9FE1CB)),
            const SizedBox(height: 6),
            // Total panen hari ini
            Text('Total Panen',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 2),
            Text(total,
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: kPrimary)),
          ],
        ),
      ),
    );
  }

  // ─── Empty state ────────────────────────────────────────────────────────────

  Widget _emptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.egg_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Belum ada data stok',
              style:
                  GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
          Text('Tap Input Pagi atau Input Sore untuk mulai!',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }
}