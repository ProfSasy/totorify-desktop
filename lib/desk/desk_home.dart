import 'package:flutter/material.dart';
import 'package:kreate_ios/models/artist.dart';
import 'package:kreate_ios/services/recommendation_service.dart';
import 'package:kreate_ios/services/spotify_catalog_service.dart';
import 'package:kreate_ios/services/storage_service.dart';
import 'package:kreate_ios/ui/widgets/song_options_sheet.dart' show playlistCoverUrl;

import 'desk.dart';
import 'desk_art.dart';
import 'desk_artist.dart';
import 'desk_collection.dart';
import 'desk_menus.dart';
import 'desk_widgets.dart';

/// The Home. Each of its parts has a look of its own: a large banner for
/// what is put forward, strips to go back to the library at a click, the
/// charts as wide cards in their colors, the mixes as veiled portraits, the
/// genres as blocks of color; covers in rows for the rest.
class DeskHomePage extends StatefulWidget {
  const DeskHomePage({super.key});

  @override
  State<DeskHomePage> createState() => _DeskHomePageState();
}

class _DeskHomePageState extends State<DeskHomePage> {
  static const int _quick = 6;

  // "Mix" cards: one per artist played most.
  List<Artist> _mixArtists = const [];
  String _mixSignature = '';

  @override
  void initState() {
    super.initState();
    StorageService.instance.historyNotifier.addListener(_refreshMixes);
    _refreshMixes();
  }

  @override
  void dispose() {
    StorageService.instance.historyNotifier.removeListener(_refreshMixes);
    super.dispose();
  }

