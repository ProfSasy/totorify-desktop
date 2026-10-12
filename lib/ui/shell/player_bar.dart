import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:kreate_ios/models/artist.dart';
import 'package:kreate_ios/services/deezer_service.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/services/storage_service.dart';

import '../app.dart';
import '../kit.dart';
import '../menus.dart';
import '../pages/artist.dart';
import '../pages/lyrics.dart';
import '../widgets.dart';

/// The bar at the foot of the window: what is playing on the left, the
/// controls and the bar of the song in the middle, and on the right what
/// opens beside the page (now playing, text, queue, devices) and the volume.
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  static const double height = 72;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: StreamBuilder<MediaItem?>(
        stream: App.player.mediaItem,
        initialData: App.player.mediaItem.value,
        builder: (context, snapshot) {
          final item = snapshot.data;
          return Row(
            children: [
              Expanded(flex: 30, child: _Now(item: item)),
              Expanded(flex: 40, child: _Controls(item: item)),
              Expanded(flex: 30, child: _Side(hasSong: item != null)),
            ],
          );
        },
      ),
    ),
  );
}

class _Now extends StatelessWidget {
  const _Now({required this.item});

  final MediaItem? item;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    if (item == null) return const SizedBox.shrink();
    final artist = DeezerService.primaryArtist(item.artist ?? '');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) {
        final song = App.player.currentSong;
        if (song != null) songMenu(context, details.globalPosition, song);
      },
      child: Row(
        children: [
          const SizedBox(width: 8),
          Tooltip(
            message: 'Vista In riproduzione',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => App.toggleSide(SideView.nowPlaying),
                child: Artwork(url: item.artUri?.toString(), seed: item.title, size: 56),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Tk.text),
                ),
                const SizedBox(height: 3),
                LinkText(
                  item.artist ?? '',
                  onTap: () {
                    if (artist.isEmpty) return;
                    App.nav.open(
                      ArtistPage(
                        artist: Artist(id: 'name:$artist', name: artist),
                      ),
                    );
                  },
                  style: const TextStyle(fontSize: 12, color: Tk.subdued),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SaveButton(song: () => App.player.currentSong, size: 17),
        ],
      ),
    );
  }
}

class _Controls extends StatefulWidget {
  const _Controls({required this.item});

  final MediaItem? item;

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  // Where the knob is while it is being dragged; the song follows when it
  // is let go.
  double? _dragged;

