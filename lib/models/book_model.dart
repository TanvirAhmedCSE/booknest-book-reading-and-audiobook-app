import 'package:hive/hive.dart';
part 'book_model.g.dart';

@HiveType(typeId: 0)
class BookModel extends HiveObject {
  @HiveField(0)
  String id; // Gutendex book id (as String)

  @HiveField(1)
  String title;

  @HiveField(2)
  String authors; // joined author names

  @HiveField(3)
  List<String> categories; // from bookshelves

  @HiveField(4)
  String about; // from summaries[0]

  @HiveField(5)
  int downloadCount; // from Gutendex download_count

  @HiveField(6)
  String coverUrl; // formats["image/jpeg"]

  @HiveField(7)
  String epubUrl; // formats["application/epub+zip"]

  @HiveField(8)
  String textUrl; // formats["text/plain; charset=utf-8"]

  @HiveField(9)
  String htmlUrl; // formats["text/html"]

  @HiveField(10)
  List<String> languages;

  @HiveField(11)
  bool copyright; // false = public domain

  @HiveField(12)
  bool isFavorite;

  // Reading progress
  // Scroll offset in the text reader (TXT/HTML). 0.0 = start.
  @HiveField(13)
  double scrollOffset;

  @HiveField(14)
  int epubChapterIndex;

  // Timestamp of the last reading activity.
  @HiveField(15)
  DateTime? lastReadAt;

  // Whether user has explicitly finished reading.
  @HiveField(16)
  bool readingFinished;

  // Audio progress
  // LibriVox RSS URL for this book (null if no audiobook).
  @HiveField(17)
  String? rssUrl;

  // Current audio chapter index (0-based).
  @HiveField(18)
  int currentAudioChapter;

  // Current position within the current audio chapter (seconds).
  @HiveField(19)
  double currentAudioPosition;

  @HiveField(20)
  Map<String, double> chapterListenedSeconds;

  // Total audiobook duration in seconds (sum of all chapters).
  @HiveField(21)
  double totalAudioSeconds;

  // Timestamp of the last listening activity.
  @HiveField(22)
  DateTime? lastListenedAt;

  // Whether user has explicitly finished listening.
  @HiveField(23)
  bool listeningFinished;

  @HiveField(24)
  double maxScrollExtent;

  BookModel({
    required this.id,
    required this.title,
    required this.authors,
    required this.categories,
    required this.about,
    required this.downloadCount,
    required this.coverUrl,
    this.epubUrl = '',
    this.textUrl = '',
    this.htmlUrl = '',
    this.languages = const ['en'],
    this.copyright = false,
    this.isFavorite = false,
    this.scrollOffset = 0.0,
    this.epubChapterIndex = 0,
    this.lastReadAt,
    this.readingFinished = false,
    this.rssUrl,
    this.currentAudioChapter = 0,
    this.currentAudioPosition = 0.0,
    Map<String, double>? chapterListenedSeconds,
    this.totalAudioSeconds = 0.0,
    this.lastListenedAt,
    this.listeningFinished = false,
    this.maxScrollExtent = 0.0,
  }) : chapterListenedSeconds = chapterListenedSeconds ?? {};

  bool get hasAudio => rssUrl != null && rssUrl!.isNotEmpty;

  bool get hasEpub => epubUrl.isNotEmpty;

  bool get hasText => textUrl.isNotEmpty;

  bool get hasHtml => htmlUrl.isNotEmpty;

  String get bestReadUrl {
    if (hasHtml) return htmlUrl;
    if (hasText) return textUrl;
    return epubUrl;
  }

  String get readFormat {
    if (hasHtml) return 'html';
    if (hasText) return 'text';
    if (hasEpub) return 'epub';
    return '';
  }

  // Reading progress 0.0–1.0 based on scroll offset vs total
  double readingProgress(double maxScroll) {
    if (maxScroll <= 0) return 0.0;
    return (scrollOffset / maxScroll).clamp(0.0, 1.0);
  }

  // Listening progress 0.0–1.0 based on total seconds listened vs total
  double get listeningProgress {
    if (totalAudioSeconds <= 0) return 0.0;
    final listened = chapterListenedSeconds.values.fold(0.0, (a, b) => a + b);
    return (listened / totalAudioSeconds).clamp(0.0, 1.0);
  }
}
