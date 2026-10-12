import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kreate_ios/models/album.dart';
import 'package:kreate_ios/models/artist.dart';
import 'package:kreate_ios/models/song.dart';
import 'package:kreate_ios/services/cover_art_service.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/services/spotify_catalog_service.dart';
import 'package:kreate_ios/services/storage_service.dart';
import 'package:kreate_ios/services/track_matcher_service.dart';
import 'package:kreate_ios/services/ytmusic_catalog_service.dart' hide ArtistPage;

import '../app.dart';
import '../kit.dart';
import '../menus.dart';
import '../widgets.dart';
import 'artist.dart';
import 'collection.dart';

/// What is found for what is typed in the top bar, as it is typed; before
/// anything is typed, the last searches and the genres to browse.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  /// How long after the last key the search starts.
  static const Duration _settle = Duration(milliseconds: 360);
  static const List<String> _kinds = ['Tutto', 'Brani', 'Artisti', 'Album'];

  String _query = '';
  String _kind = _kinds.first;
  List<Song> _songs = const [];
  List<Artist> _artists = const [];
  List<Album> _albums = const [];
  bool _searching = false;
  bool _searched = false;
  Timer? _debounce;
  int _generation = 0;
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    _recent = StorageService.instance.getRecentSearches();
    App.query.addListener(_onQuery);
    _onQuery();
  }

  @override
  void dispose() {
    App.query.removeListener(_onQuery);
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery() {
    final query = App.query.value.trim();
    if (query == _query) return;
    _debounce?.cancel();
    if (query.isEmpty) {
      _generation++;
      setState(() {
        _query = '';
        _songs = const [];
        _artists = const [];
        _albums = const [];
        _searching = false;
        _searched = false;
        _recent = StorageService.instance.getRecentSearches();
      });
      return;
    }
    setState(() {
      _query = query;
      _searching = true;
    });
    _debounce = Timer(_settle, () => _search(query));
  }

  Future<void> _search(String query) async {
    final generation = ++_generation;
    PlaybackLogService.instance.log('UI', 'cerca: "$query"');
    var found = const CatalogSearch();
    try {
      found = await YTMusicCatalogService.instance.search(query);
    } catch (e) {
      PlaybackLogService.instance.error('UI', 'cerca: "$query" non riuscita: $e');
    }
    final songs = TrackMatcherService.instance.rankSearch(query, found);
    if (!mounted || generation != _generation) return;
    setState(() {
      _songs = songs;
      _artists = found.artists.take(10).toList();
      _albums = found.albums.take(12).toList();
      _searching = false;
      _searched = true;
    });
    unawaited(_upgradeCovers(songs, generation));
  }

  /// Video results come with a frame of the video as artwork: the album
  /// cover takes its place once it is found.
  Future<void> _upgradeCovers(List<Song> songs, int generation) async {
    if (!songs.any((s) => CoverArtService.needsOriginal(s.thumbnailUrl))) return;
    try {
      final upgraded = await CoverArtService.instance.withOriginalCovers(songs);
      if (!mounted || generation != _generation) return;
      setState(() => _songs = upgraded);
    } catch (e) {
      debugPrint('SearchPage._upgradeCovers: $e');
    }
  }

  /// A search that led somewhere is kept among the recent ones.
  void _remember() {
    if (_query.isNotEmpty) StorageService.instance.addRecentSearch(_query);
  }

  void _play(Song song) {
    _remember();
    App.play(song, _songs, from: 'cerca');
  }

  Widget _artistCard(Artist artist) => MediaCard(
    title: artist.name,
    subtitle: 'Artista',
    round: true,
    art: (side) => Artwork(url: artist.imageUrl, seed: artist.name, size: side, round: true),
    onOpen: () {
      _remember();
      App.nav.open(ArtistPage(artist: artist));
    },
  );

  Widget _albumCard(Album album) => MediaCard(
    title: album.title,
    subtitle: [
      if (album.year.isNotEmpty) album.year,
      album.artist,
    ].where((p) => p.isNotEmpty).join(' • '),
    art: (side) => Artwork(url: album.coverUrl, seed: album.title, size: side, radius: 6),
    onOpen: () {
      _remember();
      CollectionPage.openAlbum(album);
    },
  );

  @override
  Widget build(BuildContext context) {
    if (_query.isEmpty) return _Browse(recent: _recent);
    final nothing = _songs.isEmpty && _artists.isEmpty && _albums.isEmpty;
    if (nothing) {
      return !_searched || _searching
          ? const Notice()
          : Notice(
              title: 'Nessun risultato trovato per "$_query"',
              text:
                  'Assicurati che le parole siano scritte correttamente, oppure usa meno '
                  'parole chiave o parole diverse.',
            );
    }

    final top = _songs.isEmpty ? null : _songs.first;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final kind in _kinds) ...[
                  Pill(kind, selected: _kind == kind, onTap: () => setState(() => _kind = kind)),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (_kind == 'Tutto') ...[
            if (top != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 26, 12, 0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final songs = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text('Brani', style: Tk.title(24)),
                        ),
                        for (final (index, song) in _songs.take(4).indexed)
                          TrackRow(
                            song: song,
                            number: index + 1,
                            queue: _songs,
                            album: false,
                            onPlay: () => _play(song),
                          ),
                      ],
                    );
                    if (constraints.maxWidth < 780) return songs;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 400,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text('Risultato più rilevante', style: Tk.title(24)),
                              ),
                              _TopResult(
                                song: top,
                                onPlay: () => _play(top),
                                onMenu: (at) => songMenu(context, at, top, queue: _songs),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: songs),
                      ],
                    );
                  },
                ),
              ),
            Shelf(
              title: 'Artisti',
              count: _artists.length,
              builder: (context, index) => _artistCard(_artists[index]),
            ),
            Shelf(
              title: 'Album',
              count: _albums.length,
              builder: (context, index) => _albumCard(_albums[index]),
            ),
          ],
          if (_kind == 'Brani') ...[
            const SizedBox(height: 18),
            const TrackHeader(album: false),
            for (final (index, song) in _songs.indexed)
              TrackRow(
                song: song,
                number: index + 1,
                queue: _songs,
                album: false,
                onPlay: () => _play(song),
              ),
          ],
          if (_kind == 'Artisti')
            Shelf(
              title: 'Artisti',
              count: _artists.length,
              rows: 4,
              builder: (context, index) => _artistCard(_artists[index]),
            ),
          if (_kind == 'Album')
            Shelf(
              title: 'Album',
              count: _albums.length,
              rows: 4,
              builder: (context, index) => _albumCard(_albums[index]),
            ),
        ],
      ),
    );
  }
}

