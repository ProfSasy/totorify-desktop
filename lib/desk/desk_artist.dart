import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kreate_ios/models/album.dart';
import 'package:kreate_ios/models/artist.dart';
import 'package:kreate_ios/models/song.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/services/storage_service.dart';
import 'package:kreate_ios/services/ytmusic_catalog_service.dart';
import 'package:kreate_ios/ui/theme/app_ambience.dart';
import 'package:kreate_ios/ui/theme/app_icons.dart';
import 'package:kreate_ios/ui/widgets/app_cover.dart';

import 'desk.dart';
import 'desk_collection.dart';
import 'desk_widgets.dart';

/// The page of an artist: who it is, its most played songs, its releases,
/// where else it appears, and who is similar.
class DeskArtistPage extends StatefulWidget {
  const DeskArtistPage({super.key, required this.artist});

  /// With an id of the catalog, or only a name to look up.
  final Artist artist;

  @override
  State<DeskArtistPage> createState() => _DeskArtistPageState();
}

class _DeskArtistPageState extends State<DeskArtistPage> {
  static const int _popularShown = 5;
  static const int _smallCatalog = 5;

  late Artist _artist = widget.artist;
  ArtistPage? _page;
  List<Album> _albums = const [];
  List<Album> _singles = const [];
  List<Song> _appearsOn = const [];
  bool _loading = true;
  bool _allPopular = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final catalog = YTMusicCatalogService.instance;
    final log = PlaybackLogService.instance;
    setState(() => _loading = true);

    var artist = widget.artist;
    if (!YTMusicCatalogService.isCatalogArtistId(artist.id)) {
      final found = await catalog.findArtist(artist.name);
      if (!mounted) return;
      if (found == null) {
        log.log('ARTIST', '"${artist.name}" non trovato nel catalogo');
        setState(() => _loading = false);
        return;
      }
      // One followed under its name only is now known by its id.
      await StorageService.instance.replaceFollowedArtist(artist.id, found);
      artist = found;
    }
    if (!mounted) return;
    setState(() => _artist = artist);

