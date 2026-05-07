import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';

class OrderScreen extends StatefulWidget {
  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color kPrimary = Color(0xFF0F6E56);
  static const Color kAccent = Color(0xFF1D9E75);
  static const Color kBg = Color(0xFFE1F5EE);
  static const Color kDark = Color(0xFF085041);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ Helper lokal — tidak perlu import currency_formatter.dart
  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _todayId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatKg(double kg) {
    if (kg == kg.truncateToDouble()) return '${kg.toInt()} kg';
    return '${kg.toStringAsFixed(1)} kg';
  }

  Future<double> _getRemainingStock() async {
    final doc = await _firestore
        .collection('daily_stocks')
        .doc(_todayId())
        .get();

    if (!doc.exists) return 0;

    final data = doc.data()!;
    final morningKg = (data['morningKg'] ?? 0) as num;
    final afternoonKg = (data['afternoonKg'] ?? 0) as num;
    final previousLeftover = (data['previousLeftover'] ?? 0) as num;
    final soldKg = (data['soldKg'] ?? 0) as num;

    final totalAvailable = morningKg + afternoonKg + previousLeftover;
    final remaining = totalAvailable - soldKg;
    return remaining < 0 ? 0 : remaining.toDouble();
  }

  // ✅ Konfirmasi hapus order
  Future<bool?> _confirmDeleteOrder(BuildContext context, EggOrder order) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Hapus Order',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: kDark)),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
            children: [
              const TextSpan(text: 'Hapus order '),
              TextSpan(
                text: order.buyerName,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: Colors.black),
              ),
              TextSpan(text: ' (${_formatKg(order.kg)} — Rp ${_formatCurrency(order.total)})?'),
              const TextSpan(text: '\n\nData tidak bisa dikembalikan.'),
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

