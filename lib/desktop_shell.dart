import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kreate_ios/services/audio_handler.dart';
import 'package:kreate_ios/services/connect/connect_controller.dart';
import 'package:kreate_ios/services/download_service.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/ui/app_navigation.dart';
import 'package:kreate_ios/ui/screens/home_screen.dart';
import 'package:kreate_ios/ui/screens/library_screen.dart';
import 'package:kreate_ios/ui/screens/search_screen.dart';
import 'package:kreate_ios/ui/screens/settings_screen.dart';
import 'package:kreate_ios/ui/theme/app_icons.dart';
import 'package:kreate_ios/ui/widgets/connect_request_prompt.dart';
import 'package:kreate_ios/ui/widgets/player_sheet.dart';
import 'package:kreate_ios/ui/widgets/top_bar.dart';

import 'desktop_player_bar.dart';

/// The frame of the app on a computer: a menu at the side, the phone app's
/// pages beside it (each tab with its own stack, as on the phone), and the
/// player bar at the foot of the window.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key, required this.handler, required this.onThemeChanged});

  final AudioPlayerHandler handler;
  final VoidCallback onThemeChanged;

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  static const List<(String, IconData)> _tabNames = [
    ('Home', Icons.home_rounded),
    ('Cerca', AppIcons.search),
    ('Libreria', AppIcons.playlist),
  ];

  /// Pages are made for a phone: on a wide window they stay readable, in
  /// the middle of the space they are given.
  static const double _pageWidth = 1040;

  int _tab = 0;
  late final List<Widget> _tabs;
  final List<StreamSubscription<String>> _notices = [];

  @override
  void initState() {
    super.initState();
    final handler = widget.handler;
    AppNavigation.currentTab.value = 0;
    AppNavigation.settingsBuilder = (_) =>
        SettingsScreen(audioHandler: handler, onThemeChanged: widget.onThemeChanged);
    _tabs = [
      _stack(0, HomeScreen(audioHandler: handler)),
      _stack(1, SearchScreen(audioHandler: handler)),
      _stack(2, LibraryScreen(audioHandler: handler)),
    ];
    HardwareKeyboard.instance.addHandler(_onKey);
    _notices
      ..add(DownloadService.instance.failures.listen(_say))
      ..add(ConnectController.instance.notices.listen(_say))
      ..add(
        handler.errorStream.listen((message) {
          // The open player covers the notice and shows the message itself.
          if (!PlayerSheet.isOpen) _say(message);
        }),
      );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    for (final notice in _notices) {
      notice.cancel();
    }
    super.dispose();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        width: 480,
      ),
    );
  }

  Widget _stack(int index, Widget root) => Navigator(
    key: AppNavigation.tabKeys[index],
    onGenerateRoute: (settings) =>
        MaterialPageRoute<void>(settings: settings, builder: (_) => root),
  );

  void _goToTab(int index) {
    if (index == _tab) {
      AppNavigation.backToStart(index);
      return;
    }
    PlaybackLogService.instance.log('UI', 'menu: ${_tabNames[index].$1}');
    FocusManager.instance.primaryFocus?.unfocus();
    AppNavigation.currentTab.value = index;
    setState(() => _tab = index);
  }

  /// The keys that play: the space bar, when nothing is being typed, and
  /// the playback keys of the keyboard, while the window is the active one.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final handler = widget.handler;
    final key = event.logicalKey;
    final playing = handler.playbackState.value.playing;
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      playing ? handler.pause() : handler.play();
    } else if (key == LogicalKeyboardKey.mediaTrackNext) {
      handler.skipToNext();
    } else if (key == LogicalKeyboardKey.mediaTrackPrevious) {
      handler.skipToPrevious();
    } else if (key == LogicalKeyboardKey.space) {
      final focused = FocusManager.instance.primaryFocus?.context;
      final typing =
          focused != null && focused.findAncestorWidgetOfExactType<EditableText>() != null;
      if (typing || handler.mediaItem.value == null) return false;
      PlaybackLogService.instance.log('UI', 'barra spaziatrice: ${playing ? 'pausa' : 'play'}');
      playing ? handler.pause() : handler.play();
    } else {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // A device that asks to play here is answered from any page.
    return ConnectRequestPrompt(
      child: Scaffold(
        backgroundColor: cs.surfaceDim,
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  _SideMenu(
                    tabs: _tabNames,
                    current: _tab,
                    onTab: _goToTab,
                    onSettings: () => ProfileButton.openSettings(context),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: _pageWidth),
                        // Hidden tabs keep their pages, with their tickers
                        // paused.
                        child: IndexedStack(
                          index: _tab,
                          children: [
                            for (var i = 0; i < _tabs.length; i++)
                              TickerMode(enabled: i == _tab, child: _tabs[i]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DesktopPlayerBar(handler: widget.handler),
          ],
        ),
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.tabs,
    required this.current,
    required this.onTab,
    required this.onSettings,
  });

  final List<(String, IconData)> tabs;
  final int current;
  final ValueChanged<int> onTab;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 216,
      color: Colors.black.withValues(alpha: 0.28),
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 22),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    'assets/images/totorify_logo.png',
                    package: 'kreate_ios',
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  'Totorify',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          for (final (index, (label, icon)) in tabs.indexed)
            _MenuItem(
              label: label,
              icon: icon,
              selected: index == current,
              onTap: () => onTab(index),
            ),
          const Spacer(),
          _MenuItem(
            label: 'Impostazioni',
            icon: AppIcons.settings,
            selected: false,
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ink = selected ? cs.onSurface : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 22, color: selected ? cs.primary : ink),
                const SizedBox(width: 13),
                Text(
                  label,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
