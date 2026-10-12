import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:kreate_ios/models/lyrics_model.dart';
import 'package:kreate_ios/models/song.dart';
import 'package:kreate_ios/services/connect/connect_controller.dart';
import 'package:kreate_ios/services/connect/connect_protocol.dart';
import 'package:kreate_ios/services/lyrics_service.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/ui/theme/app_ambience.dart';
import 'package:kreate_ios/ui/theme/app_icons.dart';
import 'package:kreate_ios/ui/widgets/app_cover.dart';

import 'desk.dart';
import 'desk_menus.dart';

/// The panel at the right of the window: the queue, the text of the song,
/// or the devices to listen on. One at a time, opened from the player bar.
class DeskSidePanel extends StatelessWidget {
  const DeskSidePanel({super.key, required this.side});

  final DeskSide side;

  static const double width = 340;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (side) {
      DeskSide.queue => ('Coda', const _Queue() as Widget),
      DeskSide.lyrics => ('Testo', const _LyricsView()),
      DeskSide.devices => ('Dove ascoltare', const _Devices()),
    };
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Desk.panel,
        borderRadius: BorderRadius.circular(Desk.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                DeskIconButton(
                  icon: AppIcons.close,
                  tooltip: 'Chiudi',
                  size: 18,
                  onTap: () => Desk.side.value = null,
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ── The queue ────────────────────────────────────────────────────────────────

class _Queue extends StatelessWidget {
  const _Queue();

  @override
  Widget build(BuildContext context) {
    final handler = Desk.handler;
    return StreamBuilder<List<MediaItem>>(
      stream: handler.queue,
      builder: (context, _) => ValueListenableBuilder<(String?, bool)>(
        valueListenable: handler.playbackIndicator,
        builder: (context, indicator, _) {
          final songs = handler.currentPlaylist;
          final at = songs.indexWhere((s) => s.id == indicator.$1);
          if (songs.isEmpty || at == -1) {
            return const _Hint(
              'La coda è vuota. Scegli un brano: quelli dopo di lui finiscono qui.',
            );
          }
          final next = songs.length - at - 1;
          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            children: [
              const _Label('In riproduzione'),
              _QueueRow(song: songs[at], current: true, onPlay: null),
              if (next > 0) const _Label('Prossimi'),
              for (var i = at + 1; i < songs.length; i++)
                _QueueRow(
                  song: songs[i],
                  current: false,
                  onPlay: () {
                    PlaybackLogService.instance.log('UI', 'coda: scelgo "${songs[i].title}"');
                    handler.skipToQueueItem(i);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.song, required this.current, required this.onPlay});

  final Song song;
  final bool current;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Hover(
      cursor: onPlay == null ? MouseCursor.defer : SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPlay,
        onSecondaryTapUp: (details) => deskSongMenu(context, details.globalPosition, song),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: hovered ? Desk.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              AppCover(url: song.thumbnailUrl, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: current ? cs.primary : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── The text ─────────────────────────────────────────────────────────────────

class _LyricsView extends StatefulWidget {
  const _LyricsView();

  @override
  State<_LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<_LyricsView> {
  StreamSubscription<MediaItem?>? _songs;
  String? _songId;
  Lyrics? _lyrics;
  bool _loading = false;
  int _line = -1;
  final List<GlobalKey> _keys = [];

  @override
  void initState() {
    super.initState();
    _songs = Desk.handler.mediaItem.listen((_) => _load());
    Desk.handler.positionNotifier.addListener(_follow);
    _load();
  }

  @override
  void dispose() {
    _songs?.cancel();
    Desk.handler.positionNotifier.removeListener(_follow);
    super.dispose();
  }

  Future<void> _load() async {
    final song = Desk.handler.currentSong;
    if (song?.id == _songId) return;
    _songId = song?.id;
    _keys.clear();
    setState(() {
      _lyrics = null;
      _line = -1;
      _loading = song != null;
    });
    if (song == null) return;
    Lyrics lyrics;
    try {
      lyrics = await LyricsService.instance.getLyrics(song);
    } catch (e) {
      debugPrint('DeskSidePanel lyrics: $e');
      lyrics = Lyrics.empty;
    }
    if (!mounted || _songId != song.id) return;
    _keys.addAll([for (final _ in lyrics.syncedLyrics) GlobalKey()]);
    setState(() {
      _lyrics = lyrics;
      _loading = false;
    });
    _follow();
  }

  /// The line being sung is lit, and kept in sight.
  void _follow() {
    final lines = _lyrics?.syncedLyrics ?? const <LyricLine>[];
    if (lines.isEmpty) return;
    final position = Desk.handler.positionNotifier.value;
    var line = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time > position) break;
      line = i;
    }
    if (line == _line) return;
    setState(() => _line = line);
    final target = line >= 0 && line < _keys.length ? _keys[line].currentContext : null;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        alignment: 0.35,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AmbientTint(
      artworkUrl: Desk.handler.mediaItem.value?.artUri?.toString(),
      fallback: cs.primary,
      builder: (context, palette) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(palette.surface, Desk.panel, 0.25)!,
              Color.lerp(palette.deep, Desk.panel, 0.5)!,
            ],
          ),
        ),
        child: _text(context),
      ),
    );
  }

  Widget _text(BuildContext context) {
    if (_songId == null) return const _Hint('Il testo compare qui mentre un brano suona.');
    if (_loading) return const DeskMessage();
    final lyrics = _lyrics;
    if (lyrics == null || lyrics.isEmpty) {
      return const _Hint('Per questo brano non ho trovato il testo.');
    }
    final synced = lyrics.syncedLyrics;
    if (synced.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child: SelectableText(
          lyrics.plainLyrics,
          style: const TextStyle(
            fontSize: 16,
            height: 1.6,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, line) in synced.indexed)
            MouseRegion(
              key: index < _keys.length ? _keys[index] : null,
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Desk.handler.seek(line.time),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    line.text.isEmpty ? '♪' : line.text,
                    style: TextStyle(
                      fontSize: 19,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: index == _line
                          ? Colors.white
                          : (index < _line ? Colors.white38 : Colors.white54),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── The devices ──────────────────────────────────────────────────────────────

class _Devices extends StatefulWidget {
  const _Devices();

  @override
  State<_Devices> createState() => _DevicesState();
}

class _DevicesState extends State<_Devices> {
  final ConnectController _connect = ConnectController.instance;
  String? _connecting;
  String? _error;

  @override
  void initState() {
    super.initState();
    PlaybackLogService.instance.log('UI', 'dispositivi: apri');
    unawaited(_connect.scan());
  }

  Future<void> _choose(ConnectDevice device) async {
    if (_connecting != null || _connect.activeDevice.value == device) return;
    PlaybackLogService.instance.log('UI', 'dispositivi: scelgo "${device.name}"');
    setState(() {
      _connecting = device.id;
      _error = null;
    });
    final ok = await _connect.transferTo(device);
    if (!mounted) return;
    setState(() {
      _connecting = null;
      if (!ok) {
        _error = _connect.refused
            ? 'Su ${device.name} la richiesta non è stata accettata.'
            : 'Non riesco a raggiungere ${device.name}. Controlla che Totorify sia '
                  'aperto lì e che siate sulla stessa rete.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _connect.activeDevice,
        _connect.devices,
        _connect.scanning,
        _connect.waitingFor,
      ]),
      builder: (context, _) {
        final active = _connect.activeDevice.value;
        final devices = _connect.devices.value;
        final scanning = _connect.scanning.value;
        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          children: [
            _DeviceRow(
              icon: AppIcons.computer,
              name: 'Questo computer',
              detail: active == null ? 'In riproduzione qui' : null,
              active: active == null,
              busy: false,
              onTap: active == null
                  ? null
                  : () {
                      PlaybackLogService.instance.log(
                        'UI',
                        'dispositivi: torno su questo computer',
                      );
                      _connect.transferBack();
                    },
            ),
            for (final device in devices)
              _DeviceRow(
                icon: switch (device.kind) {
                  ConnectDevice.kindPhone => AppIcons.phone,
                  ConnectDevice.kindComputer => AppIcons.computer,
                  _ => AppIcons.tv,
                },
                name: device.name,
                detail: active == device
                    ? 'In riproduzione'
                    : (_connecting == device.id && _connect.waitingFor.value != null
                          ? 'Conferma su ${device.name}…'
                          : (device.nowPlaying == null
                                ? device.host
                                : 'Sta suonando: ${device.nowPlaying}')),
                active: active == device,
                busy: _connecting == device.id,
                onTap: () => _choose(device),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Text(
                  _error!,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: cs.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
              child: scanning
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white60),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Cerco i dispositivi sulla rete…',
                          style: TextStyle(fontSize: 12.5, color: Colors.white60),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (devices.isEmpty)
                          const Text(
                            'Nessun dispositivo trovato. Apri Totorify sulla TV o sul telefono, '
                            'collegati alla stessa rete di questo computer, e cerca di nuovo. '
                            'Con una VPN attiva la rete di casa può non essere raggiungibile.',
                            style: TextStyle(fontSize: 12.5, height: 1.45, color: Colors.white60),
                          ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: _connect.scan,
                          child: const Text('Cerca di nuovo', style: TextStyle(fontSize: 12.5)),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.icon,
    required this.name,
    required this.detail,
    required this.active,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String name;
  final String? detail;
  final bool active;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ink = active ? cs.primary : Colors.white;
    return Hover(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: hovered && onTap != null ? Desk.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, size: 26, color: ink),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ink),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: Colors.white60),
                      ),
                    ],
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                )
              else if (active)
                Icon(AppIcons.check, size: 18, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
    child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45, color: Colors.white60)),
  );
}