  @override
  Widget build(BuildContext context) {
    final player = App.player;
    final enabled = widget.item != null;
    final length = widget.item?.duration ?? Duration.zero;
    const time = TextStyle(
      fontSize: 12,
      color: Tk.subdued,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder<PlaybackState>(
          stream: player.playbackState,
          initialData: player.playbackState.value,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final playing = state?.playing ?? false;
            final busy =
                state?.processingState == AudioProcessingState.loading ||
                state?.processingState == AudioProcessingState.buffering;
            final shuffle = state?.shuffleMode == AudioServiceShuffleMode.all;
            final repeat = state?.repeatMode ?? AudioServiceRepeatMode.none;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconBtn(
                  Ic.shuffle,
                  tip: shuffle ? 'Disattiva shuffle' : 'Attiva shuffle',
                  on: shuffle,
                  dot: true,
                  onTap: enabled
                      ? () => player.setShuffleMode(
                          shuffle ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                IconBtn(
                  Ic.previous,
                  tip: 'Precedente',
                  onTap: enabled ? player.skipToPrevious : null,
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: playing ? 'Pausa' : 'Riproduci',
                  child: Hover(
                    cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
                    builder: (context, hovered) => GestureDetector(
                      onTap: enabled
                          ? () {
                              PlaybackLogService.instance.log(
                                'UI',
                                'barra del player: ${playing ? 'pausa' : 'play'}',
                              );
                              playing ? player.pause() : player.play();
                            }
                          : null,
                      child: AnimatedScale(
                        scale: hovered && enabled ? 1.06 : 1,
                        duration: Tk.quick,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: enabled ? Tk.text : Tk.faint,
                          ),
                          child: busy && playing
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.black,
                                  ),
                                )
                              : Icon(playing ? Ic.pause : Ic.play, size: 15, color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconBtn(Ic.next, tip: 'Successivo', onTap: enabled ? player.skipToNext : null),
                const SizedBox(width: 8),
                IconBtn(
                  repeat == AudioServiceRepeatMode.one ? Ic.repeatOne : Ic.repeat,
                  tip: switch (repeat) {
                    AudioServiceRepeatMode.none => 'Attiva ripeti',
                    AudioServiceRepeatMode.one => 'Disattiva ripeti',
                    _ => 'Attiva ripeti il brano',
                  },
                  on: repeat != AudioServiceRepeatMode.none,
                  dot: true,
                  onTap: enabled
                      ? () => player.setRepeatMode(switch (repeat) {
                          AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
                          AudioServiceRepeatMode.one => AudioServiceRepeatMode.none,
                          _ => AudioServiceRepeatMode.one,
                        })
                      : null,
                ),
              ],
            );
          },
        ),
        SizedBox(
          height: 18,
          child: ValueListenableBuilder<Duration>(
            valueListenable: player.positionNotifier,
            builder: (context, position, _) {
              final total = length.inMilliseconds.toDouble();
              final at = _dragged ?? position.inMilliseconds.toDouble().clamp(0.0, total);
              return Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      enabled ? App.clock(Duration(milliseconds: at.round())) : '-:--',
                      textAlign: TextAlign.right,
                      style: time,
                    ),
                  ),
                  Expanded(
                    child: Bar(
                      label: 'Avanzamento del brano',
                      value: total > 0 ? at.clamp(0.0, total) : 0,
                      max: total > 0 ? total : 1,
                      onChanged: enabled && total > 0
                          ? (value) => setState(() => _dragged = value)
                          : null,
                      onChangeEnd: (value) {
                        setState(() => _dragged = null);
                        PlaybackLogService.instance.log(
                          'UI',
                          'barra del player: vai a ${value ~/ 1000}s',
                        );
                        player.seek(Duration(milliseconds: value.round()));
                      },
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(enabled && total > 0 ? App.clock(length) : '-:--', style: time),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Side extends StatefulWidget {
  const _Side({required this.hasSong});

  final bool hasSong;

  @override
  State<_Side> createState() => _SideState();
}

class _SideState extends State<_Side> {
  Timer? _remember;

  @override
  void dispose() {
    _remember?.cancel();
    super.dispose();
  }

  void _setVolume(double value) {
    final player = App.player;
    player.setOutputVolume(value);
    // How loud this computer plays is kept for the next start; how loud
    // another device plays is that device's to keep.
    if (player.isRemote) return;
    _remember?.cancel();
    _remember = Timer(
      const Duration(milliseconds: 500),
      () => StorageService.instance.setOutputVolume(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final player = App.player;
    return ListenableBuilder(
      listenable: Listenable.merge([App.side, App.nav]),
      builder: (context, _) {
        final side = App.side.value;
        final lyrics = App.nav.showing<LyricsPage>();
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconBtn(
              Ic.nowPlaying,
              tip: 'Vista In riproduzione',
              on: side == SideView.nowPlaying,
              dot: true,
              onTap: () => App.toggleSide(SideView.nowPlaying),
            ),
            IconBtn(
              Ic.lyrics,
              tip: 'Testi',
              on: lyrics,
              dot: true,
              onTap: widget.hasSong || lyrics
                  ? () => lyrics ? App.nav.back() : App.nav.open(const LyricsPage())
                  : null,
            ),
            IconBtn(
              Ic.queue,
              tip: 'Coda',
              on: side == SideView.queue,
              dot: true,
              onTap: () => App.toggleSide(SideView.queue),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: player.remoteNameNotifier,
              builder: (context, remote, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconBtn(
                    Ic.devices,
                    tip: remote == null ? 'Connetti a un dispositivo' : 'In ascolto su $remote',
                    on: side == SideView.devices || remote != null,
                    dot: side == SideView.devices,
                    onTap: () => App.toggleSide(SideView.devices),
                  ),
                  if (remote != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Text(
                        remote,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
                      ),
                    ),
                ],
              ),
            ),
            ValueListenableBuilder<double>(
              valueListenable: player.outputVolumeNotifier,
              builder: (context, volume, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconBtn(
                    volume == 0 ? Ic.volumeOff : (volume < 0.5 ? Ic.volumeLow : Ic.volumeHigh),
                    tip: volume == 0 ? 'Riattiva audio' : 'Disattiva audio',
                    onTap: () => _setVolume(volume == 0 ? 0.7 : 0),
                  ),
                  SizedBox(
                    width: 96,
                    child: Bar(
                      label: 'Volume',
                      value: volume.clamp(0.0, 1.0),
                      max: 1,
                      onChanged: _setVolume,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        );
      },
    );
  }
}

/// A thin bar that is dragged: white, in the color of the app and with its
/// knob under the mouse.
class Bar extends StatelessWidget {
  const Bar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Hover(
      builder: (context, hovered) => SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: hovered ? 6 : 0,
            elevation: 0,
            pressedElevation: 0,
          ),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 9),
          overlayColor: Colors.transparent,
          activeTrackColor: hovered ? accent : Tk.text,
          thumbColor: Tk.text,
          inactiveTrackColor: const Color(0xFF4D4D4D),
          disabledActiveTrackColor: const Color(0xFF4D4D4D),
          disabledInactiveTrackColor: const Color(0xFF4D4D4D),
          disabledThumbColor: Colors.transparent,
        ),
        child: Semantics(
          label: label,
          child: Slider(value: value, max: max, onChanged: onChanged, onChangeEnd: onChangeEnd),
        ),
      ),
    );
  }
}
