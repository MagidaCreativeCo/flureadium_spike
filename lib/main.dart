// lib/main.dart
//
// Flureadium reader capability spike.
// Purpose: provides an Android-first test harness for Leafra's reader-engine needs:
// EPUB navigation, scroll mode, progress restore, preferences, bookmarks, decorations,
// TTS, and Flureadium event streams.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:flureadium/flureadium.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const FlureadiumSpikeApp());
}

class FlureadiumSpikeApp extends StatelessWidget {
  const FlureadiumSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flureadium Spike Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const RenderLauncherScreen(),
    );
  }
}

class _LibraryBook {
  const _LibraryBook({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.fileName,
  });

  final String id;
  final String title;
  final String assetPath;
  final String fileName;
}

const List<_LibraryBook> _libraryBooks = [
  _LibraryBook(
    id: 'tom_sawyer',
    title: 'The Adventures of Tom Sawyer',
    assetPath: 'assets/books/The_Adventures_of_Tom_Sawyer.epub',
    fileName: 'The_Adventures_of_Tom_Sawyer.epub',
  ),
  _LibraryBook(
    id: 'minimal',
    title: 'Minimal EPUB',
    assetPath: 'assets/books/minimal.epub',
    fileName: 'minimal.epub',
  ),
];

class _SavedLocatorItem {
  const _SavedLocatorItem({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.locator,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final Locator locator;

  ReaderDecoration toBookmarkDecoration() {
    return ReaderDecoration(
      id: id,
      locator: locator,
      style: ReaderDecorationStyle(style: DecorationStyle.underline, tint: const Color(0xFF3F51B5)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'locator': locator.toJson(),
    };
  }

  static _SavedLocatorItem? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;

    final id = value['id'];
    final title = value['title'];
    final createdAt = value['createdAt'];
    final locatorJson = value['locator'];

    if (id is! String || title is! String || createdAt is! String) return null;
    if (locatorJson is! Map<String, dynamic>) return null;

    final locator = Locator.fromJson(locatorJson);
    if (locator == null) return null;

    return _SavedLocatorItem(
      id: id,
      title: title,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
      locator: locator,
    );
  }
}

class _ReaderHighlight {
  const _ReaderHighlight({
    required this.id,
    required this.title,
    required this.colorValue,
    required this.createdAt,
    required this.locator,
  });

  final String id;
  final String title;
  final int colorValue;
  final DateTime createdAt;
  final Locator locator;

  Color get color => Color(colorValue);

  ReaderDecoration toDecoration() {
    return ReaderDecoration(
      id: id,
      locator: locator,
      style: ReaderDecorationStyle(style: DecorationStyle.highlight, tint: color),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
      'locator': locator.toJson(),
    };
  }

  static _ReaderHighlight? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;

    final id = value['id'];
    final title = value['title'];
    final colorValue = value['colorValue'];
    final createdAt = value['createdAt'];
    final locatorJson = value['locator'];

    if (id is! String || title is! String || createdAt is! String) return null;
    if (colorValue is! int || locatorJson is! Map<String, dynamic>) return null;

    final locator = Locator.fromJson(locatorJson);
    if (locator == null) return null;

    return _ReaderHighlight(
      id: id,
      title: title,
      colorValue: colorValue,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
      locator: locator,
    );
  }
}

enum _ReaderThemePreset {
  light,
  sepia,
  dark,
  oled;

  String get label {
    switch (this) {
      case _ReaderThemePreset.light:
        return 'Light';
      case _ReaderThemePreset.sepia:
        return 'Sepia';
      case _ReaderThemePreset.dark:
        return 'Dark';
      case _ReaderThemePreset.oled:
        return 'OLED';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case _ReaderThemePreset.light:
        return const Color(0xFFFFFFFF);
      case _ReaderThemePreset.sepia:
        return const Color(0xFFF5E6D3);
      case _ReaderThemePreset.dark:
        return const Color(0xFF1A1A1A);
      case _ReaderThemePreset.oled:
        return const Color(0xFF000000);
    }
  }

  Color get textColor {
    switch (this) {
      case _ReaderThemePreset.light:
        return const Color(0xFF000000);
      case _ReaderThemePreset.sepia:
        return const Color(0xFF5C4033);
      case _ReaderThemePreset.dark:
        return const Color(0xFFE0E0E0);
      case _ReaderThemePreset.oled:
        return const Color(0xFFEDEDED);
    }
  }

  IconData get icon {
    switch (this) {
      case _ReaderThemePreset.light:
        return Icons.light_mode_outlined;
      case _ReaderThemePreset.sepia:
        return Icons.auto_stories_outlined;
      case _ReaderThemePreset.dark:
        return Icons.dark_mode_outlined;
      case _ReaderThemePreset.oled:
        return Icons.brightness_2_outlined;
    }
  }

  static _ReaderThemePreset fromName(Object? value) {
    if (value is! String) return _ReaderThemePreset.light;
    return _ReaderThemePreset.values.firstWhere(
      (theme) => theme.name == value,
      orElse: () => _ReaderThemePreset.light,
    );
  }
}

class _ReaderSettings {
  const _ReaderSettings({
    this.theme = _ReaderThemePreset.light,
    this.fontFamily = 'Georgia',
    this.fontSize = 100,
    this.verticalScroll = false,
    this.pageMargins = 0.1,
  });

  final _ReaderThemePreset theme;
  final String fontFamily;
  final int fontSize;
  final bool verticalScroll;
  final double pageMargins;

