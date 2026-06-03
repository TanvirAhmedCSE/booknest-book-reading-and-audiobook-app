import 'package:flutter/material.dart';
import '../data/hive_service.dart';
import '../models/book_model.dart';
import '../theme/app_theme.dart';
import '../theme/app_mode.dart';
import 'book_detail_screen.dart';

class AllCategoriesDetailScreen extends StatefulWidget {
  const AllCategoriesDetailScreen({super.key});

  @override
  State<AllCategoriesDetailScreen> createState() =>
      _AllCategoriesDetailScreenState();
}

class _AllCategoriesDetailScreenState extends State<AllCategoriesDetailScreen> {
  String _selectedCategory = 'All';
  List<String> _categories = [];
  List<BookModel> _allBooks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _categories = HiveService.getAllCategories();
      _allBooks = HiveService.getAllBooks();
    });
  }

  List<BookModel> get _filteredBooks {
    if (_selectedCategory == 'All') return List<BookModel>.from(_allBooks);
    return _allBooks
        .where(
          (b) => b.categories.any(
            (c) => c.toLowerCase() == _selectedCategory.toLowerCase(),
          ),
        )
        .toList();
  }

  Future<void> _toggleFav(String bookId) async {
    await HiveService.toggleFavorite(bookId);
    _loadData();
  }

  void _goToDetail(BookModel book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
    ).then((_) => _loadData());
  }

  Widget _readListenTag(BookModel book) {
    final hasRead = book.readFormat.isNotEmpty;
    final hasListen = book.hasAudio;
    if (!hasRead && !hasListen) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasRead) ...[
            const Icon(Icons.menu_book, color: Colors.white, size: 14),
            if (hasListen) const SizedBox(height: 4),
          ],
          if (hasListen)
            const Icon(Icons.headphones, color: Colors.white, size: 14),
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
    final books = _filteredBooks;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            pinned: true,
            backgroundColor: isDark
                ? AppColors.darkBackground
                : AppColors.lightBackground,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
            ),
            title: Text(
              'All Books',
              style: TextStyle(
                fontFamily: 'Playfair',
                fontWeight: AppFontWeights.bold,
                fontSize: AppFontSizes.lg,
                color: textColor,
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () {
                  themeModeNotifier.toggleTheme();
                  setState(() {});
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Icon(
                      isDark ? Icons.light_mode : Icons.dark_mode,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Category Chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                children: _categories.map((cat) {
                  final selected = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
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
                            fontSize: AppFontSizes.sm,
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

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${books.length} book${books.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: AppFontSizes.sm,
                  color: subText,
                  fontWeight: AppFontWeights.medium,
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          //  Book Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 18,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate((context, i) {
                final book = books[i];
                return GestureDetector(
                  onTap: () => _goToDetail(book),
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
                            // Download count badge
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.download,
                                      color: Colors.white,
                                      size: 11,
                                    ),
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
                              bottom: 8,
                              right: 8,
                              child: _readListenTag(book),
                            ),
                            // Favourite button
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
                                    color: book.isFavorite
                                        ? Colors.red
                                        : Colors.white,
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
                        style: TextStyle(
                          fontSize: AppFontSizes.xs,
                          color: subText,
                        ),
                      ),
                    ],
                  ),
                );
              }, childCount: books.length),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
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

  String _fmtCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
