import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../services/firebase_service.dart';
import '../services/ad_service.dart';
import '../models/stream_model.dart';
import '../widgets/stream_card.dart';
import '../widgets/tv_card.dart';
import 'admin_login_screen.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AppFirebaseService _firebaseService;
  String? _selectedCategoryId;
  String _sportsSubCategory = 'live_match'; // 'live_match' or 'sports_tv'
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _tabAnimController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _firebaseService = AppFirebaseService();
    _tabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    // অ্যাপ হোম স্ক্রিনে আসার পর যদি অ্যাড লোড হয়ে থাকে তবে তা দেখাবে
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService.showAppOpenAdIfAvailable();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ১৫ মিনিট পর পর অ্যাড দেখানোর জন্য চেক করা হবে যখন অ্যাপ ফোরগ্রাউন্ডে আসবে
      AdService.showAppOpenAdIfAvailable();
    }
  }

  // Helper to map string to IconData
  IconData _getIconData(String name) {
    switch (name) {
      case 'tv': return Icons.tv_rounded;
      case 'sports': return Icons.sports_soccer_rounded;
      case 'movie': return Icons.movie_rounded;
      case 'music': return Icons.music_note_rounded;
      case 'news': return Icons.newspaper_rounded;
      default: return Icons.category_rounded;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _switchCategory(String id) {
    if (_selectedCategoryId == id) return;
    
    // Show Interstitial Ad every 4th category switch
    AdService.showInterstitialAd(context, () {
      setState(() => _selectedCategoryId = id);
      _tabAnimController.forward(from: 0);
    });
  }

  Future<bool> _onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit SponT TV?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('YES'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<CategoryModel>>(
      stream: _firebaseService.getCategories(includeHidden: false),
      builder: (context, catSnapshot) {
        final categories = catSnapshot.data ?? [];
        if (_selectedCategoryId == null && categories.isNotEmpty) {
          _selectedCategoryId = categories[0].id;
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                SystemNavigator.pop();
              }
            },
            child: Scaffold(
              backgroundColor: cs.surface,
              body: Stack(
                children: [
                  _buildBackgroundDecor(cs, isDark),
                  SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.maxWidth;
                        final isWide = maxWidth > 800;
                        
                        return Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: isWide ? 1000 : maxWidth),
                            child: Column(
                              children: [
                                _buildTopBar(cs, isDark),
                                if (_isSearching) _buildSearchBar(cs, isDark),
                                _buildAnnouncementBanner(cs),
                                if (categories.isNotEmpty)
                                  _buildCategoryTabs(cs, isDark, categories),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: categories.isEmpty
                                      ? _buildState(icon: Icons.tv_off_rounded, label: 'No categories available', cs: cs)
                                      : _buildStreamList(cs, isDark, categories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => categories[0]), maxWidth),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
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
                'assets/images/icon.jpeg',
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
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
        gradient: LinearGradient(
          colors: [
            cs.primary.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
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
                color: cs.onSurface.withOpacity(0.8),
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

  Widget _buildCategoryTabs(ColorScheme cs, bool isDark, List<CategoryModel> categories) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(5),
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: categories.map((cat) {
            final isSelected = _selectedCategoryId == cat.id;
            return GestureDetector(
              onTap: () => _switchCategory(cat.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: 4),
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
                      color: cs.primary.withOpacity(0.2), // Cleaner, softer shadow
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                      : [],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getIconData(cat.icon),
                        size: 18,
                        color: isSelected
                            ? Colors.black
                            : cs.onSurface.withOpacity(0.45),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          color: isSelected
                              ? Colors.black
                              : cs.onSurface.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Stream List with Ad Injection ──────────────────────────────────────────
  Widget _buildStreamList(ColorScheme cs, bool isDark, CategoryModel currentCategory, double maxWidth) {
    int crossAxisCount = 3;
    if (maxWidth > 1200) {
      crossAxisCount = 6;
    } else if (maxWidth > 800) {
      crossAxisCount = 4;
    }

    int movieCrossAxisCount = 2;
    if (maxWidth > 1200) {
      movieCrossAxisCount = 5;
    } else if (maxWidth > 800) {
      movieCrossAxisCount = 3;
    }

    return Column(
      children: [
        if (currentCategory.icon == "sports") _buildSportsSubTabs(cs),
        Expanded(
          child: StreamBuilder<List<StreamModel>>(
            stream: _firebaseService.getStreams(categoryId: _selectedCategoryId, includeHidden: false),
            builder: (context, snapshot) {
              // ... handle loading/error ...
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
              
              // Filter by subCategory if Sports
              List<StreamModel> filtered;
              if (currentCategory.icon == "sports") {
                filtered = list
                    .where((s) => s.subCategory == _sportsSubCategory)
                    .where((s) => s.title.toLowerCase().contains(_searchQuery))
                    .toList();
              } else {
                filtered = list
                    .where((s) => s.title.toLowerCase().contains(_searchQuery))
                    .toList();
              }

              if (filtered.isEmpty) {
                return _buildState(
                  icon: Icons.tv_off_rounded,
                  label: _searchQuery.isEmpty ? 'No streams available' : 'No results found',
                  cs: cs,
                );
              }

              final key = ValueKey('$_selectedCategoryId|$_sportsSubCategory|$_searchQuery|$maxWidth');

              // --- Sports SubCategory: Sports TV (Grid View) ---
              if (currentCategory.icon == "sports" && _sportsSubCategory == "sports_tv") {
                final List<Widget> slivers = [];
                for (var i = 0; i < filtered.length; i += (crossAxisCount * 2)) {
                  final chunk = filtered.skip(i).take(crossAxisCount * 2).toList();

                  slivers.add(
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.75,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => AnimationConfiguration.staggeredGrid(
                            position: i + index,
                            duration: const Duration(milliseconds: 375),
                            columnCount: crossAxisCount,
                            child: ScaleAnimation(
                              scale: 0.88,
                              child: FadeInAnimation(child: TvCard(stream: chunk[index])),
                            ),
                          ),
                          childCount: chunk.length,
                        ),
                      ),
                    ),
                  );

                  if ((i + chunk.length) % (crossAxisCount * 2) == 0 && (i + chunk.length) < filtered.length) {
                    slivers.add(
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            AdService.getBannerWidget(cs, key: ValueKey('ad_grid_sports_$i')),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  } else {
                    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
                  }
                }

                return AnimationLimiter(
                  key: key,
                  child: CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      ...slivers,
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                );
              }

              // --- Movie View (Premium Immersive Look) ---
              if (currentCategory.icon == "movie") {
                final featuredMovie = filtered.first;
                final remainingMovies = filtered.skip(1).toList();
                final List<Widget> slivers = [];

                slivers.add(
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: _buildFeaturedMovie(cs, featuredMovie),
                    ),
                  ),
                );

                for (var i = 0; i < remainingMovies.length; i += (movieCrossAxisCount * 3)) {
                  final chunk = remainingMovies.skip(i).take(movieCrossAxisCount * 3).toList();

                  slivers.add(
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: movieCrossAxisCount,
                          childAspectRatio: 0.7,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => AnimationConfiguration.staggeredGrid(
                            position: i + index,
                            duration: const Duration(milliseconds: 375),
                            columnCount: movieCrossAxisCount,
                            child: ScaleAnimation(
                              scale: 0.9,
                              child: FadeInAnimation(
                                child: MovieCard(stream: chunk[index]),
                              ),
                            ),
                          ),
                          childCount: chunk.length,
                        ),
                      ),
                    ),
                  );

                  if ((i + chunk.length) % (movieCrossAxisCount * 3) == 0) {
                    slivers.add(
                      SliverToBoxAdapter(
                        child: AdService.getBannerWidget(cs, key: ValueKey('ad_movie_$i')),
                      ),
                    );
                  }
                }

                return AnimationLimiter(
                  key: key,
                  child: CustomScrollView(
                    slivers: slivers,
                  ),
                );
              }

              // Check if category is Sports: Live Match (List View)
              if (currentCategory.icon == "sports") {
                final List<dynamic> itemsWithAds = [];
                for (var i = 0; i < filtered.length; i++) {
                  itemsWithAds.add(filtered[i]);
                  if ((i + 1) % 6 == 0) {
                    itemsWithAds.add('banner_ad_${i + 1}');
                  }
                }

                return AnimationLimiter(
                  key: key,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: itemsWithAds.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final item = itemsWithAds[i];
                      if (item is String && item.startsWith('banner_ad_')) {
                        return AdService.getBannerWidget(cs, key: ValueKey(item));
                      }
                      return AnimationConfiguration.staggeredList(
                        position: i,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 40,
                          child: FadeInAnimation(child: StreamCard(stream: item as StreamModel)),
                        ),
                      );
                    },
                  ),
                );
              }

              // Default: TV Grid View
              final List<Widget> slivers = [];
              for (var i = 0; i < filtered.length; i += (crossAxisCount * 2)) {
                final chunk = filtered.skip(i).take(crossAxisCount * 2).toList();

                slivers.add(
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.75,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => AnimationConfiguration.staggeredGrid(
                          position: i + index,
                          duration: const Duration(milliseconds: 375),
                          columnCount: crossAxisCount,
                          child: ScaleAnimation(
                            scale: 0.88,
                            child: FadeInAnimation(child: TvCard(stream: chunk[index])),
                          ),
                        ),
                        childCount: chunk.length,
                      ),
                    ),
                  ),
                );

                if ((i + chunk.length) % (crossAxisCount * 2) == 0 && (i + chunk.length) < filtered.length) {
                  slivers.add(
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          AdService.getBannerWidget(cs, key: ValueKey('ad_grid_$i')),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                } else {
                  slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
                }
              }

              return AnimationLimiter(
                key: key,
                child: CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ...slivers,
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSportsSubTabs(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _subTabItem("Live Match", "live_match", cs),
          _subTabItem("Sports TV", "sports_tv", cs),
        ],
      ),
    );
  }

  Widget _subTabItem(String title, String id, ColorScheme cs) {
    final isSelected = _sportsSubCategory == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _sportsSubCategory = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? cs.primary.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? cs.primary.withOpacity(0.3) : Colors.transparent,
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.5),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
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

  // ── Featured Movie Widget ──────────────────────────────────────────────────
  Widget _buildFeaturedMovie(ColorScheme cs, StreamModel movie) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(stream: movie)),
      ),
      child: Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: movie.logo.isNotEmpty ? movie.logo : movie.team1Logo,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: cs.surfaceContainerHighest),
                  errorWidget: (_, __, ___) => const Icon(Icons.movie_rounded, size: 50),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.9),
                      ],
                      stops: const [0.4, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'FEATURED',
                        style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      movie.title,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      movie.subtitle.isEmpty ? 'Action • Thriller • 2024' : movie.subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PlayerScreen(stream: movie)),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                          label: const Text('Watch Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary.withOpacity(0.15)),
        ),
        child: Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.8)),
      ),
    );
  }
}

// ── NEW: Movie Card Widget ──────────────────────────────────────────────────
class MovieCard extends StatelessWidget {
  final StreamModel stream;
  const MovieCard({super.key, required this.stream});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(stream: stream)),
      ),
      child: Hero(
        tag: stream.id,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: stream.logo.isNotEmpty ? stream.logo : stream.team1Logo,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: cs.surfaceContainerHighest,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: cs.surfaceContainerHighest,
                            child: const Icon(Icons.movie_rounded, size: 40),
                          ),
                        ),
                      ),
                      // Subtle gradient overlay at the bottom
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                              stops: const [0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Quality badge (optional)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'HD',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stream.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stream.subtitle.isEmpty ? 'Action • Movie' : stream.subtitle,
                    maxLines: 1,
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
