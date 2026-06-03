import 'package:flutter/material.dart';
import '../data/hive_service.dart';
import '../models/book_model.dart';
import '../theme/app_theme.dart';
import '../theme/app_mode.dart';
import 'listening_screen.dart';
import 'book_detail_screen.dart';

class AudioScreen extends StatefulWidget {
  final VoidCallback onGoHome;
  final VoidCallback onGoBookshelf;
  final VoidCallback onGoCategories;

  const AudioScreen({
    super.key,
    required this.onGoHome,
    required this.onGoBookshelf,
    required this.onGoCategories,
  });

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  List<BookModel> _continueListening = [];
  List<BookModel> _audiobooksAll = [];
  List<String> _categories = [];
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final allBooks = HiveService.getAllBooks();
    // Books that have BOTH read and listen available
    final audiobooks = allBooks
        .where((b) => b.hasAudio && b.readFormat.isNotEmpty)
        .toList();

    // Build category list from audiobooks only
    final catSet = <String>{};
    for (final b in audiobooks) {
      for (final c in b.categories) {
        if (c.trim().isNotEmpty) catSet.add(c.trim());
      }
    }
    final cats = ['All', ...catSet.toList()..sort()];

    setState(() {
      _continueListening = HiveService.getContinueListening();
      _audiobooksAll = audiobooks;
      _categories = cats;
    });
  }

  List<BookModel> get _filteredAudiobooks {
    if (_selectedCategory == 'All') return List<BookModel>.from(_audiobooksAll);
    return _audiobooksAll
        .where(
          (b) => b.categories.any(
            (c) => c.trim().toLowerCase() == _selectedCategory.toLowerCase(),
          ),
        )
        .toList();
  }

  Future<void> _deleteFromContinueListening(BookModel book) async {
    final isDark = themeModeNotifier.isDark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        title: Text(
          'Remove from Continue Listening?',
          style: TextStyle(
            fontFamily: 'Playfair',
            fontWeight: AppFontWeights.bold,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        content: Text(
          'Do you want to remove "${book.title}" from Continue Listening?\n\nThis will reset audio progress. Favourites will not be affected.',
          style: TextStyle(
            color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'No',
              style: TextStyle(
                color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
              ),
            ),
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
      await HiveService.removeFromContinueListening(book.id);
      _loadData();
    }
  }

  void _openListening(BookModel book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ListeningScreen(bookId: book.id)),
    ).then((_) => _loadData());
  }

  void _openAudiobookDetail(BookModel book) {
    final audiobookIds = _audiobooksAll.map((b) => b.id).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BookDetailScreen(bookId: book.id, bookListOverride: audiobookIds),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _toggleFav(String bookId) async {
    await HiveService.toggleFavorite(bookId);
    _loadData();
  }

  String _fmtCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  /// Read/Listen tag widget for bottom-right of cover
  Widget _readListenTag({required bool hasRead, required bool hasListen}) {
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
            const Icon(Icons.menu_book, color: Colors.white, size: 12),
            if (hasListen) const SizedBox(height: 3),
          ],
          if (hasListen)
            const Icon(Icons.headphones, color: Colors.white, size: 12),
        ],
      ),
    );
  }

  /// Downloads badge widget for bottom-left of cover
  Widget _downloadsBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.download, color: Colors.white, size: 11),
          const SizedBox(width: 2),
          Text(
            _fmtCount(count),
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

  //  Continue Listening card (matches home screen's Continue Reading card)
  Widget _buildContinueListeningCard(
    BookModel book,
    Color textColor,
    Color subText,
  ) {
    final progress = book.listeningProgress;

    return GestureDetector(
      onTap: () => _openListening(book),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Cover
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.bookCoverRadius,
                    ),
                    child: _buildCoverImageFill(book),
                  ),
                  // Close button — top right
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _deleteFromContinueListening(book),
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
                  // Favourite button — top left
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
                  // Downloads badge — bottom left
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: _downloadsBadge(book.downloadCount),
                  ),
                  // Read/Listen tag — bottom right
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: _readListenTag(
                      hasRead: book.readFormat.isNotEmpty,
                      hasListen: book.hasAudio,
                    ),
                  ),
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
            // Progress bar
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
                  widthFactor: progress,
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

  Widget _buildCoverImageFill(BookModel book) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: book.coverUrl.isNotEmpty
          ? Image.network(
              book.coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _coverFallback(book),
            )
          : _coverFallback(book),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeModeNotifier.isDark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final navBar = isDark ? AppColors.darkNavBar : AppColors.lightNavBar;
    final filteredAudiobooks = _filteredAudiobooks;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          //  Header
          Container(
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
            child: Row(
              children: [
                Text(
                  'Audio',
                  style: TextStyle(
                    fontFamily: 'Playfair',
                    fontWeight: AppFontWeights.bold,
                    fontSize: AppFontSizes.xxl,
                    color: textColor,
                  ),
                ),
                const Spacer(),
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
              ],
            ),
          ),

          //  Body
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => _loadData(),
              child: CustomScrollView(
                slivers: [
                  //  Continue Listening
                  if (_continueListening.isNotEmpty) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Continue Listening',
                          style: TextStyle(
                            fontFamily: 'Playfair',
                            fontWeight: AppFontWeights.bold,
                            fontSize: AppFontSizes.xl,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _continueListening.length,
                          itemBuilder: (context, i) =>
                              _buildContinueListeningCard(
                                _continueListening[i],
                                textColor,
                                subText,
                              ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],

                  //  Audiobooks Section
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Audiobooks',
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

                  // Category Chips
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: _categories.map((cat) {
                          final selected = cat == _selectedCategory;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCategory = cat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? (isDark
                                            ? AppColors.darkText
                                            : AppColors.categoryChipSelected)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.chipRadius,
                                  ),
                                  border: Border.all(
                                    color: selected
                                        ? Colors.transparent
                                        : subText.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: AppFontSizes.xs,
                                    color: selected
                                        ? (isDark
                                              ? AppColors.darkBackground
                                              : Colors.white)
                                        : subText,
                                    fontWeight: selected
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
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Audiobooks count
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '${filteredAudiobooks.length} book${filteredAudiobooks.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: AppFontSizes.xs,
                          color: subText,
                          fontWeight: AppFontWeights.medium,
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Audiobooks Grid
                  if (filteredAudiobooks.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 40,
                          horizontal: 20,
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.headphones,
                                size: 48,
                                color: subText.withValues(alpha: 0.35),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No audiobooks found',
                                style: TextStyle(
                                  fontFamily: 'Playfair',
                                  fontSize: AppFontSizes.md,
                                  color: subText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.62,
                            ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final book = filteredAudiobooks[i];
                          return GestureDetector(
                            onTap: () => _openAudiobookDetail(book),
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
                                        child: book.coverUrl.isNotEmpty
                                            ? Image.network(
                                                book.coverUrl,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                                errorBuilder: (_, __, ___) =>
                                                    _coverFallback(book),
                                              )
                                            : _coverFallback(book),
                                      ),
                                      // Favourite button — top right
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _toggleFav(book.id),
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              color: Colors.black.withValues(
                                                alpha: 0.55,
                                              ),
                                            ),
                                            child: Icon(
                                              book.isFavorite
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: book.isFavorite
                                                  ? Colors.red
                                                  : Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Downloads badge — bottom left
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        child: _downloadsBadge(
                                          book.downloadCount,
                                        ),
                                      ),
                                      // Read/Listen tag — bottom right
                                      Positioned(
                                        bottom: 4,
                                        right: 4,
                                        child: _readListenTag(
                                          hasRead: book.readFormat.isNotEmpty,
                                          hasListen: book.hasAudio,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Playfair',
                                    fontWeight: AppFontWeights.semiBold,
                                    fontSize: AppFontSizes.xs,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  book.authors,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: AppFontSizes.xs,
                                    color: subText,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }, childCount: filteredAudiobooks.length),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),

          //  Bottom Nav
          Container(
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
              children: [
                _navItem(Icons.home_outlined, 'Home', subText, widget.onGoHome),
                _navItem(
                  Icons.category_outlined,
                  'Categories',
                  subText,
                  widget.onGoCategories,
                ),
                _navItem(
                  Icons.headphones,
                  'Audiobooks',
                  AppColors.primary,
                  () {},
                  selected: true,
                ),
                _navItem(
                  Icons.menu_book_outlined,
                  'Bookshelf',
                  subText,
                  widget.onGoBookshelf,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap, {
    bool selected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSizes.xs,
                color: color,
                fontWeight: selected
                    ? AppFontWeights.semiBold
                    : AppFontWeights.regular,
              ),
            ),
          ],
        ),
      ),
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
              fontSize: AppFontSizes.xs,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
