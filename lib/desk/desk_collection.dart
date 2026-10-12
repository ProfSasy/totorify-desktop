import 'package:flutter/material.dart';
import 'package:kreate_ios/models/album.dart';
import 'package:kreate_ios/models/artist.dart';
import 'package:kreate_ios/models/playlist.dart';
import 'package:kreate_ios/models/song.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/services/recommendation_service.dart';
import 'package:kreate_ios/services/spotify_catalog_service.dart';
import 'package:kreate_ios/services/storage_service.dart';
import 'package:kreate_ios/services/ytmusic_catalog_service.dart';
import 'package:kreate_ios/ui/theme/app_ambience.dart';
import 'package:kreate_ios/ui/theme/app_icons.dart';
import 'package:kreate_ios/ui/widgets/app_cover.dart';
import 'package:kreate_ios/ui/widgets/song_options_sheet.dart' show playlistCoverUrl;

import 'desk.dart';
import 'desk_menus.dart';
import 'desk_widgets.dart';

/// A list of songs with a name and a cover: a playlist, an album, a chart,
/// the liked songs.
class DeskCollection {
  const DeskCollection({
    required this.title,
    required this.songs,
    this.kind = 'Playlist',
    this.caption = '',
    this.coverUrl,
    this.cover,
    this.playlistId,
    this.saveId,
    this.isAlbum = false,
  });

  final String title;

  /// What it is, said above its name: "Playlist", "Album", "Mix".
  final String kind;
  final String caption;
  final String? coverUrl;

  /// Drawn instead of the picture at [coverUrl].
  final Widget Function(double size)? cover;
  final List<Song> songs;

  /// Its id when it is a playlist of the library: it can be renamed and
  /// removed, and songs can be taken out of it.
  final String? playlistId;

  /// The id it is kept under when it is saved in the library; null for what
  /// cannot be saved. The same ids as on the phone.
  final String? saveId;

  /// The songs of an album need no cover and no album beside each one.
  final bool isAlbum;
}

/// The page of a collection: a header in the colors of its cover, the
/// buttons that play it, and its songs as a table.
class DeskCollectionPage extends StatefulWidget {
  /// A collection of the library: [read] gives it as it is now (null once it
  /// is gone) and is asked again when [changes] says so.
  const DeskCollectionPage.live({super.key, required this.changes, required this.read})
    : load = null,
      title = null;

  /// A collection that has to be fetched. [title] is shown while it is.
  const DeskCollectionPage.load({super.key, required String this.title, required this.load})
    : changes = null,
      read = null;

  final Listenable? changes;
  final DeskCollection? Function()? read;
  final String? title;
  final Future<DeskCollection?> Function()? load;

  static void openPlaylist(String id) {
    final storage = StorageService.instance;
    Desk.nav.open(
      DeskCollectionPage.live(
        changes: Listenable.merge([storage.playlistsNotifier, storage.libraryOwnerNotifier]),
        read: () {
          final current = storage.playlistsNotifier.value.where((p) => p.id == id).firstOrNull;
          if (current == null) return null;
          return DeskCollection(
            title: current.title,
            caption: [
              ?Desk.whose(current.id),
              if ((current.description ?? '').isNotEmpty) current.description!,
            ].join(' • '),
            coverUrl: playlistCoverUrl(current),
            songs: current.songs,
            playlistId: current.id,
          );
        },
      ),
    );
  }

  static void openLiked() {
    final storage = StorageService.instance;
    Desk.nav.open(
      DeskCollectionPage.live(
        changes: storage.favoritesNotifier,
        read: () => DeskCollection(
          title: 'Brani che ti piacciono',
          cover: (size) => DeskLikedCover(size: size),
          songs: storage.favoritesNotifier.value,
        ),
      ),
    );
  }

  static void openHistory() {
    // As it was when it was opened: playing from it would otherwise shuffle
    // it under the mouse.
    final songs = StorageService.instance.historyNotifier.value;
    Desk.nav.open(
      DeskCollectionPage.live(
        changes: null,
        read: () => DeskCollection(
          title: 'Ascoltati di recente',
          kind: 'Cronologia',
          coverUrl: songs.isEmpty ? null : songs.first.thumbnailUrl,
          songs: songs,
        ),
      ),
    );
  }

