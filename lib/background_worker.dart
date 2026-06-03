import 'package:flutter/foundation.dart';
import '../data/hive_service.dart';

bool _isRunning = false;

// All background work: LibriVox mapping + Gutendex bulk fetch.
// Called from HomeScreen after the first frame is painted.
Future<void> runBackgroundWork() async {
  if (_isRunning) {
    debugPrint('Background work already running, skipping.');
    return;
  }
  _isRunning = true;
  try {
    await Future.wait([
      HiveService.buildLibriVoxMappingIfNeeded(),
      _fetchAllGutendexBooks(),
    ]);
    debugPrint(
      'All background work complete. '
      'Total books in Hive: ${HiveService.getAllBooks().length}',
    );
  } finally {
    _isRunning = false;
  }
}

Future<void> _fetchAllGutendexBooks() async {
  const int maxPages = 2500;

  //  Popular pages 1-2 first
  final int savedPopular = HiveService.getBackgroundFetchPage(sort: 'popular');

  if (savedPopular <= 2) {
    debugPrint('Gutendex popular: fetching pages 1-2 for immediate display.');
    for (int page = savedPopular; page <= 2; page++) {
      final result = await HiveService.fetchAndStoreBooksWithStatus(
        sort: 'popular',
        page: page,
      );
      if (result.networkError) {
        debugPrint('Gutendex: network error on page $page, will resume later.');
        await HiveService.saveBackgroundFetchPage(sort: 'popular', page: page);
        return;
      }
      await HiveService.saveBackgroundFetchPage(
        sort: 'popular',
        page: page + 1,
      );
      if (result.isLastPage) return;
    }
  }

  //  Popular + Descending parallel
  await Future.wait([
    _fetchSort('popular', maxPages),
    _fetchSort('descending', maxPages),
  ]);

  debugPrint('Gutendex bulk fetch done.');
}

Future<void> _fetchSort(String sort, int maxPages) async {
  final int saved = HiveService.getBackgroundFetchPage(sort: sort);
  final int startPage = sort == 'popular'
      ? (saved < 3 ? 3 : saved)
      : (saved < 1 ? 1 : saved);

  debugPrint('Gutendex $sort: starting from page $startPage');

  const int batchSize = 3;

  for (int page = startPage; page <= maxPages; page += batchSize) {
    final futures = <Future<FetchResult>>[];
    for (int i = 0; i < batchSize && (page + i) <= maxPages; i++) {
      futures.add(
        HiveService.fetchAndStoreBooksWithStatus(sort: sort, page: page + i),
      );
    }

    final results = await Future.wait(futures);

    bool hasError = false;
    bool isLast = false;

    for (int i = 0; i < results.length; i++) {
      if (results[i].networkError) {
        await HiveService.saveBackgroundFetchPage(sort: sort, page: page + i);
        hasError = true;
        break;
      }
      await HiveService.saveBackgroundFetchPage(sort: sort, page: page + i + 1);
      if (results[i].isLastPage) {
        isLast = true;
        break;
      }
    }

    if (hasError) return;
    if (isLast) {
      debugPrint('Gutendex $sort: complete.');
      break;
    }

    await Future.delayed(const Duration(milliseconds: 50));
  }
}
