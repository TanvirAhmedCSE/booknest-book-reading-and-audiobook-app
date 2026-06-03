import 'package:flutter/material.dart';
import '../data/hive_service.dart';
import '../models/book_model.dart';
import '../theme/app_theme.dart';
import '../theme/app_mode.dart';
import 'book_detail_screen.dart';
import 'audio_screen.dart';
import 'bookshelf_screen.dart';
import 'categories_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import '../background_worker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedTab = 0;

  String _selectedPopularCategory = 'All';
  String _selectedRecentCategory = 'All';
  List<String> _categories = [];
  List<BookModel> _allBooks = [];
  List<BookModel> _continueReading = [];
  List<BookModel> _popularBooks = [];
  List<BookModel> _recentlyAdded = [];
  List<BookModel> _recommendedBooks = [];

  final ScrollController _scrollController = ScrollController();
  bool _navBarVisible = true;
  double _lastScrollOffset = 0;
  bool _isLoading = false;

  // Periodic refresh timer — reloads UI every 30s while background fetch runs
  static const Duration _refreshInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBackgroundWork();
    });
  }

  // Starts background fetch and schedules periodic UI refreshes so newly
  // stored books appear without the user having to pull-to-refresh.
  Future<void> _startBackgroundWork() async {
    // Run LibriVox mapping + Gutendex bulk fetch concurrently.
    // This is fire-and-forget from initState's perspective.
    runBackgroundWork().then((_) {
      // Final reload once everything is done.
      if (mounted) _loadData();
    });

    // Refresh UI every 30 seconds while background fetch is running so the
    // user sees books accumulate progressively.
    _schedulePeriodicRefresh();
  }

  void _schedulePeriodicRefresh() {
    Future.delayed(_refreshInterval, () {
      if (!mounted) return;
      _loadData();
      // Keep scheduling until background work settles (books stop growing).
      // In practice this runs for the duration of the Gutendex bulk fetch.
      _schedulePeriodicRefresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;
    if (delta > 4 && _navBarVisible) {
      setState(() => _navBarVisible = false);
    } else if (delta < -4 && !_navBarVisible) {
      setState(() => _navBarVisible = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      runBackgroundWork().then((_) {
        if (mounted) _loadData();
      });
    }
  }

  void _loadData() {
    setState(() {
      _categories = HiveService.getAllCategories();
      _allBooks = HiveService.getAllBooks();
      _continueReading = HiveService.getContinueReading();
      _popularBooks = _computePopular();
      _recentlyAdded = _computeRecent();
      _recommendedBooks = HiveService.getRecommended(limit: 8);
    });
  }

  List<BookModel> _computePopular() {
    List<BookModel> books;
    if (_selectedPopularCategory == 'All') {
      books = List<BookModel>.from(_allBooks);
    } else {
      books = _allBooks
          .where((b) => b.categories.contains(_selectedPopularCategory))
          .toList();
    }
    books.sort((a, b) => b.downloadCount.compareTo(a.downloadCount));
    return books.take(8).toList();
  }

  List<BookModel> _computeRecent() {
    List<BookModel> books;
    if (_selectedRecentCategory == 'All') {
      books = List<BookModel>.from(_allBooks);
    } else {
      books = _allBooks
          .where((b) => b.categories.contains(_selectedRecentCategory))
          .toList();
    }
    books.sort((a, b) {
      final aId = int.tryParse(a.id) ?? 0;
      final bId = int.tryParse(b.id) ?? 0;
      return bId.compareTo(aId);
    });
    return books.take(8).toList();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await HiveService.fetchAndStoreBooks(sort: 'popular', page: 1);
    await HiveService.fetchAndStoreBooks(sort: 'descending', page: 1);
    _loadData();
    setState(() => _isLoading = false);
  }

  Future<void> _deleteFromContinueReading(BookModel book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Continue Reading?'),
        content: Text(
          'Do you want to remove "${book.title}" from Continue Reading?\n\nThis will reset reading progress. Favourites will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await HiveService.removeFromContinueReading(book.id);
      _loadData();
    }
  }

  void _goToDetail(BookModel book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
    ).then((_) => _loadData());
  }

  Future<void> _toggleFav(String bookId) async {
    await HiveService.toggleFavorite(bookId);
    _loadData();
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  // Read/Listen tag for bottom-right corner of cover image
  Widget _readListenTag(BookModel book, {double iconSize = 12}) {
    final hasRead = book.readFormat.isNotEmpty;
    final hasListen = book.hasAudio;
    if (!hasRead && !hasListen) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasRead) ...[
            Icon(Icons.menu_book, color: Colors.white, size: iconSize),
            if (hasListen) const SizedBox(height: 3),
          ],
          if (hasListen)
            Icon(Icons.headphones, color: Colors.white, size: iconSize),
        ],
      ),
    );
  }

  // Downloads badge for bottom-left of cover
  Widget _downloadsBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.download, color: Colors.white, size: 11),
          const SizedBox(width: 2),
          Text(
            _formatCount(count),
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppFontSizes.xs,
              fontWeight: AppFontWeights.semiBold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeModeNotifier.isDark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final searchBg = isDark ? AppColors.darkSearchBg : AppColors.lightSearchBg;
    final navBar = isDark ? AppColors.darkNavBar : AppColors.lightNavBar;

    final bottomNav = _buildBottomNav(subText, navBar);

    if (_selectedTab == 1) {
      return Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            const CategoriesScreen(),
            Positioned(left: 0, right: 0, bottom: 0, child: bottomNav),
          ],
        ),
      );
    }

    if (_selectedTab == 2) {
      return AudioScreen(
        onGoHome: () {
          _loadData();
          setState(() => _selectedTab = 0);
        },
        onGoBookshelf: () => setState(() => _selectedTab = 3),
        onGoCategories: () => setState(() => _selectedTab = 1),
      );
    }

    if (_selectedTab == 3) {
      return BookshelfScreen(
        onGoHome: () {
          _loadData();
          setState(() => _selectedTab = 0);
        },
        onGoAudio: () => setState(() => _selectedTab = 2),
        onGoCategories: () => setState(() => _selectedTab = 1),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                //  Header
                SliverToBoxAdapter(
                  child: _buildHeader(isDark, textColor, subText, searchBg),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                //  Continue Reading
                if (_continueReading.isNotEmpty) ...[
                  _sectionHeader('Continue Reading', textColor, subText),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _continueReading.length,
                        itemBuilder: (context, i) => _buildContinueCard(
                          _continueReading[i],
                          textColor,
                          subText,
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],

                //  Popular
                _sectionHeader('Popular', textColor, subText),
                _buildCategoryChips(
                  selected: _selectedPopularCategory,
                  subText: subText,
                  isDark: isDark,
                  onSelect: (cat) {
                    setState(() {
                      _selectedPopularCategory = cat;
                      _popularBooks = _computePopular();
                    });
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 230,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _popularBooks.length,
                      itemBuilder: (context, i) =>
                          _buildBookCard(_popularBooks[i], textColor, subText),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                //  Recently Added
                _sectionHeader('Recently Added', textColor, subText),
                _buildCategoryChips(
                  selected: _selectedRecentCategory,
                  subText: subText,
                  isDark: isDark,
                  onSelect: (cat) {
                    setState(() {
                      _selectedRecentCategory = cat;
                      _recentlyAdded = _computeRecent();
                    });
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 230,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _recentlyAdded.length,
                      itemBuilder: (context, i) =>
                          _buildBookCard(_recentlyAdded[i], textColor, subText),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                //  Recommended For You
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Recommended For You',
                      style: TextStyle(
                        fontFamily: 'Playfair',
                        fontWeight: AppFontWeights.bold,
                        fontSize: AppFontSizes.xl,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _buildRecommendedCard(
                      _recommendedBooks[i],
                      cardColor,
                      textColor,
                      subText,
                      isDark,
                    ),
                    childCount: _recommendedBooks.length,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: _navBarVisible ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: bottomNav,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    bool isDark,
    Color textColor,
    Color subText,
    Color searchBg,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.headerGradientDark
            : AppColors.headerGradientLight,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {},
                child: Icon(Icons.menu, color: textColor, size: 26),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  themeModeNotifier.toggleTheme();
                  setState(() {});
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: Icon(
                    isDark ? Icons.light_mode : Icons.dark_mode,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Hello, Tanvir',
                style: TextStyle(
                  fontFamily: 'Playfair',
                  fontWeight: AppFontWeights.semiBold,
                  fontSize: AppFontSizes.lg,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ).then((_) => _loadData());
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: const AssetImage(
                      'assets/images/profile.png',
                    ),
                    onBackgroundImageError: (_, __) {},
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  '"You don\'t rise to the level of your goals, you\nfall to the level of your systems."',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontStyle: FontStyle.italic,
                    fontSize: AppFontSizes.sm,
                    color: textColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '– James Clear (Atomic Habits)',
                  style: TextStyle(fontSize: AppFontSizes.xs, color: subText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const SearchScreen(openSortImmediately: false),
                ),
              ).then((_) => _loadData());
            },
            child: Container(
              decoration: BoxDecoration(
                color: searchBg,
                borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      readOnly: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const SearchScreen(openSortImmediately: false),
                          ),
                        ).then((_) => _loadData());
                      },
                      style: TextStyle(
                        color: textColor,
                        fontSize: AppFontSizes.sm,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by Title, Author, Category',
                        hintStyle: TextStyle(
                          color: subText,
                          fontSize: AppFontSizes.sm,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: subText,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.only(
                          top: 14,
                          bottom: 12,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const SearchScreen(openSortImmediately: true),
                        ),
                      ).then((_) => _loadData());
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.tune, color: subText, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, Color textColor, Color subText) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Playfair',
                fontWeight: AppFontWeights.bold,
                fontSize: AppFontSizes.xl,
                color: textColor,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {},
              child: Text(
                'view all',
                style: TextStyle(color: subText, fontSize: AppFontSizes.sm),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips({
    required String selected,
    required Color subText,
    required bool isDark,
    required ValueChanged<String> onSelect,
  }) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: _categories.map((cat) {
            final isSelected = cat == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                              ? AppColors.darkText
                              : AppColors.categoryChipSelected)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : subText.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: AppFontSizes.sm,
                      color: isSelected
                          ? (isDark ? AppColors.darkBackground : Colors.white)
                          : subText,
                      fontWeight: isSelected
                          ? AppFontWeights.semiBold
                          : AppFontWeights.regular,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  //  Popular & Recently Added card
  Widget _buildBookCard(BookModel book, Color textColor, Color subText) {
    return GestureDetector(
      onTap: () => _goToDetail(book),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.bookCoverRadius,
                  ),
                  child: SizedBox(
                    height: 175,
                    width: 130,
                    child: _buildCoverImage(book),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: _downloadsBadge(book.downloadCount),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _toggleFav(book.id),
                    child: Container(
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                      child: Icon(
                        book.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: book.isFavorite ? Colors.red : Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                Positioned(bottom: 8, right: 8, child: _readListenTag(book)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Playfair',
                fontWeight: AppFontWeights.semiBold,
                fontSize: AppFontSizes.sm,
                color: textColor,
              ),
            ),
            Text(
              book.authors,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppFontSizes.xs, color: subText),
            ),
          ],
        ),
      ),
    );
  }

  //  Continue Reading card
  Widget _buildContinueCard(BookModel book, Color textColor, Color subText) {
    return GestureDetector(
      onTap: () => _goToDetail(book),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.bookCoverRadius,
                    ),
                    child: _buildCoverImageFill(book),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _deleteFromContinueReading(book),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: GestureDetector(
                      onTap: () => _toggleFav(book.id),
                      child: Container(
                        width: 27,
                        height: 27,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                        child: Icon(
                          book.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: book.isFavorite ? Colors.red : Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: _downloadsBadge(book.downloadCount),
                  ),
                  Positioned(bottom: 6, right: 6, child: _readListenTag(book)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Playfair',
                fontWeight: AppFontWeights.semiBold,
                fontSize: AppFontSizes.sm,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Stack(
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: subText.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (book.scrollOffset > 0 ? 0.3 : 0.0).clamp(
                    0.0,
                    1.0,
                  ),
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  //  Recommended card
  Widget _buildRecommendedCard(
    BookModel book,
    Color cardColor,
    Color textColor,
    Color subText,
    bool isDark,
  ) {
    final hasRead = book.readFormat.isNotEmpty;
    final hasListen = book.hasAudio;

    return GestureDetector(
      onTap: () => _goToDetail(book),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          boxShadow: isDark
              ? AppShadows.cardShadowDark
              : AppShadows.cardShadowLight,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 90,
                child: _buildCoverImage(book),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Playfair',
                      fontWeight: AppFontWeights.semiBold,
                      fontSize: AppFontSizes.md,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    book.authors,
                    style: TextStyle(fontSize: AppFontSizes.sm, color: subText),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: book.categories.take(2).map((cat) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cat,
                          style: const TextStyle(
                            fontSize: AppFontSizes.xs,
                            color: AppColors.primary,
                            fontWeight: AppFontWeights.semiBold,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.download,
                        color: AppColors.primary,
                        size: 13,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _formatCount(book.downloadCount),
                        style: TextStyle(
                          fontSize: AppFontSizes.xs,
                          fontWeight: AppFontWeights.semiBold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (hasRead) ...[
                        const Icon(
                          Icons.menu_book,
                          color: AppColors.primary,
                          size: 13,
                        ),
                        if (hasListen) const SizedBox(width: 5),
                      ],
                      if (hasListen)
                        const Icon(
                          Icons.headphones,
                          color: AppColors.primary,
                          size: 13,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _toggleFav(book.id),
              child: Icon(
                book.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: book.isFavorite ? Colors.red : subText,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(BookModel book) {
    if (book.coverUrl.isNotEmpty) {
      return Image.network(
        book.coverUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _coverFallback(book),
      );
    }
    return _coverFallback(book);
  }

  Widget _buildCoverImageFill(BookModel book) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: _buildCoverImage(book),
    );
  }

  Widget _coverFallback(BookModel book) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.15),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            book.title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Playfair',
              fontWeight: AppFontWeights.bold,
              fontSize: AppFontSizes.sm,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(Color subText, Color navBar) {
    final tabs = [
      (Icons.home, Icons.home_outlined, 'Home'),
      (Icons.category, Icons.category_outlined, 'Categories'),
      (Icons.headphones, Icons.headphones_outlined, 'Audiobooks'),
      (Icons.menu_book, Icons.menu_book_outlined, 'Bookshelf'),
    ];
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: navBar,
        boxShadow: AppShadows.navBarShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (i) {
          final selected = _selectedTab == i;
          final (filledIcon, outlinedIcon, label) = tabs[i];
          return GestureDetector(
            onTap: () {
              if (_selectedTab != i) {
                _loadData();
                setState(() => _selectedTab = i);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? filledIcon : outlinedIcon,
                    color: selected ? AppColors.primary : subText,
                    size: 24,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: AppFontSizes.xs,
                      color: selected ? AppColors.primary : subText,
                      fontWeight: selected
                          ? AppFontWeights.semiBold
                          : AppFontWeights.regular,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
