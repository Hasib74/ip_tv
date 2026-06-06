import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late FirebaseService _firebaseService;
  String _selectedCategoryId = 'live_tv';
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _tabAnimController;

  final List<Map<String, dynamic>> _categories = [
    {'id': 'live_tv', 'name': 'Live TV', 'icon': Icons.tv_rounded},
    {'id': 'live_sports', 'name': 'Sports', 'icon': Icons.sports_soccer_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _tabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _tabAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _switchCategory(String id) {
    if (_selectedCategoryId == id) return;
    setState(() => _selectedCategoryId = id);
    _tabAnimController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: cs.background,
        body: Stack(
          children: [
            _buildBackgroundDecor(cs, isDark),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(cs, isDark),
                  if (_isSearching) _buildSearchBar(cs, isDark),
                  _buildAnnouncementBanner(cs),
                  _buildCategoryTabs(cs, isDark),
                  const SizedBox(height: 8),
                  Expanded(child: _buildStreamList(cs, isDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Background subtle decor using theme colors ──────────────────────────
  Widget _buildBackgroundDecor(ColorScheme cs, bool isDark) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -80,
            child: _glowCircle(cs.primary, 280, isDark ? 0.08 : 0.05),
          ),
          Positioned(
            bottom: 80,
            right: -70,
            child: _glowCircle(cs.secondary, 240, isDark ? 0.07 : 0.04),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(Color color, double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────
  Widget _buildTopBar(ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onLongPress: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
            ),
            child: Hero(
              tag: 'logo',
              child: Image.asset(
                'assets/images/icon.png',
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const Spacer(),
          _TopBarButton(
            icon: _isSearching ? Icons.close_rounded : Icons.search_rounded,
            cs: cs,
            onTap: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchQuery = '';
                _searchController.clear();
              }
            }),
          ),
        ],
      ),
    );
  }

  // ── Search Bar ───────────────────────────────────────────────────────────
  Widget _buildSearchBar(ColorScheme cs, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      height: 48,
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(
          color: cs.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search channels or matches...',
          hintStyle: TextStyle(
            color: cs.onSurface.withOpacity(0.4),
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: cs.primary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
      ),
    );
  }

  // ── Announcement Banner ──────────────────────────────────────────────────
  Widget _buildAnnouncementBanner(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.campaign_rounded, color: cs.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Welcome to SponT TV! Watch HD Live Sports & TV Channels for free.',
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Category Tabs — properly tall ───────────────────────────────────────
  Widget _buildCategoryTabs(ColorScheme cs, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(5),
      height: 60, // ← taller tab row
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategoryId == cat['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () => _switchCategory(cat['id'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary, cs.secondary],
                  )
                      : null,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                      : [],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 19,
                        color: isSelected
                            ? cs.onPrimary
                            : cs.onSurface.withOpacity(0.45),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat['name'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: isSelected
                              ? cs.onPrimary
                              : cs.onSurface.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Stream List ──────────────────────────────────────────────────────────
  Widget _buildStreamList(ColorScheme cs, bool isDark) {
    return StreamBuilder<List<StreamModel>>(
      stream: _firebaseService.getStreams(categoryId: _selectedCategoryId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildState(
            icon: Icons.error_outline_rounded,
            label: 'Something went wrong',
            cs: cs,
            iconColor: cs.error,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Loading streams...',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final list = snapshot.data ?? [];
        final filtered = list
            .where((s) => s.title.toLowerCase().contains(_searchQuery))
            .toList();

        if (filtered.isEmpty) {
          return _buildState(
            icon: Icons.tv_off_rounded,
            label: _searchQuery.isEmpty ? 'No streams available' : 'No results found',
            cs: cs,
          );
        }

        final key = ValueKey('$_selectedCategoryId|$_searchQuery');

        if (_selectedCategoryId == 'live_tv') {
          return AnimationLimiter(
            key: key,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.72, // slightly taller card
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) => AnimationConfiguration.staggeredGrid(
                position: i,
                duration: const Duration(milliseconds: 350),
                columnCount: 3,
                child: ScaleAnimation(
                  scale: 0.88,
                  child: FadeInAnimation(child: TvCard(stream: filtered[i])),
                ),
              ),
            ),
          );
        }

        return AnimationLimiter(
          key: key,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => AnimationConfiguration.staggeredList(
              position: i,
              duration: const Duration(milliseconds: 350),
              child: SlideAnimation(
                verticalOffset: 40,
                child:
                FadeInAnimation(child: StreamCard(stream: filtered[i])),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildState({
    required IconData icon,
    required String label,
    required ColorScheme cs,
    Color? iconColor,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: iconColor ?? cs.onSurface.withOpacity(0.12)),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.35),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widget ────────────────────────────────────────────────────────────
class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _TopBarButton({
    required this.icon,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withOpacity(0.15)),
        ),
        child: Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.8)),
      ),
    );
  }
}