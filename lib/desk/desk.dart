import 'package:flutter/material.dart';
import 'package:kreate_ios/models/playlist.dart';
import 'package:kreate_ios/models/song.dart';
import 'package:kreate_ios/services/audio_handler.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/services/storage_service.dart';

/// What the panel at the right of the window shows, when it is open.
enum DeskSide { queue, lyrics, devices }

/// What every part of the computer app reaches for: the player, the pages
/// of the main panel, what is typed in the search field, the panel at the
/// right, and the look they share.
class Desk {
  Desk._();

  static late AudioPlayerHandler handler;
  static final DeskNav nav = DeskNav();

  /// What is typed in the search field of the top bar.
  static final ValueNotifier<String> query = ValueNotifier<String>('');

  /// The panel at the right of the window; null when it is closed.
  static final ValueNotifier<DeskSide?> side = ValueNotifier<DeskSide?>(null);

  /// Whether the library at the left shows only its covers.
  static final ValueNotifier<bool> libraryCollapsed = ValueNotifier<bool>(false);

  static final GlobalKey<ScaffoldMessengerState> messenger = GlobalKey<ScaffoldMessengerState>();

  // The window is black, and what is in it sits on panels a shade lighter,
  // a little apart from each other.
  static const Color window = Color(0xFF000000);
  static const Color panel = Color(0xFF121212);
  static const Color raised = Color(0xFF1F1F1F);
  static const Color hover = Color(0xFF2A2A2A);
  static const double gap = 8;

  /// The typeface of the computer app.
  static const String font = 'Figtree';
  static const double radius = 10;

  static void toggleSide(DeskSide which) => side.value = side.value == which ? null : which;

  /// A short line at the foot of the window.
  static void say(String message) {
    messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          backgroundColor: Colors.white,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          width: 380,
        ),
      );
  }

  static void play(Song song, List<Song> queue, {required String from}) {
    PlaybackLogService.instance.log('UI', '$from: scelgo "${song.title}"');
    handler.playSong(song, queue: queue);
  }

  static String clock(Duration d) {
    final seconds = d.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:${minutes.toString().padLeft(2, '0')}:$rest' : '$minutes:$rest';
  }

  static String songs(int count) => count == 1 ? '1 brano' : '$count brani';

  /// How long a list of songs lasts, in words.
  static String length(List<Song> songs) {
    final seconds = songs.fold<int>(0, (sum, s) => sum + s.duration.inSeconds);
    if (seconds == 0) return '';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return minutes > 0 ? '$hours h $minutes min' : '$hours h';
    return '$minutes min';
  }

  /// Whose a playlist of the library is, while a phone's library is shown
  /// beside the computer's own; null while there is only the computer's.
  static String? whose(String playlistId) {
    final storage = StorageService.instance;
    final phone = storage.libraryOwnerNotifier.value;
    if (phone == null) return null;
    return storage.isGuestPlaylist(playlistId) ? phone.name : 'Questo computer';
  }

  /// The playlists of the library in the order they are listed: the
  /// phone's before the computer's, the newest first among each.
  static List<Playlist> playlists() {
    final storage = StorageService.instance;
    final all = storage.playlistsNotifier.value;
    return [
      ...all.where((p) => storage.isGuestPlaylist(p.id)).toList().reversed,
      ...all.where((p) => !storage.isGuestPlaylist(p.id)).toList().reversed,
    ];
  }
}

/// The pages of the main panel, as a browser keeps them: back and forward
/// go through the ones that were opened, each as it was left.
class DeskNav extends ChangeNotifier {
  static const int _kept = 40;

  final List<({Key key, Widget page})> _pages = [];
  int _index = -1;
  int _made = 0;

  List<({Key key, Widget page})> get pages => List.unmodifiable(_pages);
  int get index => _index;
  bool get canGoBack => _index > 0;
  bool get canGoForward => _index < _pages.length - 1;

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
  bool showing<T extends Widget>() => _index >= 0 && _pages[_index].page is T;
}

/// Builds with whether the mouse is over it.
class Hover extends StatefulWidget {
  const Hover({super.key, required this.builder, this.cursor = MouseCursor.defer});

  final Widget Function(BuildContext context, bool hovered) builder;
  final MouseCursor cursor;

  @override
  State<Hover> createState() => _HoverState();
}

class _HoverState extends State<Hover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.cursor,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: widget.builder(context, _hovered),
  );
}

/// A round button with a glyph, brighter under the mouse.
class DeskIconButton extends StatelessWidget {
  const DeskIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 20,
    this.active = false,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;

  /// Drawn in the color of the app (a mode that is on, a panel that is open).
  final bool active;

  /// On a disc of its own, like the buttons of the top bar.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Hover(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        builder: (context, hovered) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: size + 14,
            height: size + 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? (hovered && enabled ? Desk.hover : Desk.raised) : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: size,
              color: !enabled
                  ? Colors.white24
                  : active
                  ? cs.primary
                  : (hovered ? Colors.white : Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}

/// The round button that plays: the color of the app, a little larger
/// under the mouse.
class DeskPlayButton extends StatelessWidget {
  const DeskPlayButton({
    super.key,
    required this.onTap,
    this.size = 48,
    this.playing = false,
    this.tooltip,
  });

  final VoidCallback onTap;
  final double size;
  final bool playing;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip ?? (playing ? 'Pausa' : 'Riproduci'),
      waitDuration: const Duration(milliseconds: 500),
      child: Hover(
        cursor: SystemMouseCursors.click,
        builder: (context, hovered) => GestureDetector(
          onTap: onTap,
          child: AnimatedScale(
            scale: hovered ? 1.06 : 1,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary,
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: size * 0.58,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A chip that filters what is listed.
class DeskChip extends StatelessWidget {
  const DeskChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hover(
    cursor: SystemMouseCursors.click,
    builder: (context, hovered) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : (hovered ? Desk.hover : const Color(0xFF232323)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.black : Colors.white,
          ),
        ),
      ),
    ),
  );
}

/// A page that is loading, or that could not be loaded.
class DeskMessage extends StatelessWidget {
  const DeskMessage({super.key, this.icon, this.title, this.subtitle, this.action, this.onAction});

  /// With no title: a spinner.
  final IconData? icon;
  final String? title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    if (title == null) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white70),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 44, color: Colors.white38),
          const SizedBox(height: 14),
          Text(
            title!,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: 420,
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, height: 1.4, color: Colors.white60),
              ),
            ),
          ],
          if (action != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              onPressed: onAction,
              child: Text(action!),
            ),
          ],
        ],
      ),
    );
  }
}
