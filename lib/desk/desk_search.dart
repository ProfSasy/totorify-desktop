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
import 'package:kreate_ios/services/ytmusic_catalog_service.dart';
import 'package:kreate_ios/ui/theme/app_icons.dart';
import 'package:kreate_ios/ui/widgets/app_cover.dart';

import 'desk.dart';
import 'desk_artist.dart';
import 'desk_collection.dart';
import 'desk_menus.dart';
import 'desk_widgets.dart';

/// What is found for what is typed in the top bar, as it is typed; before
/// anything is typed, the last searches and the genres to browse.
class DeskSearchPage extends StatefulWidget {
  const DeskSearchPage({super.key});

  @override
  State<DeskSearchPage> createState() => _DeskSearchPageState();
}

class _DeskSearchPageState extends State<DeskSearchPage> {
  /// How long after the last key the search starts.
  static const Duration _settle = Duration(milliseconds: 380);

  String _query = '';
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
    Desk.query.addListener(_onQuery);
    _onQuery();
  }

  @override
  void dispose() {
    Desk.query.removeListener(_onQuery);
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery() {
    final query = Desk.query.value.trim();
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
      _artists = found.artists.take(8).toList();
      _albums = found.albums.take(10).toList();
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
      debugPrint('DeskSearchPage._upgradeCovers: $e');
    }
  }

  /// A search that led somewhere is kept among the recent ones.
  void _remember() {
    if (_query.isNotEmpty) StorageService.instance.addRecentSearch(_query);
  }

  void _play(Song song) {
    _remember();
    Desk.play(song, _songs, from: 'cerca');
  }

  @override
  Widget build(BuildContext context) {
    if (_query.isEmpty) return _Browse(recent: _recent);
    final nothing = _songs.isEmpty && _artists.isEmpty && _albums.isEmpty;
    if (nothing) {
      return !_searched || _searching
          ? const DeskMessage()
          : DeskMessage(
              icon: AppIcons.search,
              title: 'Nessun risultato per "$_query"',
              subtitle: 'Controlla come è scritto, o prova con meno parole.',
            );
    }

    final top = _songs.isEmpty ? null : _songs.first;
    final first = _songs.take(4).toList();
    final others = _songs.skip(4).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (top != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final best = _TopResult(
                    song: top,
                    onPlay: () => _play(top),
                    onMenu: (at) => deskSongMenu(context, at, top, queue: _songs),
                  );
                  final list = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Heading('Brani'),
                      for (final (index, song) in first.indexed)
                        DeskTrackRow(
                          song: song,
                          number: index + 1,
                          queue: _songs,
                          showAlbum: false,
                          onPlay: () => _play(song),
                        ),
                    ],
                  );
                  if (!wide) return list;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 380,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [const _Heading('Risultato più rilevante'), best],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(child: list),
                    ],
                  );
                },
              ),
            ),
          DeskShelf(
            title: 'Artisti',
            count: _artists.length,
            builder: (context, index) {
              final artist = _artists[index];
              return DeskCard(
                title: artist.name,
                subtitle: 'Artista',
                round: true,
                cover: (size) =>
                    AppCover(url: artist.imageUrl, size: size, circle: true, icon: AppIcons.artist),
                onOpen: () {
                  _remember();
                  Desk.nav.open(DeskArtistPage(artist: artist));
                },
              );
            },
          ),
          DeskShelf(
            title: 'Album',
            count: _albums.length,
            builder: (context, index) {
              final album = _albums[index];
              return DeskCard(
                title: album.title,
                subtitle: [album.caption, if (album.artist.isNotEmpty) album.artist].join(' • '),
                cover: (size) =>
                    AppCover(url: album.coverUrl, size: size, radius: 0, icon: AppIcons.album),
                onOpen: () {
                  _remember();
                  DeskCollectionPage.openAlbum(album);
                },
              );
            },
          ),
          if (others.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 26, 12, 0),
              child: _Heading('Altri brani'),
            ),
            for (final (index, song) in others.indexed)
              DeskTrackRow(
                song: song,
                number: index + 5,
                queue: _songs,
                showAlbum: false,
                onPlay: () => _play(song),
              ),
          ],
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: Colors.white,
      ),
    ),
  );
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
        duration: const Duration(milliseconds: 120),
        height: 4 * DeskTrackRow.height,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: hovered ? Desk.hover : Desk.raised,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCover(url: song.thumbnailUrl, size: 92),
                const Spacer(),
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Brano • ${song.artist}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, color: Colors.white60),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: hovered ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: DeskPlayButton(onTap: onPlay, size: 48),
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
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recent.isNotEmpty) ...[
            const _Heading('Ricerche recenti'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final query in recent)
                  DeskChip(label: query, selected: false, onTap: () => Desk.query.value = query),
              ],
            ),
            const SizedBox(height: 28),
          ],
          const _Heading('Sfoglia tutto'),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 220).floor().clamp(2, 6);
              const gap = 16.0;
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final genre in genres)
                    Hover(
                      cursor: SystemMouseCursors.click,
                      builder: (context, hovered) => GestureDetector(
                        onTap: () => DeskCollectionPage.openEditorial(
                          id: genre.playlistId,
                          title: genre.title,
                          coverUrl: genre.coverUrl.isEmpty ? null : genre.coverUrl,
                        ),
                        child: AnimatedScale(
                          scale: hovered ? 1.02 : 1,
                          duration: const Duration(milliseconds: 120),
                          child: Container(
                            width: width,
                            height: 118,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: genre.color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              children: [
                                if (genre.coverUrl.isNotEmpty)
                                  Positioned(
                                    right: -14,
                                    bottom: -6,
                                    child: Transform.rotate(
                                      angle: 0.4,
                                      child: AppCover(url: genre.coverUrl, size: 84),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Text(
                                    genre.title,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
