import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'stock_screen.dart';
import 'order_screen.dart';
import 'expense_screen.dart';
import 'report_screen.dart';
import '../utils/update_checker.dart';

class MainScreen extends StatefulWidget {
  final String role; // 'owner' atau 'investor'
  const MainScreen({super.key, required this.role});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  bool get _isInvestor => widget.role == 'investor';

  List<Widget> get _screens => [
        StockScreen(isReadOnly: _isInvestor),
        OrderScreen(isReadOnly: _isInvestor),
        ExpenseScreen(isReadOnly: _isInvestor),
        ReportScreen(),
      ];

  @override
  void initState() {
    super.initState();
    // Update checker hanya untuk owner
    if (!_isInvestor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            UpdateChecker.checkForUpdate(context);
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F6E56),
        toolbarHeight: 70,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.4,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
            Text(
              'Langgeng Barokah',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),

      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF0F6E56),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.egg_outlined),
            label: 'Stok Telor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Pesanan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Pengeluaran',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            label: 'Laporan',
          ),
        ],
      ),
    );
  }
}