import 'package:flutter/material.dart';
import 'package:kreate_ios/models/artist.dart';
import 'package:kreate_ios/services/recommendation_service.dart';
import 'package:kreate_ios/services/spotify_catalog_service.dart';
import 'package:kreate_ios/services/storage_service.dart';
import 'package:kreate_ios/ui/theme/app_icons.dart';
import 'package:kreate_ios/ui/widgets/app_cover.dart';
import 'package:kreate_ios/ui/widgets/song_options_sheet.dart' show playlistCoverUrl;

import 'desk.dart';
import 'desk_artist.dart';
import 'desk_collection.dart';
import 'desk_menus.dart';
import 'desk_widgets.dart';

/// The Home: what to go back to at a click, then rows of what was played,
/// what is made from it, the charts, the library and the genres.
class DeskHomePage extends StatefulWidget {
  const DeskHomePage({super.key});

  @override
  State<DeskHomePage> createState() => _DeskHomePageState();
}

class _DeskHomePageState extends State<DeskHomePage> {
  static const int _quick = 8;

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

        // What to go back to: the liked songs, the playlists, then charts.
        final quick = <Widget>[
          _QuickTile(
            title: 'Brani che ti piacciono',
            cover: const DeskLikedCover(size: 56),
            onOpen: DeskCollectionPage.openLiked,
          ),
          for (final playlist in playlists.take(_quick - 3))
            _QuickTile(
              title: playlist.title,
              cover: AppCover(
                url: playlistCoverUrl(playlist),
                size: 56,
                radius: 0,
                icon: AppIcons.playlist,
              ),
              onOpen: () => DeskCollectionPage.openPlaylist(playlist.id),
              onPlay: playlist.songs.isEmpty
                  ? null
                  : () => Desk.play(playlist.songs.first, playlist.songs, from: 'home'),
            ),
        ];
        for (final bundle in featured) {
          if (quick.length >= _quick) break;
          quick.add(
            _QuickTile(
              title: bundle.title,
              cover: AppCover(url: bundle.coverUrl, size: 56, radius: 0, icon: AppIcons.playlist),
              onOpen: () => DeskCollectionPage.openEditorial(
                id: bundle.id,
                title: bundle.title,
                caption: bundle.subtitle,
                coverUrl: bundle.coverUrl,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 22, 12, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.32],
                colors: [Color.lerp(cs.primary, Desk.panel, 0.72)!, Desk.panel],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: Text(
                    _greeting(),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 980
                          ? 4
                          : (constraints.maxWidth >= 640 ? 3 : 2);
                      const gap = 10.0;
                      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final tile in quick) SizedBox(width: width, height: 56, child: tile),
                        ],
                      );
                    },
                  ),
                ),

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
                      cover: (size) => AppCover(url: song.thumbnailUrl, size: size, radius: 0),
                      onOpen: play,
                      onPlay: play,
                      onMenu: (at) => deskSongMenu(context, at, song, queue: history),
                    );
                  },
                ),
                DeskShelf(
                  title: 'Mix per te',
                  count: _mixArtists.length,
                  builder: (context, index) {
                    final artist = _mixArtists[index];
                    return DeskCard(
                      title: 'Mix ${artist.name}',
                      subtitle: '${artist.name} e artisti simili',
                      cover: (size) => AppCover(
                        url: artist.imageUrl,
                        size: size,
                        radius: 0,
                        icon: AppIcons.smart,
                      ),
                      onOpen: () => DeskCollectionPage.openMix(artist),
                    );
                  },
                ),
                DeskShelf(
                  title: 'Classifiche e novità',
                  count: featured.length,
                  builder: (context, index) {
                    final bundle = featured[index];
                    return DeskCard(
                      title: bundle.title,
                      subtitle: bundle.subtitle,
                      cover: (size) => AppCover(
                        url: bundle.coverUrl,
                        size: size,
                        radius: 0,
                        icon: AppIcons.playlist,
                      ),
                      onOpen: () => DeskCollectionPage.openEditorial(
                        id: bundle.id,
                        title: bundle.title,
                        caption: bundle.subtitle,
                        coverUrl: bundle.coverUrl,
                      ),
                    );
                  },
                ),
                DeskShelf(
                  title: 'Le tue playlist',
                  count: playlists.length,
                  rows: 2,
                  builder: (context, index) {
                    final playlist = playlists[index];
                    return DeskCard(
                      title: playlist.title,
                      subtitle: [
                        Desk.songs(playlist.songs.length),
                        ?Desk.whose(playlist.id),
                      ].join(' • '),
                      cover: (size) => AppCover(
                        url: playlistCoverUrl(playlist),
                        size: size,
                        radius: 0,
                        icon: AppIcons.playlist,
                      ),
                      onOpen: () => DeskCollectionPage.openPlaylist(playlist.id),
                      onPlay: playlist.songs.isEmpty
                          ? null
                          : () => Desk.play(playlist.songs.first, playlist.songs, from: 'home'),
                      onMenu: (at) => deskPlaylistMenu(context, at, playlist),
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
                      cover: (size) => AppCover(
                        url: artist.imageUrl,
                        size: size,
                        circle: true,
                        icon: AppIcons.artist,
                      ),
                      onOpen: () => Desk.nav.open(DeskArtistPage(artist: artist)),
                    );
                  },
                ),
                DeskShelf(
                  title: 'Generi e momenti',
                  count: genres.length,
                  rows: 2,
                  builder: (context, index) {
                    final genre = genres[index];
                    return DeskCard(
                      title: genre.title,
                      subtitle: 'Playlist',
                      cover: (size) => genre.coverUrl.isEmpty
                          ? Container(
                              width: size,
                              height: size,
                              color: genre.color,
                              child: Icon(AppIcons.note, size: size * 0.4, color: Colors.white),
                            )
                          : AppCover(
                              url: genre.coverUrl,
                              size: size,
                              radius: 0,
                              icon: AppIcons.playlist,
                            ),
                      onOpen: () => DeskCollectionPage.openEditorial(
                        id: genre.playlistId,
                        title: genre.title,
                        coverUrl: genre.coverUrl.isEmpty ? null : genre.coverUrl,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One of the things to go back to at the top of the Home: a small cover
/// and a name, in a strip.
class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.title, required this.cover, required this.onOpen, this.onPlay});

  final String title;
  final Widget cover;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) => Hover(
    cursor: SystemMouseCursors.click,
    builder: (context, hovered) => GestureDetector(
      onTap: onOpen,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: hovered ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            SizedBox(width: 56, height: 56, child: cover),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: Colors.white,
                ),
              ),
            ),
            if (onPlay != null && hovered)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DeskPlayButton(onTap: onPlay!, size: 34),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    ),
  );
}
