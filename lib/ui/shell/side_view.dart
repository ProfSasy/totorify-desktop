import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:kreate_ios/models/artist.dart';
import 'package:kreate_ios/models/song.dart';
import 'package:kreate_ios/services/connect/connect_controller.dart';
import 'package:kreate_ios/services/connect/connect_protocol.dart';
import 'package:kreate_ios/services/deezer_service.dart';
import 'package:kreate_ios/services/playback_log_service.dart';

import '../app.dart';
import '../kit.dart';
import '../menus.dart';
import '../pages/artist.dart';
import '../widgets.dart';

/// The view at the right of the window, opened from the player bar: what is
/// playing, the queue, or the devices to listen on. One at a time.
class SidePanel extends StatelessWidget {
  const SidePanel({super.key, required this.view});

  final SideView view;

  static const double width = 340;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (view) {
      SideView.nowPlaying => ('In riproduzione', const _NowPlaying() as Widget),
      SideView.queue => ('Coda', const _Queue()),
      SideView.devices => ('Connetti a un dispositivo', const _Devices()),
    };
    return Container(
      width: width,
      decoration: BoxDecoration(color: Tk.panel, borderRadius: BorderRadius.circular(Tk.radius)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Tk.text,
                      ),
                    ),
                  ),
                  IconBtn(Ic.close, tip: 'Chiudi', size: 15, onTap: () => App.side.value = null),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

void _openArtist(String names) {
  final artist = DeezerService.primaryArtist(names);
  if (artist.isEmpty) return;
  App.nav.open(
    ArtistPage(
      artist: Artist(id: 'name:$artist', name: artist),
    ),
  );
}

// ── What is playing ──────────────────────────────────────────────────────────

class _NowPlaying extends StatelessWidget {
  const _NowPlaying();

