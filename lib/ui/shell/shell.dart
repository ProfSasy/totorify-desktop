import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kreate_ios/services/connect/connect_controller.dart';
import 'package:kreate_ios/services/connect/connect_host.dart';
import 'package:kreate_ios/services/download_service.dart';
import 'package:kreate_ios/services/playback_log_service.dart';

import '../app.dart';
import '../kit.dart';
import '../pages/home.dart';
import 'library.dart';
import 'player_bar.dart';
import 'side_view.dart';
import 'title_bar.dart';

/// The window: the bar at the top that moves it and searches, the library
/// at the left, the page in the middle, a view at the right when it is asked
/// for, the player at the foot. Each on a panel of its own, a little apart
/// from the others, on black.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final FocusNode _searchFocus = FocusNode(debugLabel: 'cerca');
  final List<StreamSubscription<String>> _notices = [];

  // The question of a device that wants to play here, while it is shown.
  Route<void>? _asking;

  @override
  void initState() {
    super.initState();
    if (App.nav.pages.isEmpty) App.nav.open(const HomePage());
    HardwareKeyboard.instance.addHandler(_onKey);
    _notices
      ..add(DownloadService.instance.failures.listen(App.toast))
      ..add(ConnectController.instance.notices.listen(App.toast))
      ..add(App.player.errorStream.listen(App.toast));
    ConnectHost.instance.request.addListener(_onRequest);
    // One that arrived before the window was drawn.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRequest());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    ConnectHost.instance.request.removeListener(_onRequest);
    for (final notice in _notices) {
      notice.cancel();
    }
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _typing {
    final focused = FocusManager.instance.primaryFocus?.context;
    return focused != null && focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// The keys that are commands: the space bar plays and pauses when
  /// nothing is being typed, the playback keys work while the window is the
  /// active one, Alt with the arrows goes through the pages, Ctrl+K (or
  /// Ctrl+L) puts the cursor in the search field.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final player = App.player;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final playing = player.playbackState.value.playing;
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      playing ? player.pause() : player.play();
    } else if (key == LogicalKeyboardKey.mediaTrackNext) {
      player.skipToNext();
    } else if (key == LogicalKeyboardKey.mediaTrackPrevious) {
      player.skipToPrevious();
    } else if (key == LogicalKeyboardKey.space) {
      if (_typing || player.mediaItem.value == null) return false;
      PlaybackLogService.instance.log('UI', 'barra spaziatrice: ${playing ? 'pausa' : 'play'}');
      playing ? player.pause() : player.play();
    } else if (keyboard.isAltPressed && key == LogicalKeyboardKey.arrowLeft) {
      App.nav.back();
    } else if (keyboard.isAltPressed && key == LogicalKeyboardKey.arrowRight) {
      App.nav.forward();
    } else if (keyboard.isControlPressed &&
        (key == LogicalKeyboardKey.keyK || key == LogicalKeyboardKey.keyL)) {
      _searchFocus.requestFocus();
    } else {
      return false;
    }
    return true;
  }

  /// A device asks to play on this computer: the question is put over
  /// whatever is on the screen, and goes away by itself when it is answered
  /// for the user (time ran out).
  void _onRequest() {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final shown = _asking;
    if (shown != null) {
      _asking = null;
      if (shown.isActive) navigator.removeRoute(shown);
    }
    final asked = ConnectHost.instance.request.value;
    if (asked == null) return;

    // Answering clears the request, which takes the question away.
    void answer({required bool allow, bool always = false}) {
      PlaybackLogService.instance.log(
        'UI',
        'richiesta di "${asked.name}": ${allow ? (always ? 'sempre' : 'questa volta') : 'no'}',
      );
      ConnectHost.instance.answer(asked, allow: allow, always: always);
    }

    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xB3000000),
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Ic.devices, size: 28, color: Tk.text),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          asked.listener ? 'Ascoltare insieme?' : 'Richiesta di connessione',
                          style: Tk.title(22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    asked.listener
                        ? '${asked.name} vuole ascoltare quello che suona su questo computer, '
                              'in sincrono.'
                        : '${asked.name} vuole riprodurre la sua musica su questo computer e '
                              'controllarla. Quello che stai ascoltando verrà sostituito.',
                    style: const TextStyle(fontSize: 14, height: 1.5, color: Tk.subdued),
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      GhostButton('Rifiuta', onTap: () => answer(allow: false)),
                      GhostButton('Solo questa volta', onTap: () => answer(allow: true)),
                      WhiteButton(
                        'Consenti sempre',
                        accent: true,
                        onTap: () => answer(allow: true, always: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    _asking = route;
    navigator.push(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tk.base,
      body: Listener(
        // The side buttons of a mouse go back and forward, as in a browser.
        onPointerDown: (event) {
          if (event.buttons == kBackMouseButton) App.nav.back();
          if (event.buttons == kForwardMouseButton) App.nav.forward();
        },
        child: Column(
          children: [
            TitleBar(searchFocus: _searchFocus),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tk.gap),
                child: LayoutBuilder(
                  builder: (context, constraints) => ValueListenableBuilder<SideView?>(
                    valueListenable: App.side,
                    builder: (context, side, _) {
                      // In a small window the page comes first: the library
                      // folds down to its covers to leave it room.
                      final room = constraints.maxWidth - (side == null ? 0 : SidePanel.width);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LibraryPanel(narrow: room < 900),
                          const SizedBox(width: Tk.gap),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Tk.panel,
                                borderRadius: BorderRadius.circular(Tk.radius),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: ListenableBuilder(
                                listenable: App.nav,
                                builder: (context, _) => IndexedStack(
                                  index: App.nav.index,
                                  children: [
                                    for (final entry in App.nav.pages)
                                      KeyedSubtree(key: entry.key, child: entry.page),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (side != null) ...[
                            const SizedBox(width: Tk.gap),
                            SidePanel(key: ValueKey(side), view: side),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // At the foot of the window, so that a notice comes out above it and
      // never over its buttons.
      bottomNavigationBar: const ColoredBox(color: Tk.base, child: PlayerBar()),
    );
  }
}
