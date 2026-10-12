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

import '../app.dart';
import '../kit.dart';
import '../menus.dart';
import '../widgets.dart';

/// A list of songs with a name and a picture: a playlist, an album, a
/// chart, the liked songs.
class Collection {
  const Collection({
    required this.title,
    required this.songs,
    this.kind = 'Playlist',
    this.about = '',
    this.by = '',
    this.coverUrl,
    this.art,
    this.playlistId,
    this.saveId,
    this.isAlbum = false,
  });

  final String title;

  /// What it is, said above its name.
  final String kind;

  /// A line about it, under its name.
  final String about;

  /// Whose it is, or who made it: the first thing said in its last line.
  final String by;
  final String? coverUrl;

  /// Drawn instead of the picture at [coverUrl].
  final Widget Function(double side)? art;
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

/// The page of a collection: its name large on the colors of its picture,
/// the buttons that play it, and its songs as a table.
class CollectionPage extends StatefulWidget {
  /// A collection of the library: [read] gives it as it is now (null once it
  /// is gone) and is asked again when [changes] says so.
  const CollectionPage.live({super.key, required this.changes, required this.read})
    : load = null,
      title = null;

  /// A collection that has to be fetched. [title] is shown while it is.
  const CollectionPage.load({super.key, required String this.title, required this.load})
    : changes = null,
      read = null;

  final Listenable? changes;
  final Collection? Function()? read;
  final String? title;
  final Future<Collection?> Function()? load;

  static void openPlaylist(String id) {
    final storage = StorageService.instance;
    App.nav.open(
      CollectionPage.live(
        changes: Listenable.merge([storage.playlistsNotifier, storage.libraryOwnerNotifier]),
        read: () {
          final current = storage.playlistsNotifier.value.where((p) => p.id == id).firstOrNull;
          if (current == null) return null;
          return Collection(
            title: current.title,
            about: current.description ?? '',
            by: App.owner(current.id),
            coverUrl: App.coverOf(current),
            songs: current.songs,
            playlistId: current.id,
          );
        },
      ),
    );
  }

  static void openLiked() {
    final storage = StorageService.instance;
    App.nav.open(
      CollectionPage.live(
        changes: storage.favoritesNotifier,
        read: () => Collection(
          title: 'Brani che ti piacciono',
          art: (side) => LikedArt(size: side, radius: 4),
          songs: storage.favoritesNotifier.value,
        ),
      ),
    );
  }

