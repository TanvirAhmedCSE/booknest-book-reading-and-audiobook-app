import 'package:flutter/material.dart';
import '../data/hive_service.dart';
import '../models/book_model.dart';
import '../theme/app_theme.dart';
import '../theme/app_mode.dart';
import 'book_detail_screen.dart';

//  Sort Option Enum
enum SortOption { none, mostDownloaded, titleAZ }

extension SortOptionLabel on SortOption {
  String get label {
    switch (this) {
      case SortOption.mostDownloaded:
        return 'Most Downloaded';
      case SortOption.titleAZ:
        return 'Title A–Z';
      case SortOption.none:
        return '';
    }
  }

  IconData get icon {
    switch (this) {
      case SortOption.mostDownloaded:
        return Icons.download_rounded;
      case SortOption.titleAZ:
        return Icons.sort_by_alpha_rounded;
      case SortOption.none:
        return Icons.sort_rounded;
    }
  }
}

//  Search Screen
class SearchScreen extends StatefulWidget {
  final bool openSortImmediately;
  const SearchScreen({super.key, this.openSortImmediately = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<BookModel> _allBooks = [];
  SortOption _selectedSort = SortOption.none;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _allBooks = HiveService.getAllBooks();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });

    if (widget.openSortImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSortDialog());
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focusNode.requestFocus(),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<BookModel> get _results {
    List<BookModel> filtered;
    if (_query.isEmpty) {
      filtered = List<BookModel>.from(_allBooks);
    } else {
      final q = _query.toLowerCase();
      filtered = _allBooks.where((b) {
        return b.title.toLowerCase().contains(q) ||
            b.authors.toLowerCase().contains(q) ||
            b.categories.any((c) => c.toLowerCase().contains(q));
      }).toList();
    }

    switch (_selectedSort) {
      case SortOption.mostDownloaded:
        filtered.sort((a, b) => b.downloadCount.compareTo(a.downloadCount));
        break;
      case SortOption.titleAZ:
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case SortOption.none:
        break;
    }

    return filtered;
  }

