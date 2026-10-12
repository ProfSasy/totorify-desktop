import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kreate_ios/services/connect/connect_controller.dart';
import 'package:kreate_ios/services/download_service.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/ui/screens/settings_screen.dart';
import 'package:kreate_ios/ui/widgets/connect_request_prompt.dart';

import 'desk.dart';
import 'desk_home.dart';
import 'desk_player_bar.dart';
import 'desk_side_panel.dart';
import 'desk_sidebar.dart';
import 'desk_top_bar.dart';

/// The window of the app on a computer: a bar at the top to move and to
/// search, the library at the left, the page in the middle, a panel at the
/// right when it is asked for, and the player at the foot. Each sits on its
/// own panel, a little apart from the others, on black.
class DeskShell extends StatefulWidget {
  const DeskShell({super.key, required this.onThemeChanged});

  final VoidCallback onThemeChanged;

  @override
  State<DeskShell> createState() => _DeskShellState();
}

class _DeskShellState extends State<DeskShell> {
  final FocusNode _searchFocus = FocusNode(debugLabel: 'cerca');
  final List<StreamSubscription<String>> _notices = [];

  @override
  void initState() {
    super.initState();
    if (Desk.nav.pages.isEmpty) Desk.nav.open(const DeskHomePage());
    HardwareKeyboard.instance.addHandler(_onKey);
    _notices
      ..add(DownloadService.instance.failures.listen(Desk.say))
      ..add(ConnectController.instance.notices.listen(Desk.say))
      ..add(Desk.handler.errorStream.listen(Desk.say));
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
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

  /// The keys of the keyboard that are commands: the space bar plays and
  /// pauses when nothing is being typed, the playback keys work while the
  /// window is the active one, Alt with the arrows goes through the pages,
  /// Ctrl+K puts the cursor in the search field.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final handler = Desk.handler;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final playing = handler.playbackState.value.playing;
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      playing ? handler.pause() : handler.play();
    } else if (key == LogicalKeyboardKey.mediaTrackNext) {
      handler.skipToNext();
    } else if (key == LogicalKeyboardKey.mediaTrackPrevious) {
      handler.skipToPrevious();
    } else if (key == LogicalKeyboardKey.space) {
      if (_typing || handler.mediaItem.value == null) return false;
      PlaybackLogService.instance.log('UI', 'barra spaziatrice: ${playing ? 'pausa' : 'play'}');
      playing ? handler.pause() : handler.play();
    } else if (keyboard.isAltPressed && key == LogicalKeyboardKey.arrowLeft) {
      Desk.nav.back();
    } else if (keyboard.isAltPressed && key == LogicalKeyboardKey.arrowRight) {
      Desk.nav.forward();
    } else if (keyboard.isControlPressed && key == LogicalKeyboardKey.keyK) {
      _searchFocus.requestFocus();
    } else {
      return false;
    }
    return true;
  }

  /// The settings are the phone app's, in a window of their own over this
  /// one.
  void _openSettings() {
    PlaybackLogService.instance.log('UI', 'apri impostazioni');
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Desk.panel,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Desk.radius)),
        child: SizedBox(
          width: 720,
          height: MediaQuery.sizeOf(context).height * 0.86,
          child: SettingsScreen(audioHandler: Desk.handler, onThemeChanged: widget.onThemeChanged),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A device that asks to play here is answered from any page.
    return ConnectRequestPrompt(
      child: Scaffold(
        backgroundColor: Desk.window,
        body: Listener(
          // The side buttons of a mouse go back and forward, as in a browser.
          onPointerDown: (event) {
            if (event.buttons == kBackMouseButton) Desk.nav.back();
            if (event.buttons == kForwardMouseButton) Desk.nav.forward();
          },
          child: Column(
            children: [
              DeskTopBar(onSettings: _openSettings, searchFocus: _searchFocus),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Desk.gap),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DeskSidebar(),
                      const SizedBox(width: Desk.gap),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Desk.panel,
                            borderRadius: BorderRadius.circular(Desk.radius),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListenableBuilder(
                            listenable: Desk.nav,
                            builder: (context, _) => IndexedStack(
                              index: Desk.nav.index,
                              children: [
                                for (final entry in Desk.nav.pages)
                                  KeyedSubtree(key: entry.key, child: entry.page),
                              ],
                            ),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<DeskSide?>(
                        valueListenable: Desk.side,
                        builder: (context, side, _) => side == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(left: Desk.gap),
                                child: DeskSidePanel(key: ValueKey(side), side: side),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const DeskPlayerBar(),
            ],
          ),
        ),
      ),
    );
  }
}
