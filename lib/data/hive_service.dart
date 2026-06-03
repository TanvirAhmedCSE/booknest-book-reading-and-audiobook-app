import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/book_model.dart';

class HiveService {
  static const String _booksBox = 'books_v2';
  static const String _settingsBox = 'settings';
  // Maps gutenberg book id (int as String) -> LibriVox rss url
  static const String _audioMapBox = 'audio_map';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(BookModelAdapter());
    await Hive.openBox<BookModel>(_booksBox);
    await Hive.openBox(_settingsBox);
    await Hive.openBox<String>(_audioMapBox);
  }

  static Box<BookModel> get _box => Hive.box<BookModel>(_booksBox);
  static Box get _settings => Hive.box(_settingsBox);
  static Box<String> get _audioMap => Hive.box<String>(_audioMapBox);

  //  Gutendex API
  static const String _gutendexBase = 'https://gutendex.com/books';

  static Future<List<BookModel>> fetchAndStoreBooks({
    String sort = 'popular',
    int page = 1,
  }) async {
    final uri = Uri.parse('$_gutendexBase/?sort=$sort&page=$page');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? [];

      // If the API returns an empty results array we have passed the last page.
      if (results.isEmpty) return [];

      final books = <BookModel>[];
      for (final item in results) {
        final book = _parseGutendexBook(item as Map<String, dynamic>);
        if (book == null) continue;

        // Preserve existing user data if this book is already cached.
        final existing = _box.get(book.id);
        if (existing != null) {
          book.isFavorite = existing.isFavorite;
          book.scrollOffset = existing.scrollOffset;
          book.epubChapterIndex = existing.epubChapterIndex;
          book.lastReadAt = existing.lastReadAt;
          book.readingFinished = existing.readingFinished;
          book.rssUrl = existing.rssUrl;
          book.currentAudioChapter = existing.currentAudioChapter;
          book.currentAudioPosition = existing.currentAudioPosition;
          book.chapterListenedSeconds = existing.chapterListenedSeconds;
          book.totalAudioSeconds = existing.totalAudioSeconds;
          book.lastListenedAt = existing.lastListenedAt;
          book.listeningFinished = existing.listeningFinished;
        }

        // Apply LibriVox audio mapping if available and not already set.
        // This works whether the mapping was built before or after this fetch.
        final mappedRss = _audioMap.get(book.id);
        if (mappedRss != null && mappedRss.isNotEmpty) {
          book.rssUrl = mappedRss;
        }

        await _box.put(book.id, book);
        books.add(book);
      }
      return books;
    } catch (e) {
      debugPrint('Gutendex fetch error (sort=$sort page=$page): $e');
      return [];
    }
  }

  static Future<FetchResult> fetchAndStoreBooksWithStatus({
    String sort = 'popular',
    int page = 1,
  }) async {
    final uri = Uri.parse('$_gutendexBase/?sort=$sort&page=$page');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        return FetchResult(books: [], networkError: true);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? [];
      if (results.isEmpty) {
        return FetchResult(books: [], networkError: false); // Real last page
      }
      final stored = await fetchAndStoreBooks(sort: sort, page: page);
      return FetchResult(books: stored, networkError: false);
    } catch (e) {
      debugPrint('Gutendex fetch error (sort=$sort page=$page): $e');
      return FetchResult(books: [], networkError: true); // Net off or timeout
    }
  }

  // Fetch multiple pages from Gutendex for a given sort order.
  static Future<void> fetchAndStoreBooksMultiPage({
    String sort = 'popular',
    int pages = 5,
  }) async {
    for (int page = 1; page <= pages; page++) {
      await fetchAndStoreBooks(sort: sort, page: page);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  static BookModel? _parseGutendexBook(Map<String, dynamic> item) {
    try {
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty) return null;
      final title = item['title'] as String? ?? '';

      // Authors
      final authorsList = (item['authors'] as List?) ?? [];
      final authors = authorsList
          .map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .join(', ');

      // Categories from bookshelves — strip "Category: " prefix
      final bookshelves = (item['bookshelves'] as List?) ?? [];
      final categories = bookshelves
          .map((b) {
            final s = b.toString();
            return s.startsWith('Category: ') ? s.substring(10) : s;
          })
          .where((c) => c.isNotEmpty)
          .toList();

      // About from summaries
      final summaries = (item['summaries'] as List?) ?? [];
      final about = summaries.isNotEmpty ? summaries[0].toString() : '';

      final downloadCount = (item['download_count'] as num?)?.toInt() ?? 0;

      final formats = (item['formats'] as Map<String, dynamic>?) ?? {};
      final coverUrl = formats['image/jpeg'] as String? ?? '';
      final epubUrl = formats['application/epub+zip'] as String? ?? '';
      // Prefer utf-8 plain text
      final textUrl =
          (formats['text/plain; charset=utf-8'] as String?) ??
          (formats['text/plain; charset=us-ascii'] as String?) ??
          '';
      final htmlUrl = formats['text/html'] as String? ?? '';

      final languages = ((item['languages'] as List?) ?? []).cast<String>();
      final copyright = item['copyright'] as bool? ?? false;

      return BookModel(
        id: id,
        title: title,
        authors: authors,
        categories: categories,
        about: about,
        downloadCount: downloadCount,
        coverUrl: coverUrl,
        epubUrl: epubUrl,
        textUrl: textUrl,
        htmlUrl: htmlUrl,
        languages: languages.isEmpty ? ['en'] : languages,
        copyright: copyright,
      );
    } catch (e) {
      debugPrint('Parse error: $e');
      return null;
    }
  }

  // Fetch a single book by Gutendex id and update Hive.
  static Future<BookModel?> fetchBookById(String id) async {
    try {
      final response = await http
          .get(Uri.parse('$_gutendexBase/$id'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final book = _parseGutendexBook(data);
      if (book == null) return null;
      final existing = _box.get(book.id);
      if (existing != null) {
        book.isFavorite = existing.isFavorite;
        book.scrollOffset = existing.scrollOffset;
        book.epubChapterIndex = existing.epubChapterIndex;
        book.lastReadAt = existing.lastReadAt;
        book.readingFinished = existing.readingFinished;
        book.rssUrl = existing.rssUrl;
        book.currentAudioChapter = existing.currentAudioChapter;
        book.currentAudioPosition = existing.currentAudioPosition;
        book.chapterListenedSeconds = existing.chapterListenedSeconds;
        book.totalAudioSeconds = existing.totalAudioSeconds;
        book.lastListenedAt = existing.lastListenedAt;
        book.listeningFinished = existing.listeningFinished;
      }
      final mappedRss = _audioMap.get(book.id);
      if (mappedRss != null && mappedRss.isNotEmpty) {
        book.rssUrl = mappedRss;
      }
      await _box.put(book.id, book);
      return book;
    } catch (e) {
      debugPrint('fetchBookById error: $e');
      return null;
    }
  }

  //  LibriVox Mapping
  static const String _librivoxApiBase =
      'https://librivox.org/api/feed/audiobooks/?format=json'
      '&fields={url_text_source,url_rss}&limit=500&offset=';

  static final RegExp _gutenbergIdPattern = RegExp(
    r'gutenberg\.org/(?:etext|ebooks)/(\d+)',
    caseSensitive: false,
  );

  // Build (or resume building) the Gutenberg-ID → LibriVox-RSS-URL mapping.
  static Future<void> buildLibriVoxMappingIfNeeded() async {
    final done =
        _settings.get('librivox_mapping_done', defaultValue: false) as bool;
    if (done) {
      // Mapping is complete — just ensure any newly fetched Gutendex books
      // also get their rssUrl applied (cheap, in-memory pass).
      await _applyAudioMapToAllBooks();
      return;
    }

    // Resume from the last saved offset (in case of a previous partial run).
    final resumeOffset =
        _settings.get('librivox_mapping_offset', defaultValue: 0) as int;
    debugPrint(
      'Building LibriVox mapping… (resuming from offset $resumeOffset)',
    );

    int offset = resumeOffset;
    bool hasMore = true;
    int totalMapped = 0;

    while (hasMore) {
      try {
        final uri = Uri.parse('$_librivoxApiBase$offset');
        final response = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 30));

        if (response.statusCode != 200) {
          debugPrint('LibriVox HTTP ${response.statusCode} at offset $offset');
          // Save progress and stop — will resume next launch.
          await _settings.put('librivox_mapping_offset', offset);
          break;
        }

        final raw = response.body.trim();
        List<dynamic>? books;

        // Try JSON first
        if (raw.startsWith('{') || raw.startsWith('[')) {
          try {
            final data = jsonDecode(raw);
            if (data is Map) {
              books = data['books'] as List?;
            } else if (data is List) {
              books = data;
            }
          } catch (_) {
            books = null;
          }
        }

        // Fall back to XML if JSON failed
        if (books == null && (raw.startsWith('<') || raw.contains('<books>'))) {
          books = _parseLibriVoxXml(raw);
        }

        if (books == null || books.isEmpty) {
          debugPrint(
            'LibriVox: no books at offset $offset — mapping complete.',
          );
          hasMore = false;
          break;
        }

        // Parse this batch and write to audioMap
        int batchMapped = 0;
        for (final b in books) {
          final book = b as Map<String, dynamic>;
          final urlTextSource = book['url_text_source'] as String? ?? '';
          final rssUrl = book['url_rss'] as String? ?? '';
          if (rssUrl.isEmpty || urlTextSource.isEmpty) continue;

          final match = _gutenbergIdPattern.firstMatch(urlTextSource);
          if (match == null) continue;

          final gutenbergId = match.group(1)!;
          // Only write if not already stored (avoids unnecessary disk writes)
          if (_audioMap.get(gutenbergId) == null) {
            await _audioMap.put(gutenbergId, rssUrl);
            batchMapped++;
          }
          totalMapped++;
        }

        if (batchMapped > 0) {
          await _applyAudioMapToAllBooks();
        }

        offset += 500;
        // Save progress so we can resume if interrupted
        await _settings.put('librivox_mapping_offset', offset);

        if (books.length < 500) {
          hasMore = false; // Last page
        }

        // Polite delay between API calls
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint('LibriVox fetch error at offset $offset: $e');
        await _settings.put('librivox_mapping_offset', offset);
        // Try next batch rather than stopping entirely
        offset += 500;
        if (offset > 25000) break; // Safety limit (LibriVox has ~20,648 books)
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Mark as complete and clear the resume offset
    await _settings.put('librivox_mapping_done', true);
    await _settings.put('librivox_mapping_offset', 0);
    debugPrint(
      'LibriVox mapping complete: $totalMapped entries processed, '
      '${_audioMap.length} unique IDs in cache.',
    );

    // Final pass: apply to everything in Hive
    await _applyAudioMapToAllBooks();
  }

  // Apply the audio map to every book in Hive that doesn't yet have an rssUrl.
  // Called after each batch and after the full mapping is done.
  static Future<void> _applyAudioMapToAllBooks() async {
    for (final book in _box.values) {
      if (book.rssUrl != null && book.rssUrl!.isNotEmpty) continue;
      final rss = _audioMap.get(book.id);
      if (rss != null && rss.isNotEmpty) {
        book.rssUrl = rss;
        await book.save();
      }
    }
  }

  // Parse LibriVox XML response into a list of book maps.
  static List<Map<String, dynamic>> _parseLibriVoxXml(String xmlStr) {
    final result = <Map<String, dynamic>>[];
    try {
      final document = XmlDocument.parse(xmlStr);
      final bookElements = document.findAllElements('book');
      for (final bookEl in bookElements) {
        final urlTextSource =
            bookEl.findElements('url_text_source').firstOrNull?.innerText ?? '';
        final urlRss =
            bookEl.findElements('url_rss').firstOrNull?.innerText ?? '';
        if (urlTextSource.isNotEmpty || urlRss.isNotEmpty) {
          result.add({'url_text_source': urlTextSource, 'url_rss': urlRss});
        }
      }
    } catch (e) {
      debugPrint('LibriVox XML parse error: $e');
    }
    return result;
  }

  // Force-rebuild the LibriVox mapping (e.g. after a reset or update).
  static Future<void> rebuildLibriVoxMapping() async {
    await _settings.put('librivox_mapping_done', false);
    await _settings.put('librivox_mapping_offset', 0);
    await _audioMap.clear();
    await buildLibriVoxMappingIfNeeded();
  }

  //  Audio chapter fetching
  // Parse RSS feed for a book and return chapter list.
  static Future<List<AudioChapter>> fetchChaptersFromRss(String rssUrl) async {
    return _fetchChaptersFromRssFallback(rssUrl);
  }

  static String? _extractLibriVoxProjectId(String rssUrl) {
    try {
      final uri = Uri.parse(rssUrl);
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[segments.length - 2] == 'rss') {
        return segments.last;
      }
      final trimmed = rssUrl.trimRight().replaceAll(RegExp(r'/$'), '');
      final match = RegExp(r'/rss/(\d+)$').firstMatch(trimmed);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  // Fetch chapters using the LibriVox Audiotracks API.
  static Future<List<AudioChapter>> _fetchChaptersFromAudiotracksApi(
    String projectId,
  ) async {
    try {
      final url =
          'https://librivox.org/api/feed/audiotracks?project_id=$projectId&format=json';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body);
      final sections = json['sections'] as List<dynamic>?;
      if (sections == null || sections.isEmpty) return [];

      final chapters = <AudioChapter>[];
      for (final s in sections) {
        final title = (s['title'] as String? ?? '').trim();
        final episode =
            int.tryParse(s['section_number']?.toString() ?? '') ??
            (chapters.length + 1);
        final audioUrl = (s['listen_url'] as String? ?? '').trim();
        final playtime = (s['playtime'] as String? ?? '').trim();
        final durationSeconds = _parseDuration(playtime);

        if (audioUrl.isNotEmpty) {
          chapters.add(
            AudioChapter(
              index: chapters.length,
              episode: episode,
              title: title.isNotEmpty ? title : 'Chapter $episode',
              audioUrl: audioUrl,
              durationSeconds: durationSeconds,
            ),
          );
        }
      }
      return chapters;
    } catch (e) {
      debugPrint('Audiotracks API error: $e');
      return [];
    }
  }

  // RSS parser: namespace-aware so itunes:episode / itunes:duration
  // are matched correctly regardless of prefix.
  static Future<List<AudioChapter>> _fetchChaptersFromRssFallback(
    String rssUrl,
  ) async {
    try {
      final response = await http
          .get(Uri.parse(rssUrl))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return [];

      final document = XmlDocument.parse(response.body);
      final items = document.findAllElements('item');
      final chapters = <AudioChapter>[];

      for (final item in items) {
        final title =
            item.findElements('title').firstOrNull?.innerText.trim() ?? '';

        final episodeText = item.descendants
            .whereType<XmlElement>()
            .firstWhere(
              (e) => e.localName == 'episode',
              orElse: () => XmlElement(XmlName('_empty')),
            )
            .innerText
            .trim();
        final episode = int.tryParse(episodeText) ?? (chapters.length + 1);

        String audioUrl = '';
        final enclosure = item.findElements('enclosure').firstOrNull;
        if (enclosure != null) {
          audioUrl = enclosure.getAttribute('url') ?? '';
        }
        if (audioUrl.isEmpty) {
          audioUrl =
              item.descendants
                  .whereType<XmlElement>()
                  .firstWhere(
                    (e) => e.localName == 'content',
                    orElse: () => XmlElement(XmlName('_empty')),
                  )
                  .getAttribute('url') ??
              '';
        }

        final durationText = item.descendants
            .whereType<XmlElement>()
            .firstWhere(
              (e) => e.localName == 'duration',
              orElse: () => XmlElement(XmlName('_empty')),
            )
            .innerText
            .trim();
        final durationSeconds = _parseDuration(durationText);

        if (audioUrl.isNotEmpty) {
          chapters.add(
            AudioChapter(
              index: chapters.length,
              episode: episode,
              title: title.isNotEmpty ? title : 'Chapter $episode',
              audioUrl: audioUrl,
              durationSeconds: durationSeconds,
            ),
          );
        }
      }

      return chapters;
    } catch (e) {
      debugPrint('RSS fallback parse error: $e');
      return [];
    }
  }

  static double _parseDuration(String text) {
    final parts = text.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return (h * 3600 + m * 60 + s).toDouble();
    } else if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return (m * 60 + s).toDouble();
    }
    return 0.0;
  }

  //  Get all books
  static List<BookModel> getAllBooks() => _box.values.toList();

  static BookModel? getBook(String id) => _box.get(id);

  static List<BookModel> getBooksByCategory(String category) {
    return _box.values
        .where(
          (b) => b.categories.any(
            (c) => c.toLowerCase() == category.toLowerCase(),
          ),
        )
        .toList();
  }

  //  Popular: sorted by downloadCount desc
  static List<BookModel> getPopular({int limit = 8}) {
    final all = _box.values.toList();
    all.sort((a, b) => b.downloadCount.compareTo(a.downloadCount));
    return all.take(limit).toList();
  }

  //  Recently added: sorted by id desc (largest id = newest)
  static List<BookModel> getRecentlyAdded({int limit = 8}) {
    final all = _box.values.toList();
    all.sort((a, b) {
      final aId = int.tryParse(a.id) ?? 0;
      final bId = int.tryParse(b.id) ?? 0;
      return bId.compareTo(aId);
    });
    return all.take(limit).toList();
  }

  //  Recommended: based on categories of read/listened books
  static List<BookModel> getRecommended({int limit = 8}) {
    final all = _box.values.toList();

    final interactedCategories = <String>{};
    for (final b in all) {
      final hasReadActivity = b.scrollOffset > 0 || b.readingFinished;
      final hasListenActivity =
          b.currentAudioPosition > 0 || b.listeningFinished;
      if (hasReadActivity || hasListenActivity) {
        interactedCategories.addAll(b.categories);
      }
    }

    List<BookModel> candidates;
    if (interactedCategories.isNotEmpty) {
      candidates = all
          .where(
            (b) =>
                b.categories.any((c) => interactedCategories.contains(c)) &&
                !b.readingFinished &&
                !b.listeningFinished,
          )
          .toList();
      candidates.sort((a, b) => b.downloadCount.compareTo(a.downloadCount));
    } else {
      final seen = <String>{};
      final diversePicks = <BookModel>[];
      final sorted = List<BookModel>.from(all)
        ..sort((a, b) => b.downloadCount.compareTo(a.downloadCount));

      for (final book in sorted) {
        for (final cat in book.categories) {
          if (!seen.contains(cat)) {
            seen.add(cat);
            if (!diversePicks.contains(book)) diversePicks.add(book);
            break;
          }
        }
        if (diversePicks.length >= limit) break;
      }

      if (diversePicks.length < limit) {
        for (final book in sorted) {
          if (!diversePicks.contains(book)) diversePicks.add(book);
          if (diversePicks.length >= limit) break;
        }
      }

      candidates = diversePicks;
    }

    return candidates.take(limit).toList();
  }

  //  Continue Reading
  static List<BookModel> getContinueReading() {
    final books = _box.values
        .where(
          (b) =>
              (b.scrollOffset > 0 || b.epubChapterIndex > 0) &&
              !b.readingFinished &&
              b.lastReadAt != null,
        )
        .toList();
    books.sort((a, b) {
      final aTime = a.lastReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return books;
  }

  //  Continue Listening
  static List<BookModel> getContinueListening() {
    final books = _box.values
        .where(
          (b) =>
              (b.currentAudioPosition > 0 || b.currentAudioChapter > 0) &&
              !b.listeningFinished &&
              b.lastListenedAt != null,
        )
        .toList();
    books.sort((a, b) {
      final aTime = a.lastListenedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastListenedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return books;
  }

  //  Finished books
  static List<BookModel> getFinishedBooks() {
    return _box.values
        .where((b) => b.readingFinished || b.listeningFinished)
        .toList();
  }

  static bool isFinished(BookModel book) => book.readingFinished;
  static bool isFinishedAudio(BookModel book) => book.listeningFinished;
  static bool isFinishedBook(BookModel book) =>
      book.readingFinished || book.listeningFinished;

  //  Progress saves

  static Future<void> saveReadingProgress(
    String bookId, {
    required double scrollOffset,
    int? epubChapterIndex,
  }) async {
    final book = _box.get(bookId);
    if (book == null) return;
    book.scrollOffset = scrollOffset;
    if (epubChapterIndex != null) book.epubChapterIndex = epubChapterIndex;
    book.lastReadAt = DateTime.now();
    await book.save();
  }

  static Future<void> markReadingFinished(String bookId) async {
    final book = _box.get(bookId);
    if (book == null) return;
    book.readingFinished = true;
    book.lastReadAt = DateTime.now();
    await book.save();
  }

  static Future<void> saveAudioProgress(
    String bookId, {
    required int chapterIndex,
    required double positionSeconds,
    required double chapterDurationSeconds,
  }) async {
    final book = _box.get(bookId);
    if (book == null) return;
    book.currentAudioChapter = chapterIndex;
    book.currentAudioPosition = positionSeconds;
    final key = chapterIndex.toString();
    final existing = book.chapterListenedSeconds[key] ?? 0.0;
    if (positionSeconds > existing) {
      book.chapterListenedSeconds[key] = positionSeconds;
    }
    book.lastListenedAt = DateTime.now();
    await book.save();
  }

  static Future<void> markListeningFinished(String bookId) async {
    final book = _box.get(bookId);
    if (book == null) return;
    book.listeningFinished = true;
    book.lastListenedAt = DateTime.now();
    await book.save();
  }

  static Future<void> saveTotalAudioSeconds(
    String bookId,
    double totalSeconds,
  ) async {
    final book = _box.get(bookId);
    if (book == null) return;
    book.totalAudioSeconds = totalSeconds;
    await book.save();
  }

  //  Remove from continue reading / listening
  static Future<void> removeFromContinueReading(String bookId) async {
    final book = _box.get(bookId);
    if (book == null) return;
    book.scrollOffset = 0.0;
    book.epubChapterIndex = 0;
    book.lastReadAt = null;
    await book.save();
  }

  static Future<void> removeFromContinueListening(String bookId) async {
    final book = _box.get(bookId);
    if (book == null) return;
    book.currentAudioPosition = 0.0;
    book.currentAudioChapter = 0;
    book.chapterListenedSeconds = {};
    book.lastListenedAt = null;
    await book.save();
  }

  static Future<void> removeFromFinished(String bookId) async {
    await removeFromContinueReading(bookId);
    await removeFromContinueListening(bookId);
    final book = _box.get(bookId);
    if (book == null) return;
    book.readingFinished = false;
    book.listeningFinished = false;
    await book.save();
  }

  //  Favourite
  static Future<void> toggleFavorite(String bookId) async {
    final book = _box.get(bookId);
    if (book == null) return;
    book.isFavorite = !book.isFavorite;
    await book.save();
  }

  //  Settings: reading font
  static String getReadingFont() =>
      _settings.get('reading_font', defaultValue: 'Lora') as String;
  static Future<void> saveReadingFont(String font) =>
      _settings.put('reading_font', font);

  //  All categories
  static List<String> getAllCategories() {
    final Set<String> cats = {};
    for (final book in _box.values) {
      cats.addAll(book.categories);
    }
    return ['All', ...cats.toList()..sort()];
  }

  static int getBackgroundFetchPage({required String sort}) {
    return _settings.get('bg_fetch_page_$sort', defaultValue: 1) as int;
  }

  // Saves the next page number to fetch for the given sort order.
  static Future<void> saveBackgroundFetchPage({
    required String sort,
    required int page,
  }) async {
    await _settings.put('bg_fetch_page_$sort', page);
  }
}

//  Audio Chapter model
class AudioChapter {
  final int index;
  final int episode;
  final String title;
  final String audioUrl;
  final double durationSeconds;

  const AudioChapter({
    required this.index,
    required this.episode,
    required this.title,
    required this.audioUrl,
    required this.durationSeconds,
  });

  String get formattedDuration {
    final total = durationSeconds.toInt();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

//  Fetch Result
class FetchResult {
  final List books;
  final bool networkError;

  const FetchResult({required this.books, required this.networkError});

  // True = genuine last page, False with empty = network error
  bool get isLastPage => !networkError && books.isEmpty;
}
