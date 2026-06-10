// lib/main.dart
//
// Minimal Flureadium spike entry point.
// Purpose: copies bundled EPUB assets to device storage, opens the selected book with
// Flureadium, and renders it with ReadiumReaderWidget for Android runtime testing.

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
      title: 'Flureadium Spike',
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

class _ReaderBookmark {
  const _ReaderBookmark({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.locator,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final Locator locator;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'locator': locator.toJson(),
    };
  }

  static _ReaderBookmark? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final id = value['id'];
    final title = value['title'];
    final createdAt = value['createdAt'];
    final locatorJson = value['locator'];

    if (id is! String || title is! String || createdAt is! String) {
      return null;
    }

    if (locatorJson is! Map<String, dynamic>) {
      return null;
    }

    final locator = Locator.fromJson(locatorJson);

    if (locator == null) {
      return null;
    }

    return _ReaderBookmark(
      id: id,
      title: title,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
      locator: locator,
    );
  }
}

enum _ReaderThemePreset {
  light,
  sepia,
  dark;

  String get label {
    switch (this) {
      case _ReaderThemePreset.light:
        return 'Light';
      case _ReaderThemePreset.sepia:
        return 'Sepia';
      case _ReaderThemePreset.dark:
        return 'Dark';
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
    }
  }

  static _ReaderThemePreset fromName(Object? value) {
    if (value is! String) {
      return _ReaderThemePreset.light;
    }

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
    if (value is! Map<String, dynamic>) {
      return const _ReaderSettings();
    }

    final fontFamily = value['fontFamily'];
    final fontSize = value['fontSize'];
    final verticalScroll = value['verticalScroll'];
    final pageMargins = value['pageMargins'];

    return _ReaderSettings(
      theme: _ReaderThemePreset.fromName(value['theme']),
      fontFamily: fontFamily is String && fontFamily.trim().isNotEmpty ? fontFamily : 'Georgia',
      fontSize: fontSize is int ? fontSize.clamp(50, 200).toInt() : 100,
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

  static const String _selectedBookKey = 'selected_book_id';
  static const String _readerPreferencesKey = 'reader_preferences_global';

  StreamSubscription<Locator>? _locatorSubscription;
  Locator? _lastLocator;
  _ReaderSettings _readerSettings = const _ReaderSettings();

  _LibraryBook _selectedBook = _libraryBooks.first;
  Publication? _publication;
  String _status = 'Preparing EPUB...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSelectedBookAndOpen();
  }

  @override
  void dispose() {
    _locatorSubscription?.cancel();
    super.dispose();
  }

  String _lastLocatorKeyFor(String bookId) => 'last_locator_$bookId';

  String _bookmarksKeyFor(String bookId) => 'bookmarks_$bookId';

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

      if (mounted) {
        setState(() {
          _selectedBook = book;
          _publication = null;
          _lastLocator = null;
          _status = 'Copying ${book.title} to device storage...';
          _error = null;
        });
      }

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_selectedBookKey, book.id);

      final bookPath = await _copyAssetBookToFile(book);

      if (mounted) {
        setState(() {
          _status = 'Loading reader preferences...';
        });
      }

      final readerSettings = await _loadReaderSettings();
      _flureadium.setDefaultPreferences(readerSettings.toEPUBPreferences());

      final savedLocator = await _loadSavedLocator(book.id);

      if (mounted) {
        setState(() {
          _readerSettings = readerSettings;
          _lastLocator = savedLocator;
          _status = 'Opening ${book.title} with Flureadium...';
        });
      }

      final publication = await _flureadium.openPublication('file://$bookPath');

      debugPrint('Opened book: ${book.title}');
      debugPrint('Publication: $publication');
      debugPrint('Publication runtime type: ${publication.runtimeType}');
      debugPrint('TOC: ${publication.tableOfContents}');
      debugPrint('TOC: ${publication.toc}');

      _locatorSubscription = _flureadium.onTextLocatorChanged.listen((locator) async {
        _lastLocator = locator;

        debugPrint('Reader locator changed for ${book.id}: $locator');

        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(_lastLocatorKeyFor(book.id), jsonEncode(locator.toJson()));

        if (mounted && _selectedBook.id == book.id) {
          setState(() {});
        }
      });

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