  void _showAddOrderDialog(BuildContext context, double remainingStock) {
    final buyerCtrl = TextEditingController();
    final kgCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          double kg = double.tryParse(kgCtrl.text.replaceAll(',', '.')) ?? 0;
          double price = double.tryParse(priceCtrl.text) ?? 0;
          double total = kg * price;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.add_shopping_cart, color: kPrimary, size: 22),
                const SizedBox(width: 8),
                Text('Order Baru',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.bold, color: kDark)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: remainingStock > 0 ? kBg : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: remainingStock > 0
                            ? const Color(0xFF9FE1CB)
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            color: remainingStock > 0 ? kAccent : Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Stok tersedia: ${_formatKg(remainingStock)}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: remainingStock > 0 ? kDark : Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: buyerCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nama Pembeli',
                      prefixIcon: const Icon(Icons.person_outline, color: kAccent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kPrimary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: kgCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Jumlah (kg)',
                      suffixText: 'kg',
                      prefixIcon: const Icon(Icons.scale_outlined, color: kAccent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kPrimary, width: 2),
                      ),
                      errorText: errorMsg,
                    ),
                    onChanged: (_) => setDialog(() => errorMsg = null),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Harga per kg',
                      prefixText: 'Rp ',
                      prefixIcon: const Icon(Icons.attach_money, color: kAccent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kPrimary, width: 2),
                      ),
                    ),
                    onChanged: (_) => setDialog(() {}),
                  ),
                  if (kg > 0 && price > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF9FE1CB)),
                      ),
                      child: Column(
                        children: [
                          Text('Total Pembayaran',
                              style: GoogleFonts.poppins(
                                  color: Colors.grey[600], fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            'Rp ${_formatCurrency(total)}',
                            style: GoogleFonts.poppins(
                                color: kDark,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_formatKg(kg)} × Rp ${_formatCurrency(price)}/kg',
                            style: GoogleFonts.poppins(
                                color: Colors.grey[500], fontSize: 11),
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
                onPressed: remainingStock <= 0
                    ? null
                    : () async {
                        if (buyerCtrl.text.trim().isEmpty ||
                            kgCtrl.text.isEmpty ||
                            priceCtrl.text.isEmpty) return;

                        final kgVal = double.tryParse(
                                kgCtrl.text.replaceAll(',', '.')) ??
                            0;
                        final priceVal =
                            double.tryParse(priceCtrl.text) ?? 0;
                        if (kgVal <= 0 || priceVal <= 0) return;

                        if (kgVal > remainingStock) {
                          setDialog(() {
                            errorMsg =
                                'Melebihi stok! Sisa ${_formatKg(remainingStock)}';
                          });
                          return;
                        }

                        try {
                          final stockRef = _firestore
                              .collection('daily_stocks')
                              .doc(_todayId());

                          await _firestore
                              .runTransaction((transaction) async {
                            final stockSnap =
                                await transaction.get(stockRef);

                            double currentSold = 0;
                            double totalAvailable = 0;

                            if (stockSnap.exists) {
                              final d = stockSnap.data()!;
                              final morning =
                                  (d['morningKg'] ?? 0) as num;
                              final afternoon =
                                  (d['afternoonKg'] ?? 0) as num;
                              final leftover =
                                  (d['previousLeftover'] ?? 0) as num;
                              currentSold = ((d['soldKg'] ?? 0) as num)
                                  .toDouble();
                              totalAvailable =
                                  (morning + afternoon + leftover)
                                      .toDouble();
                            }

                            final currentRemaining =
                                totalAvailable - currentSold;

                            if (kgVal > currentRemaining) {
                              throw Exception('Stok tidak mencukupi');
                            }

                            final orderRef =
                                _firestore.collection('orders').doc();
                            transaction.set(orderRef, {
                              'buyerName': buyerCtrl.text.trim(),
                              'kg': kgVal,
                              'pricePerKg': priceVal,
                              'total': kgVal * priceVal,
                              'isPaid': false,
                              'dateTime':
                                  DateTime.now().toIso8601String(),
                            });

                            if (stockSnap.exists) {
                              transaction.update(stockRef, {
                                'soldKg': currentSold + kgVal,
                              });
                            }
                          });

                          if (mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setDialog(() {
                            errorMsg = 'Stok tidak mencukupi, coba lagi';
                          });
                        }
                      },
                child: Text('Buat Order',
                    style:
                        GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmLunas(BuildContext context, EggOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: kAccent, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Konfirmasi Lunas',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: kDark)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tandai order ini sebagai lunas?',
                style: GoogleFonts.poppins(fontSize: 14)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.buyerName,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, color: kDark)),
                  Text(
                      '${_formatKg(order.kg)} × Rp ${_formatCurrency(order.pricePerKg)}/kg',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey[600])),
                  Text('Total: Rp ${_formatCurrency(order.total)}',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: kPrimary,
                          fontSize: 15)),
                ],
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
              backgroundColor: kAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              await _firestore
                  .collection('orders')
                  .doc(order.id)
                  .update({'isPaid': true});
              if (mounted) Navigator.pop(ctx);
            },
            child: Text('Ya, Lunas',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _ordersStream(bool isPaid) {
    if (!isPaid) {
      return _firestore
          .collection('orders')
          .where('isPaid', isEqualTo: false)
          .orderBy('dateTime', descending: true)
          .snapshots();
    }
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _firestore
        .collection('orders')
        .where('isPaid', isEqualTo: true)
        .where('dateTime',
            isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('dateTime', isLessThan: endOfDay.toIso8601String())
        .orderBy('dateTime', descending: true)
        .snapshots();
  }

  Widget _buildOrderCard(EggOrder order) {
    final dt = order.dateTime;
    final dateStr =
        '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    // ✅ Swipe kiri untuk hapus
    return Dismissible(
      key: Key(order.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteOrder(context, order),
      onDismissed: (_) async {
        await _firestore.collection('orders').doc(order.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order ${order.buyerName} dihapus',
                  style: GoogleFonts.poppins()),
              backgroundColor: Colors.red[400],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      },
      // ✅ Background merah saat digeser
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_forever, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text('Hapus',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration:
                        BoxDecoration(color: kBg, shape: BoxShape.circle),
                    child: const Center(
                        child:
                            Text('🥚', style: TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.buyerName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: kDark),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                        // ✅ Hint swipe
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.swipe_left,
                                size: 11, color: Colors.grey[400]),
                            const SizedBox(width: 3),
                            Text('Geser kiri untuk hapus',
                                style: GoogleFonts.poppins(
                                    fontSize: 10, color: Colors.grey[400])),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          order.isPaid ? kAccent : Colors.orange[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.isPaid ? '✓ Lunas' : 'Belum Lunas',
                      style: GoogleFonts.poppins(
                        color: order.isPaid
                            ? Colors.white
                            : Colors.orange[800],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Expanded(
                        child: _orderDetail('Jumlah',
                            _formatKg(order.kg), Icons.scale_outlined)),
                    Container(
                        width: 1,
                        height: 36,
                        color: const Color(0xFF9FE1CB)),
                    Expanded(
                        child: _orderDetail(
                            'Harga/kg',
                            'Rp ${_formatCurrency(order.pricePerKg)}',
                            Icons.sell_outlined)),
                    Container(
                        width: 1,
                        height: 36,
                        color: const Color(0xFF9FE1CB)),
                    Expanded(
                        child: _orderDetail(
                            'Total',
                            'Rp ${_formatCurrency(order.total)}',
                            Icons.payments_outlined,
                            bold: true,
                            color: kPrimary)),
                  ],
                ),
              ),
              if (!order.isPaid) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmLunas(context, order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.check_circle_outline,
                        size: 18),
                    label: Text('Tandai Lunas',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderDetail(String label, String value, IconData icon,
      {bool bold = false, Color? color}) {
    return Column(
      children: [
        Icon(icon, size: 16, color: kAccent),
        const SizedBox(height: 4),
        Text(label,
            style:
                GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: color ?? kDark,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _emptyState(String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Icon(Icons.shopping_cart_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Tidak ada order $label',
              style:
                  GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500])),
          const SizedBox(height: 6),
          Text('hari ini',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: kBg,
            child: TabBar(
              controller: _tabController,
              labelColor: kPrimary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: kPrimary,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
              tabs: const [
                Tab(text: 'Belum Lunas'),
                Tab(text: 'Lunas'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _ordersStream(false),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(color: kPrimary));
                    }
                    final orders = snapshot.data!.docs
                        .map((d) => EggOrder.fromMap(
                            d.id, d.data() as Map<String, dynamic>))
                        .toList();
                    if (orders.isEmpty) return _emptyState('aktif');
                    return ListView.builder(
                      padding:
                          const EdgeInsets.only(top: 8, bottom: 80),
                      itemCount: orders.length,
                      itemBuilder: (_, i) => _buildOrderCard(orders[i]),
                    );
                  },
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: _ordersStream(true),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(color: kPrimary));
                    }
                    final orders = snapshot.data!.docs
                        .map((d) => EggOrder.fromMap(
                            d.id, d.data() as Map<String, dynamic>))
                        .toList();
                    if (orders.isEmpty) return _emptyState('lunas');
                    return ListView.builder(
                      padding:
                          const EdgeInsets.only(top: 8, bottom: 80),
                      itemCount: orders.length,
                      itemBuilder: (_, i) => _buildOrderCard(orders[i]),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<double>(
        future: _getRemainingStock(),
        builder: (context, snapshot) {
          final remaining = snapshot.data ?? 0;
          final hasStock = remaining > 0;

          return FloatingActionButton.extended(
            onPressed: hasStock
                ? () => _showAddOrderDialog(context, remaining)
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Stok habis! Silakan input stok terlebih dahulu.',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
            backgroundColor: hasStock ? kPrimary : Colors.grey,
            foregroundColor: Colors.white,
            icon: Icon(hasStock ? Icons.add : Icons.block),
            label: Text(
              hasStock ? 'Order Baru' : 'Stok Habis',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
    );
  }
}