  EPUBPreferences toEPUBPreferences() {
    return EPUBPreferences(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: null,
      verticalScroll: verticalScroll,
      backgroundColor: theme.backgroundColor,
      textColor: theme.textColor,
      pageMargins: pageMargins,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'theme': theme.name,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'verticalScroll': verticalScroll,
      'pageMargins': pageMargins,
    };
  }

  static _ReaderSettings fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return const _ReaderSettings();

    final fontFamily = value['fontFamily'];
    final fontSize = value['fontSize'];
    final verticalScroll = value['verticalScroll'];
    final pageMargins = value['pageMargins'];

    return _ReaderSettings(
      theme: _ReaderThemePreset.fromName(value['theme']),
      fontFamily: fontFamily is String && fontFamily.trim().isNotEmpty ? fontFamily : 'Georgia',
      fontSize: fontSize is int ? fontSize.clamp(50, 220).toInt() : 100,
      verticalScroll: verticalScroll is bool ? verticalScroll : false,
      pageMargins: pageMargins is num ? pageMargins.toDouble().clamp(0.0, 0.25).toDouble() : 0.1,
    );
  }

  _ReaderSettings copyWith({
    _ReaderThemePreset? theme,
    String? fontFamily,
    int? fontSize,
    bool? verticalScroll,
    double? pageMargins,
  }) {
    return _ReaderSettings(
      theme: theme ?? this.theme,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      verticalScroll: verticalScroll ?? this.verticalScroll,
      pageMargins: pageMargins ?? this.pageMargins,
    );
  }
}

class RenderLauncherScreen extends StatefulWidget {
  const RenderLauncherScreen({super.key});

  @override
  State<RenderLauncherScreen> createState() => _RenderLauncherScreenState();
}

class _RenderLauncherScreenState extends State<RenderLauncherScreen> {
  final Flureadium _flureadium = Flureadium();
  final List<String> _diagnostics = [];

  static const String _selectedBookKey = 'selected_book_id';
  static const String _readerPreferencesKey = 'reader_preferences_global';

  StreamSubscription<Locator>? _locatorSubscription;
  StreamSubscription<dynamic>? _statusSubscription;
  StreamSubscription<dynamic>? _timebasedSubscription;
  StreamSubscription<dynamic>? _errorSubscription;

  Locator? _lastLocator;
  Locator? _initialLocator;
  _ReaderSettings _readerSettings = const _ReaderSettings();

