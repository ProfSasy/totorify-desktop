import 'package:flutter/material.dart';
import 'package:kreate_ios/models/playlist.dart';
import 'package:kreate_ios/models/song.dart';
import 'package:kreate_ios/services/audio_handler.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/services/storage_service.dart';

import 'kit.dart';

/// What the view at the right of the window shows, when it is open.
enum SideView { nowPlaying, queue, devices }

/// What every part of the window reaches for: the player, the pages of the
/// main view, what is typed in the search field, the view at the right.
class App {
  App._();

  static late AudioPlayerHandler player;
  static final Nav nav = Nav();

  /// What is typed in the search field of the top bar.
  static final ValueNotifier<String> query = ValueNotifier<String>('');

  /// The view at the right of the window; null when it is closed.
  static final ValueNotifier<SideView?> side = ValueNotifier<SideView?>(null);

  /// Whether the library at the left is folded down to its covers.
  static final ValueNotifier<bool> libraryFolded = ValueNotifier<bool>(false);

  static final GlobalKey<ScaffoldMessengerState> messenger = GlobalKey<ScaffoldMessengerState>();

  static void toggleSide(SideView view) => side.value = side.value == view ? null : view;

  /// A short line at the foot of the window: what was just done.
  static void toast(String message) {
    messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: Tk.font,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          backgroundColor: Tk.text,
          duration: const Duration(milliseconds: 2600),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: null,
          width: 360,
          elevation: 8,
        ),
      );
  }

  static void play(Song song, List<Song> queue, {required String from}) {
    PlaybackLogService.instance.log('UI', '$from: riproduco "${song.title}"');
    player.playSong(song, queue: queue);
  }

  static String clock(Duration d) {
    final seconds = d.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:${minutes.toString().padLeft(2, '0')}:$rest' : '$minutes:$rest';
  }

  static String songs(int count) => count == 1 ? '1 brano' : '$count brani';

  /// How long a list of songs lasts, as it is said under a playlist's name.
  static String length(List<Song> songs) {
    final seconds = songs.fold<int>(0, (sum, s) => sum + s.duration.inSeconds);
    if (seconds == 0) return '';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return minutes > 0 ? 'circa $hours h $minutes min' : 'circa $hours h';
    return '$minutes min';
  }

  /// The picture of a playlist: its own, or the cover of its first song.
  static String? coverOf(Playlist playlist) {
    final own = playlist.thumbnailUrl;
    if (own != null && own.isNotEmpty) return own;
    for (final song in playlist.songs) {
      if (song.thumbnailUrl.isNotEmpty) return song.thumbnailUrl;
    }
    return null;
  }

  /// Whose a playlist of the library is: the phone's whose library is shown
  /// beside the computer's own, or this computer's.
  static String owner(String playlistId) {
    final storage = StorageService.instance;
    final phone = storage.libraryOwnerNotifier.value;
    return phone != null && storage.isGuestPlaylist(playlistId) ? phone.name : 'Questo computer';
  }

  /// The playlists of the library in the order they are listed: the phone's
  /// before the computer's, the newest first among each.
  static List<Playlist> playlists() {
    final storage = StorageService.instance;
    final all = storage.playlistsNotifier.value;
    return [
      ...all.where((p) => storage.isGuestPlaylist(p.id)).toList().reversed,
      ...all.where((p) => !storage.isGuestPlaylist(p.id)).toList().reversed,
    ];
  }
}

/// The pages of the main view, kept as a browser keeps them: back and
/// forward go through the ones that were opened, each as it was left.
class Nav extends ChangeNotifier {
  static const int _kept = 40;

  final List<({Key key, Widget page})> _pages = [];
  int _index = -1;
  int _made = 0;

  List<({Key key, Widget page})> get pages => List.unmodifiable(_pages);
  int get index => _index;
  bool get canGoBack => _index > 0;
  bool get canGoForward => _index < _pages.length - 1;
  Widget? get current => _index < 0 ? null : _pages[_index].page;

  /// Opens [page] after the one in sight; what was ahead of it is dropped.
  void open(Widget page) {
    if (_index < _pages.length - 1) _pages.removeRange(_index + 1, _pages.length);
    _pages.add((key: ValueKey<int>(_made++), page: page));
    if (_pages.length > _kept) _pages.removeAt(0);
    _index = _pages.length - 1;
    notifyListeners();
  }

  void back() {
    if (!canGoBack) return;
    _index--;
    notifyListeners();
  }

  void forward() {
    if (!canGoForward) return;
    _index++;
    notifyListeners();
  }

  /// Whether the page in sight is a [T].
  bool showing<T extends Widget>() => current is T;
}
