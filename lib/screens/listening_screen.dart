import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../data/hive_service.dart';
import '../models/book_model.dart';
import '../theme/app_theme.dart';
import '../theme/app_mode.dart';
import 'reading_screen.dart';

class ListeningScreen extends StatefulWidget {
  final String bookId;
  final bool showBottomNav;

  const ListeningScreen({
    super.key,
    required this.bookId,
    this.showBottomNav = false,
  });

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen>
    with SingleTickerProviderStateMixin {
  late BookModel _book;
  late AnimationController _pulseController;

  final AudioPlayer _player = AudioPlayer();

  //  Chapter list
  List<AudioChapter> _chapters = [];
  bool _chaptersLoading = true;
  int _currentChapterIndex = 0;

  //  Playback state
  double _uiPosition = 0.0;
  double _chapterDuration = 0.0;
  bool _isDragging = false;
  double _dragPosition = 0.0;

  static const List<String> _cdnNodes = [
    'ia800107.us.archive.org', // this one is at first
    'ia600107.us.archive.org',
    'dn721301.us.archive.org',
    'dn720901.us.archive.org',
    'dn710107.ca.archive.org',
    'dn720101.ca.archive.org',
  ];

  //  Loading state for chapter switch
  bool _chapterLoading = false;

  //  Playback speed
  double _playbackSpeed = 1.0;
  static const List<double> _speedOptions = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  //  Total audiobook progress
  double _totalListenedSeconds = 0.0;
  double _totalAudioSeconds = 0.0;

  // Stream subscriptions — cancelled on each new chapter load
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _book = HiveService.getBook(widget.bookId)!;
    _currentChapterIndex = _book.currentAudioChapter;
    _uiPosition = _book.currentAudioPosition;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _loadChapters();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _player.playerStateStream.listen((state) {
      debugPrint('Player state: ${state.processingState}');
    });

    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        debugPrint('Playback error: $e');
      },
    );
  }

  //  archive.org URL -> CDN URL transform
  String _toCdnUrl(String originalUrl, String node) {
    return originalUrl.replaceFirst(
      RegExp(r'https?://(www\.)?archive\.org/download/'),
      'https://$node/0/items/',
    );
  }

  Future<String?> _findWorkingUrl(String originalUrl) async {
    final urlsToTry = _cdnNodes
        .map((node) => _toCdnUrl(originalUrl, node))
        .toList();

    for (final url in urlsToTry) {
      debugPrint('Trying URL: $url');
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 8);

        final request = await client.headUrl(Uri.parse(url));
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        );
        request.headers.set('Referer', 'https://archive.org/');

        final response = await request.close();
        await response.drain();
        client.close();

        debugPrint('Status for $url: ${response.statusCode}');

        if (response.statusCode == 200) {
          debugPrint('Working URL found: $url');
          return url;
        }
      } catch (e) {
        debugPrint('Error for $url: $e');
      }
    }

    debugPrint('All URLs failed for: $originalUrl');
    return null;
  }

  Future<void> _loadChapters() async {
    if (_book.rssUrl == null || _book.rssUrl!.isEmpty) {
      setState(() => _chaptersLoading = false);
      return;
    }
    final chapters = await HiveService.fetchChaptersFromRss(_book.rssUrl!);
    if (!mounted) return;

    double total = 0;
    for (final ch in chapters) {
      total += ch.durationSeconds;
    }

    if (_book.totalAudioSeconds <= 0 && total > 0) {
      await HiveService.saveTotalAudioSeconds(widget.bookId, total);
    }

    setState(() {
      _chapters = chapters;
      _totalAudioSeconds = total > 0 ? total : _book.totalAudioSeconds;
      _chaptersLoading = false;
    });

    _recalcListened();

    if (chapters.isNotEmpty) {
      final idx = _currentChapterIndex.clamp(0, chapters.length - 1);
      await _loadChapterAudio(
        idx,
        seekTo: idx == _currentChapterIndex ? _uiPosition : 0.0,
      );
    }
  }

  void _recalcListened() {
    double total = 0;
    for (final entry in _book.chapterListenedSeconds.entries) {
      total += entry.value;
    }
    setState(() => _totalListenedSeconds = total);
  }

  Future<void> _loadChapterAudio(int index, {double seekTo = 0.0}) async {
    if (_chapters.isEmpty || index >= _chapters.length) return;
    final chapter = _chapters[index];

    if (mounted) {
      setState(() {
        _chapterLoading = true;
        _currentChapterIndex = index;
        _uiPosition = seekTo;
      });
    }

    try {
      await _posSub?.cancel();
      await _stateSub?.cancel();
      await _player.stop();

      final workingUrl = await _findWorkingUrl(chapter.audioUrl);
      if (workingUrl == null) {
        debugPrint('No working URL found: ${chapter.audioUrl}');
        if (mounted) setState(() => _chapterLoading = false);
        return;
      }

      Duration? duration;
      try {
        duration = await _player
            .setUrl(workingUrl)
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('Audio load error: $e');
        if (mounted) setState(() => _chapterLoading = false);
        return;
      }

      double resolvedDuration = duration?.inSeconds.toDouble() ?? 0.0;
      if (resolvedDuration <= 0) {
        resolvedDuration = chapter.durationSeconds;
      }

      await _player.setSpeed(_playbackSpeed);

      if (seekTo > 0 && seekTo < resolvedDuration) {
        await _player.seek(Duration(milliseconds: (seekTo * 1000).toInt()));
      }

      if (mounted) {
        setState(() {
          _currentChapterIndex = index;
          _uiPosition = seekTo;
          _chapterDuration = resolvedDuration;
          _chapterLoading = false;
        });
      }

      // Position stream listener
      _posSub = _player.positionStream.listen((pos) {
        if (!_isDragging && mounted) {
          final posSeconds = pos.inMilliseconds / 1000.0;
          setState(() => _uiPosition = posSeconds);
          HiveService.saveAudioProgress(
            widget.bookId,
            chapterIndex: _currentChapterIndex,
            positionSeconds: posSeconds,
            chapterDurationSeconds: _chapterDuration,
          );
          final key = _currentChapterIndex.toString();
          final existing = _book.chapterListenedSeconds[key] ?? 0.0;
          if (posSeconds > existing) {
            _book.chapterListenedSeconds[key] = posSeconds;
            _recalcListened();
          }
        }
      });

      // State stream listener — auto next chapter
      _stateSub = _player.playerStateStream.listen((state) async {
        if (state.processingState == ProcessingState.completed && mounted) {
          final key = _currentChapterIndex.toString();
          _book.chapterListenedSeconds[key] = _chapterDuration;
          _recalcListened();
          await HiveService.saveAudioProgress(
            widget.bookId,
            chapterIndex: _currentChapterIndex,
            positionSeconds: _chapterDuration,
            chapterDurationSeconds: _chapterDuration,
          );
          if (_currentChapterIndex < _chapters.length - 1) {
            final next = _currentChapterIndex + 1;
            await _loadChapterAudio(next, seekTo: 0.0);
            _player.play();
          } else {
            await HiveService.markListeningFinished(widget.bookId);
            setState(() => _uiPosition = 0.0);
          }
        }
      });
    } catch (e) {
      debugPrint('_loadChapterAudio error: $e');
      if (mounted) setState(() => _chapterLoading = false);
    }
  }

  Future<void> _saveAndPop() async {
    await _player.pause();
    await HiveService.saveAudioProgress(
      widget.bookId,
      chapterIndex: _currentChapterIndex,
      positionSeconds: _uiPosition,
      chapterDurationSeconds: _chapterDuration,
    );
    await _player.dispose();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _pulseController.dispose();
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
    setState(() {});
  }

  void _seek(double seconds) {
    final newPos = (_uiPosition + seconds).clamp(0.0, _chapterDuration);
    setState(() => _uiPosition = newPos);
    _player.seek(Duration(milliseconds: (newPos * 1000).toInt()));
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _playbackSpeed = speed);
    await _player.setSpeed(speed);
  }

  void _showSpeedPicker(BuildContext context) {
    final isDark = themeModeNotifier.isDark;
    final bg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.bottomSheetRadius),
        ),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: subText.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Playback Speed',
              style: TextStyle(
                fontFamily: 'Playfair',
                fontWeight: AppFontWeights.bold,
                fontSize: AppFontSizes.lg,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _speedOptions.map((speed) {
                final isSelected = speed == _playbackSpeed;
                final label = speed == speed.truncate()
                    ? '${speed.toInt()}×'
                    : '${speed}×';
                return GestureDetector(
                  onTap: () {
                    _setSpeed(speed);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.chipRadius,
                      ),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: AppFontSizes.sm,
                        fontWeight: AppFontWeights.semiBold,
                        color: isSelected ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(double seconds) {
    final total = seconds.toInt();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _listeningProgress {
    if (_totalAudioSeconds <= 0) return 0.0;
    return (_totalListenedSeconds / _totalAudioSeconds).clamp(0.0, 1.0);
  }

  bool _isChapterDone(int index) {
    if (index >= _chapters.length) return false;
    final key = index.toString();
    final listened = _book.chapterListenedSeconds[key] ?? 0.0;
    final duration = _chapters[index].durationSeconds;
    if (duration <= 0) return false;
    return listened >= duration * 0.95;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeModeNotifier.isDark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final navBar = isDark ? AppColors.darkNavBar : AppColors.lightNavBar;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    final isPlaying = _player.playing;
    final currentChapter =
        _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
        ? _chapters[_currentChapterIndex]
        : null;

    final speedLabel = _playbackSpeed == _playbackSpeed.truncate()
        ? '${_playbackSpeed.toInt()}×'
        : '${_playbackSpeed}×';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _saveAndPop();
      },
      child: Scaffold(
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
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _saveAndPop,
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
                                  currentChapter != null
                                      ? 'Chapter ${currentChapter.episode}'
                                      : _book.authors,
                                  style: TextStyle(
                                    fontSize: AppFontSizes.xs,
                                    color: subText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.share_outlined,
                            color: textColor,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 180,
                      margin: const EdgeInsets.symmetric(horizontal: 60),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppShadows.bookShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _book.coverUrl.isNotEmpty
                            ? Image.network(
                                _book.coverUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => _coverFallback(),
                              )
                            : _coverFallback(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            //  Playback controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3.0,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7.0,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14.0,
                      ),
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: subText.withValues(alpha: 0.25),
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _isDragging
                          ? _dragPosition.clamp(
                              0.0,
                              _chapterDuration > 0 ? _chapterDuration : 1.0,
                            )
                          : _uiPosition.clamp(
                              0.0,
                              _chapterDuration > 0 ? _chapterDuration : 1.0,
                            ),
                      min: 0,
                      max: _chapterDuration > 0 ? _chapterDuration : 1.0,
                      onChangeStart: (v) => setState(() {
                        _isDragging = true;
                        _dragPosition = v;
                      }),
                      onChanged: (v) => setState(() {
                        _uiPosition = v;
                        _dragPosition = v;
                      }),
                      onChangeEnd: (v) async {
                        setState(() {
                          _uiPosition = v;
                          _isDragging = false;
                        });
                        await _player.seek(
                          Duration(milliseconds: (v * 1000).toInt()),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(_uiPosition),
                          style: TextStyle(
                            fontSize: AppFontSizes.xs,
                            color: subText,
                          ),
                        ),
                        Text(
                          _chapterDuration > 0
                              ? _formatTime(_chapterDuration)
                              : (currentChapter != null
                                    ? currentChapter.formattedDuration
                                    : '00:00'),
                          style: TextStyle(
                            fontSize: AppFontSizes.xs,
                            color: subText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    '${(_listeningProgress * 100).toInt()}% of audiobook listened',
                    style: TextStyle(fontSize: AppFontSizes.xs, color: subText),
                  ),

                  const SizedBox(height: 16),

                  // Play / skip controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _seek(-10),
                        child: Icon(
                          Icons.fast_rewind,
                          color: textColor,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 32),
                      GestureDetector(
                        onTap: _chapterLoading ? null : _togglePlay,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, child) => Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: textColor,
                              boxShadow: [
                                BoxShadow(
                                  color: textColor.withValues(
                                    alpha: isPlaying
                                        ? 0.25 * _pulseController.value
                                        : 0.0,
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                            child: _chapterLoading
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                      color: bg,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: bg,
                                    size: 32,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                      GestureDetector(
                        onTap: () => _seek(10),
                        child: Icon(
                          Icons.fast_forward,
                          color: textColor,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            //  Chapter list
            Expanded(
              child: _chaptersLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _chapters.isEmpty
                  ? Center(
                      child: Text(
                        'No chapters available',
                        style: TextStyle(color: subText),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _chapters.length,
                      itemBuilder: (context, i) {
                        final chapter = _chapters[i];
                        final isSelected = i == _currentChapterIndex;
                        final isDone = _isChapterDone(i);
                        final listenedSec =
                            _book.chapterListenedSeconds[i.toString()] ?? 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.4)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isDone
                                    ? Colors.red.withValues(alpha: 0.15)
                                    : isSelected
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : subText.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: isDone
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.red,
                                        size: 14,
                                      )
                                    : Text(
                                        '${chapter.episode}',
                                        style: TextStyle(
                                          fontSize: AppFontSizes.xs,
                                          fontWeight: AppFontWeights.semiBold,
                                          color: isSelected
                                              ? AppColors.primary
                                              : subText,
                                        ),
                                      ),
                              ),
                            ),
                            title: Text(
                              chapter.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppFontSizes.sm,
                                fontWeight: isSelected
                                    ? AppFontWeights.semiBold
                                    : AppFontWeights.regular,
                                color: isSelected
                                    ? AppColors.primary
                                    : textColor,
                              ),
                            ),
                            subtitle: isDone
                                ? Text(
                                    'Done',
                                    style: TextStyle(
                                      fontSize: AppFontSizes.xs,
                                      color: Colors.red,
                                      fontWeight: AppFontWeights.semiBold,
                                    ),
                                  )
                                : listenedSec > 0 && !isDone
                                ? Text(
                                    '${_formatTime(listenedSec)} / ${chapter.formattedDuration}',
                                    style: TextStyle(
                                      fontSize: AppFontSizes.xs,
                                      color: subText,
                                    ),
                                  )
                                : Text(
                                    chapter.formattedDuration,
                                    style: TextStyle(
                                      fontSize: AppFontSizes.xs,
                                      color: subText,
                                    ),
                                  ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected)
                                  GestureDetector(
                                    onTap: () => _showSpeedPicker(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.35,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        speedLabel,
                                        style: const TextStyle(
                                          fontSize: AppFontSizes.xs,
                                          fontWeight: AppFontWeights.semiBold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Play/Pause button per chapter
                                GestureDetector(
                                  onTap: _chapterLoading
                                      ? null
                                      : () async {
                                          if (isSelected) {
                                            _togglePlay();
                                          } else {
                                            await _loadChapterAudio(
                                              i,
                                              seekTo: listenedSec > 0 && !isDone
                                                  ? listenedSec
                                                  : 0.0,
                                            );
                                            if (mounted) {
                                              await _player.play();
                                              setState(() {});
                                            }
                                          }
                                        },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withValues(
                                              alpha: 0.15,
                                            )
                                          : subText.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: _chapterLoading && isSelected
                                        ? Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: CircularProgressIndicator(
                                              color: AppColors.primary,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(
                                            isSelected && isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            color: isSelected
                                                ? AppColors.primary
                                                : subText,
                                            size: 18,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            //  Bottom toolbar
            Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 8,
                top: 10,
                left: 32,
                right: 32,
              ),
              decoration: BoxDecoration(
                color: navBar,
                boxShadow: AppShadows.navBarShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_book.readFormat.isNotEmpty)
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReadingScreen(bookId: widget.bookId),
                        ),
                      ),
                      child: Icon(Icons.menu_book, color: subText, size: 22),
                    )
                  else
                    Icon(
                      Icons.menu_book,
                      color: subText.withValues(alpha: 0.3),
                      size: 22,
                    ),
                  GestureDetector(
                    onTap: () {
                      themeModeNotifier.toggleTheme();
                      setState(() {});
                    },
                    child: Icon(
                      isDark ? Icons.light_mode : Icons.dark_mode,
                      color: subText,
                      size: 22,
                    ),
                  ),
                  const Icon(
                    Icons.headphones,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.2),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _book.title,
            textAlign: TextAlign.center,
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
}