  static void openEditorial({
    required String id,
    required String title,
    String caption = '',
    String? coverUrl,
  }) {
    Desk.nav.open(
      DeskCollectionPage.load(
        title: title,
        load: () async {
          final songs = await SpotifyCatalogService.instance.getPlaylistSongs(id);
          if (songs.isEmpty) return null;
          return DeskCollection(
            title: title,
            caption: caption,
            coverUrl: coverUrl,
            songs: songs,
            saveId: id,
          );
        },
      ),
    );
  }

  static void openMix(Artist artist) {
    Desk.nav.open(
      DeskCollectionPage.load(
        title: 'Mix ${artist.name}',
        load: () async {
          final songs = await RecommendationService.instance.mixOf(artist);
          if (songs.isEmpty) return null;
          return DeskCollection(
            title: 'Mix ${artist.name}',
            kind: 'Mix',
            caption: '${artist.name} e artisti simili, scelti per te',
            coverUrl: artist.imageUrl,
            songs: songs,
            saveId: 'mix_${artist.id}',
          );
        },
      ),
    );
  }

  static void openAlbum(Album album) {
    Desk.nav.open(
      DeskCollectionPage.load(
        title: album.title,
        load: () async {
          final loaded = await YTMusicCatalogService.instance.albumTracks(album);
          if (loaded == null) return null;
          final (found, songs) = loaded;
          return DeskCollection(
            title: found.title,
            kind: found.type,
            caption: [
              if (found.artist.isNotEmpty) found.artist,
              if (found.year.isNotEmpty) found.year,
            ].join(' • '),
            coverUrl: found.coverUrl,
            songs: songs,
            saveId: 'album_${found.id}',
            isAlbum: true,
          );
        },
      ),
    );
  }

  @override
  State<DeskCollectionPage> createState() => _DeskCollectionPageState();
}

class _DeskCollectionPageState extends State<DeskCollectionPage> {
  DeskCollection? _loaded;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.load != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    DeskCollection? loaded;
    try {
      loaded = await widget.load!();
    } catch (e) {
      PlaybackLogService.instance.error('UI', 'raccolta "${widget.title}" non letta: $e');
    }
    if (!mounted) return;
    setState(() {
      _loaded = loaded;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.load != null) {
      final loaded = _loaded;
      if (loaded != null) return _CollectionView(collection: loaded);
      return _loading
          ? const DeskMessage()
          : DeskMessage(
              icon: AppIcons.album,
              title: 'Brani non disponibili',
              subtitle: 'Non sono riuscito a leggere "${widget.title}".',
              action: 'Riprova',
              onAction: _load,
            );
    }
    Widget view(BuildContext context) {
      final collection = widget.read!();
      return collection == null
          ? const DeskMessage(
              icon: AppIcons.playlist,
              title: 'Questa playlist non c\'è più',
              subtitle: 'È stata tolta dalla libreria.',
            )
          : _CollectionView(collection: collection);
    }

    final changes = widget.changes;
    return changes == null
        ? view(context)
        : ListenableBuilder(listenable: changes, builder: (context, _) => view(context));
  }
}

class _CollectionView extends StatelessWidget {
  const _CollectionView({required this.collection});

  final DeskCollection collection;

  static double _titleSize(String title) => switch (title.length) {
    <= 14 => 68,
    <= 24 => 52,
    <= 40 => 38,
    _ => 28,
  };

