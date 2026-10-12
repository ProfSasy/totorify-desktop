import 'package:flutter/material.dart';
import 'package:kreate_ios/models/artist.dart';
import 'package:kreate_ios/models/playlist.dart';
import 'package:kreate_ios/models/song.dart';
import 'package:kreate_ios/services/deezer_service.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/services/playlist_importer_service.dart';
import 'package:kreate_ios/services/storage_service.dart';

import 'app.dart';
import 'kit.dart';
import 'pages/artist.dart';
import 'pages/collection.dart';

/// The menus that open under the mouse and the small windows that ask
/// something, for the whole app.

/// One line of a menu.
PopupMenuEntry<String> menuItem(String value, IconData icon, String label, {bool danger = false}) =>
    PopupMenuItem<String>(
      value: value,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Hover(
        builder: (context, hovered) => Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: hovered ? Tk.menuHover : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: Tk.subdued),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Tk.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );

const PopupMenuEntry<String> menuLine = PopupMenuDivider(height: 9);

/// Opens a menu at [at], a point of the window.
Future<String?> openMenu(BuildContext context, Offset at, List<PopupMenuEntry<String>> items) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  return showMenu<String>(
    context: context,
    menuPadding: const EdgeInsets.symmetric(vertical: 4),
    constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
    position: RelativeRect.fromRect(Rect.fromLTWH(at.dx, at.dy, 0, 0), Offset.zero & overlay.size),
    items: items,
  );
}

/// A small window with a title, something in it and two answers.
Future<T?> _ask<T>(
  BuildContext context, {
  required String title,
  required Widget body,
  required String confirm,
  required T? Function() onConfirm,
}) => showDialog<T>(
  context: context,
  barrierColor: const Color(0xB3000000),
  builder: (context) => Dialog(
    child: SizedBox(
      width: 420,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Tk.title(22)),
            const SizedBox(height: 16),
            body,
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                LinkText(
                  'Annulla',
                  onTap: () => Navigator.of(context).pop(),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Tk.subdued,
                  ),
                ),
                const SizedBox(width: 24),
                WhiteButton(
                  confirm,
                  accent: true,
                  onTap: () {
                    final value = onConfirm();
                    if (value != null) Navigator.of(context).pop(value);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
);

/// Asks for a short text; null when it is given up.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirm,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  String? value() {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  return _ask<String>(
    context,
    title: title,
    confirm: confirm,
    onConfirm: value,
    body: Builder(
      builder: (context) => TextField(
        controller: controller,
        autofocus: true,
        maxLength: 200,
        style: const TextStyle(fontSize: 14.5, color: Tk.text),
        onSubmitted: (_) {
          final text = value();
          if (text != null) Navigator.of(context).pop(text);
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Tk.faint),
          counterText: '',
          filled: true,
          fillColor: Tk.menuHover,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Tk.faint),
          ),
        ),
      ),
    ),
  );
}

/// Asks before something that cannot be taken back.
Future<bool> askSure(
  BuildContext context, {
  required String title,
  required String text,
  required String confirm,
}) async =>
    await _ask<bool>(
      context,
      title: title,
      confirm: confirm,
      onConfirm: () => true,
      body: Text(text, style: const TextStyle(fontSize: 14, height: 1.45, color: Tk.subdued)),
    ) ??
    false;

/// Asks for a name and makes a playlist of this computer.
Future<Playlist?> createPlaylist(BuildContext context, {bool open = true}) async {
  final name = await askText(
    context,
    title: 'Crea playlist',
    hint: 'Dai un nome alla playlist',
    confirm: 'Crea',
  );
  if (name == null) return null;
  PlaybackLogService.instance.log('UI', 'nuova playlist "$name"');
  final created = await StorageService.instance.createPlaylist(name);
  if (open) CollectionPage.openPlaylist(created.id);
  return created;
}

/// Brings in a playlist from a link of Spotify or of YouTube Music.
Future<void> importPlaylist(BuildContext context) async {
  final link = await askText(
    context,
    title: 'Importa playlist',
    hint: 'Incolla un link di Spotify o YouTube Music',
    confirm: 'Importa',
  );
  if (link == null) return;
  PlaybackLogService.instance.log('UI', 'importa playlist da link');
  App.toast('Importazione in corso…');
  try {
    final created = await PlaylistImporterService.instance.importFromUrl(link);
    if (created == null) {
      App.toast('Impossibile importare: link non valido o playlist privata');
      return;
    }
    App.toast('"${created.title}" aggiunta alla tua libreria');
    CollectionPage.openPlaylist(created.id);
  } catch (e) {
    PlaybackLogService.instance.error('UI', 'import della playlist: $e');
    App.toast('Impossibile importare la playlist');
  }
}

