import 'package:flutter/material.dart';
import '../data/hive_service.dart';
import '../models/book_model.dart';
import '../theme/app_theme.dart';
import '../theme/app_mode.dart';
import 'book_detail_screen.dart';

class BookshelfScreen extends StatefulWidget {
  final VoidCallback onGoHome;
  final VoidCallback onGoAudio;
  final VoidCallback onGoCategories;

  const BookshelfScreen({
    super.key,
    required this.onGoHome,
    required this.onGoAudio,
    required this.onGoCategories,
  });

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<BookModel> _continueBooks = [];
  List<BookModel> _favouriteBooks = [];
  List<BookModel> _finishedBooks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    final continueReading = HiveService.getContinueReading();
    final continueListening = HiveService.getContinueListening();

    final Map<String, BookModel> merged = {};
    for (final b in continueReading) merged[b.id] = b;
    for (final b in continueListening) merged[b.id] = b;
    final mergedList = merged.values.toList();
    mergedList.sort((a, b) {
      final aTime = _latestActivity(a);
      final bTime = _latestActivity(b);
      return bTime.compareTo(aTime);
    });

    setState(() {
      _continueBooks = mergedList;
      _favouriteBooks = HiveService.getAllBooks()
          .where((b) => b.isFavorite)
          .toList();
      _finishedBooks = HiveService.getFinishedBooks();
    });
  }

  DateTime _latestActivity(BookModel b) {
    final r = b.lastReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final l = b.lastListenedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return r.isAfter(l) ? r : l;
  }

  void _goToDetail(BookModel book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
    ).then((_) => _loadData());
  }

  Future<void> _removeFromFavourites(BookModel book) async {
    await HiveService.toggleFavorite(book.id);
    _loadData();
  }

  Future<void> _removeFromFinished(BookModel book) async {
    await HiveService.removeFromFinished(book.id);
    _loadData();
  }

  Future<void> _deleteFromContinue(BookModel book) async {
    final isDark = themeModeNotifier.isDark;
    final inReading =
        (book.scrollOffset > 0 || book.epubChapterIndex > 0) &&
        !book.readingFinished;
    final inListening =
        (book.currentAudioPosition > 0 || book.currentAudioChapter > 0) &&
        !book.listeningFinished;
    final inBoth = inReading && inListening;

    String locationText;
    if (inBoth) {
      locationText =
          'Do you want to remove "${book.title}" from Continue? It appears in both Continue Reading and Continue Listening.\n\nThis will reset reading progress and audio progress. Favourites will not be affected.';
    } else if (inReading) {
      locationText =
          'Do you want to remove "${book.title}" from Continue Reading?\n\nThis will reset reading progress. Favourites will not be affected.';
    } else {
      locationText =
          'Do you want to remove "${book.title}" from Continue Listening?\n\nThis will reset audio progress. Favourites will not be affected.';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        title: Text(
          'Remove from Continue?',
          style: TextStyle(
            fontFamily: 'Playfair',
            fontWeight: AppFontWeights.bold,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        content: Text(
          locationText,
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
      if (!book.readingFinished)
        await HiveService.removeFromContinueReading(book.id);
      if (!book.listeningFinished)
        await HiveService.removeFromContinueListening(book.id);
      _loadData();
    }
  }

  //  Progress helpers

  String _progressLabel(BookModel book) {
    final inReading =
        (book.scrollOffset > 0 || book.epubChapterIndex > 0) &&
        !book.readingFinished;
    final inListening = book.listeningProgress > 0 && !book.listeningFinished;

    if (inReading && inListening) {
      return '${(_readingPercent(book)).toInt()}% Reading\n${(book.listeningProgress * 100).toInt()}% Listening';
    } else if (inReading) {
      return '${(_readingPercent(book)).toInt()}% Reading';
    } else {
      return '${(book.listeningProgress * 100).toInt()}% Listening';
    }
  }

  double _readingPercent(BookModel book) {
    // Simple proxy: if scroll offset > 0, show based on scrollOffset/0 (we don't know max)
    // Best we can do without knowing maxScrollExtent is show >0 as "started"
    if (book.readingFinished) return 100.0;
    if (book.scrollOffset > 0)
      return 10.0; // placeholder — real % shown in reading_screen
    return 0.0;
  }

  //  Build

  @override
  Widget build(BuildContext context) {
    final isDark = themeModeNotifier.isDark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final navBar = isDark ? AppColors.darkNavBar : AppColors.lightNavBar;

    Widget continueTab = _buildGrid(
      books: _continueBooks,
      emptyIcon: Icons.menu_book_outlined,
      emptyTitle: 'Nothing in progress',
      emptySubtitle: 'Start reading or listening to a book to see it here.',
      textColor: textColor,
      subText: subText,
      itemBuilder: (book) => _buildContinueItem(book, textColor, subText),
    );

    Widget favouritesTab = _buildGrid(
      books: _favouriteBooks,
      emptyIcon: Icons.favorite_border,
      emptyTitle: 'No favourites yet',
      emptySubtitle: 'Tap the heart icon on any book to favourite it.',
      textColor: textColor,
      subText: subText,
      itemBuilder: (book) => _buildFavouriteItem(book, textColor, subText),
    );

    Widget finishedTab = _buildGrid(
      books: _finishedBooks,
      emptyIcon: Icons.menu_book_outlined,
      emptyTitle: 'No finished books yet',
      emptySubtitle: 'Complete reading or listening to a book to see it here.',
      textColor: textColor,
      subText: subText,
      itemBuilder: (book) => _buildFinishedItem(book, textColor, subText),
    );

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
              bottom: 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'My Bookshelf',
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
                      child: Icon(
                        isDark ? Icons.light_mode : Icons.dark_mode,
                        color: textColor,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: subText,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                    fontFamily: 'Playfair',
                    fontWeight: AppFontWeights.semiBold,
                    fontSize: AppFontSizes.sm,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: AppFontSizes.sm,
                    fontWeight: AppFontWeights.regular,
                  ),
                  tabs: const [
                    Tab(text: 'Continue'),
                    Tab(text: 'Favourites'),
                    Tab(text: 'Finished'),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [continueTab, favouritesTab, finishedTab],
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
                  Icons.headphones_outlined,
                  'Audiobooks',
                  subText,
                  widget.onGoAudio,
                ),
                _navItem(
                  Icons.menu_book,
                  'Bookshelf',
                  AppColors.primary,
                  () {},
                  selected: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid({
    required List<BookModel> books,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    required Color textColor,
    required Color subText,
    required Widget Function(BookModel) itemBuilder,
  }) {
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 64, color: subText.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: TextStyle(
                fontFamily: 'Playfair',
                fontSize: AppFontSizes.lg,
                color: subText,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFontSizes.sm,
                  color: subText.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: 130 / 220,
      ),
      itemCount: books.length,
      itemBuilder: (context, i) {
        final book = books[i];
        return GestureDetector(
          onTap: () => _goToDetail(book),
          child: itemBuilder(book),
        );
      },
    );
  }

  Widget _buildContinueItem(BookModel book, Color textColor, Color subText) {
    final label = _progressLabel(book);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.bookCoverRadius),
                child: _bookCover(book),
              ),
              // Progress badge
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (book.readingFinished || book.listeningFinished)
                        _finishedBadge(book),
                      if (book.readingFinished || book.listeningFinished)
                        const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: AppFontSizes.xs,
                            fontWeight: AppFontWeights.semiBold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Download count badge
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                        _fmtCount(book.downloadCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppFontSizes.xs,
                          fontWeight: AppFontWeights.semiBold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Delete top right
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => _deleteFromContinue(book),
                  child: Container(
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(
                      color: (book.readingFinished || book.listeningFinished)
                          ? Colors.red.withValues(alpha: 0.85)
                          : Colors.black.withValues(alpha: 0.65),
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
              // Favourite top left
              Positioned(
                top: 6,
                left: 6,
                child: GestureDetector(
                  onTap: () async {
                    await HiveService.toggleFavorite(book.id);
                    _loadData();
                  },
                  child: Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                    child: Icon(
                      book.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: book.isFavorite ? Colors.red : Colors.white,
                      size: 22,
                    ),
                  ),
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
        Text(
          book.authors,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: subText),
        ),
      ],
    );
  }

  Widget _buildFavouriteItem(BookModel book, Color textColor, Color subText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.bookCoverRadius),
                child: _bookCover(book),
              ),
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                        _fmtCount(book.downloadCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppFontSizes.xs,
                          fontWeight: AppFontWeights.semiBold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => _removeFromFavourites(book),
                  child: Container(
                    width: 27,
                    height: 27,
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
        Text(
          book.authors,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: subText),
        ),
      ],
    );
  }

  Widget _buildFinishedItem(BookModel book, Color textColor, Color subText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.bookCoverRadius),
                child: _bookCover(book),
              ),
              Positioned.fill(child: Center(child: _finishedBadge(book))),
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                        _fmtCount(book.downloadCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppFontSizes.xs,
                          fontWeight: AppFontWeights.semiBold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (book.isFavorite)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 22,
                    ),
                  ),
                ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => _removeFromFinished(book),
                  child: Container(
                    width: 27,
                    height: 27,
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
        Text(
          book.authors,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: subText),
        ),
      ],
    );
  }

  Widget _finishedBadge(BookModel book) {
    final fr = book.readingFinished;
    final fl = book.listeningFinished;
    final label = (fr && fl)
        ? 'Finished Reading\n& Listening'
        : fr
        ? 'Finished Reading'
        : 'Finished Listening';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: AppFontSizes.xs,
          fontWeight: AppFontWeights.semiBold,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _bookCover(BookModel book) {
    if (book.coverUrl.isNotEmpty) {
      return Image.network(
        book.coverUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _coverFallback(book),
      );
    }
    return _coverFallback(book);
  }

  Widget _coverFallback(BookModel book) => Container(
    color: AppColors.primary.withValues(alpha: 0.15),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
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

  String _fmtCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