  _LibraryBook _selectedBook = _libraryBooks.first;
  Publication? _publication;
  String _status = 'Preparing EPUB...';
  String? _error;
  bool _streamsReady = false;
  bool _ttsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedBookAndOpen();
  }

  @override
  void dispose() {
    _locatorSubscription?.cancel();
    _statusSubscription?.cancel();
    _timebasedSubscription?.cancel();
    _errorSubscription?.cancel();
    _flureadium.stop();
    _flureadium.closePublication();
    super.dispose();
  }

  static const String _highlightDecorationGroupId = 'leafra-spike-highlights';
  static const String _bookmarkDecorationGroupId = 'leafra-spike-bookmarks';

  String _lastLocatorKeyFor(String bookId) => 'last_locator_$bookId';
  String _bookmarksKeyFor(String bookId) => 'bookmarks_$bookId';
  String _highlightsKeyFor(String bookId) => 'highlights_$bookId';

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    debugPrint('[$timestamp] $message');
    if (!mounted) return;
    setState(() {
      _diagnostics.insert(0, '[$timestamp] $message');
      if (_diagnostics.length > 120) {
        _diagnostics.removeRange(120, _diagnostics.length);
      }
    });
  }

  Future<void> _loadSelectedBookAndOpen() async {
    final preferences = await SharedPreferences.getInstance();
    final savedBookId = preferences.getString(_selectedBookKey);
    final savedBook = _libraryBooks.firstWhere(
      (book) => book.id == savedBookId,
      orElse: () => _libraryBooks.first,
    );
    await _openBook(savedBook);
  }

  Future<void> _openBook(_LibraryBook book) async {
    try {
      await _locatorSubscription?.cancel();
      _locatorSubscription = null;
      _streamsReady = false;

      if (mounted) {
        setState(() {
          _selectedBook = book;
          _publication = null;
          _lastLocator = null;
          _initialLocator = null;
          _status = 'Copying ${book.title} to device storage...';
          _error = null;
        });
      }

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_selectedBookKey, book.id);

      try {
        await _flureadium.closePublication();
        _log('Closed previous publication before opening ${book.title}.');
      } catch (error) {
        _log('closePublication before open reported: $error');
      }

      final bookPath = await _copyAssetBookToFile(book);
      _log('Copied ${book.title} to $bookPath');

      final readerSettings = await _loadReaderSettings();
      _flureadium.setDefaultPreferences(readerSettings.toEPUBPreferences());
      _log('Applied default preferences before opening: ${jsonEncode(readerSettings.toJson())}');

      final savedLocator = await _loadSavedLocator(book.id);

      if (mounted) {
        setState(() {
          _readerSettings = readerSettings;
          _initialLocator = savedLocator;
          _lastLocator = savedLocator;
          _status = 'Opening ${book.title} with Flureadium...';
        });
      }

      final publication = await _flureadium.openPublication('file://$bookPath');
      _log(
        'Opened ${book.title}. TOC=${publication.tableOfContents.length}, readingOrder=${publication.readingOrder.length}',
      );

      if (!mounted) return;
      setState(() {
        _publication = publication;
        _status = 'Reader ready';
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to open EPUB: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _status = 'Failed to open EPUB';
      });
    }
  }

  Future<String> _copyAssetBookToFile(_LibraryBook book) async {
    final bytes = await rootBundle.load(book.assetPath);
    final tempDirectory = await getTemporaryDirectory();
    final bookFile = File('${tempDirectory.path}/${book.fileName}');
    await bookFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return bookFile.path;
  }

  Future<Locator?> _loadSavedLocator(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final savedLocatorJson = preferences.getString(_lastLocatorKeyFor(bookId));
    if (savedLocatorJson == null || savedLocatorJson.isEmpty) return null;

    try {
      final decoded = jsonDecode(savedLocatorJson);
      if (decoded is! Map<String, dynamic>) return null;
      return Locator.fromJson(decoded);
    } catch (error, stackTrace) {
      debugPrint('Failed to load saved locator: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _saveLocatorForBook(String bookId, Locator locator) async {
    _lastLocator = locator;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastLocatorKeyFor(bookId), jsonEncode(locator.toJson()));
    if (mounted && _selectedBook.id == bookId) setState(() {});
  }

  Future<_ReaderSettings> _loadReaderSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final settingsJson = preferences.getString(_readerPreferencesKey);
    if (settingsJson == null || settingsJson.isEmpty) return const _ReaderSettings();

    try {
      final decoded = jsonDecode(settingsJson);
      if (decoded is! Map<String, dynamic>) return const _ReaderSettings();
      return _ReaderSettings.fromJson(decoded);
    } catch (error, stackTrace) {
      debugPrint('Failed to load reader preferences: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const _ReaderSettings();
    }
  }

  Future<void> _saveReaderSettings(_ReaderSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_readerPreferencesKey, jsonEncode(settings.toJson()));
  }

  Future<void> _applyReaderSettings(_ReaderSettings settings) async {
    setState(() => _readerSettings = settings);
    await _saveReaderSettings(settings);

    final preferences = settings.toEPUBPreferences();
    _log('Preference request: ${jsonEncode(settings.toJson())}');
    _flureadium.setDefaultPreferences(preferences);
    _log('setDefaultPreferences() completed for requested preferences.');
    if (_publication != null) {
      await _flureadium.setEPUBPreferences(preferences);
      _log('setEPUBPreferences() completed for live publication.');
    } else {
      _log('setEPUBPreferences() skipped because no publication is open.');
    }
  }

  Future<void> _setDefaultVerticalScrollThenOpen() async {
    final settings = _readerSettings.copyWith(verticalScroll: true);
    setState(() => _readerSettings = settings);
    await _saveReaderSettings(settings);
    _flureadium.setDefaultPreferences(settings.toEPUBPreferences());
    _log('Vertical scroll proof A: setDefaultPreferences(verticalScroll=true) before reopen.');
    await _openBook(_selectedBook);
  }

  Future<void> _applyLiveVerticalScroll() async {
    final settings = _readerSettings.copyWith(verticalScroll: true);
    _log('Vertical scroll proof B: applying setEPUBPreferences(verticalScroll=true) live.');
    await _applyReaderSettings(settings);
  }

  Future<void> _applyVerticalScrollThenReopen() async {
    final settings = _readerSettings.copyWith(verticalScroll: true);
    _log('Vertical scroll proof C: apply live preferences, then reopen publication.');
    await _applyReaderSettings(settings);
    await _openBook(_selectedBook);
  }

  Future<void> _restorePaginatedThenReopen() async {
    final settings = _readerSettings.copyWith(verticalScroll: false);
    _log('Preference proof reset: verticalScroll=false, then reopen publication.');
    await _applyReaderSettings(settings);
    await _openBook(_selectedBook);
  }

  void _subscribeToStreamsOnce() {
    if (_streamsReady) return;
    _streamsReady = true;
    _log('Reader onReady fired. Subscribing to Flureadium streams.');

    _locatorSubscription?.cancel();
    _locatorSubscription = _flureadium.onTextLocatorChanged.listen((locator) async {
      _log('Locator: ${_locatorSummary(locator)}');
      await _saveLocatorForBook(_selectedBook.id, locator);
    });

    _statusSubscription?.cancel();
    _statusSubscription = _flureadium.onReaderStatusChanged.listen((status) {
      _log('Reader status: $status');
    });

    _timebasedSubscription?.cancel();
    _timebasedSubscription = _flureadium.onTimebasedPlayerStateChanged.listen((state) {
      _log('Timebased state: $state');
    });

    _errorSubscription?.cancel();
    _errorSubscription = _flureadium.onErrorEvent.listen((error) {
      _log('Reader error: $error');
    });
  }

  Future<List<_SavedLocatorItem>> _loadBookmarks(String bookId) async {
    return _loadSavedLocatorItems(_bookmarksKeyFor(bookId));
  }

  Future<void> _saveBookmarks(String bookId, List<_SavedLocatorItem> bookmarks) async {
    await _saveSavedLocatorItems(_bookmarksKeyFor(bookId), bookmarks);
  }

  Future<List<_SavedLocatorItem>> _loadSavedLocatorItems(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final json = preferences.getString(key);
    if (json == null || json.isEmpty) return const [];

    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];
      return decoded.map(_SavedLocatorItem.fromJson).whereType<_SavedLocatorItem>().toList();
    } catch (error, stackTrace) {
      debugPrint('Failed to load locator items: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const [];
    }
  }

  Future<void> _saveSavedLocatorItems(String key, List<_SavedLocatorItem> items) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(items.map((item) => item.toJson()).toList()));
  }

  Future<List<_ReaderHighlight>> _loadHighlights(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final highlightsJson = preferences.getString(_highlightsKeyFor(bookId));
    if (highlightsJson == null || highlightsJson.isEmpty) return const [];

    try {
      final decoded = jsonDecode(highlightsJson);
      if (decoded is! List) return const [];
      return decoded.map(_ReaderHighlight.fromJson).whereType<_ReaderHighlight>().toList();
    } catch (error, stackTrace) {
      debugPrint('Failed to load highlights: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const [];
    }
  }

  Future<void> _saveHighlights(String bookId, List<_ReaderHighlight> highlights) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _highlightsKeyFor(bookId),
      jsonEncode(highlights.map((highlight) => highlight.toJson()).toList()),
    );
  }

  Future<void> _applySavedHighlights() async {
    final highlights = await _loadHighlights(_selectedBook.id);
    await _flureadium.applyDecorations(
      _highlightDecorationGroupId,
      highlights.map((h) => h.toDecoration()).toList(),
    );
    _log(
      'applyDecorations($_highlightDecorationGroupId) completed with ${highlights.length} highlight decoration(s).',
    );
  }

  Future<void> _applySavedBookmarkDecorations() async {
    final bookmarks = await _loadBookmarks(_selectedBook.id);
    await _flureadium.applyDecorations(
      _bookmarkDecorationGroupId,
      bookmarks.map((bookmark) => bookmark.toBookmarkDecoration()).toList(),
    );
    _log(
      'applyDecorations($_bookmarkDecorationGroupId) completed with ${bookmarks.length} underline/bookmark decoration(s).',
    );
  }

  Future<void> _applyAllSavedDecorations() async {
    await _applySavedHighlights();
    await _applySavedBookmarkDecorations();
  }

  Future<void> _clearAppliedDecorationsOnly() async {
    await _flureadium.applyDecorations(_highlightDecorationGroupId, const <ReaderDecoration>[]);
    _log('applyDecorations($_highlightDecorationGroupId) completed with 0 decoration(s).');
    await _flureadium.applyDecorations(_bookmarkDecorationGroupId, const <ReaderDecoration>[]);
    _log('applyDecorations($_bookmarkDecorationGroupId) completed with 0 decoration(s).');
  }

  Future<void> _logCurrentLocatorProbe() async {
    final streamLocator = _lastLocator;
    _log(
      'Current locator from stream cache: ${streamLocator == null ? 'none' : _locatorSummary(streamLocator)}',
    );
    try {
      final dynamic flureadium = _flureadium;
      final dynamic locator = await flureadium.getCurrentLocator();
      if (locator is Locator) {
        await _saveLocatorForBook(_selectedBook.id, locator);
        _log('getCurrentLocator() completed: ${_locatorSummary(locator)}');
      } else {
        _log('getCurrentLocator() completed but returned ${locator.runtimeType}: $locator');
      }
    } catch (error) {
      _log('getCurrentLocator() unavailable or failed: $error');
    }
  }

  Future<void> _showLibrary(BuildContext context) async {
    final progressByBook = <String, Locator?>{};
    final bookmarkCountByBook = <String, int>{};
    final highlightCountByBook = <String, int>{};

    for (final book in _libraryBooks) {
      progressByBook[book.id] = await _loadSavedLocator(book.id);
      bookmarkCountByBook[book.id] = (await _loadBookmarks(book.id)).length;
      highlightCountByBook[book.id] = (await _loadHighlights(book.id)).length;
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _libraryBooks.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final book = _libraryBooks[index];
              final progress = progressByBook[book.id];
              final bookmarkCount = bookmarkCountByBook[book.id] ?? 0;
              final highlightCount = highlightCountByBook[book.id] ?? 0;
              final isSelected = book.id == _selectedBook.id;

              return ListTile(
                leading: Icon(isSelected ? Icons.menu_book : Icons.menu_book_outlined),
                title: Text(book.title),
                subtitle: Text(
                  [
                    progress == null
                        ? 'No saved progress yet'
                        : 'Saved: ${_locatorSummary(progress)}',
                    '$bookmarkCount bookmark${bookmarkCount == 1 ? '' : 's'}',
                    '$highlightCount highlight${highlightCount == 1 ? '' : 's'}',
                  ].join('\n'),
                ),
                isThreeLine: true,
                trailing: isSelected ? const Icon(Icons.check_circle) : null,
                onTap: () async {
                  Navigator.of(context).pop();
                  if (book.id != _selectedBook.id) await _openBook(book);
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showReaderSettings(BuildContext context) async {
    var draftSettings = _readerSettings;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> updateSettings(_ReaderSettings settings) async {
              setSheetState(() => draftSettings = settings);
              await _applyReaderSettings(settings);
            }

            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                shrinkWrap: true,
                children: [
                  Text('Reading preferences', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  Text('Theme', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _ReaderThemePreset.values.map((theme) {
                      return ChoiceChip(
                        avatar: Icon(theme.icon, size: 18),
                        label: Text(theme.label),
                        selected: draftSettings.theme == theme,
                        onSelected: (_) => updateSettings(draftSettings.copyWith(theme: theme)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text('Font size', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      Text('${draftSettings.fontSize}%'),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Decrease font size',
                        onPressed: draftSettings.fontSize <= 50
                            ? null
                            : () => updateSettings(
                                draftSettings.copyWith(fontSize: draftSettings.fontSize - 10),
                              ),
                        icon: const Icon(Icons.text_decrease),
                      ),
                      Expanded(
                        child: Slider(
                          min: 50,
                          max: 220,
                          divisions: 17,
                          label: '${draftSettings.fontSize}%',
                          value: draftSettings.fontSize.toDouble(),
                          onChanged: (value) =>
                              updateSettings(draftSettings.copyWith(fontSize: value.round())),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Increase font size',
                        onPressed: draftSettings.fontSize >= 220
                            ? null
                            : () => updateSettings(
                                draftSettings.copyWith(fontSize: draftSettings.fontSize + 10),
                              ),
                        icon: const Icon(Icons.text_increase),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Font family', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const ['Georgia', 'Palatino', 'Helvetica', 'Arial', 'Times New Roman']
                        .map((fontFamily) {
                          return ChoiceChip(
                            label: Text(fontFamily),
                            selected: draftSettings.fontFamily == fontFamily,
                            onSelected: (_) =>
                                updateSettings(draftSettings.copyWith(fontFamily: fontFamily)),
                          );
                        })
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Vertical scroll mode'),
                    subtitle: const Text(
                      'Test native Flureadium scroll only. No external Leafra-style gesture bridge is used in this spike.',
                    ),
                    value: draftSettings.verticalScroll,
                    onChanged: (value) =>
                        updateSettings(draftSettings.copyWith(verticalScroll: value)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Page margins', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      Text('${(draftSettings.pageMargins * 100).round()}%'),
                    ],
                  ),
                  Slider(
                    min: 0,
                    max: 0.25,
                    divisions: 5,
                    label: '${(draftSettings.pageMargins * 100).round()}%',
                    value: draftSettings.pageMargins,
                    onChanged: (value) =>
                        updateSettings(draftSettings.copyWith(pageMargins: value)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showTableOfContents(BuildContext context, Publication publication) async {
    final toc = publication.tableOfContents;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        if (toc.isEmpty) {
          return const Center(
            child: Padding(padding: EdgeInsets.all(24), child: Text('No table of contents found.')),
          );
        }
        return SafeArea(
          child: ListView(
            children: _buildTocTiles(context: context, publication: publication, links: toc),
          ),
        );
      },
    );
  }

  List<Widget> _buildTocTiles({
    required BuildContext context,
    required Publication publication,
    required List<Link> links,
    int depth = 0,
  }) {
    final widgets = <Widget>[];
    for (var index = 0; index < links.length; index += 1) {
      final item = links[index];
      final title = item.title ?? 'Chapter ${index + 1}';
      final children = item.children;
      final hasChildren = children.isNotEmpty;
      widgets.add(
        ListTile(
          contentPadding: EdgeInsetsDirectional.only(start: 16.0 + (depth * 20.0), end: 16),
          leading: Icon(hasChildren ? Icons.folder_open_outlined : Icons.article_outlined),
          title: Text(title),
          subtitle: Text(item.href),
          trailing: hasChildren ? Text('${children.length}') : null,
          onTap: () async {
            Navigator.of(context).pop();
            await _goToTocLink(publication: publication, link: item);
          },
        ),
      );
      if (hasChildren) {
        widgets.addAll(
          _buildTocTiles(
            context: context,
            publication: publication,
            links: children,
            depth: depth + 1,
          ),
        );
      }
    }
    return widgets;
  }

  Future<void> _goToTocLink({required Publication publication, required Link link}) async {
    try {
      _log('TOC goByLink: ${link.title ?? link.href}');
      await _flureadium.goByLink(link, publication);
    } catch (error, stackTrace) {
      debugPrint('goByLink failed, falling back to Link.toLocator: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _flureadium.goToLocator(link.toLocator());
    }
  }

  Future<void> _addCurrentBookmark(BuildContext context) async {
    final locator = _lastLocator;
    if (locator == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No locator captured yet.')));
      return;
    }

    final bookmarks = await _loadBookmarks(_selectedBook.id);
    final createdAt = DateTime.now();
    final bookmark = _SavedLocatorItem(
      id: createdAt.microsecondsSinceEpoch.toString(),
      title: _bookmarkTitle(locator, bookmarks.length + 1),
      createdAt: createdAt,
      locator: locator,
    );
    final updatedBookmarks = [...bookmarks, bookmark];
    await _saveBookmarks(_selectedBook.id, updatedBookmarks);
    await _flureadium.applyDecorations(
      _bookmarkDecorationGroupId,
      updatedBookmarks.map((item) => item.toBookmarkDecoration()).toList(),
    );
    _log(
      'Added underline/bookmark decoration at ${_locatorSummary(locator)}. Count=${updatedBookmarks.length}.',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Bookmark saved: ${bookmark.title}')));
  }

  Future<void> _addCurrentHighlight(BuildContext context) async {
    final locator = _lastLocator;
    if (locator == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No locator captured yet.')));
      return;
    }

    final highlights = await _loadHighlights(_selectedBook.id);
    final createdAt = DateTime.now();
    final highlight = _ReaderHighlight(
      id: 'highlight-${createdAt.microsecondsSinceEpoch}',
      title: _bookmarkTitle(locator, highlights.length + 1),
      colorValue: const Color(0x66FFEB3B).value,
      createdAt: createdAt,
      locator: locator,
    );

    final updated = [...highlights, highlight];
    await _saveHighlights(_selectedBook.id, updated);
    await _flureadium.applyDecorations(
      _highlightDecorationGroupId,
      updated.map((h) => h.toDecoration()).toList(),
    );
    _log(
      'Added highlight decoration at ${_locatorSummary(locator)}. Count=${updated.length}. applyDecorations completed.',
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Highlight applied: ${highlight.title}')));
  }

  Future<void> _showBookmarks(BuildContext context) async {
    final book = _selectedBook;
    var bookmarks = await _loadBookmarks(book.id);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (bookmarks.isEmpty) {
              return SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No bookmarks for ${book.title}.'),
                  ),
                ),
              );
            }

            return SafeArea(
              child: ListView.separated(
                itemCount: bookmarks.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final bookmark = bookmarks[index];
                  return ListTile(
                    leading: const Icon(Icons.bookmark_outline),
                    title: Text(bookmark.title),
                    subtitle: Text(
                      '${_locatorSummary(bookmark.locator)}\n${_formatDate(bookmark.createdAt)}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Delete bookmark',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final updated = bookmarks.where((item) => item.id != bookmark.id).toList();
                        await _saveBookmarks(book.id, updated);
                        await _flureadium.applyDecorations(
                          _bookmarkDecorationGroupId,
                          updated.map((item) => item.toBookmarkDecoration()).toList(),
                        );
                        _log('Bookmark decoration delete applied. Count=${updated.length}.');
                        setSheetState(() => bookmarks = updated);
                      },
                    ),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _flureadium.goToLocator(bookmark.locator);
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showHighlights(BuildContext context) async {
    final book = _selectedBook;
    var highlights = await _loadHighlights(book.id);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (highlights.isEmpty) {
              return SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No highlights for ${book.title}.'),
                  ),
                ),
              );
            }

            return SafeArea(
              child: ListView.separated(
                itemCount: highlights.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final highlight = highlights[index];
                  return ListTile(
                    leading: Icon(Icons.format_color_fill_outlined, color: highlight.color),
                    title: Text(highlight.title),
                    subtitle: Text(
                      '${_locatorSummary(highlight.locator)}\n${_formatDate(highlight.createdAt)}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Delete highlight',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final updated = highlights
                            .where((item) => item.id != highlight.id)
                            .toList();
                        await _saveHighlights(book.id, updated);
                        await _flureadium.applyDecorations(
                          _highlightDecorationGroupId,
                          updated.map((item) => item.toDecoration()).toList(),
                        );
                        _log('Highlight decoration delete applied. Count=${updated.length}.');
                        setSheetState(() => highlights = updated);
                      },
                    ),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _flureadium.goToLocator(highlight.locator);
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showTtsPanel(BuildContext context) async {
    final voices = <dynamic>[];
    final availableVoices = <dynamic>[];
    bool? canSpeak;
    String? voicesError;
    try {
      canSpeak = await _flureadium.ttsCanSpeak();
      _log('ttsCanSpeak() completed: $canSpeak');
    } catch (error) {
      _log('ttsCanSpeak() failed: $error');
    }
    try {
      voices.addAll(await _flureadium.ttsGetSystemVoices());
      _log('ttsGetSystemVoices() completed with ${voices.length} voice(s).');
    } catch (error) {
      voicesError = error.toString();
      _log('ttsGetSystemVoices() failed: $error');
    }
    try {
      availableVoices.addAll(await _flureadium.ttsGetAvailableVoices());
      _log('ttsGetAvailableVoices() completed with ${availableVoices.length} voice(s).');
    } catch (error) {
      _log('ttsGetAvailableVoices() failed or unavailable: $error');
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            shrinkWrap: true,
            children: [
              Text('TTS test panel', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Use this to test Flureadium TTS, playback controls, voices, and timebased events.',
              ),
              const SizedBox(height: 4),
              Text('ttsCanSpeak: ${canSpeak == null ? 'unknown' : canSpeak.toString()}'),
              Text('System voices: ${voices.length} · Available voices: ${availableVoices.length}'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.record_voice_over_outlined),
                    label: const Text('Enable'),
                    onPressed: () async {
                      try {
                        final canSpeak = await _flureadium.ttsCanSpeak();
                        _log('ttsCanSpeak() before enable: $canSpeak');
                        if (!canSpeak) {
                          _log('ttsRequestInstallVoice() requested because canSpeak=false.');
                          await _flureadium.ttsRequestInstallVoice();
                        }
                        await _flureadium.ttsSetPreferences(TTSPreferences(speed: 1.0, pitch: 1.0));
                        _log('ttsSetPreferences(speed=1.0,pitch=1.0) completed.');
                        await _flureadium.ttsEnable(
                          TTSPreferences(speed: 1.0, pitch: 1.0),
                          fromLocator: _lastLocator,
                        );
                        _log(
                          'ttsEnable() completed with locator=${_lastLocator == null ? 'null' : _locatorSummary(_lastLocator!)}.',
                        );
                        await _flureadium.setDecorationStyle(
                          ReaderDecorationStyle(
                            style: DecorationStyle.highlight,
                            tint: const Color(0x55FFEB3B),
                          ),
                          ReaderDecorationStyle(
                            style: DecorationStyle.underline,
                            tint: const Color(0xFF2196F3),
                          ),
                        );
                        setState(() => _ttsEnabled = true);
                        _log('setDecorationStyle() completed for TTS active/highlight styles.');
                      } catch (error) {
                        _log('TTS enable failed: $error');
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                    onPressed: () async => _runTtsCommand('play', () => _flureadium.play(null)),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                    onPressed: () async => _runTtsCommand('pause', _flureadium.pause),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Resume'),
                    onPressed: () async => _runTtsCommand('resume', _flureadium.resume),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Next'),
                    onPressed: () async => _runTtsCommand('next utterance', _flureadium.next),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.skip_previous),
                    label: const Text('Previous'),
                    onPressed: () async =>
                        _runTtsCommand('previous utterance', _flureadium.previous),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    onPressed: () async => _runTtsCommand('stop', () async {
                      await _flureadium.stop();
                      setState(() => _ttsEnabled = false);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(_ttsEnabled ? Icons.check_circle : Icons.info_outline),
                title: Text(_ttsEnabled ? 'TTS enabled' : 'TTS not enabled yet'),
                subtitle: const Text('Watch Diagnostics for playback state and locator updates.'),
              ),
              const Divider(),
              Text('System voices', style: Theme.of(context).textTheme.titleMedium),
              if (voicesError != null)
                Text(voicesError, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              for (final voice in voices.take(20))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.spatial_audio_off_outlined),
                  title: Text('${voice.name}'),
                  subtitle: Text('${voice.language} · ${voice.identifier}'),
                  onTap: () async {
                    try {
                      await _flureadium.ttsSetVoice('${voice.identifier}', '${voice.language}');
                      _log('Selected voice: ${voice.name} (${voice.language})');
                    } catch (error) {
                      _log('Failed to set voice: $error');
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runTtsCommand(String label, Future<void> Function() command) async {
    try {
      await command();
      _log('TTS command succeeded: $label');
    } catch (error) {
      _log('TTS command failed: $label → $error');
    }
  }

  Future<void> _showDiagnostics(BuildContext context) async {
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Text('Diagnostics', style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _diagnostics.clear());
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _diagnostics.isEmpty
                    ? const Center(child: Text('No diagnostics yet.'))
                    : ListView.builder(
                        itemCount: _diagnostics.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: SelectableText(_diagnostics[index]),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<int>> _decorationCounts() async {
    final highlights = await _loadHighlights(_selectedBook.id);
    final bookmarks = await _loadBookmarks(_selectedBook.id);
    return [highlights.length, bookmarks.length];
  }

  Future<void> _showCapabilityLab(BuildContext context) async {
    final publication = _publication;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            shrinkWrap: true,
            children: [
              Text('Flureadium capability lab', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Selected: ${_selectedBook.title}'),
              Text('Mode: ${_readerSettings.verticalScroll ? 'Vertical scroll' : 'Paginated'}'),
              Text(
                'Locator: ${_lastLocator == null ? 'None yet' : _locatorSummary(_lastLocator!)}',
              ),
              FutureBuilder<List<int>>(
                future: _decorationCounts(),
                builder: (context, snapshot) {
                  final counts = snapshot.data ?? const [0, 0];
                  return Text(
                    'Requested prefs: ${jsonEncode(_readerSettings.toJson())}\n'
                    'Last href: ${_lastLocator?.href ?? 'none'}\n'
                    'Highlights: ${counts[0]} · Bookmark/underline decorations: ${counts[1]}',
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildLabSection(
                context,
                title: 'Navigation',
                children: [
                  _labButton(
                    'goLeft page',
                    Icons.chevron_left,
                    publication == null ? null : _flureadium.goLeft,
                  ),
                  _labButton(
                    'goRight page',
                    Icons.chevron_right,
                    publication == null ? null : _flureadium.goRight,
                  ),
                  _labButton(
                    'skip previous chapter',
                    Icons.first_page,
                    publication == null ? null : _flureadium.skipToPrevious,
                  ),
                  _labButton(
                    'skip next chapter',
                    Icons.last_page,
                    publication == null ? null : _flureadium.skipToNext,
                  ),
                ],
              ),
              _buildLabSection(
                context,
                title: 'Preference proof',
                children: [
                  _labButton(
                    'Default vertical + reopen',
                    Icons.open_in_new_outlined,
                    publication == null ? null : _setDefaultVerticalScrollThenOpen,
                  ),
                  _labButton(
                    'Live vertical apply',
                    Icons.swap_vert_outlined,
                    publication == null ? null : _applyLiveVerticalScroll,
                  ),
                  _labButton(
                    'Apply vertical + reopen',
                    Icons.refresh_outlined,
                    publication == null ? null : _applyVerticalScrollThenReopen,
                  ),
                  _labButton(
                    'Reset paginated + reopen',
                    Icons.view_carousel_outlined,
                    publication == null ? null : _restorePaginatedThenReopen,
                  ),
                ],
              ),
              _buildLabSection(
                context,
                title: 'Reader data and decoration proof',
                children: [
                  _labButton(
                    'Get current locator',
                    Icons.my_location_outlined,
                    publication == null ? null : _logCurrentLocatorProbe,
                  ),
                  _labButton(
                    'Apply saved decorations',
                    Icons.format_color_fill_outlined,
                    publication == null ? null : _applyAllSavedDecorations,
                  ),
                  _labButton(
                    'Decorate locator highlight',
                    Icons.border_color_outlined,
                    publication == null ? null : () => _addCurrentHighlight(context),
                  ),
                  _labButton(
                    'Decorate locator bookmark',
                    Icons.bookmark_add_outlined,
                    publication == null ? null : () => _addCurrentBookmark(context),
                  ),
                  _labButton(
                    'Clear applied decorations',
                    Icons.layers_clear_outlined,
                    publication == null ? null : _clearAppliedDecorationsOnly,
                  ),
                  _labButton(
                    'Show highlights',
                    Icons.palette_outlined,
                    publication == null ? null : () => _showHighlights(context),
                  ),
                  _labButton(
                    'Show bookmarks',
                    Icons.bookmarks_outlined,
                    publication == null ? null : () => _showBookmarks(context),
                  ),
                  _labButton(
                    'Diagnostics',
                    Icons.bug_report_outlined,
                    () => _showDiagnostics(context),
                  ),
                ],
              ),
              _buildLabSection(
                context,
                title: 'Audio/TTS',
                children: [
                  _labButton(
                    'TTS panel',
                    Icons.record_voice_over_outlined,
                    publication == null ? null : () => _showTtsPanel(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Scroll-mode test rule: do not add Flutter drag bridges here. Enable vertical scroll in preferences, then test native vertical scroll, native swipe between spine items, and skipToNext/skipToPrevious separately.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }

  Widget _labButton(String label, IconData icon, Future<void> Function()? action) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: action == null
          ? null
          : () async {
              try {
                await action();
                _log('Action succeeded: $label');
              } catch (error, stackTrace) {
                debugPrintStack(stackTrace: stackTrace);
                _log('Action failed: $label → $error');
              }
            },
    );
  }

  String _bookmarkTitle(Locator locator, int fallbackNumber) {
    final title = locator.title;
    if (title != null && title.trim().isNotEmpty) return title.trim();
    if (locator.href.isNotEmpty) return locator.href.split('/').last;
    return 'Position $fallbackNumber';
  }

  String _locatorSummary(Locator locator) {
    final href = locator.href.isEmpty ? 'Unknown location' : locator.href.split('/').last;
    final locations = locator.locations;
    final position = locations?.position;
    final progression = locations?.progression;
    final totalProgression = locations?.totalProgression;
    final parts = <String>[href];

    if (position != null) parts.add('pos $position');
    if (progression != null) parts.add('${(progression * 100).round()}% chapter');
    if (totalProgression != null) parts.add('${(totalProgression * 100).round()}% book');
    return parts.join(' · ');
  }

  String _formatDate(DateTime createdAt) {
    final local = createdAt.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final publication = _publication;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          publication == null
              ? 'Flureadium Spike Lab'
              : '${_selectedBook.title}${_lastLocator == null ? '' : ' · Progress captured'}',
        ),
        actions: [
          IconButton(
            tooltip: 'Library',
            onPressed: () => _showLibrary(context),
            icon: const Icon(Icons.library_books_outlined),
          ),
          IconButton(
            tooltip: 'Preferences',
            onPressed: publication == null ? null : () => _showReaderSettings(context),
            icon: const Icon(Icons.text_fields),
          ),
          IconButton(
            tooltip: 'Capability lab',
            onPressed: publication == null ? null : () => _showCapabilityLab(context),
            icon: const Icon(Icons.science_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'More tests',
            onSelected: (value) async {
              switch (value) {
                case 'bookmark':
                  await _addCurrentBookmark(context);
                  break;
                case 'bookmarks':
                  await _showBookmarks(context);
                  break;
                case 'highlight':
                  await _addCurrentHighlight(context);
                  break;
                case 'highlights':
                  await _showHighlights(context);
                  break;
                case 'toc':
                  if (publication != null) await _showTableOfContents(context, publication);
                  break;
                case 'diagnostics':
                  await _showDiagnostics(context);
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'bookmark', child: Text('Add bookmark')),
              PopupMenuItem(value: 'bookmarks', child: Text('Bookmarks')),
              PopupMenuItem(value: 'highlight', child: Text('Add highlight here')),
              PopupMenuItem(value: 'highlights', child: Text('Highlights')),
              PopupMenuItem(value: 'toc', child: Text('Table of contents')),
              PopupMenuItem(value: 'diagnostics', child: Text('Diagnostics')),
            ],
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_error != null) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText('Status: $_status\n\nError:\n$_error'),
            );
          }
          if (publication == null) return Center(child: Text(_status));

          return ReadiumReaderWidget(
            key: ValueKey('${_selectedBook.id}_${_readerSettings.verticalScroll}'),
            publication: publication,
            initialLocator: _initialLocator,
            onReady: () async {
              _subscribeToStreamsOnce();
              await _applyAllSavedDecorations();
            },
            onTap: () => _log('Reader content tap'),
            onGoLeft: () => _log('Reader reported goLeft'),
            onGoRight: () => _log('Reader reported goRight'),
            onSwipe: () => _log('Reader reported swipe'),
            onLocatorChanged: (locator) async {
              _log('Widget onLocatorChanged: ${_locatorSummary(locator)}');
              await _saveLocatorForBook(_selectedBook.id, locator);
            },
            onExternalLinkActivated: (url) {
              _log('External link activated: $url');
            },
          );
        },
      ),
    );
  }
}
