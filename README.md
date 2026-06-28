<div align="center">

<img src="app screenshots/ic_launcher.png" width="130" height="130" style="border-radius: 50%;" alt="BookNest Logo"/>

# BookNest

**BookNest brings thousands of free public domain books and audiobooks to your fingertips. Powered by Gutendex (Project Gutenberg's open API) for an ever-growing library of classics, and LibriVox for human-narrated audio editions — read in a beautifully styled reader with 5 serif fonts, or listen chapter-by-chapter with full playback control. All offline-cached, progress-synced, and distraction-free.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Hive](https://img.shields.io/badge/Hive-2.2.3-FF6B35?logo=hive&logoColor=white)](https://pub.dev/packages/hive)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue)](https://flutter.dev)
[![API](https://img.shields.io/badge/API-Gutendex%20%2B%20LibriVox-orange)](https://gutendex.com)

*Read free public domain books. Listen to free audiobooks. All in one app.*

</div>

---

## Features

### Reading
- **Multi-format support** — HTML, Plain Text, and EPUB (with text fallback)
- **5 reading fonts** — Lora, Playfair Display, Merriweather, Libre Baskerville, Crimson Text
- **Reading progress** — Scroll position auto-saved, restored on reopen
- **Finish tracking** — Mark books as finished with a single tap at end of text
- **Dark / Light mode** — Injected CSS for clean WebView reading in both themes
- **Horizontal progress bar** — Visual progress indicator in text mode

### Audiobooks (LibriVox Integration)
- **RSS-based chapter loading** — Namespace-aware parser handles all LibriVox feeds
- **CDN fallback system** — Tries 6 archive.org CDN nodes for reliable playback
- **Per-chapter progress** — Time-tracked per chapter, visualized in chapter list
- **Auto-advance** — Seamlessly moves to next chapter on completion
- **Playback speed control** — 7 speeds: 0.5× to 2.0×
- **Full-audiobook progress** — Overall percentage tracked across all chapters
- **Resume playback** — Remembers exact chapter + position

### Library Management
- **Bookshelf** — Three tabs: Continue, Favourites, Finished
- **Continue Reading + Listening** — Merged view, sorted by latest activity
- **Favourites** — Heart any book from any screen
- **Finished** — Separate read/listened/both badges
- **Swipe-to-remove** — Close button to remove from continue/favourites/finished

### Search & Discovery
- **Full-text search** — By title, author, or category
- **Sort options** — Most Downloaded, Title A–Z
- **Category grid** — All Gutendex categories in a 2-column chip grid
- **Category detail** — Per-category book grid with filtering

### Home
- **Popular books** — Sorted by download count, filterable by category
- **Recently Added** — Sorted by Gutendex ID (newest), filterable by category
- **Recommended For You** — Based on categories of books you've interacted with
- **Continue Reading** — Horizontal scroll with progress bars
- **Animated nav bar** — Auto-hides on scroll down, reveals on scroll up
- **Pull-to-refresh** — Re-fetches latest popular and recent pages

### UI / UX
- **Dark & Light themes** — Persistent toggle, smooth transitions
- **Playfair Display + Lora** — Serif typography throughout for a premium book feel
- **Book Detail Carousel** — Infinite scroll PageView with shrink animation for non-active books
- **Read/Listen tags** — Book/headphone icons on every cover indicating available formats
- **Download count badges** — Shown on all covers
- **Finished badge overlay** — Green overlay directly on cover
- **Custom category chips** — Horizontal scroll, styled selection state

---

## Screenshots

### Book Reading
<table>
  <tr>
    <td align="center"><img src="app screenshots/a.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/b.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/c.jpg" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><img src="app screenshots/d.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/e.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/f.jpg" width="220"/></td>
  </tr>
</table>

---

### Audiobooks
<table>
  <tr>
    <td align="center"><img src="app screenshots/g.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/h.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/i.jpg" width="220"/></td>
  </tr>
</table>

---

### Search Books
<table>
  <tr>
    <td align="center"><img src="app screenshots/j.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/k.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/l.jpg" width="220"/></td>
  </tr>
</table>

---

### Book Categories
<table>
  <tr>
    <td align="center"><img src="app screenshots/m.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/n.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/o.jpg" width="220"/></td>
  </tr>
</table>

---

### Bookshelf
<table>
  <tr>
    <td align="center"><img src="app screenshots/p.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/q.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/r.jpg" width="220"/></td>
  </tr>
</table>

---

### Night Mode
<table>
  <tr>
    <td align="center"><img src="app screenshots/s.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/t.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/u.jpg" width="220"/></td>
  </tr>
  <tr>
    <td align="center"><img src="app screenshots/w.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/x.jpg" width="220"/></td>
    <td align="center"><img src="app screenshots/y.jpg" width="220"/></td>
  </tr>
</table>

---

## Architecture

```
book_nest/
├── lib/
│   ├── main.dart                        # App entry point, Hive init
│   ├── data/
│   │   └── hive_service.dart            # All Hive + API logic (Gutendex + LibriVox)
│   ├── models/
│   │   ├── book_model.dart              # BookModel HiveObject
│   │   └── book_model.g.dart            # Generated TypeAdapter
│   ├── screens/
│   │   ├── home_screen.dart             # Main scaffold + bottom nav
│   │   ├── book_detail_screen.dart      # Infinite carousel detail
│   │   ├── reading_screen.dart          # Text/HTML/EPUB reader
│   │   ├── listening_screen.dart        # Audio player + chapter list
│   │   ├── categories_screen.dart       # Category grid
│   │   ├── category_detail_screen.dart  # Books in one category
│   │   ├── all_categories_detail_screen.dart  # All books + category filter
│   │   ├── bookshelf_screen.dart        # Continue/Favourites/Finished tabs
│   │   ├── audio_screen.dart            # Audiobooks tab
│   │   ├── search_screen.dart           # Search + sort
│   │   └── profile_screen.dart          # Stats + settings
│   ├── theme/
│   │   ├── app_theme.dart               # Colors, shadows, sizes, spacing
│   │   ├── app_mode.dart                # ThemeModeNotifier + ThemeData
│   │   └── app_fonts.dart               # Reading font list
│   └── background_worker.dart           # Background Gutendex fetch orchestrator
├── assets/
│   ├── fonts/                           # Playfair, Lora, Merriweather, etc.
│   └── images/                          # Profile image
└── pubspec.yaml
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x / Dart 3.x |
| **Local Storage** | Hive 2.2.3 + hive_flutter |
| **Book API** | [Gutendex](https://gutendex.com) (Project Gutenberg index) |
| **Audio API** | [LibriVox](https://librivox.org/api) (RSS + Audiotracks) |
| **Audio Playback** | just_audio 0.9.40 |
| **HTTP** | http 1.2.0 |
| **XML Parsing** | xml 6.5.0 |
| **Web Reading** | webview_flutter 4.7.0 |
| **State Management** | `setState` + `ValueNotifier` (no external package) |
| **Code Generation** | hive_generator + build_runner |

---

## Data Model

`BookModel` is a `HiveObject` with **24 typed fields** covering both reading and listening state:

```dart
@HiveType(typeId: 0)
class BookModel extends HiveObject {
  // Core metadata (from Gutendex)
  String id, title, authors, about;
  List<String> categories, languages;
  String coverUrl, epubUrl, textUrl, htmlUrl;
  int downloadCount;
  bool copyright;

  // User state
  bool isFavorite;

  // Reading progress
  double scrollOffset;
  int epubChapterIndex;
  DateTime? lastReadAt;
  bool readingFinished;

  // Audio progress
  String? rssUrl;                          // LibriVox RSS URL
  int currentAudioChapter;
  double currentAudioPosition;
  Map<String, double> chapterListenedSeconds;
  double totalAudioSeconds;
  DateTime? lastListenedAt;
  bool listeningFinished;
}
```

---

## Background Data Pipeline

BookNest uses a two-track background worker that runs concurrently:

```
App Launch
    │
    ├──► LibriVox Mapping
    │       └── Fetches all ~20k LibriVox audiobooks in batches of 500
    │           Builds Gutenberg ID → RSS URL map in Hive
    │           Resumes from last offset on restart
    │           Applies rssUrl to all matching books
    │
    └──► Gutendex Bulk Fetch
            ├── Pages 1-2 popular (immediate, for UI)
            └── Parallel: popular + descending (up to 2500 pages each)
                Saves resume page to Hive settings
                UI refreshes every 30s while fetch is running
```

---

## Getting Started

### Prerequisites
- Flutter SDK `^3.11.3`
- Dart SDK `^3.0`
- Android Studio / VS Code

### Setup

```bash
# Clone the repository
git clone https://github.com/TanvirAhmedCSE/booknest-book-reading-and-audiobook-app.git
cd booknest-book-reading-and-audiobook-app

# Install dependencies
flutter pub get

# Generate Hive adapters
dart run build_runner build --delete-conflicting-outputs

# Run
flutter run
```

### Font Assets

Place the following font files in `assets/fonts/`:

| Family | Files |
|---|---|
| Playfair Display | `PlayfairDisplay-Regular.ttf`, `PlayfairDisplay-Bold.ttf`, `PlayfairDisplay-Italic.ttf` |
| Lora | `Lora-Regular.ttf`, `Lora-Bold.ttf` |
| Merriweather | `Merriweather-Regular.ttf`, `Merriweather-Bold.ttf` |
| Libre Baskerville | `LibreBaskerville-Regular.ttf`, `LibreBaskerville-Bold.ttf` |
| Crimson Text | `CrimsonText-Regular.ttf`, `CrimsonText-Bold.ttf` |

> All fonts are available free from [Google Fonts](https://fonts.google.com).

---

## API Reference

### Gutendex (Books)
```
Base URL: https://gutendex.com/books

GET /?sort=popular&page=1   → Popular books
GET /?sort=descending&page=1 → Recently added
GET /{id}                    → Single book by ID
```

### LibriVox (Audiobooks)
```
Base URL: https://librivox.org/api/feed

GET /audiobooks/?format=json&fields={url_text_source,url_rss}&limit=500&offset=N
    → Batch of audiobooks with Gutenberg source URL + RSS feed URL

GET /audiotracks?project_id={id}&format=json
    → Chapter list for a specific audiobook
```

### archive.org CDN (Audio Files)
BookNest transforms LibriVox audio URLs to use fast CDN nodes:
```
https://archive.org/download/{item}/{file}
  →  https://ia800107.us.archive.org/0/items/{item}/{file}
```
6 CDN nodes are tried in sequence until a working URL is found.

---

## Design System

### Color Palette

| Token | Light | Dark |
|---|---|---|
| `primary` | `#FF6B35` | `#FF6B35` |
| `background` | `#F5F0EB` | `#0F0F1A` |
| `surface / card` | `#FFFFFF` | `#252538` |
| `text` | `#1A1A2E` | `#F0EDE8` |
| `subText` | `#6B6B80` | `#9A97A8` |
| `navBar` | `#FFFFFF` | `#1A1A2E` |
| `header gradient` | `#FFB5A0 → #FFD4C0` | `#2A1A2E → #1A1A3E` |

### Typography
- **Display / Headings** — Playfair Display (serif)
- **Body / Reading** — Lora (serif, default), switchable to 4 other serif fonts
- **Size scale** — `xs:11` `sm:13` `md:15` `lg:17` `xl:20` `xxl:24` `xxxl:28`

---

## Hive Storage Boxes

| Box | Type | Purpose |
|---|---|---|
| `books_v2` | `Box<BookModel>` | All cached books + user progress |
| `settings` | `Box<dynamic>` | Reading font, background fetch pages, LibriVox mapping state |
| `audio_map` | `Box<String>` | Gutenberg ID → LibriVox RSS URL mapping |

---

## License

```
MIT License

Copyright (c) 2025 Tanvir Ahmed

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software.
```

---

## Author

**Tanvir Ahmed**
- GitHub: [@TanvirAhmedCSE](https://github.com/TanvirAhmedCSE)

---

<div align="center">

Built with ❤️ using Flutter · Powered by [Project Gutenberg](https://www.gutenberg.org) & [LibriVox](https://librivox.org)

</div>
