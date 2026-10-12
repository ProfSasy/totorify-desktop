import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kreate_ios/models/album.dart';
import 'package:kreate_ios/models/artist.dart';
import 'package:kreate_ios/models/song.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/services/storage_service.dart';
// The catalog has a class with the name of this page: it is kept apart.
import 'package:kreate_ios/services/ytmusic_catalog_service.dart' as yt;
import 'package:kreate_ios/ui/theme/app_ambience.dart';

import '../app.dart';
import '../kit.dart';
import '../widgets.dart';
import 'collection.dart';

/// The page of an artist: the picture across the page with the name on it,
/// the most played songs, the discography, where else the artist appears,
/// and who the same listeners like.
class ArtistPage extends StatefulWidget {
  const ArtistPage({super.key, required this.artist});

  /// With an id of the catalog, or only a name to look up.
  final Artist artist;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  static const int _smallCatalog = 5;

  late Artist _artist = widget.artist;
  yt.ArtistPage? _page;
  List<Album> _albums = const [];
  List<Album> _singles = const [];
  List<Song> _appearsOn = const [];
  bool _loading = true;
  bool _morePopular = false;

  /// Which releases the discography shows: 'album' or 'singoli'.
  String _releases = 'album';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final catalog = yt.YTMusicCatalogService.instance;
    final log = PlaybackLogService.instance;
    setState(() => _loading = true);

