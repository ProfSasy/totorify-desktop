import 'package:flutter/material.dart';
import 'package:kreate_ios/models/artist.dart';
import 'package:kreate_ios/models/playlist.dart';
import 'package:kreate_ios/models/song.dart';
import 'package:kreate_ios/services/deezer_service.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/services/playlist_importer_service.dart';
import 'package:kreate_ios/services/storage_service.dart';
import 'package:kreate_ios/ui/theme/app_icons.dart';

import 'desk.dart';
import 'desk_artist.dart';
import 'desk_collection.dart';

/// The menu that opens under the mouse, with the right button or from the
/// three dots of a row.
Future<T?> deskMenu<T>(BuildContext context, Offset at, List<PopupMenuEntry<T>> items) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  return showMenu<T>(
    context: context,
    color: const Color(0xFF282828),
    elevation: 12,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    position: RelativeRect.fromRect(Rect.fromLTWH(at.dx, at.dy, 0, 0), Offset.zero & overlay.size),
    items: items,
  );
}

PopupMenuItem<String> _item(String value, IconData icon, String label, {Color? color}) =>
    PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.white70),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, color: Colors.white),
            ),
          ),
        ],
      ),
    );

/// Asks for a short text in a small window; null when it is given up.
Future<String?> deskAskText(
  BuildContext context, {
  required String title,
  required String hint,
  required String action,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  void done(BuildContext context) {
    final text = controller.text.trim();
    if (text.isNotEmpty) Navigator.of(context).pop(text);
  }

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF282828),
      title: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: InputDecoration(hintText: hint, counterText: ''),
          onSubmitted: (_) => done(context),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
        FilledButton(onPressed: () => done(context), child: Text(action)),
      ],
    ),
  );
}

/// Asks before something that cannot be taken back.
Future<bool> deskConfirm(
  BuildContext context, {
  required String title,
  required String detail,
  required String action,
}) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF282828),
      title: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      content: SizedBox(width: 380, child: Text(detail)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
      ],
    ),
  );
  return sure ?? false;
}

/// Asks for a name and makes a playlist of this computer, then opens it.
Future<Playlist?> deskCreatePlaylist(BuildContext context, {bool open = true}) async {
  final name = await deskAskText(
    context,
    title: 'Nuova playlist',
    hint: 'Come si chiama?',
    action: 'Crea',
  );
  if (name == null) return null;
  PlaybackLogService.instance.log('UI', 'nuova playlist "$name"');
  final created = await StorageService.instance.createPlaylist(name);
  if (open) DeskCollectionPage.openPlaylist(created.id);
  return created;
}

/// Brings in a playlist from a link of Spotify or of YouTube Music.
Future<void> deskImportPlaylist(BuildContext context) async {
  final link = await deskAskText(
    context,
    title: 'Importa una playlist',
    hint: 'Incolla il link di Spotify o di YouTube Music',
    action: 'Importa',
  );
  if (link == null) return;
  PlaybackLogService.instance.log('UI', 'importa playlist da link');
  Desk.say('Importo la playlist…');
  try {
    final created = await PlaylistImporterService.instance.importFromUrl(link);
    if (created == null) {
      Desk.say('Import non riuscito: link non valido o playlist privata.');
      return;
    }
    Desk.say('"${created.title}" importata');
    DeskCollectionPage.openPlaylist(created.id);
  } catch (e) {
    PlaybackLogService.instance.error('UI', 'import della playlist: $e');
    Desk.say('Import non riuscito.');
  }
}