  Future<void> _toggleSaved(bool saved) async {
    final storage = StorageService.instance;
    final id = collection.saveId!;
    if (saved) {
      await storage.deletePlaylist(id);
      Desk.say('Tolta dalla tua libreria');
    } else {
      await storage.savePlaylist(
        Playlist(
          id: id,
          title: collection.title,
          description: collection.caption.isEmpty ? null : collection.caption,
          thumbnailUrl: collection.coverUrl,
          songs: collection.songs,
        ),
      );
      Desk.say('Salvata nella tua libreria');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final handler = Desk.handler;
    final songs = collection.songs;
    final about = [
      Desk.songs(songs.length),
      Desk.length(songs),
    ].where((s) => s.isNotEmpty).join(', ');
    void play(Song song, List<Song> queue) => Desk.play(song, queue, from: collection.title);

    return AmbientTint(
      artworkUrl: collection.coverUrl,
      fallback: cs.primary,
      builder: (context, palette) => CustomScrollView(
        slivers: [
          // ── What it is, on the colors of its cover ───────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [palette.surface, Color.lerp(palette.surface, Desk.panel, 0.55)!],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 10)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child:
                          collection.cover?.call(200) ??
                          AppCover(
                            url: collection.coverUrl,
                            size: 200,
                            radius: 0,
                            icon: AppIcons.playlist,
                          ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.kind,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          collection.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _titleSize(collection.title),
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: -1.5,
                            color: Colors.white,
                          ),
                        ),
                        if (collection.caption.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            collection.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, color: Colors.white70),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          about,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── What can be done with it ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(palette.surface, Desk.panel, 0.72)!, Desk.panel],
                ),
              ),
              child: Row(
                children: [
                  if (songs.isNotEmpty) ...[
                    ValueListenableBuilder<(String?, bool)>(
                      valueListenable: handler.playbackIndicator,
                      builder: (context, indicator, _) {
                        final isCurrent =
                            handler.currentSong != null &&
                            songs.any((s) => s.id == handler.currentSong!.id);
                        final playing = isCurrent && indicator.$2;
                        return DeskPlayButton(
                          size: 56,
                          playing: playing,
                          onTap: () {
                            if (playing) {
                              handler.pause();
                            } else if (isCurrent) {
                              handler.play();
                            } else {
                              play(songs.first, songs);
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 18),
                    DeskIconButton(
                      icon: AppIcons.shuffle,
                      tooltip: 'Riproduzione casuale',
                      size: 26,
                      onTap: () {
                        final shuffled = List<Song>.from(songs)..shuffle();
                        play(shuffled.first, shuffled);
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (collection.saveId != null && songs.isNotEmpty)
                    ValueListenableBuilder<List<Playlist>>(
                      valueListenable: StorageService.instance.playlistsNotifier,
                      builder: (context, playlists, _) {
                        final saved = playlists.any((p) => p.id == collection.saveId);
                        return DeskIconButton(
                          icon: saved ? AppIcons.saved : AppIcons.save,
                          tooltip: saved ? 'Togli dalla tua libreria' : 'Salva nella tua libreria',
                          size: 26,
                          active: saved,
                          onTap: () => _toggleSaved(saved),
                        );
                      },
                    ),
                  if (collection.playlistId != null)
                    Builder(
                      builder: (context) => DeskIconButton(
                        icon: AppIcons.more,
                        tooltip: 'Altre opzioni',
                        size: 26,
                        onTap: () {
                          final playlist = StorageService.instance.playlistsNotifier.value
                              .where((p) => p.id == collection.playlistId)
                              .firstOrNull;
                          if (playlist == null) return;
                          final box = context.findRenderObject()! as RenderBox;
                          deskPlaylistMenu(
                            context,
                            box.localToGlobal(Offset(0, box.size.height)),
                            playlist,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Its songs ────────────────────────────────────────────────────
          if (songs.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: DeskMessage(
                icon: AppIcons.note,
                title: 'Ancora nessun brano',
                subtitle:
                    'Cerca un brano, poi con il tasto destro scegli "Aggiungi a una playlist".',
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverToBoxAdapter(child: DeskTrackHeader(showAlbum: !collection.isAlbum)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 28),
              sliver: SliverFixedExtentList(
                itemExtent: DeskTrackRow.height,
                delegate: SliverChildBuilderDelegate(childCount: songs.length, (context, index) {
                  final song = songs[index];
                  return DeskTrackRow(
                    song: song,
                    number: index + 1,
                    queue: songs,
                    playlistId: collection.playlistId,
                    showAlbum: !collection.isAlbum,
                    showCover: !collection.isAlbum,
                    onPlay: () => play(song, songs),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