    final page = await catalog.artistPage(artist.id);
    if (!mounted) return;
    if (page == null) {
      log.log('ARTIST', 'pagina di "${artist.name}" non leggibile');
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _page = page;
      _artist = page.artist;
      _albums = page.albums;
      _singles = page.singles;
      _loading = false;
    });

    final ownTitles = [
      ...page.topSongs.map((s) => s.title),
      ...page.albums.map((a) => a.title),
      ...page.singles.map((a) => a.title),
    ];
    try {
      final extras = await Future.wait([
        catalog.appearsOn(
          page.artist,
          ownTitles: ownTitles,
          includeOwnVideos: ownTitles.length < _smallCatalog,
        ),
        page.moreSingles == null
            ? Future.value(page.singles)
            : catalog.releases(page.moreSingles!, artist: page.artist.name, kind: 'Single'),
        page.moreAlbums == null
            ? Future.value(page.albums)
            : catalog.releases(page.moreAlbums!, artist: page.artist.name, kind: 'Album'),
      ]);
      if (!mounted) return;
      final singles = extras[1] as List<Album>;
      final albums = extras[2] as List<Album>;
      setState(() {
        _appearsOn = extras[0] as List<Song>;
        if (singles.isNotEmpty) _singles = singles;
        if (albums.isNotEmpty) _albums = albums;
      });
    } catch (e) {
      log.error('ARTIST', 'il resto della pagina di "${page.artist.name}": $e');
    }
  }

  Future<void> _openAllSongs() async {
    final page = _page;
    if (page?.allSongs == null) return;
    Desk.nav.open(
      DeskCollectionPage.load(
        title: page!.artist.name,
        load: () async {
          final songs = await YTMusicCatalogService.instance.playlistTracks(
            page.allSongs!,
            fallbackArtist: page.artist.name,
          );
          if (songs.isEmpty) return null;
          return DeskCollection(
            title: page.artist.name,
            kind: 'Tutti i brani',
            coverUrl: page.artist.imageUrl,
            songs: songs,
          );
        },
      ),
    );
  }

  Widget _releases(String title, List<Album> albums) => DeskShelf(
    title: title,
    count: albums.length,
    rows: 2,
    builder: (context, index) {
      final album = albums[index];
      return DeskCard(
        title: album.title,
        subtitle: album.caption,
        cover: (size) => AppCover(url: album.coverUrl, size: size, radius: 0, icon: AppIcons.album),
        onOpen: () => DeskCollectionPage.openAlbum(album),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final page = _page;
    if (page == null) {
      return _loading
          ? const DeskMessage()
          : DeskMessage(
              icon: AppIcons.artistMissing,
              title: 'Pagina non disponibile',
              subtitle: 'Non sono riuscito a leggere la pagina di "${_artist.name}".',
              action: 'Riprova',
              onAction: _load,
            );
    }

    final artist = _artist;
    final topSongs = page.topSongs;
    final playable = topSongs.isNotEmpty ? topSongs : _appearsOn;
    final popular = _allPopular
        ? topSongs.take(10).toList()
        : topSongs.take(_popularShown).toList();
    void play(Song song, List<Song> queue) =>
        Desk.play(song, queue, from: 'artista ${artist.name}');

    return AmbientTint(
      artworkUrl: artist.imageUrl,
      fallback: cs.primary,
      builder: (context, palette) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Who it is: the picture across the page, the name on it ────
            SizedBox(
              height: 340,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: palette.surface),
                  if (artist.imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: artist.imageUrl,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.5),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x26000000), Color(0x8C000000), Desk.panel],
                        stops: [0, 0.6, 1],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(AppIcons.verified, size: 20, color: palette.accent),
                            const SizedBox(width: 6),
                            const Text(
                              'ARTISTA',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.8,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          artist.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: artist.name.length <= 14 ? 88 : 58,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            letterSpacing: -3,
                            color: Colors.white,
                            shadows: const [Shadow(color: Colors.black54, blurRadius: 24)],
                          ),
                        ),
                        if (artist.audience.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            artist.audience,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Play, follow ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 6),
              child: Row(
                children: [
                  if (playable.isNotEmpty) ...[
                    DeskPlayButton(size: 56, onTap: () => play(playable.first, playable)),
                    const SizedBox(width: 20),
                  ],
                  ValueListenableBuilder<List<Artist>>(
                    valueListenable: StorageService.instance.followedArtistsNotifier,
                    builder: (context, _, _) {
                      final following = StorageService.instance.isFollowingArtist(artist.id);
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: following ? Colors.white : Colors.white54),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () {
                          PlaybackLogService.instance.log(
                            'UI',
                            'artista: ${following ? 'non seguo più' : 'seguo'} "${artist.name}"',
                          );
                          StorageService.instance.toggleFollowArtist(artist);
                        },
                        child: Text(
                          following ? 'Segui già' : 'Segui',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Songs ──────────────────────────────────────────────────
                  if (popular.isNotEmpty) ...[
                    const _Title('Popolari'),
                    for (final (index, song) in popular.indexed)
                      DeskTrackRow(
                        song: song,
                        number: index + 1,
                        queue: topSongs,
                        onPlay: () => play(song, topSongs),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        children: [
                          if (topSongs.length > _popularShown)
                            DeskLink(
                              _allPopular ? 'Mostra meno' : 'Mostra altro',
                              () => setState(() => _allPopular = !_allPopular),
                            ),
                          if (page.allSongs != null) ...[
                            const SizedBox(width: 22),
                            DeskLink('Tutti i brani', _openAllSongs),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // ── Releases ───────────────────────────────────────────────
                  _releases('Album', _albums),
                  _releases('Singoli ed EP', _singles),

                  if (_appearsOn.isNotEmpty) ...[
                    const _Title('Compare in'),
                    for (final (index, song) in _appearsOn.take(8).indexed)
                      DeskTrackRow(
                        song: song,
                        number: index + 1,
                        queue: _appearsOn,
                        onPlay: () => play(song, _appearsOn),
                      ),
                  ],

                  // ── Who is similar ─────────────────────────────────────────
                  DeskShelf(
                    title: 'Artisti simili',
                    count: page.related.length,
                    builder: (context, index) {
                      final related = page.related[index];
                      return DeskCard(
                        title: related.name,
                        subtitle: 'Artista',
                        round: true,
                        cover: (size) => AppCover(
                          url: related.imageUrl,
                          size: size,
                          circle: true,
                          icon: AppIcons.artist,
                        ),
                        onOpen: () => Desk.nav.open(DeskArtistPage(artist: related)),
                      );
                    },
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

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 26, 12, 10),
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
