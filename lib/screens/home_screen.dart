import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _isSearching
            ? _buildSearchField(colorScheme)
            : GestureDetector(
                onLongPress: () => Navigator.push(
                    context, MaterialPageRoute(builder: (c) => const AdminLoginScreen())),
                child: Hero(
                  tag: 'logo',
                  child: Image.asset(
                    'assets/images/icon.jpeg',
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
        actions: [
          _buildSearchAction(colorScheme),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.5,
            colors: [
              colorScheme.primary.withOpacity(0.05),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildMarquee(colorScheme),
              _buildCategoryTabs(colorScheme),
              const SizedBox(height: 10),
              Expanded(
                child: _buildStreamList(colorScheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(ColorScheme colorScheme) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search channels or matches...',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: colorScheme.primary, size: 20),
          hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
      ),
    );
  }

  Widget _buildSearchAction(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: _isSearching ? colorScheme.primary.withOpacity(0.1) : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(_isSearching ? Icons.close : Icons.search,
            color: _isSearching ? colorScheme.primary : colorScheme.onSurface),
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
    );
  }

  Widget _buildStreamList(ColorScheme colorScheme) {
    return StreamBuilder<List<StreamModel>>(
      stream: _firebaseService.getStreams(categoryId: _selectedCategoryId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text("Something went wrong", style: TextStyle(color: colorScheme.error)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: colorScheme.primary, strokeWidth: 2),
                const SizedBox(height: 16),
                Text("Loading streams...",
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          );
        }

        final list = snapshot.data ?? [];
        final filteredList =
            list.where((s) => s.title.toLowerCase().contains(_searchQuery)).toList();

        if (filteredList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tv_off, size: 48, color: colorScheme.onSurface.withOpacity(0.1)),
                const SizedBox(height: 16),
                Text("No items found",
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 14)),
              ],
            ),
          );
        }

        if (_selectedCategoryId == 'live_tv') {
          return AnimationLimiter(
            key: ValueKey(_selectedCategoryId + _searchQuery), // Reset animation when cat or search changes
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.75,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                return AnimationConfiguration.staggeredGrid(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  columnCount: 3,
                  child: ScaleAnimation(
                    child: FadeInAnimation(
                      child: TvCard(stream: filteredList[index]),
                    ),
                  ),
                );
              },
            ),
          );
        }

        return AnimationLimiter(
          key: ValueKey(_selectedCategoryId + _searchQuery),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: filteredList.length,
            itemBuilder: (context, index) {
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: StreamCard(stream: filteredList[index]),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMarquee(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign_rounded, color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Welcome to SponT TV! Watch HD Live Sports & TV Channels for free.",
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(ColorScheme colorScheme) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategoryId == cat['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategoryId = cat['id']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colorScheme.primary, colorScheme.secondary],
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.2), // Reduced opacity for "cleaner" look
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      cat['icon'] == 'live_tv' ? Icons.tv_rounded : Icons.sports_soccer_rounded,
                      color: isSelected ? Colors.black : colorScheme.onSurface.withOpacity(0.6),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cat['name']!,
                      style: TextStyle(
                        color: isSelected ? Colors.black : colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