/// What can be done with a song: with the right button on it, or from its
/// three dots. [playlistId] is the playlist of the library it is listed in.
Future<void> deskSongMenu(
  BuildContext context,
  Offset at,
  Song song, {
  List<Song>? queue,
  String? playlistId,
}) async {
  final storage = StorageService.instance;
  final handler = Desk.handler;
  final liked = storage.isFavorite(song.id);
  final current = handler.currentSong;
  final canQueue = current != null && current.id != song.id;
  final artist = DeezerService.primaryArtist(song.artist);
  final log = PlaybackLogService.instance;

  final choice = await deskMenu<String>(context, at, [
    _item('play', AppIcons.play, 'Riproduci'),
    if (canQueue) ...[
      _item('next', AppIcons.playNext, 'Riproduci come prossimo'),
      _item('queue', AppIcons.addToQueue, 'Aggiungi in coda'),
    ],
    const PopupMenuDivider(height: 8),
    _item(
      'like',
      liked ? AppIcons.heartFilled : AppIcons.heart,
      liked ? 'Togli dai brani che ti piacciono' : 'Salva nei brani che ti piacciono',
    ),
    _item('playlist', AppIcons.add, 'Aggiungi a una playlist'),
    if (playlistId != null) _item('remove', AppIcons.trash, 'Togli da questa playlist'),
    if (artist.isNotEmpty) ...[
      const PopupMenuDivider(height: 8),
      _item('artist', AppIcons.artistPage, 'Vai all\'artista'),
    ],
  ]);
  if (choice == null || !context.mounted) return;
  log.log('UI', 'menu brano: $choice "${song.title}"');
  switch (choice) {
    case 'play':
      handler.playSong(song, queue: queue ?? [song]);
    case 'next':
      handler.playNext(song);
      Desk.say('Verrà riprodotto dopo questo brano');
    case 'queue':
      handler.addToQueue(song);
      Desk.say('Aggiunto in coda');
    case 'like':
      await storage.toggleFavorite(song);
      Desk.say(liked ? 'Tolto dai brani che ti piacciono' : 'Salvato nei brani che ti piacciono');
    case 'remove':
      await storage.removeSongFromPlaylist(playlistId!, song.id);
      Desk.say('Tolto dalla playlist');
    case 'artist':
      Desk.nav.open(
        DeskArtistPage(
          artist: Artist(id: 'name:$artist', name: artist),
        ),
      );
    case 'playlist':
      final picked = await deskMenu<String>(context, at, [
        _item('', AppIcons.add, 'Nuova playlist'),
        const PopupMenuDivider(height: 8),
        for (final playlist in Desk.playlists())
          _item(
            playlist.id,
            AppIcons.playlist,
            [playlist.title, ?Desk.whose(playlist.id)].join('  •  '),
          ),
      ]);
      if (picked == null || !context.mounted) return;
      final Playlist? target = picked.isEmpty
          ? await deskCreatePlaylist(context, open: false)
          : storage.playlistsNotifier.value.where((p) => p.id == picked).firstOrNull;
      if (target == null) return;
      final added = await storage.addSongToPlaylist(target.id, song);
      Desk.say(added ? 'Aggiunto a "${target.title}"' : 'È già in "${target.title}"');
  }
}

/// What can be done with a playlist of the library.
Future<void> deskPlaylistMenu(BuildContext context, Offset at, Playlist playlist) async {
  final storage = StorageService.instance;
  final choice = await deskMenu<String>(context, at, [
    _item('play', AppIcons.play, 'Riproduci'),
    const PopupMenuDivider(height: 8),
    _item('rename', Icons.edit_outlined, 'Rinomina'),
    _item('delete', AppIcons.trash, 'Elimina'),
  ]);
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 'play':
      if (playlist.songs.isNotEmpty) {
        Desk.play(playlist.songs.first, playlist.songs, from: 'menu della playlist');
      }
    case 'rename':
      final name = await deskAskText(
        context,
        title: 'Rinomina playlist',
        hint: 'Come si chiama?',
        action: 'Salva',
        initial: playlist.title,
      );
      if (name == null || name == playlist.title) return;
      await storage.renamePlaylist(playlist.id, name);
    case 'delete':
      final sure = await deskConfirm(
        context,
        title: 'Eliminare "${playlist.title}"?',
        detail: 'La playlist viene tolta dalla libreria.',
        action: 'Elimina',
      );
      if (!sure) return;
      PlaybackLogService.instance.log('UI', 'elimino la playlist "${playlist.title}"');
      await storage.deletePlaylist(playlist.id);
      Desk.say('Playlist eliminata');
  }
}