/// What can be done with a song: with the right button on it, or from its
/// three dots. [playlistId] is the playlist of the library it is listed in.
Future<void> songMenu(
  BuildContext context,
  Offset at,
  Song song, {
  List<Song>? queue,
  String? playlistId,
}) async {
  final storage = StorageService.instance;
  final player = App.player;
  final liked = storage.isFavorite(song.id);
  final current = player.currentSong;
  final canQueue = current != null && current.id != song.id;
  final artist = DeezerService.primaryArtist(song.artist);

  final choice = await openMenu(context, at, [
    menuItem('playlist', Ic.plus, 'Aggiungi alla playlist'),
    if (playlistId != null) menuItem('remove', Ic.trash, 'Rimuovi da questa playlist'),
    menuItem(
      'like',
      liked ? Ic.saved : Ic.save,
      liked ? 'Rimuovi da Brani che ti piacciono' : 'Salva in Brani che ti piacciono',
    ),
    if (canQueue) ...[
      menuItem('queue', Ic.addToQueue, 'Aggiungi in coda'),
      menuItem('next', Ic.playNext, 'Riproduci subito dopo'),
    ],
    if (artist.isNotEmpty) ...[menuLine, menuItem('artist', Ic.artist, 'Vai all\'artista')],
  ]);
  if (choice == null || !context.mounted) return;
  PlaybackLogService.instance.log('UI', 'menu brano: $choice "${song.title}"');
  switch (choice) {
    case 'next':
      player.playNext(song);
      App.toast('In riproduzione subito dopo');
    case 'queue':
      player.addToQueue(song);
      App.toast('Aggiunto alla coda');
    case 'like':
      await storage.toggleFavorite(song);
      App.toast(liked ? 'Rimosso da Brani che ti piacciono' : 'Aggiunto a Brani che ti piacciono');
    case 'remove':
      await storage.removeSongFromPlaylist(playlistId!, song.id);
      App.toast('Rimosso dalla playlist');
    case 'artist':
      App.nav.open(
        ArtistPage(
          artist: Artist(id: 'name:$artist', name: artist),
        ),
      );
    case 'playlist':
      final picked = await openMenu(context, at, [
        menuItem('', Ic.plus, 'Nuova playlist'),
        menuLine,
        for (final playlist in App.playlists()) menuItem(playlist.id, Ic.playlist, playlist.title),
      ]);
      if (picked == null || !context.mounted) return;
      final Playlist? target = picked.isEmpty
          ? await createPlaylist(context, open: false)
          : storage.playlistsNotifier.value.where((p) => p.id == picked).firstOrNull;
      if (target == null) return;
      final added = await storage.addSongToPlaylist(target.id, song);
      App.toast(added ? 'Aggiunto a ${target.title}' : 'È già in ${target.title}');
  }
}

/// What can be done with a playlist of the library.
Future<void> playlistMenu(BuildContext context, Offset at, Playlist playlist) async {
  final storage = StorageService.instance;
  final choice = await openMenu(context, at, [
    if (playlist.songs.isNotEmpty) ...[
      menuItem('queue', Ic.addToQueue, 'Aggiungi in coda'),
      menuLine,
    ],
    menuItem('rename', Ic.edit, 'Modifica nome'),
    menuItem('delete', Ic.trash, 'Elimina'),
  ]);
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 'queue':
      if (App.player.currentSong == null) {
        App.play(playlist.songs.first, playlist.songs, from: 'menu della playlist');
      } else {
        for (final song in playlist.songs) {
          App.player.addToQueue(song);
        }
        App.toast('Aggiunta alla coda');
      }
    case 'rename':
      final name = await askText(
        context,
        title: 'Modifica nome',
        hint: 'Dai un nome alla playlist',
        confirm: 'Salva',
        initial: playlist.title,
      );
      if (name == null || name == playlist.title) return;
      await storage.renamePlaylist(playlist.id, name);
    case 'delete':
      final sure = await askSure(
        context,
        title: 'Eliminare dalla tua libreria?',
        text: 'Questa azione elimina "${playlist.title}" dalla tua libreria.',
        confirm: 'Elimina',
      );
      if (!sure) return;
      PlaybackLogService.instance.log('UI', 'elimino la playlist "${playlist.title}"');
      await storage.deletePlaylist(playlist.id);
      App.toast('Rimossa dalla tua libreria');
  }
}
