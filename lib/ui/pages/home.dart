import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kreate_ios/models/artist.dart';
import 'package:kreate_ios/services/recommendation_service.dart';
import 'package:kreate_ios/services/spotify_catalog_service.dart';
import 'package:kreate_ios/services/storage_service.dart';

import '../app.dart';
import '../kit.dart';
import '../menus.dart';
import '../widgets.dart';
import 'artist.dart';
import 'collection.dart';

/// The Home: pills that choose what it shows, eight strips to go back to
/// what is listened to most, then rows of cards.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const List<String> _filters = ['Tutto', 'Per te', 'Classifiche', 'Generi'];

  String _filter = _filters.first;

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
      debugPrint('HomePage._refreshMixes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
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
        final playlists = App.playlists();
        final artists = storage.followedArtistsNotifier.value;
        final charts = catalog.featuredPlaylists;
        final genres = catalog.browseCategories;
        final all = _filter == 'Tutto';
        final forYou = all || _filter == 'Per te';
        final showCharts = all || _filter == 'Classifiche';
        final showGenres = all || _filter == 'Generi';

        // What to go back to: the liked songs, the playlists, then charts.
        final quick = <Widget>[
          QuickTile(
            title: 'Brani che ti piacciono',
            art: const LikedArt(size: QuickTile.height, radius: 0),
            onOpen: CollectionPage.openLiked,
          ),
          for (final playlist in playlists.take(5))
            QuickTile(
              title: playlist.title,
              art: Artwork(
                url: App.coverOf(playlist),
                seed: playlist.title,
                size: QuickTile.height,
                radius: 0,
              ),
              onOpen: () => CollectionPage.openPlaylist(playlist.id),
              onPlay: playlist.songs.isEmpty
                  ? null
                  : () => App.play(playlist.songs.first, playlist.songs, from: 'home'),
              onMenu: (at) => playlistMenu(context, at, playlist),
            ),
        ];
        for (final chart in charts) {
          if (quick.length >= 8) break;
          quick.add(
            QuickTile(
              title: chart.title,
              art: Artwork(
                url: chart.coverUrl,
                seed: chart.title,
                size: QuickTile.height,
                radius: 0,
              ),
              onOpen: () => CollectionPage.openEditorial(
                id: chart.id,
                title: chart.title,
                about: chart.subtitle,
                coverUrl: chart.coverUrl,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.28],
                colors: [Color.lerp(accent, Tk.panel, 0.76)!, Tk.panel],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      for (final filter in _filters) ...[
                        Pill(
                          filter,
                          selected: _filter == filter,
                          onTap: () => setState(() => _filter = filter),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                if (all)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 860
                            ? 4
                            : (constraints.maxWidth >= 440 ? 2 : 1);
                        const gap = 8.0;
                        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [for (final tile in quick) SizedBox(width: width, child: tile)],
                        );
                      },
                    ),
                  ),

                if (forYou) ...[
                  Shelf(
                    title: 'Ascoltati di recente',
                    count: history.length,
                    onShowAll: CollectionPage.openHistory,
                    builder: (context, index) {
                      final song = history[index];
                      void play() => App.play(song, history, from: 'home, ascoltati di recente');
                      return MediaCard(
                        title: song.title,
                        subtitle: song.artist,
                        art: (side) => Artwork(
                          url: song.thumbnailUrl,
                          seed: song.title,
                          size: side,
                          radius: 6,
                        ),
                        onOpen: play,
                        onPlay: play,
                        onMenu: (at) => songMenu(context, at, song, queue: history),
                      );
                    },
                  ),
                  Shelf(
                    title: 'Creati per te',
                    count: _mixArtists.length,
                    builder: (context, index) {
                      final artist = _mixArtists[index];
                      return MediaCard(
                        title: 'Mix ${artist.name}',
                        subtitle: '${artist.name} e artisti simili',
                        art: (side) => _MixArt(artist: artist, index: index, side: side),
                        onOpen: () => CollectionPage.openMix(artist),
                      );
                    },
                  ),
                ],
                if (showCharts)
                  Shelf(
                    title: 'Classifiche in evidenza',
                    count: charts.length,
                    rows: all ? 1 : 3,
                    builder: (context, index) {
                      final chart = charts[index];
                      return MediaCard(
                        title: chart.title,
                        subtitle: chart.subtitle,
                        art: (side) =>
                            Artwork(url: chart.coverUrl, seed: chart.title, size: side, radius: 6),
                        onOpen: () => CollectionPage.openEditorial(
                          id: chart.id,
                          title: chart.title,
                          about: chart.subtitle,
                          coverUrl: chart.coverUrl,
                        ),
                      );
                    },
                  ),
                if (forYou) ...[
                  Shelf(
                    title: 'Le tue playlist',
                    count: playlists.length,
                    rows: all ? 1 : 3,
                    builder: (context, index) {
                      final playlist = playlists[index];
                      return MediaCard(
                        title: playlist.title,
                        subtitle: 'Di ${App.owner(playlist.id)}',
                        art: (side) => Artwork(
                          url: App.coverOf(playlist),
                          seed: playlist.title,
                          size: side,
                          radius: 6,
                        ),
                        onOpen: () => CollectionPage.openPlaylist(playlist.id),
                        onPlay: playlist.songs.isEmpty
                            ? null
                            : () => App.play(playlist.songs.first, playlist.songs, from: 'home'),
                        onMenu: (at) => playlistMenu(context, at, playlist),
                      );
                    },
                  ),
                  Shelf(
                    title: 'I tuoi artisti preferiti',
                    count: artists.length,
                    builder: (context, index) {
                      final artist = artists[index];
                      return MediaCard(
                        title: artist.name,
                        subtitle: 'Artista',
                        round: true,
                        art: (side) => Artwork(
                          url: artist.imageUrl,
                          seed: artist.name,
                          size: side,
                          round: true,
                        ),
                        onOpen: () => App.nav.open(ArtistPage(artist: artist)),
                      );
                    },
                  ),
                ],
                if (showGenres && genres.isNotEmpty) ...[
                  const SectionTitle('Sfoglia per genere'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = (constraints.maxWidth / 220).floor().clamp(2, 6);
                        const gap = 16.0;
                        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final genre in genres) GenreTile(genre: genre, width: width),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The picture of a mix: the artist's portrait with a band of color at its
/// foot, as the covers of the mixes made for one listener are drawn.
class _MixArt extends StatelessWidget {
  const _MixArt({required this.artist, required this.index, required this.side});

  final Artist artist;
  final int index;
  final double side;

  static const List<Color> _bands = [
    Color(0xFF1ED760),
    Color(0xFFF59B23),
    Color(0xFFE91429),
    Color(0xFF509BF5),
    Color(0xFFAF2896),
    Color(0xFF27856A),
  ];

  @override
  Widget build(BuildContext context) {
    final band = _bands[index % _bands.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: side,
        height: side,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (artist.imageUrl.isEmpty)
              Artwork(url: null, seed: artist.name, size: side, radius: 0)
            else
              CachedNetworkImage(
                imageUrl: artist.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => const ColoredBox(color: Tk.hover),
                errorWidget: (_, _, _) =>
                    Artwork(url: null, seed: artist.name, size: side, radius: 0),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x99000000)],
                ),
              ),
            ),
            Positioned(
              left: 0,
              bottom: side * 0.1,
              child: Container(
                height: side * 0.17,
                padding: EdgeInsets.only(left: side * 0.07, right: side * 0.08),
                alignment: Alignment.center,
                color: band,
                child: Text(
                  'Mix',
                  style: TextStyle(
                    fontSize: side * 0.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: side * 0.08,
              child: Container(width: 5, height: side * 0.2, color: band),
            ),
          ],
        ),
      ),
    );
  }
}
