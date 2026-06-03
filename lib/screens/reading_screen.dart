import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import '../data/hive_service.dart';
import '../models/book_model.dart';
import '../theme/app_theme.dart';
import '../theme/app_mode.dart';
import '../theme/app_fonts.dart';
import 'listening_screen.dart';

class ReadingScreen extends StatefulWidget {
  final String bookId;
  const ReadingScreen({super.key, required this.bookId});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  late BookModel _book;

  String _selectedFont = 'Lora';

  //  Text/EPUB content
  String _plainText = '';
  bool _isLoading = true;
  String? _errorMsg;

  //  Scroll (for text mode)
  final ScrollController _scrollController = ScrollController();
  double _maxScrollExtent = 0;
  bool _isBookFinished = false;
  bool _showFinishButton = false;

  //  WebView (for HTML mode)
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _book = HiveService.getBook(widget.bookId)!;
    _selectedFont = HiveService.getReadingFont();
    _isBookFinished = _book.readingFinished;
    _loadContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  //  Content Loading
  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      if (_book.readFormat == 'html') {
        await _loadHtml();
      } else if (_book.readFormat == 'text') {
        await _loadPlainText();
      } else if (_book.readFormat == 'epub') {
        // EPUB: fallback — load as text if available, else show epub in webview
        await _loadEpubAsText();
      } else {
        setState(() {
          _errorMsg = 'No readable format available.';
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Failed to load content: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPlainText() async {
    final response = await http
        .get(Uri.parse(_book.textUrl))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      String text;
      try {
        text = utf8.decode(response.bodyBytes);
      } catch (_) {
        text = latin1.decode(response.bodyBytes);
      }
      setState(() {
        _plainText = text;
        _isLoading = false;
      });
      _restoreScrollPosition();
    } else {
      setState(() {
        _errorMsg = 'Failed to fetch text (${response.statusCode})';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEpubAsText() async {
    if (_book.textUrl.isNotEmpty) {
      await _loadPlainText();
    } else {
      await _loadHtml(urlOverride: _book.epubUrl);
    }
  }

  Future<void> _loadHtml({String? urlOverride}) async {
    final url = urlOverride ?? _book.htmlUrl;
    final isDark = themeModeNotifier.isDark;

    final controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ScrollTracker',
        onMessageReceived: (msg) {
          final offset = double.tryParse(msg.message) ?? 0.0;
          HiveService.saveReadingProgress(widget.bookId, scrollOffset: offset);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            await _injectHtmlStyles(controller, isDark);
            final offset = _book.scrollOffset;
            if (offset > 0) {
              await controller.runJavaScript('window.scrollTo(0, $offset);');
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {
      _webViewController = controller;
      _isLoading = false;
    });
  }

  /// Inject CSS + JS into the loaded HTML page for better reading experience.
  Future<void> _injectHtmlStyles(
    WebViewController controller,
    bool isDark,
  ) async {
    final bgColor = isDark ? '#0F0F1A' : '#F5F0EB';
    final textColor = isDark ? '#F0EDE8' : '#1A1A2E';
    final linkColor = isDark ? '#FF8C5A' : '#FF6B35';
    final codeBg = isDark ? '#1A1A2E' : '#EFE8DF';

    await controller.runJavaScript('''
(function() {
  // 1. Fix viewport: disable zoom, fit device width 
  var vp = document.querySelector("meta[name=viewport]");
  if (!vp) {
    vp = document.createElement("meta");
    vp.name = "viewport";
    document.head.appendChild(vp);
  }
  vp.content = "width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no";

  // 2. Inject reading styles 
  var existing = document.getElementById("_booknest_style");
  if (existing) existing.remove();
  var style = document.createElement("style");
  style.id = "_booknest_style";
  style.textContent = [
    "html { overflow-x: hidden !important; }",
    "body {",
    "  background-color: $bgColor !important;",
    "  color: $textColor !important;",
    "  font-size: 17px !important;",
    "  line-height: 1.85 !important;",
    "  width: 100% !important;",
    "  max-width: 100% !important;",
    "  padding: 20px 22px 80px 22px !important;",
    "  margin: 0 !important;",
    "  box-sizing: border-box !important;",
    "  overflow-x: hidden !important;",
    "  word-wrap: break-word !important;",
    "  overflow-wrap: break-word !important;",
    "  word-break: break-word !important;",
    "}",
    "*, *::before, *::after { box-sizing: border-box !important; }",
    "p, div, span, li, td, th, blockquote {",
    "  color: $textColor !important;",
    "  max-width: 100% !important;",
    "  overflow-wrap: break-word !important;",
    "  word-wrap: break-word !important;",
    "}",
    "h1,h2,h3,h4,h5,h6 {",
    "  color: $textColor !important;",
    "  margin-top: 1.4em !important;",
    "  margin-bottom: 0.5em !important;",
    "  word-wrap: break-word !important;",
    "}",
    "a { color: $linkColor !important; }",
    "img {",
    "  max-width: 100% !important;",
    "  width: auto !important;",
    "  height: auto !important;",
    "  display: block !important;",
    "  margin: 16px auto !important;",
    "  border-radius: 8px !important;",
    "}",
    "table {",
    "  max-width: 100% !important;",
    "  width: 100% !important;",
    "  overflow-x: auto !important;",
    "  display: block !important;",
    "  word-break: break-word !important;",
    "}",
    "pre, code {",
    "  white-space: pre-wrap !important;",
    "  word-break: break-all !important;",
    "  background: $codeBg !important;",
    "  padding: 2px 6px !important;",
    "  border-radius: 4px !important;",
    "  max-width: 100% !important;",
    "  overflow-x: hidden !important;",
    "}",
    "#pg-header, #pg-footer, .noprint, #sidebar { display: none !important; }",
  ].join(" ");
  document.head.appendChild(style);

  // 3. Scroll tracker (bind only once) 
  if (!window._booknestScrollBound) {
    window._booknestScrollBound = true;
    var lastSent = 0;
    window.addEventListener("scroll", function() {
      var now = Date.now();
      if (now - lastSent > 800) {
        lastSent = now;
        ScrollTracker.postMessage(String(Math.round(window.scrollY)));
      }
    }, { passive: true });
  }
})();
''');
  }

  void _restoreScrollPosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _book.scrollOffset > 0) {
        _scrollController.jumpTo(
          _book.scrollOffset.clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      }
      _scrollController.addListener(_onScroll);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;
    _maxScrollExtent = maxExtent;

    // Save progress
    HiveService.saveReadingProgress(widget.bookId, scrollOffset: offset);

    // Show finish button near bottom
    final atBottom = offset >= maxExtent - 20;
    if (atBottom && !_isBookFinished && !_showFinishButton) {
      setState(() => _showFinishButton = true);
    } else if (!atBottom && _showFinishButton) {
      setState(() => _showFinishButton = false);
    }
  }

  Future<void> _finishBook() async {
    await HiveService.markReadingFinished(widget.bookId);
    setState(() {
      _isBookFinished = true;
      _showFinishButton = false;
    });
    if (mounted) Navigator.of(context).pop();
  }

  //  Progress calculation
  double get _progressValue {
    if (_isBookFinished) return 1.0;
    if (_maxScrollExtent <= 0) return 0.0;
    final offset = _scrollController.hasClients
        ? _scrollController.offset
        : _book.scrollOffset;
    return (offset / _maxScrollExtent).clamp(0.0, 1.0);
  }

  String get _progressLabel {
    if (_isBookFinished) return 'Finished';
    final pct = (_progressValue * 100).toInt();
    return '$pct% read';
  }

  //  Font picker
  void _showFontPicker() {
    final isDark = themeModeNotifier.isDark;
    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.bottomSheetRadius),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: subText.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Text(
                  'Choose Font',
                  style: TextStyle(
                    fontFamily: 'Playfair',
                    fontWeight: AppFontWeights.bold,
                    fontSize: AppFontSizes.xl,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(sheetContext),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: subText.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: textColor, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...AppFontsList.readingFonts.map((font) {
              final isSelected = font['name'] == _selectedFont;
              return GestureDetector(
                onTap: () async {
                  setState(() => _selectedFont = font['name']!);
                  await HiveService.saveReadingFont(font['name']!);
                  Navigator.pop(sheetContext);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : subText.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              font['label']!,
                              style: TextStyle(
                                fontFamily: font['name'],
                                fontSize: AppFontSizes.lg,
                                color: isSelected
                                    ? AppColors.primary
                                    : textColor,
                                fontWeight: isSelected
                                    ? AppFontWeights.bold
                                    : AppFontWeights.regular,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'The quick brown fox...',
                              style: TextStyle(
                                fontFamily: font['name'],
                                fontSize: AppFontSizes.sm,
                                color: subText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 18,
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  //  Build
  @override
  Widget build(BuildContext context) {
    final isDark = themeModeNotifier.isDark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final navBar = isDark ? AppColors.darkNavBar : AppColors.lightNavBar;
    // HTML is now first priority; text is second; epub falls back to webview
    final isHtmlMode = _webViewController != null;
    final isTextMode = !isHtmlMode;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) return;
        // Save scroll on back
        if (_scrollController.hasClients) {
          await HiveService.saveReadingProgress(
            widget.bookId,
            scrollOffset: _scrollController.offset,
          );
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            //  App bar
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        if (_scrollController.hasClients) {
                          await HiveService.saveReadingProgress(
                            widget.bookId,
                            scrollOffset: _scrollController.offset,
                          );
                        }
                        if (mounted) Navigator.pop(context);
                      },
                      child: Icon(
                        Icons.chevron_left,
                        size: 30,
                        color: textColor,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Playfair',
                              fontWeight: AppFontWeights.semiBold,
                              fontSize: AppFontSizes.md,
                              color: textColor,
                            ),
                          ),
                          Text(
                            _progressLabel,
                            style: TextStyle(
                              fontSize: AppFontSizes.xs,
                              color: subText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.share_outlined, color: textColor, size: 22),
                  ],
                ),
              ),
            ),

            //  Content area
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading book…',
                            style: TextStyle(color: subText),
                          ),
                        ],
                      ),
                    )
                  : _errorMsg != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: subText),
                            const SizedBox(height: 12),
                            Text(
                              _errorMsg!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: subText),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        // Text/Epub mode
                        if (isTextMode)
                          SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
                            child: Text(
                              _plainText,
                              textAlign: TextAlign.justify,
                              style: TextStyle(
                                fontFamily: _selectedFont,
                                fontSize: AppFontSizes.md,
                                color: textColor,
                                height: 1.8,
                              ),
                            ),
                          ),
                        // HTML mode
                        if (!isTextMode && _webViewController != null)
                          WebViewWidget(controller: _webViewController!),
                        // Finish button
                        if (_showFinishButton && !_isBookFinished)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: _finishBook,
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF22C55E),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF22C55E,
                                        ).withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Done badge
                        if (_isBookFinished)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Done',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),

            //  Progress bar (text mode only)
            if (!_isLoading && _errorMsg == null && isTextMode)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 4,
                ),
                child: LinearProgressIndicator(
                  value: _progressValue,
                  backgroundColor: subText.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

            //  Bottom toolbar
            Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 8,
                top: 10,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                color: navBar,
                boxShadow: AppShadows.navBarShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Reading icon (active)
                  const Icon(
                    Icons.menu_book,
                    color: AppColors.primary,
                    size: 22,
                  ),

                  // Font button (only for text/epub mode)
                  if (isTextMode)
                    GestureDetector(
                      onTap: _showFontPicker,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: subText.withValues(alpha: 0.12),
                        ),
                        child: Center(
                          child: Text(
                            'A',
                            style: TextStyle(
                              fontSize: AppFontSizes.lg,
                              fontWeight: AppFontWeights.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Dark/light mode toggle
                  GestureDetector(
                    onTap: () async {
                      themeModeNotifier.toggleTheme();
                      setState(() {});
                      // Re-inject styles into WebView after theme change
                      if (_webViewController != null) {
                        await _injectHtmlStyles(
                          _webViewController!,
                          themeModeNotifier.isDark,
                        );
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: subText.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        isDark ? Icons.light_mode : Icons.dark_mode,
                        color: textColor,
                        size: 18,
                      ),
                    ),
                  ),

                  // Audio button (only if book has audio)
                  if (_book.hasAudio)
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ListeningScreen(bookId: widget.bookId),
                        ),
                      ),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: subText.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.headphones,
                          color: textColor,
                          size: 18,
                        ),
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
