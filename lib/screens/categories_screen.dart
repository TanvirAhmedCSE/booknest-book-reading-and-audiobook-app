import 'package:flutter/material.dart';
import '../data/hive_service.dart';
import '../models/book_model.dart';
import '../theme/app_theme.dart';
import '../theme/app_mode.dart';
import 'all_categories_detail_screen.dart';
import 'category_detail_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<String> _categories = [];
  List<BookModel> _allBooks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _categories = HiveService.getAllCategories(); // includes 'All' at index 0
      _allBooks = HiveService.getAllBooks();
    });
  }

  int _bookCountForCategory(String category) {
    if (category == 'All') return _allBooks.length;
    return _allBooks
        .where(
          (b) => b.categories.any(
            (c) => c.toLowerCase() == category.toLowerCase(),
          ),
        )
        .length;
  }

  void _onCategoryTap(String category) {
    if (category == 'All') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AllCategoriesDetailScreen()),
      ).then((_) => _loadData());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryDetailScreen(category: category),
        ),
      ).then((_) => _loadData());
    }
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
                  'Categories',
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

          //  Category Grid
          Expanded(
            child: _categories.isEmpty
                ? Center(
                    child: Text(
                      'No categories yet.\nPull to refresh.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subText,
                        fontSize: AppFontSizes.md,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 150),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 2.2,
                        ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final count = _bookCountForCategory(category);
                      final isAll = category == 'All';
                      return GestureDetector(
                        onTap: () => _onCategoryTap(category),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isAll ? AppColors.primary : cardColor,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.cardRadius,
                            ),
                            boxShadow: isDark
                                ? AppShadows.cardShadowDark
                                : AppShadows.cardShadowLight,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isAll
                                    ? Icons.auto_stories
                                    : Icons.bookmark_border,
                                color: isAll ? Colors.white : AppColors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Playfair',
                                        fontWeight: AppFontWeights.bold,
                                        fontSize: AppFontSizes.md,
                                        color: isAll ? Colors.white : textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '($count)',
                                      style: TextStyle(
                                        fontSize: AppFontSizes.xs,
                                        color: isAll
                                            ? Colors.white.withValues(
                                                alpha: 0.8,
                                              )
                                            : subText,
                                        fontWeight: AppFontWeights.medium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: isAll
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : subText,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