  /// Looks the mixes up again only when the artists played most change.
  Future<void> _refreshMixes() async {
    final history = StorageService.instance.historyNotifier.value;
    final signature = RecommendationService.topArtistKeys(history).join('|');
    if (signature == _mixSignature) return;
    _mixSignature = signature;
    try {
      final artists = await RecommendationService.instance.mixArtists(history);
      if (mounted && signature == _mixSignature) setState(() => _mixArtists = artists);
    } catch (e) {
      debugPrint('DeskHomePage._refreshMixes: $e');
    }
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Buonanotte';
    if (hour < 13) return 'Buongiorno';
    if (hour < 18) return 'Buon pomeriggio';
    return 'Buonasera';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final storage = StorageService.instance;
    final catalog = SpotifyCatalogService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        storage.historyNotifier,
        storage.favoritesNotifier,
        storage.playlistsNotifier,
        storage.followedArtistsNotifier,
      ]),
      builder: (context, _) {
        final history = storage.historyNotifier.value;
        final playlists = Desk.playlists();
        final artists = storage.followedArtistsNotifier.value;
        final featured = catalog.featuredPlaylists;
        final genres = catalog.browseCategories;
        final last = history.isEmpty ? null : history.first;
        final lead = featured.isEmpty ? null : featured.first;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── What is put forward ──────────────────────────────────────
              if (last != null)
                _Hero(
                  greeting: _greeting(),
                  label: 'Riprendi da dove eri',
                  title: last.title,
                  subtitle: last.artist,
                  coverUrl: last.thumbnailUrl,
                  action: 'Riproduci',
                  onAction: () => Desk.play(last, history, from: 'home, in evidenza'),
                  more: 'Cronologia',
                  onMore: DeskCollectionPage.openHistory,
                )
              else if (lead != null)
                _Hero(
                  greeting: _greeting(),
                  label: 'In evidenza',
                  title: lead.title,
                  subtitle: lead.subtitle,
                  coverUrl: lead.coverUrl,
                  action: 'Apri',
                  onAction: () => DeskCollectionPage.openEditorial(
                    id: lead.id,
                    title: lead.title,
                    caption: lead.subtitle,
                    coverUrl: lead.coverUrl,
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Back to the library at a click ──────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 900
                              ? 3
                              : (constraints.maxWidth >= 560 ? 2 : 1);
                          const gap = 10.0;
                          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                          final tiles = <Widget>[
                            _QuickTile(
                              title: 'Brani che ti piacciono',
                              subtitle: Desk.songs(storage.favoritesNotifier.value.length),
                              cover: const DeskLikedCover(size: 64),
                              onOpen: DeskCollectionPage.openLiked,
                            ),
                            for (final playlist in playlists.take(_quick - 1))
                              _QuickTile(
                                title: playlist.title,
                                subtitle: [
                                  Desk.songs(playlist.songs.length),
                                  ?Desk.whose(playlist.id),
                                ].join(' • '),
                                cover: DeskCover(
                                  url: playlistCoverUrl(playlist),
                                  seed: playlist.title,
                                  size: 64,
                                ),
                                onOpen: () => DeskCollectionPage.openPlaylist(playlist.id),
                                onPlay: playlist.songs.isEmpty
                                    ? null
                                    : () => Desk.play(
                                        playlist.songs.first,
                                        playlist.songs,
                                        from: 'home',
                                      ),
                                onMenu: (at) => deskPlaylistMenu(context, at, playlist),
                              ),
                          ];
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final tile in tiles)
                                SizedBox(width: width, height: 64, child: tile),
                            ],
                          );
                        },
                      ),
                    ),

                    // ── The charts, each in its colors ──────────────────────
                    if (featured.isNotEmpty) ...[
                      const _SectionTitle('Classifiche e novità', 'Aggiornate ogni giorno'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 1040
                                ? 3
                                : (constraints.maxWidth >= 640 ? 2 : 1);
                            const gap = 12.0;
                            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                for (final bundle in featured)
                                  SizedBox(
                                    width: width,
                                    child: DeskFeatureCard(
                                      label: 'Playlist',
                                      title: bundle.title,
                                      subtitle: bundle.subtitle,
                                      coverUrl: bundle.coverUrl,
                                      onOpen: () => DeskCollectionPage.openEditorial(
                                        id: bundle.id,
                                        title: bundle.title,
                                        caption: bundle.subtitle,
                                        coverUrl: bundle.coverUrl,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],

                    // ── What is made from what was played ───────────────────
                    if (_mixArtists.isNotEmpty) ...[
                      const _SectionTitle('Mix per te', 'Dai tuoi ascolti, con artisti simili'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final perRow = (constraints.maxWidth / 190).floor().clamp(2, 8);
                            return Row(
                              children: [
                                for (var i = 0; i < perRow; i++)
                                  Expanded(
                                    child: i < _mixArtists.length
                                        ? DeskMixCard(
                                            name: _mixArtists[i].name,
                                            imageUrl: _mixArtists[i].imageUrl,
                                            index: i,
                                            onOpen: () =>
                                                DeskCollectionPage.openMix(_mixArtists[i]),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],

                    DeskShelf(
                      title: 'Ascoltati di recente',
                      count: history.length,
                      onShowAll: DeskCollectionPage.openHistory,
                      builder: (context, index) {
                        final song = history[index];
                        void play() => Desk.play(song, history, from: 'home, ascoltati di recente');
                        return DeskCard(
                          title: song.title,
                          subtitle: song.artist,
                          cover: (size) =>
                              DeskCover(url: song.thumbnailUrl, seed: song.title, size: size),
                          onOpen: play,
                          onPlay: play,
                          onMenu: (at) => deskSongMenu(context, at, song, queue: history),
                        );
                      },
                    ),
                    DeskShelf(
                      title: 'I tuoi artisti',
                      count: artists.length,
                      builder: (context, index) {
                        final artist = artists[index];
                        return DeskCard(
                          title: artist.name,
                          subtitle: 'Artista',
                          round: true,
                          cover: (size) => DeskCover(
                            url: artist.imageUrl,
                            seed: artist.name,
                            size: size,
                            round: true,
                          ),
                          onOpen: () => Desk.nav.open(DeskArtistPage(artist: artist)),
                        );
                      },
                    ),

                    // ── The genres, as blocks of color ──────────────────────
                    if (genres.isNotEmpty) ...[
                      const _SectionTitle('Generi e momenti', 'Per ogni ora della giornata'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = (constraints.maxWidth / 210).floor().clamp(2, 6);
                            const gap = 12.0;
                            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                for (final genre in genres)
                                  DeskGenreTile(genre: genre, width: width, height: 104),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (last == null && lead == null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _greeting(),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The banner at the top of the Home: one thing put forward, on its own
/// picture spread large behind it.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.greeting,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.action,
    required this.onAction,
    this.more,
    this.onMore,
  });

  final String greeting;
  final String label;
  final String title;
  final String subtitle;
  final String? coverUrl;
  final String action;
  final VoidCallback onAction;
  final String? more;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 290,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DeskBackdrop(url: coverUrl, fallback: Color.lerp(cs.primary, Desk.panel, 0.6)!),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(color: Colors.black54, blurRadius: 28, offset: Offset(0, 10)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: DeskCover(url: coverUrl, seed: title, size: 168),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: title.length <= 22 ? 46 : 32,
                              fontWeight: FontWeight.w900,
                              height: 1.04,
                              letterSpacing: -1.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                                  shape: const StadiumBorder(),
                                  textStyle: const TextStyle(
                                    fontFamily: Desk.font,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                onPressed: onAction,
                                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                                label: Text(action),
                              ),
                              if (more != null && onMore != null) ...[
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white38),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                    shape: const StadiumBorder(),
                                    textStyle: const TextStyle(
                                      fontFamily: Desk.font,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onPressed: onMore,
                                  child: Text(more!),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The name of a part of the Home, with a line under it saying what it is.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 34, 12, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white54)),
      ],
    ),
  );
}

/// One of the things to go back to: a small cover, a name and a line, in a
/// strip.
class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.title,
    required this.subtitle,
    required this.cover,
    required this.onOpen,
    this.onPlay,
    this.onMenu,
  });

  final String title;
  final String subtitle;
  final Widget cover;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;
  final void Function(Offset at)? onMenu;

  @override
  Widget build(BuildContext context) => Hover(
    cursor: SystemMouseCursors.click,
    builder: (context, hovered) => GestureDetector(
      onTap: onOpen,
      onSecondaryTapUp: onMenu == null ? null : (details) => onMenu!(details.globalPosition),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: hovered ? 0.16 : 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(width: 64, height: 64, child: cover),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
            if (onPlay != null && hovered)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: DeskPlayButton(onTap: onPlay!, size: 38),
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    ),
  );
}