    var artist = widget.artist;
    if (!yt.YTMusicCatalogService.isCatalogArtistId(artist.id)) {
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
      _releases = page.albums.isEmpty ? 'singoli' : 'album';
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

  void _openAllSongs(yt.ArtistPage page) {
    App.nav.open(
      CollectionPage.load(
        title: page.artist.name,
        load: () async {
          final songs = await yt.YTMusicCatalogService.instance.playlistTracks(
            page.allSongs!,
            fallbackArtist: page.artist.name,
          );
          if (songs.isEmpty) return null;
          return Collection(
            title: page.artist.name,
            kind: 'Tutti i brani',
            by: page.artist.name,
            coverUrl: page.artist.imageUrl,
            songs: songs,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final page = _page;
    if (page == null) {
      return _loading
          ? const Notice()
          : Notice(
              icon: Ic.artist,
              title: 'Impossibile caricare l\'artista',
              text: 'Controlla la connessione e riprova ad aprire "${_artist.name}".',
              action: 'Riprova',
              onAction: _load,
            );
    }

    final artist = _artist;
    final topSongs = page.topSongs;
    final playable = topSongs.isNotEmpty ? topSongs : _appearsOn;
    final popular = topSongs.take(_morePopular ? 10 : 5).toList();
    final releases = _releases == 'album' ? _albums : _singles;
    void play(Song song, List<Song> queue) => App.play(song, queue, from: 'artista ${artist.name}');

    return AmbientTint(
      artworkUrl: artist.imageUrl,
      fallback: accent,
      builder: (context, palette) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── The picture across the page, the name on it ────────────────
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
                        colors: [Color(0x1A000000), Color(0x99000000)],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Ic.verified, size: 22, color: Color(0xFF4CB3FF)),
                            SizedBox(width: 8),
                            Text(
                              'Artista verificato',
                              style: TextStyle(fontSize: 14, color: Tk.text),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          artist.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Tk.title(artist.name.length <= 14 ? 92 : 60).copyWith(
                            fontWeight: FontWeight.w900,
                            shadows: const [Shadow(color: Color(0x80000000), blurRadius: 24)],
                          ),
                        ),
                        if (artist.audience.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            artist.audience,
                            style: const TextStyle(fontSize: 15, color: Tk.text),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Play, follow ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(palette.surface, Tk.panel, 0.7)!, Tk.panel],
                ),
              ),
              child: Row(
                children: [
                  if (playable.isNotEmpty) ...[
                    PlayFab(size: 56, onTap: () => play(playable.first, playable)),
                    const SizedBox(width: 22),
                    IconBtn(
                      Ic.shuffle,
                      tip: 'Riproduci in ordine casuale',
                      size: 30,
                      onTap: () {
                        final shuffled = List<Song>.from(playable)..shuffle();
                        play(shuffled.first, shuffled);
                      },
                    ),
                    const SizedBox(width: 18),
                  ],
                  ValueListenableBuilder<List<Artist>>(
                    valueListenable: StorageService.instance.followedArtistsNotifier,
                    builder: (context, _, _) {
                      final following = StorageService.instance.isFollowingArtist(artist.id);
                      return GhostButton(
                        following ? 'Segui già' : 'Segui',
                        small: true,
                        onTap: () {
                          PlaybackLogService.instance.log(
                            'UI',
                            'artista: ${following ? 'non seguo più' : 'seguo'} "${artist.name}"',
                          );
                          StorageService.instance.toggleFollowArtist(artist);
                          App.toast(
                            following ? 'Rimosso dalla tua libreria' : 'Aggiunto alla tua libreria',
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (popular.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 0),
                      child: SectionTitle('Popolari'),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 940),
                      child: Column(
                        children: [
                          for (final (index, song) in popular.indexed)
                            TrackRow(
                              song: song,
                              number: index + 1,
                              queue: topSongs,
                              onPlay: () => play(song, topSongs),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        children: [
                          if (topSongs.length > 5)
                            LinkText(
                              _morePopular ? 'Mostra meno' : 'Mostra altro',
                              onTap: () => setState(() => _morePopular = !_morePopular),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Tk.subdued,
                              ),
                            ),
                          if (page.allSongs != null) ...[
                            const SizedBox(width: 24),
                            LinkText(
                              'Tutti i brani',
                              onTap: () => _openAllSongs(page),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Tk.subdued,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // ── The discography ────────────────────────────────────────
                  if (_albums.isNotEmpty || _singles.isNotEmpty) ...[
                    const SectionTitle('Discografia'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Row(
                        children: [
                          if (_albums.isNotEmpty)
                            Pill(
                              'Album',
                              selected: _releases == 'album',
                              onTap: () => setState(() => _releases = 'album'),
                            ),
                          const SizedBox(width: 8),
                          if (_singles.isNotEmpty)
                            Pill(
                              'Singoli ed EP',
                              selected: _releases == 'singoli',
                              onTap: () => setState(() => _releases = 'singoli'),
                            ),
                        ],
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final perRow = (constraints.maxWidth / 180).floor().clamp(2, 10);
                        final shown = releases.take(perRow * 2).toList();
                        return Column(
                          children: [
                            for (var start = 0; start < shown.length; start += perRow)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (var i = start; i < start + perRow; i++)
                                    Expanded(
                                      child: i < shown.length
                                          ? MediaCard(
                                              title: shown[i].title,
                                              subtitle: [
                                                if (shown[i].year.isNotEmpty) shown[i].year,
                                                shown[i].type,
                                              ].join(' • '),
                                              art: (side) => Artwork(
                                                url: shown[i].coverUrl,
                                                seed: shown[i].title,
                                                size: side,
                                              ),
                                              onOpen: () => CollectionPage.openAlbum(shown[i]),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                  ],

                  if (_appearsOn.isNotEmpty) ...[
                    const SectionTitle('Compare in'),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 940),
                      child: Column(
                        children: [
                          for (final (index, song) in _appearsOn.take(6).indexed)
                            TrackRow(
                              song: song,
                              number: index + 1,
                              queue: _appearsOn,
                              onPlay: () => play(song, _appearsOn),
                            ),
                        ],
                      ),
                    ),
                  ],

                  Shelf(
                    title: 'Ai fan piace anche',
                    count: page.related.length,
                    builder: (context, index) {
                      final related = page.related[index];
                      return MediaCard(
                        title: related.name,
                        subtitle: 'Artista',
                        round: true,
                        art: (side) => Artwork(
                          url: related.imageUrl,
                          seed: related.name,
                          size: side,
                          round: true,
                        ),
                        onOpen: () => App.nav.open(ArtistPage(artist: related)),
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