/// The first thing found, large.
class _TopResult extends StatelessWidget {
  const _TopResult({required this.song, required this.onPlay, required this.onMenu});

  final Song song;
  final VoidCallback onPlay;
  final void Function(Offset at) onMenu;

  @override
  Widget build(BuildContext context) => Hover(
    cursor: SystemMouseCursors.click,
    builder: (context, hovered) => GestureDetector(
      onTap: onPlay,
      onSecondaryTapUp: (details) => onMenu(details.globalPosition),
      child: AnimatedContainer(
        duration: Tk.quick,
        height: 4 * TrackRow.height,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hovered ? Tk.hover : const Color(0xFF181818),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(color: Color(0x80000000), blurRadius: 18, offset: Offset(0, 8)),
                    ],
                  ),
                  child: Artwork(url: song.thumbnailUrl, seed: song.title, size: 92),
                ),
                const Spacer(),
                Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tk.title(30)),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Brano • ',
                        style: TextStyle(color: Tk.subdued),
                      ),
                      TextSpan(text: song.artist),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Tk.text),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: hovered ? Offset.zero : const Offset(0, 0.18),
                duration: const Duration(milliseconds: 160),
                child: AnimatedOpacity(
                  opacity: hovered ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: PlayFab(onTap: onPlay, size: 48),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Before anything is typed: the last searches, and the genres as tiles.
class _Browse extends StatelessWidget {
  const _Browse({required this.recent});

  final List<String> recent;

  @override
  Widget build(BuildContext context) {
    final genres = SpotifyCatalogService.instance.browseCategories;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recent.isNotEmpty) ...[
            Text('Ricerche recenti', style: Tk.title(24)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final query in recent)
                  Pill(query, selected: false, onTap: () => App.query.value = query),
              ],
            ),
            const SizedBox(height: 34),
          ],
          Text('Sfoglia tutto', style: Tk.title(24)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 230).floor().clamp(2, 6);
              const gap = 20.0;
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [for (final genre in genres) GenreTile(genre: genre, width: width)],
              );
            },
          ),
        ],
      ),
    );
  }
}
