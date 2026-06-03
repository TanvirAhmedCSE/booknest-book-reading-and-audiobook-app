import 'package:flutter/material.dart';
import '../data/hive_service.dart';
import '../models/book_model.dart';
import '../theme/app_theme.dart';
import '../theme/app_mode.dart';
import 'reading_screen.dart';
import 'listening_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final String bookId;

  final List<String>? bookListOverride;

  const BookDetailScreen({
    super.key,
    required this.bookId,
    this.bookListOverride,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late PageController _pageController;
  late List<BookModel> _allBooks;
  late int _currentIndex;
  late BookModel _currentBook;

  @override
  void initState() {
    super.initState();
    _initBooks();
  }

  void _initBooks() {
    final allFromHive = HiveService.getAllBooks();

    if (widget.bookListOverride != null &&
        widget.bookListOverride!.isNotEmpty) {
      final idOrder = widget.bookListOverride!;
      final bookMap = {for (final b in allFromHive) b.id: b};
      _allBooks = idOrder
          .map((id) => bookMap[id])
          .whereType<BookModel>()
          .toList();
      if (_allBooks.isEmpty) _allBooks = allFromHive;
    } else {
      _allBooks = allFromHive;
    }

    _currentIndex = _allBooks.indexWhere((b) => b.id == widget.bookId);
    if (_currentIndex == -1) _currentIndex = 0;
    _currentBook = _allBooks[_currentIndex];
    _pageController = PageController(
      initialPage: _currentIndex + _allBooks.length * 500,
      viewportFraction: 0.6,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final realIndex = index % _allBooks.length;
    setState(() {
      _currentIndex = realIndex;
      _currentBook = _allBooks[realIndex];
    });
  }

  Future<void> _toggleFav() async {
    await HiveService.toggleFavorite(_currentBook.id);
    setState(() {
      _currentBook = HiveService.getBook(_currentBook.id) ?? _currentBook;
    });
  }

  void _refreshBook() {
    setState(() {
      _currentBook = HiveService.getBook(_currentBook.id) ?? _currentBook;
    });
  }

  Widget _buildCover(BookModel book) {
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

  Widget _coverFallback(BookModel book) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            book.title,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Playfair',
              color: AppColors.primary,
              fontWeight: AppFontWeights.bold,
            ),
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  /// Read/Listen tag for bottom-right corner of cover in carousel
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
            const Icon(Icons.menu_book, color: Colors.white, size: 13),
            if (hasListen) const SizedBox(height: 4),
          ],
          if (hasListen)
            const Icon(Icons.headphones, color: Colors.white, size: 13),
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

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          //  Top gradient header with book carousel
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
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(
                            Icons.chevron_left,
                            size: 30,
                            color: textColor,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.share_outlined, color: textColor, size: 22),
                        const SizedBox(width: 5),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 260,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) {
                        final realIndex = index % _allBooks.length;
                        final book = _allBooks[realIndex];
                        final isCenter = realIndex == _currentIndex;
                        return GestureDetector(
                          onTap: () {
                            if (!isCenter) {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            margin: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: isCenter ? 0 : 30,
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: _buildCover(book),
                                ),
                                // Download count badge — bottom left
                                if (isCenter)
                                  Positioned(
                                    bottom: 10,
                                    left: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.75,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.download,
                                            color: Colors.white,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            _formatCount(book.downloadCount),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: AppFontSizes.sm,
                                              fontWeight: AppFontWeights.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Favourite button — top right
                                if (isCenter)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: _toggleFav,
                                      child: Container(
                                        width: 27,
                                        height: 27,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            17,
                                          ),
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
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Read/Listen tag — bottom right (always visible)
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: _readListenTag(book),
                                ),
                                // Finished badge
                                Builder(
                                  builder: (_) {
                                    final fr = HiveService.isFinished(book);
                                    final fl = HiveService.isFinishedAudio(
                                      book,
                                    );
                                    if (!fr && !fl)
                                      return const SizedBox.shrink();
                                    final label = (fr && fl)
                                        ? 'Finished Reading\n& Listening'
                                        : fr
                                        ? 'Finished Reading'
                                        : 'Finished Listening';
                                    return Positioned.fill(
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            label,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: AppFontSizes.xs,
                                              fontWeight: AppFontWeights.bold,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          //  Book info
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _currentBook.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Playfair',
                      fontWeight: AppFontWeights.bold,
                      fontSize: AppFontSizes.xxl,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentBook.authors,
                    style: TextStyle(fontSize: AppFontSizes.md, color: subText),
                  ),
                  const SizedBox(height: 20),

                  //  Stats row
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.cardRadius,
                      ),
                      boxShadow: isDark
                          ? AppShadows.cardShadowDark
                          : AppShadows.cardShadowLight,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatItem(
                          value: _formatCount(_currentBook.downloadCount),
                          label: 'Downloads',
                          textColor: textColor,
                          subText: subText,
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: subText.withValues(alpha: 0.2),
                        ),
                        _StatItem(
                          value: _currentBook.languages
                              .join(', ')
                              .toUpperCase(),
                          label: 'Language',
                          textColor: textColor,
                          subText: subText,
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: subText.withValues(alpha: 0.2),
                        ),
                        _StatItem(
                          value: _currentBook.copyright ? 'Yes' : 'Free',
                          label: 'Copyright',
                          textColor: textColor,
                          subText: subText,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  //  Categories
                  if (_currentBook.categories.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Categories',
                        style: TextStyle(
                          fontFamily: 'Playfair',
                          fontWeight: AppFontWeights.bold,
                          fontSize: AppFontSizes.lg,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _currentBook.categories.map((cat) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
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
                    ),
                    const SizedBox(height: 20),
                  ],

                  //  About
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'About',
                      style: TextStyle(
                        fontFamily: 'Playfair',
                        fontWeight: AppFontWeights.bold,
                        fontSize: AppFontSizes.xl,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentBook.about,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: AppFontSizes.sm,
                      color: subText,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 30),

                  //  Read & Listen buttons
                  Row(
                    children: [
                      if (_currentBook.readFormat.isNotEmpty)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReadingScreen(bookId: _currentBook.id),
                              ),
                            ).then((_) => _refreshBook()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C3E),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.menu_book,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Read',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: AppFontWeights.semiBold,
                                      fontSize: AppFontSizes.md,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      if (_currentBook.hasAudio) ...[
                        if (_currentBook.readFormat.isNotEmpty)
                          const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ListeningScreen(bookId: _currentBook.id),
                              ),
                            ).then((_) => _refreshBook()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C3E),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.headphones,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Listen',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: AppFontWeights.semiBold,
                                      fontSize: AppFontSizes.md,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color textColor;
  final Color subText;

  const _StatItem({
    required this.value,
    required this.label,
    required this.textColor,
    required this.subText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Playfair',
            fontWeight: AppFontWeights.bold,
            fontSize: AppFontSizes.lg,
            color: textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: AppFontSizes.xs, color: subText),
        ),
      ],
    );
  }
}