    if (savedLocatorJson == null || savedLocatorJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(savedLocatorJson);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return Locator.fromJson(decoded);
    } catch (error, stackTrace) {
      debugPrint('Failed to load saved locator: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<_ReaderSettings> _loadReaderSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final settingsJson = preferences.getString(_readerPreferencesKey);

    if (settingsJson == null || settingsJson.isEmpty) {
      return const _ReaderSettings();
    }

    try {
      final decoded = jsonDecode(settingsJson);

      if (decoded is! Map<String, dynamic>) {
        return const _ReaderSettings();
      }

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
    setState(() {
      _readerSettings = settings;
    });

    await _saveReaderSettings(settings);

    final preferences = settings.toEPUBPreferences();
    _flureadium.setDefaultPreferences(preferences);

    if (_publication != null) {
      await _flureadium.setEPUBPreferences(preferences);
    }
  }

  Future<void> _showLibrary(BuildContext context) async {
    final progressByBook = <String, Locator?>{};
    final bookmarkCountByBook = <String, int>{};

    for (final book in _libraryBooks) {
      progressByBook[book.id] = await _loadSavedLocator(book.id);
      bookmarkCountByBook[book.id] = (await _loadBookmarks(book.id)).length;
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
              final isSelected = book.id == _selectedBook.id;

              return ListTile(
                leading: Icon(isSelected ? Icons.menu_book : Icons.menu_book_outlined),
                title: Text(book.title),
                subtitle: Text(
                  [
                    progress == null
                        ? 'No saved progress yet'
                        : 'Saved progress: ${_locatorSummary(progress)}',
                    '$bookmarkCount bookmark${bookmarkCount == 1 ? '' : 's'}',
                  ].join('\n'),
                ),
                isThreeLine: true,
                trailing: isSelected ? const Icon(Icons.check_circle) : null,
                onTap: () async {
                  Navigator.of(context).pop();
                  if (book.id == _selectedBook.id) {
                    return;
                  }

                  await _openBook(book);
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
              setSheetState(() {
                draftSettings = settings;
              });

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
                        onSelected: (_) async {
                          await updateSettings(draftSettings.copyWith(theme: theme));
                        },
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
                            : () async {
                                await updateSettings(
                                  draftSettings.copyWith(fontSize: draftSettings.fontSize - 10),
                                );
                              },
                        icon: const Icon(Icons.text_decrease),
                      ),
                      Expanded(
                        child: Slider(
                          min: 50,
                          max: 200,
                          divisions: 15,
                          label: '${draftSettings.fontSize}%',
                          value: draftSettings.fontSize.toDouble(),
                          onChanged: (value) async {
                            await updateSettings(draftSettings.copyWith(fontSize: value.round()));
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Increase font size',
                        onPressed: draftSettings.fontSize >= 200
                            ? null
                            : () async {
                                await updateSettings(
                                  draftSettings.copyWith(fontSize: draftSettings.fontSize + 10),
                                );
                              },
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
                    children: const ['Georgia', 'Palatino', 'Helvetica', 'Arial'].map((fontFamily) {
                      return ChoiceChip(
                        label: Text(fontFamily),
                        selected: draftSettings.fontFamily == fontFamily,
                        onSelected: (_) async {
                          await updateSettings(draftSettings.copyWith(fontFamily: fontFamily));
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Vertical scroll mode'),
                    subtitle: const Text(
                      'Off keeps the current paginated page-by-page mode. Scroll mode had spot-on bookmark accuracy in testing.',
                    ),
                    value: draftSettings.verticalScroll,
                    onChanged: (value) async {
                      await updateSettings(draftSettings.copyWith(verticalScroll: value));
                    },
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
                    onChanged: (value) async {
                      await updateSettings(draftSettings.copyWith(pageMargins: value));
                    },
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

    for (final item in toc) {
      _debugTocItem(item);
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        if (toc.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No table of contents found for this EPUB.'),
            ),
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
    final href = link.href;

    if (href.isEmpty) {
      debugPrint('TOC item has an empty href: $link');
      return;
    }

    try {
      debugPrint('Going to TOC link: title=${link.title}, href=$href');

      final locator = link.toLocator();
      await _flureadium.goToLocator(locator);
    } catch (error, stackTrace) {
      debugPrint('Failed to navigate with Link.toLocator(): $error');
      debugPrintStack(stackTrace: stackTrace);

      try {
        debugPrint('Falling back to direct goByLink navigation');
        await _flureadium.goByLink(link, publication);
      } catch (fallbackError, fallbackStackTrace) {
        debugPrint('Failed to navigate with goByLink: $fallbackError');
        debugPrintStack(stackTrace: fallbackStackTrace);
      }
    }
  }

  void _debugTocItem(Link item, {int depth = 0}) {
    final prefix = '  ' * depth;

    debugPrint('${prefix}TOC item runtime type: ${item.runtimeType}');
    debugPrint('${prefix}TOC title: ${item.title}');
    debugPrint('${prefix}TOC href: ${item.href}');
    debugPrint('${prefix}TOC children count: ${item.children.length}');

    for (final child in item.children) {
      _debugTocItem(child, depth: depth + 1);
    }
  }

  Future<List<_ReaderBookmark>> _loadBookmarks(String bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final bookmarksJson = preferences.getString(_bookmarksKeyFor(bookId));

    if (bookmarksJson == null || bookmarksJson.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(bookmarksJson);

      if (decoded is! List) {
        return const [];
      }

      return decoded
          .map(_ReaderBookmark.fromJson)
          .whereType<_ReaderBookmark>()
          .toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('Failed to load bookmarks: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const [];
    }
  }

  Future<void> _saveBookmarks(String bookId, List<_ReaderBookmark> bookmarks) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _bookmarksKeyFor(bookId),
      jsonEncode(bookmarks.map((bookmark) => bookmark.toJson()).toList()),
    );
  }

  Future<void> _addCurrentBookmark(BuildContext context) async {
    final locator = _lastLocator;
    final book = _selectedBook;

    if (locator == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No reading position captured yet. Turn a page first.')),
      );
      return;
    }

    final bookmarks = await _loadBookmarks(book.id);
    final createdAt = DateTime.now();
    final bookmark = _ReaderBookmark(
      id: createdAt.microsecondsSinceEpoch.toString(),
      title: _bookmarkTitle(locator, bookmarks.length + 1),
      createdAt: createdAt,
      locator: locator,
    );

    await _saveBookmarks(book.id, [...bookmarks, bookmark]);

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Bookmark saved for ${book.title}: ${bookmark.title}')));
  }

  String _bookmarkTitle(Locator locator, int fallbackNumber) {
    final title = locator.title;

    if (title != null && title.trim().isNotEmpty) {
      return title.trim();
    }

    final href = locator.href;

    if (href.isNotEmpty) {
      return href.split('/').last;
    }

    return 'Bookmark $fallbackNumber';
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
                    child: Text('No bookmarks saved yet for ${book.title}.'),
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
                      '${_locatorSummary(bookmark.locator)}\n${_formatBookmarkDate(bookmark.createdAt)}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Delete bookmark',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final updatedBookmarks = bookmarks
                            .where((savedBookmark) => savedBookmark.id != bookmark.id)
                            .toList(growable: false);

                        await _saveBookmarks(book.id, updatedBookmarks);

                        setSheetState(() {
                          bookmarks = updatedBookmarks;
                        });
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

  String _locatorSummary(Locator locator) {
    final href = locator.href.isEmpty ? 'Unknown location' : locator.href.split('/').last;
    final locations = locator.locations;
    final position = locations?.position;
    final progression = locations?.progression;
    final totalProgression = locations?.totalProgression;

    final parts = <String>[href];

    if (position != null) {
      parts.add('pos $position');
    }

    if (progression != null) {
      parts.add('${(progression * 100).round()}% chapter');
    }

    if (totalProgression != null) {
      parts.add('${(totalProgression * 100).round()}% book');
    }

    return parts.join(' · ');
  }

  String _formatBookmarkDate(DateTime createdAt) {
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
              ? 'Flureadium Spike'
              : '${_selectedBook.title}${_lastLocator == null ? '' : ' · Progress captured'}',
        ),
        actions: [
          IconButton(
            tooltip: 'Library',
            onPressed: () async {
              await _showLibrary(context);
            },
            icon: const Icon(Icons.library_books_outlined),
          ),
          IconButton(
            tooltip: 'Reading preferences',
            onPressed: publication == null
                ? null
                : () async {
                    await _showReaderSettings(context);
                  },
            icon: const Icon(Icons.text_fields),
          ),
          IconButton(
            tooltip: 'Add bookmark',
            onPressed: publication == null
                ? null
                : () async {
                    await _addCurrentBookmark(context);
                  },
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
          IconButton(
            tooltip: 'Bookmarks',
            onPressed: publication == null
                ? null
                : () async {
                    await _showBookmarks(context);
                  },
            icon: const Icon(Icons.bookmarks_outlined),
          ),
          IconButton(
            tooltip: 'Table of contents',
            onPressed: publication == null
                ? null
                : () {
                    _showTableOfContents(context, publication);
                  },
            icon: const Icon(Icons.list),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed: publication == null
                ? null
                : () async {
                    await _flureadium.goLeft();
                  },
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: publication == null
                ? null
                : () async {
                    await _flureadium.goRight();
                  },
            icon: const Icon(Icons.chevron_right),
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

          if (publication == null) {
            return Center(child: Text(_status));
          }

          return ReadiumReaderWidget(
            key: ValueKey(_selectedBook.id),
            publication: publication,
            onReady: () async {
              debugPrint('Readium reader is ready for ${_selectedBook.title}');

              final savedLocator = await _loadSavedLocator(_selectedBook.id);

              if (savedLocator == null) {
                debugPrint('No saved locator found for ${_selectedBook.id}');
                return;
              }

              debugPrint('Restoring saved locator for ${_selectedBook.id}: $savedLocator');
              await _flureadium.goToLocator(savedLocator);
            },
          );
        },
      ),
    );
  }
}