  static void openHistory() {
    // As it was when it was opened: playing from it would otherwise shuffle
    // it under the mouse.
    final songs = StorageService.instance.historyNotifier.value;
    App.nav.open(
      CollectionPage.live(
        changes: null,
        read: () => Collection(
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
    String about = '',
    String? coverUrl,
  }) {
    App.nav.open(
      CollectionPage.load(
        title: title,
        load: () async {
          final songs = await SpotifyCatalogService.instance.getPlaylistSongs(id);
          if (songs.isEmpty) return null;
          return Collection(
            title: title,
            about: about,
            by: 'Totorify',
            coverUrl: coverUrl,
            songs: songs,
            saveId: id,
          );
        },
      ),
    );
  }

  static void openMix(Artist artist) {
    App.nav.open(
      CollectionPage.load(
        title: 'Mix ${artist.name}',
        load: () async {
          final songs = await RecommendationService.instance.mixOf(artist);
          if (songs.isEmpty) return null;
          return Collection(
            title: 'Mix ${artist.name}',
            kind: 'Mix',
            about: '${artist.name} e artisti simili, in base a quello che ascolti',
            by: 'Creato per te',
            coverUrl: artist.imageUrl,
            songs: songs,
            saveId: 'mix_${artist.id}',
          );
        },
      ),
    );
  }

  static void openAlbum(Album album) {
    App.nav.open(
      CollectionPage.load(
        title: album.title,
        load: () async {
          final loaded = await YTMusicCatalogService.instance.albumTracks(album);
          if (loaded == null) return null;
          final (found, songs) = loaded;
          return Collection(
            title: found.title,
            kind: found.type,
            by: [
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
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  Collection? _loaded;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.load != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    Collection? loaded;
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
      if (loaded != null) return _View(collection: loaded);
      return _loading
          ? const Notice()
          : Notice(
              icon: Ic.album,
              title: 'Impossibile caricare i brani',
              text: 'Controlla la connessione e riprova ad aprire "${widget.title}".',
              action: 'Riprova',
              onAction: _load,
            );
    }
    Widget view(BuildContext context) {
      final collection = widget.read!();
      return collection == null
          ? const Notice(
              icon: Ic.playlist,
              title: 'Playlist non disponibile',
              text: 'È stata eliminata dalla libreria.',
            )
          : _View(collection: collection);
    }

    final changes = widget.changes;
    return changes == null
        ? view(context)
        : ListenableBuilder(listenable: changes, builder: (context, _) => view(context));
  }
}

class _View extends StatelessWidget {
  const _View({required this.collection});

  final Collection collection;

  static double _titleSize(String title) => switch (title.length) {
    <= 12 => 88,
    <= 20 => 68,
    <= 32 => 48,
    _ => 32,
  };

  Future<void> _toggleSaved(bool saved) async {
    final storage = StorageService.instance;
    final id = collection.saveId!;
    if (saved) {
      await storage.deletePlaylist(id);
      App.toast('Rimossa dalla tua libreria');
    } else {
      await storage.savePlaylist(
        Playlist(
          id: id,
          title: collection.title,
          description: collection.about.isEmpty ? null : collection.about,
          thumbnailUrl: collection.coverUrl,
          songs: collection.songs,
        ),
      );
      App.toast('Aggiunta alla tua libreria');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final player = App.player;
    final songs = collection.songs;
    final facts = [
      App.songs(songs.length),
      App.length(songs),
    ].where((part) => part.isNotEmpty).join(', ');
    void play(Song song, List<Song> queue) => App.play(song, queue, from: collection.title);

    return AmbientTint(
      artworkUrl: collection.coverUrl,
      fallback: collection.art != null ? const Color(0xFF5038A0) : accent,
      builder: (context, palette) => CustomScrollView(
        slivers: [
          // ── Its name, on the colors of its picture ───────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [palette.surface, Color.lerp(palette.surface, Tk.panel, 0.5)!],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(color: Color(0x80000000), blurRadius: 44, offset: Offset(0, 6)),
                      ],
                    ),
                    child:
                        collection.art?.call(208) ??
                        Artwork(url: collection.coverUrl, seed: collection.title, size: 208),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.kind,
                          style: const TextStyle(fontSize: 13.5, color: Tk.text),
                        ),
                        Text(
                          collection.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Tk.title(
                            _titleSize(collection.title),
                          ).copyWith(fontWeight: FontWeight.w900),
                        ),
                        if (collection.about.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            collection.about,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, color: Color(0xB3FFFFFF)),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            children: [
                              if (collection.by.isNotEmpty)
                                TextSpan(
                                  text: collection.by,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              if (collection.by.isNotEmpty) const TextSpan(text: ' • '),
                              TextSpan(
                                text: facts,
                                style: const TextStyle(color: Color(0xB3FFFFFF)),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: Tk.text),
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(palette.surface, Tk.panel, 0.74)!, Tk.panel],
                ),
              ),
              child: Row(
                children: [
                  if (songs.isNotEmpty) ...[
                    ValueListenableBuilder<(String?, bool)>(
                      valueListenable: player.playbackIndicator,
                      builder: (context, indicator, _) {
                        final isCurrent =
                            player.currentSong != null &&
                            songs.any((s) => s.id == player.currentSong!.id);
                        final playing = isCurrent && indicator.$2;
                        return PlayFab(
                          size: 56,
                          playing: playing,
                          onTap: () {
                            if (playing) {
                              player.pause();
                            } else if (isCurrent) {
                              player.play();
                            } else {
                              play(songs.first, songs);
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 22),
                    IconBtn(
                      Ic.shuffle,
                      tip: 'Riproduci in ordine casuale',
                      size: 30,
                      onTap: () {
                        final shuffled = List<Song>.from(songs)..shuffle();
                        play(shuffled.first, shuffled);
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (collection.saveId != null && songs.isNotEmpty)
                    ValueListenableBuilder<List<Playlist>>(
                      valueListenable: StorageService.instance.playlistsNotifier,
                      builder: (context, playlists, _) {
                        final saved = playlists.any((p) => p.id == collection.saveId);
                        return IconBtn(
                          saved ? Ic.saved : Ic.save,
                          tip: saved ? 'Rimuovi dalla tua libreria' : 'Salva nella tua libreria',
                          size: 30,
                          on: saved,
                          onTap: () => _toggleSaved(saved),
                        );
                      },
                    ),
                  if (collection.playlistId != null)
                    Builder(
                      builder: (context) => IconBtn(
                        Ic.more,
                        tip: 'Altre opzioni per ${collection.title}',
                        size: 30,
                        onTap: () {
                          final playlist = StorageService.instance.playlistsNotifier.value
                              .where((p) => p.id == collection.playlistId)
                              .firstOrNull;
                          if (playlist == null) return;
                          final box = context.findRenderObject()! as RenderBox;
                          playlistMenu(
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
            SliverFillRemaining(
              hasScrollBody: false,
              child: collection.playlistId != null
                  ? const Notice(
                      icon: Ic.note,
                      title: 'Troviamo qualcosa per la tua playlist',
                      text:
                          'Cerca un brano, poi fai clic con il tasto destro e scegli '
                          '"Aggiungi alla playlist".',
                    )
                  : const Notice(
                      icon: Ic.note,
                      title: 'Qui compariranno i tuoi brani',
                      text: 'Salva i brani con il pulsante "+" accanto al titolo.',
                    ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverToBoxAdapter(child: TrackHeader(album: !collection.isAlbum)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
              sliver: SliverFixedExtentList(
                itemExtent: TrackRow.height,
                delegate: SliverChildBuilderDelegate(childCount: songs.length, (context, index) {
                  final song = songs[index];
                  return TrackRow(
                    song: song,
                    number: index + 1,
                    queue: songs,
                    playlistId: collection.playlistId,
                    album: !collection.isAlbum,
                    art: !collection.isAlbum,
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
