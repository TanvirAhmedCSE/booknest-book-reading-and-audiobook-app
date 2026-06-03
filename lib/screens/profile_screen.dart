import 'package:flutter/material.dart';
import '../data/hive_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_mode.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _booksRead = 0;
  int _favorites = 0;
  int _booksListened = 0;
  int _inProgress = 0;
  double _totalReadingProgress = 0.0;
  double _totalListeningProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    final allBooks = HiveService.getAllBooks();
    final continueReading = HiveService.getContinueReading();
    final continueListening = HiveService.getContinueListening();

    // Reading progress average across in-progress books
    double readProg = 0.0;
    if (continueReading.isNotEmpty) {
      readProg =
          continueReading
              .map((b) => b.scrollOffset > 0 ? 0.5 : 0.0) // rough estimate
              .fold(0.0, (a, b) => a + b) /
          continueReading.length;
    }

    // Listening progress average across in-progress books
    double listenProg = 0.0;
    if (continueListening.isNotEmpty) {
      listenProg =
          continueListening
              .map((b) => b.listeningProgress)
              .fold(0.0, (a, b) => a + b) /
          continueListening.length;
    }

    setState(() {
      _booksRead = allBooks.where((b) => b.readingFinished).length;
      _booksListened = allBooks.where((b) => b.listeningFinished).length;
      _favorites = allBooks.where((b) => b.isFavorite).length;
      _inProgress = (continueReading.length + continueListening.length).clamp(
        0,
        999,
      );
      _totalReadingProgress = readProg;
      _totalListeningProgress = listenProg;
    });
  }

  //  Helpers
  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Playfair',
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
    width: 1,
    height: 36,
    color: Colors.white.withValues(alpha: 0.3),
  );

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? labelColor,
    bool isDark = false,
    required Color cardColor,
    required Color textColor,
    required Color subText,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark
              ? AppShadows.cardShadowDark
              : AppShadows.cardShadowLight,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? (isDark ? Colors.white : Colors.black87),
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Playfair',
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: labelColor ?? textColor,
              ),
            ),
            const Spacer(),
            trailing ?? Icon(Icons.chevron_right, color: subText, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _progressCard({
    required String label,
    required double progress,
    required IconData icon,
    required Color cardColor,
    required Color textColor,
    required Color subText,
    required bool isDark,
  }) {
    final pct = (progress * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? AppShadows.cardShadowDark
            : AppShadows.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Playfair',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
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
    final cardColor = isDark ? AppColors.darkCard : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          //  Header
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppColors.headerGradientDark
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF6B35), Color(0xFFFF9A6C)],
                      ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20,
                right: 20,
                bottom: 28,
              ),
              child: Column(
                children: [
                  // Top row: back + theme toggle
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Profile avatar
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/profile.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.white.withValues(alpha: 0.2),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Tanvir Ahmed',
                    style: TextStyle(
                      fontFamily: 'Playfair',
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'tanvir.ahmed@gmail.com',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _statItem(_booksRead.toString(), 'Books Read'),
                      _statDivider(),
                      _statItem(_booksListened.toString(), 'Listened'),
                      _statDivider(),
                      _statItem(_favorites.toString(), 'Favorites'),
                      _statDivider(),
                      _statItem(_inProgress.toString(), 'In Progress'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          //  Activity Progress
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity',
                    style: TextStyle(
                      fontFamily: 'Playfair',
                      fontWeight: FontWeight.w700,
                      fontSize: AppFontSizes.lg,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _progressCard(
                    label: 'Reading Progress',
                    progress: _totalReadingProgress,
                    icon: Icons.menu_book_rounded,
                    cardColor: cardColor,
                    textColor: textColor,
                    subText: subText,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _progressCard(
                    label: 'Listening Progress',
                    progress: _totalListeningProgress,
                    icon: Icons.headphones_rounded,
                    cardColor: cardColor,
                    textColor: textColor,
                    subText: subText,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          //  Settings / Menu
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontFamily: 'Playfair',
                      fontWeight: FontWeight.w700,
                      fontSize: AppFontSizes.lg,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Edit Profile
                  _menuItem(
                    icon: Icons.person_outline,
                    label: 'Edit Profile',
                    onTap: () {},
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                    subText: subText,
                  ),
                  const SizedBox(height: 10),

                  // Dark / Light Mode toggle
                  _menuItem(
                    icon: isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    label: isDark ? 'Light Mode' : 'Dark Mode',
                    onTap: () {
                      themeModeNotifier.toggleTheme();
                      setState(() {});
                    },
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                    subText: subText,
                    trailing: Switch(
                      value: isDark,
                      onChanged: (_) {
                        themeModeNotifier.toggleTheme();
                        setState(() {});
                      },
                      activeColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Notifications
                  _menuItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () {},
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                    subText: subText,
                  ),
                  const SizedBox(height: 10),

                  // Language
                  _menuItem(
                    icon: Icons.language_outlined,
                    label: 'Language',
                    onTap: () {},
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                    subText: subText,
                  ),
                  const SizedBox(height: 10),

                  // Help & Support
                  _menuItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () {},
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                    subText: subText,
                  ),
                  const SizedBox(height: 10),

                  // Privacy Policy
                  _menuItem(
                    icon: Icons.security_outlined,
                    label: 'Privacy Policy',
                    onTap: () {},
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                    subText: subText,
                  ),
                  const SizedBox(height: 10),

                  // Logout
                  _menuItem(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    onTap: () => _showLogoutDialog(context),
                    iconColor: Colors.red,
                    labelColor: Colors.red,
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                    subText: subText,
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.red.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final isDark = themeModeNotifier.isDark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout',
          style: TextStyle(
            fontFamily: 'Playfair',
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