  void _showSortDialog() {
    final isDark = themeModeNotifier.isDark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    SortOption tempSelected = _selectedSort;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              border: isDark
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? AppColors.headerGradientDark
                        : AppColors.headerGradientLight,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Sort By',
                        style: TextStyle(
                          fontFamily: 'Playfair',
                          fontWeight: AppFontWeights.bold,
                          fontSize: AppFontSizes.xl,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      if (tempSelected != SortOption.none)
                        GestureDetector(
                          onTap: () {
                            setDialogState(
                              () => tempSelected = SortOption.none,
                            );
                            setState(() => _selectedSort = SortOption.none);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: AppFontSizes.xs,
                                color: AppColors.primary,
                                fontWeight: AppFontWeights.semiBold,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.07),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: subText,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: divider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: SortOption.values
                        .where((s) => s != SortOption.none)
                        .map((option) {
                          final isSelected = tempSelected == option;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedSort = option);
                              Navigator.pop(ctx);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.10)
                                    : cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.6)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withValues(
                                              alpha: 0.15,
                                            )
                                          : (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.06,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.05,
                                                  )),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      option.icon,
                                      size: 17,
                                      color: isSelected
                                          ? AppColors.primary
                                          : subText,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: TextStyle(
                                        fontFamily: 'Lora',
                                        fontSize: AppFontSizes.md,
                                        fontWeight: isSelected
                                            ? AppFontWeights.semiBold
                                            : AppFontWeights.regular,
                                        color: isSelected
                                            ? AppColors.primary
                                            : textColor,
                                      ),
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check_circle_rounded,
                                            key: ValueKey('checked'),
                                            color: AppColors.primary,
                                            size: 20,
                                          )
                                        : Icon(
                                            Icons.circle_outlined,
                                            key: ValueKey('unchecked'),
                                            color: subText.withValues(
                                              alpha: 0.5,
                                            ),
                                            size: 20,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goToDetail(BookModel book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
    ).then((_) => setState(() => _allBooks = HiveService.getAllBooks()));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeModeNotifier.isDark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final searchBg = isDark ? AppColors.darkSearchBg : AppColors.lightSearchBg;

    final results = _results;
    final hasQuery = _query.isNotEmpty;
    final hasSortSelected = _selectedSort != SortOption.none;
    final showContextBar = hasQuery || hasSortSelected;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          //  Search bar header
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppColors.headerGradientDark
                  : AppColors.headerGradientLight,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.primary,
                      size: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: searchBg,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.chipRadius,
                      ),
                      boxShadow: isDark
                          ? AppShadows.cardShadowDark
                          : AppShadows.cardShadowLight,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(Icons.search, color: subText, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _focusNode,
                            style: TextStyle(
                              color: textColor,
                              fontSize: AppFontSizes.sm,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search by Title, Author, Category…',
                              hintStyle: TextStyle(
                                color: subText,
                                fontSize: AppFontSizes.sm,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          GestureDetector(
                            onTap: () => _searchController.clear(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: subText,
                                size: 18,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _showSortDialog,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hasSortSelected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          color: hasSortSelected
                              ? Colors.white
                              : AppColors.primary,
                          size: 20,
                        ),
                        if (hasSortSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          //  Context bar
          if (showContextBar)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasQuery)
                          Text(
                            'Results for "$_query"',
                            style: TextStyle(
                              fontFamily: 'Playfair',
                              fontSize: AppFontSizes.md,
                              fontWeight: AppFontWeights.semiBold,
                              color: textColor,
                            ),
                          ),
                        if (hasSortSelected)
                          Padding(
                            padding: EdgeInsets.only(top: hasQuery ? 2 : 0),
                            child: Row(
                              children: [
                                Text(
                                  'Sorted by: ',
                                  style: TextStyle(
                                    fontSize: AppFontSizes.xs,
                                    color: subText,
                                  ),
                                ),
                                Text(
                                  _selectedSort.label,
                                  style: const TextStyle(
                                    fontSize: AppFontSizes.xs,
                                    color: AppColors.primary,
                                    fontWeight: AppFontWeights.semiBold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${results.length} book${results.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: AppFontSizes.xs,
                      color: subText,
                      fontWeight: AppFontWeights.medium,
                    ),
                  ),
                ],
              ),
            ),

          //  Results list
          Expanded(
            child: results.isEmpty
                ? _EmptyState(
                    query: _query,
                    textColor: textColor,
                    subText: subText,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final book = results[i];
                      return _SearchResultItem(
                        book: book,
                        isDark: isDark,
                        cardColor: cardColor,
                        textColor: textColor,
                        subText: subText,
                        onTap: () => _goToDetail(book),
                        onFavTap: () async {
                          await HiveService.toggleFavorite(book.id);
                          setState(() => _allBooks = HiveService.getAllBooks());
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

//  Search Result Item
class _SearchResultItem extends StatelessWidget {
  final BookModel book;
  final bool isDark;
  final Color cardColor;
  final Color textColor;
  final Color subText;
  final VoidCallback onTap;
  final VoidCallback onFavTap;

  const _SearchResultItem({
    required this.book,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
    required this.subText,
    required this.onTap,
    required this.onFavTap,
  });

  String _fmtCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 90,
                child: book.coverUrl.isNotEmpty
                    ? Image.network(
                        book.coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallback(),
                      )
                    : _fallback(),
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
                  const SizedBox(height: 6),
                  // Category chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: book.categories
                        .take(2)
                        .map(
                          (cat) => Container(
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
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                  // Download count
                  Row(
                    children: [
                      const Icon(
                        Icons.download_rounded,
                        color: AppColors.primary,
                        size: 13,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _fmtCount(book.downloadCount),
                        style: TextStyle(
                          fontSize: AppFontSizes.xs,
                          fontWeight: AppFontWeights.semiBold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        book.languages.join(', ').toUpperCase(),
                        style: TextStyle(
                          fontSize: AppFontSizes.xs,
                          color: subText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onFavTap,
              child: Icon(
                book.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: book.isFavorite ? Colors.red : subText,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Container(
    color: AppColors.primary.withValues(alpha: 0.15),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(6),
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
  );
}

//  Empty State
class _EmptyState extends StatelessWidget {
  final String query;
  final Color textColor;
  final Color subText;

  const _EmptyState({
    required this.query,
    required this.textColor,
    required this.subText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 72,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              query.isEmpty ? 'Search for books' : 'No results for "$query"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Playfair',
                fontSize: AppFontSizes.lg,
                fontWeight: AppFontWeights.semiBold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              query.isEmpty
                  ? 'Type a title, author, or category above'
                  : 'Try a different keyword or clear the search',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSizes.sm,
                color: subText,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