  @override
  Widget build(BuildContext context) {
    final player = App.player;
    return StreamBuilder<List<MediaItem>>(
      stream: player.queue,
      builder: (context, _) => StreamBuilder<MediaItem?>(
        stream: player.mediaItem,
        initialData: player.mediaItem.value,
        builder: (context, snapshot) {
          final item = snapshot.data;
          if (item == null) {
            return const _Hint(
              'Qui trovi il brano in riproduzione, con la copertina in grande e quello che '
              'viene dopo. Scegli qualcosa da ascoltare.',
            );
          }
          final songs = player.currentPlaylist;
          final at = songs.indexWhere((s) => s.id == player.currentSong?.id);
          final next = at >= 0 && at + 1 < songs.length ? songs[at + 1] : null;
          final artist = DeezerService.primaryArtist(item.artist ?? '');
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              LayoutBuilder(
                builder: (context, constraints) => Artwork(
                  url: item.artUri?.toString(),
                  seed: item.title,
                  size: constraints.maxWidth,
                  radius: 8,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Tk.title(23),
                        ),
                        const SizedBox(height: 5),
                        LinkText(
                          item.artist ?? '',
                          onTap: () => _openArtist(item.artist ?? ''),
                          style: const TextStyle(fontSize: 15, color: Tk.subdued),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SaveButton(song: () => player.currentSong, size: 22),
                ],
              ),
              if (artist.isNotEmpty) ...[
                const SizedBox(height: 20),
                _Card(
                  title: 'Informazioni sull\'artista',
                  child: Row(
                    children: [
                      Artwork(url: null, seed: artist, size: 48, round: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Tk.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GhostButton('Apri', small: true, onTap: () => _openArtist(artist)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _Card(
                title: 'Prossimo in coda',
                action: 'Apri coda',
                onAction: () => App.side.value = SideView.queue,
                child: next == null
                    ? const Text(
                        'Dopo questo brano la coda è finita.',
                        style: TextStyle(fontSize: 13.5, color: Tk.subdued),
                      )
                    : _SongLine(
                        song: next,
                        current: false,
                        flush: true,
                        onPlay: () {
                          PlaybackLogService.instance.log(
                            'UI',
                            'in riproduzione: passo a "${next.title}"',
                          );
                          player.skipToQueueItem(at + 1);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.action, this.onAction});

  final String title;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Tk.raised, borderRadius: BorderRadius.circular(8)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Tk.text),
              ),
            ),
            if (action != null && onAction != null)
              LinkText(
                action!,
                onTap: onAction!,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Tk.subdued,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

// ── The queue ────────────────────────────────────────────────────────────────

class _Queue extends StatelessWidget {
  const _Queue();

  @override
  Widget build(BuildContext context) {
    final player = App.player;
    return StreamBuilder<List<MediaItem>>(
      stream: player.queue,
      builder: (context, _) => ValueListenableBuilder<(String?, bool)>(
        valueListenable: player.playbackIndicator,
        builder: (context, indicator, _) {
          final songs = player.currentPlaylist;
          final at = songs.indexWhere((s) => s.id == indicator.$1);
          if (songs.isEmpty || at == -1) {
            return const _Hint(
              'La coda è vuota. Avvia un brano: quelli che lo seguono compaiono qui, e puoi '
              'aggiungerne altri dal menu di ogni brano.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            children: [
              const _Label('In riproduzione'),
              _SongLine(song: songs[at], current: true, onPlay: null),
              if (at + 1 < songs.length) const _Label('Prossimi in coda'),
              for (var i = at + 1; i < songs.length; i++)
                _SongLine(
                  song: songs[i],
                  current: false,
                  onPlay: () {
                    PlaybackLogService.instance.log('UI', 'coda: scelgo "${songs[i].title}"');
                    player.skipToQueueItem(i);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SongLine extends StatelessWidget {
  const _SongLine({
    required this.song,
    required this.current,
    required this.onPlay,
    this.flush = false,
  });

  final Song song;
  final bool current;
  final VoidCallback? onPlay;

  /// With no room at its sides, where it is inside a card.
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Hover(
      cursor: onPlay == null ? MouseCursor.defer : SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPlay,
        onSecondaryTapUp: (details) => songMenu(context, details.globalPosition, song),
        child: Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: flush ? 0 : 8),
          decoration: BoxDecoration(
            color: hovered && !flush ? Tk.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Artwork(url: song.thumbnailUrl, seed: song.title, size: 40),
                    if (hovered && onPlay != null)
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Ic.play, size: 16, color: Tk.text),
                      ),
                  ],
                ),
              ),
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
                      style: TextStyle(fontSize: 14.5, color: current ? accent : Tk.text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Tk.subdued),
                    ),
                  ],
                ),
              ),
              if (current) ...[const SizedBox(width: 8), Equalizer(color: accent)],
            ],
          ),
        ),
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
            ? 'Su ${device.name} la richiesta è stata rifiutata.'
            : 'Impossibile connettersi a ${device.name}. Controlla che Totorify sia aperto '
                  'su quel dispositivo e che sia sulla stessa rete di questo computer.';
      }
    });
  }

  static IconData _iconOf(ConnectDevice device) => switch (device.kind) {
    ConnectDevice.kindPhone => Ic.phone,
    ConnectDevice.kindComputer => Ic.computer,
    _ => Ic.tv,
  };

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final error = Theme.of(context).colorScheme.error;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _connect.activeDevice,
        _connect.devices,
        _connect.scanning,
        _connect.waitingFor,
      ]),
      builder: (context, _) {
        final active = _connect.activeDevice.value;
        final others = [
          for (final device in _connect.devices.value)
            if (device != active) device,
        ];
        final scanning = _connect.scanning.value;
        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          children: [
            // ── Where the music is coming out now ───────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Tk.raised, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(active == null ? Ic.computer : _iconOf(active), size: 32, color: accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dispositivo corrente',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          active?.name ?? 'Questo computer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Tk.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Equalizer(color: accent, size: 16),
                ],
              ),
            ),
            const _Label('Seleziona un altro dispositivo'),
            if (active != null)
              _DeviceRow(
                icon: Ic.computer,
                name: 'Questo computer',
                detail: 'Riporta qui la riproduzione',
                busy: false,
                onTap: () {
                  PlaybackLogService.instance.log('UI', 'dispositivi: torno su questo computer');
                  _connect.transferBack();
                },
              ),
            for (final device in others)
              _DeviceRow(
                icon: _iconOf(device),
                name: device.name,
                detail: _connecting == device.id
                    ? (_connect.waitingFor.value != null
                          ? 'Conferma la richiesta su ${device.name}'
                          : 'Connessione in corso…')
                    : (device.nowPlaying == null
                          ? 'Totorify Connect'
                          : 'In riproduzione: ${device.nowPlaying}'),
                busy: _connecting == device.id,
                onTap: () => _choose(device),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(_error!, style: TextStyle(fontSize: 13, height: 1.45, color: error)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: scanning
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Tk.subdued),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Ricerca dei dispositivi in corso…',
                          style: TextStyle(fontSize: 13, color: Tk.subdued),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (others.isEmpty && active == null) ...[
                          const Text(
                            'Nessun altro dispositivo trovato',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Tk.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Apri Totorify sul telefono o sulla TV e collegali alla stessa rete '
                            'Wi-Fi di questo computer. Sulle reti pubbliche, come quelle di '
                            'università e hotel, e con una VPN attiva i dispositivi non si vedono '
                            'tra loro.',
                            style: TextStyle(fontSize: 13, height: 1.5, color: Tk.subdued),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GhostButton('Cerca di nuovo', small: true, onTap: _connect.scan),
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
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String name;
  final String detail;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hover(
    cursor: SystemMouseCursors.click,
    builder: (context, hovered) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: hovered ? Tk.raised : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: hovered ? Tk.text : Tk.subdued),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, color: Tk.text),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Tk.subdued),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Tk.subdued),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Tk.text),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
    child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.5, color: Tk.subdued)),
  );
}
