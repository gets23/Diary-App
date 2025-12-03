import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import 'dashboard/dashboard_view.dart';
import 'books/collection_view.dart';
import 'books/add_book_view.dart';
import 'profile/profile_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;
  
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardView(
        onNavigateToSearch: () => setState(() => _selectedIndex = 1),
        onNavigateToCollection: () => setState(() => _selectedIndex = 2),
      ),
      const AddBookView(),
      const CollectionView(),
      const ProfileView(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 27),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: textPrimary,
              unselectedItemColor: textSecondary.withOpacity(0.6),
              showSelectedLabels: false,
              showUnselectedLabels: false,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: ''),
                BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: ''),
                BottomNavigationBarItem(icon: Icon(Icons.library_books_rounded), label: ''),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: ''),
              ],
            ),
          ),
        ),
      ),
    );
  }
}