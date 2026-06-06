import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import '../models/stream_model.dart';
import '../widgets/stream_card.dart';
import '../widgets/tv_card.dart';
import 'admin_login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late FirebaseService _firebaseService;
  String _selectedCategoryId = 'live_tv'; 
  String _searchQuery = "";
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _categories = [
    {'id': 'live_tv', 'name': 'Live TV', 'icon': 'live_tv'},
    {'id': 'live_sports', 'name': 'Live Sports', 'icon': 'sports'},
  ];

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search match or channel...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              )
            : Center(
                child: GestureDetector(
                  onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminLoginScreen())),
                  child: Text(
                    'Sportzfy',
                    style: GoogleFonts.bangers(
                      textStyle: const TextStyle(color: Colors.cyanAccent, fontSize: 32, letterSpacing: 2),
                    ),
                  ),
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = "";
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMarquee(),
          _buildCategoryTabs(),
          Expanded(
            child: StreamBuilder<List<StreamModel>>(
              stream: _firebaseService.getStreams(categoryId: _selectedCategoryId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                }
                
                final list = snapshot.data ?? [];
                final filteredList = list.where((s) => s.title.toLowerCase().contains(_searchQuery)).toList();

                if (filteredList.isEmpty) {
                  return const Center(child: Text("No items found in this category", style: TextStyle(color: Colors.white54)));
                }

                if (_selectedCategoryId == 'live_tv') {
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.8,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) => TvCard(stream: filteredList[index]),
                  );
                }

                return ListView.builder(
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) => StreamCard(stream: filteredList[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarquee() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        "Welcome to Sportzfy! Enjoy Live TV and Sports streaming.",
        style: TextStyle(color: Colors.white70, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _categories.map((cat) {
        final isSelected = _selectedCategoryId == cat['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedCategoryId = cat['id']!),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.cyanAccent.withOpacity(0.1) : Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(cat['icon'] == 'live_tv' ? Icons.tv : Icons.sports_soccer, 
                     color: isSelected ? Colors.cyanAccent : Colors.white60, size: 20),
                const SizedBox(width: 8),
                Text(cat['name']!, style: TextStyle(color: isSelected ? Colors.cyanAccent : Colors.white60, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
