import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:kreate_ios/models/artist.dart';
import 'package:kreate_ios/services/deezer_service.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/services/storage_service.dart';
import 'package:kreate_ios/ui/theme/app_icons.dart';
import 'package:kreate_ios/ui/widgets/app_cover.dart';
import 'package:kreate_ios/ui/widgets/favorite_button.dart';

import 'desk.dart';
import 'desk_artist.dart';
import 'desk_menus.dart';
import 'desk_widgets.dart';

/// The player at the foot of the window: what is playing on the left, the
/// controls and the bar of the song in the middle, and on the right the
/// text, the queue, the device that plays and how loud.
class DeskPlayerBar extends StatelessWidget {
  const DeskPlayerBar({super.key});

  static const double height = 80;

  @override
  Widget build(BuildContext context) {
    final handler = Desk.handler;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: StreamBuilder<MediaItem?>(
          stream: handler.mediaItem,
          initialData: handler.mediaItem.value,
          builder: (context, snapshot) {
            final item = snapshot.data;
            return Row(
              children: [
                Expanded(flex: 3, child: _NowPlaying(item: item)),
                Expanded(flex: 4, child: _Transport(item: item)),
                const Expanded(flex: 3, child: _Extras()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.item});

  final MediaItem? item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = this.item;
    if (item == null) return const SizedBox.shrink();
    final handler = Desk.handler;
    final artist = DeezerService.primaryArtist(item.artist ?? '');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) {
        final song = handler.currentSong;
        if (song != null) deskSongMenu(context, details.globalPosition, song);
      },
      child: Row(
        children: [
          AppCover(url: item.artUri?.toString(), size: 56),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                DeskLink(item.artist ?? '', () {
                  if (artist.isEmpty) return;
                  Desk.nav.open(
                    DeskArtistPage(
                      artist: Artist(id: 'name:$artist', name: artist),
                    ),
                  );
                }, style: const TextStyle(fontSize: 12, color: Colors.white60)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FavoriteButton(
            song: () => handler.currentSong,
            activeColor: cs.primary,
            size: 20,
            source: 'barra del player',
          ),
        ],
      ),
    );
  }
}

class _Transport extends StatefulWidget {
  const _Transport({required this.item});

  final MediaItem? item;

  @override
  State<_Transport> createState() => _TransportState();
}

class _TransportState extends State<_Transport> {
  // Where the knob is while it is being dragged; the song follows when it
  // is let go.
  double? _dragged;

  @override
  Widget build(BuildContext context) {
    final handler = Desk.handler;
    final enabled = widget.item != null;
    final length = widget.item?.duration ?? Duration.zero;
    const time = TextStyle(
      fontSize: 11.5,
      color: Colors.white60,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          initialData: handler.playbackState.value,
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
                DeskIconButton(
                  icon: AppIcons.shuffle,
                  tooltip: shuffle ? 'Disattiva la riproduzione casuale' : 'Riproduzione casuale',
                  active: shuffle,
                  size: 19,
                  onTap: enabled
                      ? () => handler.setShuffleMode(
                          shuffle ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                DeskIconButton(
                  icon: AppIcons.previous,
                  tooltip: 'Brano precedente',
                  size: 26,
                  onTap: enabled ? handler.skipToPrevious : null,
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: playing ? 'Pausa' : 'Riproduci',
                  waitDuration: const Duration(milliseconds: 500),
                  child: Hover(
                    cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
                    builder: (context, hovered) => GestureDetector(
                      onTap: enabled
                          ? () {
                              PlaybackLogService.instance.log(
                                'UI',
                                'barra del player: ${playing ? 'pausa' : 'play'}',
                              );
                              playing ? handler.pause() : handler.play();
                            }
                          : null,
                      child: AnimatedScale(
                        scale: hovered && enabled ? 1.06 : 1,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: enabled ? Colors.white : Colors.white24,
                          ),
                          child: busy && playing
                              ? const Padding(
                                  padding: EdgeInsets.all(9),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.black,
                                  ),
                                )
                              : Icon(
                                  playing ? AppIcons.pause : AppIcons.play,
                                  size: 24,
                                  color: Colors.black,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DeskIconButton(
                  icon: AppIcons.next,
                  tooltip: 'Brano successivo',
                  size: 26,
                  onTap: enabled ? handler.skipToNext : null,
                ),
                const SizedBox(width: 6),
                DeskIconButton(
                  icon: repeat == AudioServiceRepeatMode.one ? AppIcons.repeatOne : AppIcons.repeat,
                  tooltip: switch (repeat) {
                    AudioServiceRepeatMode.none => 'Ripeti',
                    AudioServiceRepeatMode.one => 'Non ripetere',
                    _ => 'Ripeti il brano',
                  },
                  active: repeat != AudioServiceRepeatMode.none,
                  size: 19,
                  onTap: enabled
                      ? () => handler.setRepeatMode(switch (repeat) {
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
        const SizedBox(height: 2),
        SizedBox(
          height: 20,
          child: ValueListenableBuilder<Duration>(
            valueListenable: handler.positionNotifier,
            builder: (context, position, _) {
              final total = length.inMilliseconds.toDouble();
              final at = _dragged ?? position.inMilliseconds.toDouble().clamp(0.0, total);
              return Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      enabled ? Desk.clock(Duration(milliseconds: at.round())) : '',
                      textAlign: TextAlign.right,
                      style: time,
                    ),
                  ),
                  Expanded(
                    child: _Bar(
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
                        handler.seek(Duration(milliseconds: value.round()));
                      },
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(enabled && total > 0 ? Desk.clock(length) : '', style: time),
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

class _Extras extends StatefulWidget {
  const _Extras();

  @override
  State<_Extras> createState() => _ExtrasState();
}

class _ExtrasState extends State<_Extras> {
  Timer? _remember;

  @override
  void dispose() {
    _remember?.cancel();
    super.dispose();
  }

  void _setVolume(double value) {
    final handler = Desk.handler;
    handler.setOutputVolume(value);
    // How loud this computer plays is kept for the next start; how loud
    // another device plays is that device's to keep.
    if (handler.isRemote) return;
    _remember?.cancel();
    _remember = Timer(
      const Duration(milliseconds: 500),
      () => StorageService.instance.setOutputVolume(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final handler = Desk.handler;
    return ValueListenableBuilder<DeskSide?>(
      valueListenable: Desk.side,
      builder: (context, side, _) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          DeskIconButton(
            icon: AppIcons.lyrics,
            tooltip: 'Testo',
            size: 19,
            active: side == DeskSide.lyrics,
            onTap: () => Desk.toggleSide(DeskSide.lyrics),
          ),
          DeskIconButton(
            icon: AppIcons.queue,
            tooltip: 'Coda',
            size: 19,
            active: side == DeskSide.queue,
            onTap: () => Desk.toggleSide(DeskSide.queue),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: handler.remoteNameNotifier,
            builder: (context, remote, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DeskIconButton(
                  icon: AppIcons.devices,
                  tooltip: remote == null ? 'Dove ascoltare' : 'In riproduzione su $remote',
                  size: 19,
                  active: side == DeskSide.devices || remote != null,
                  onTap: () => Desk.toggleSide(DeskSide.devices),
                ),
                if (remote != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      remote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          ValueListenableBuilder<double>(
            valueListenable: handler.outputVolumeNotifier,
            builder: (context, volume, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DeskIconButton(
                  icon: volume == 0
                      ? Icons.volume_off_rounded
                      : (volume < 0.5 ? AppIcons.volumeDown : AppIcons.volumeUp),
                  tooltip: volume == 0 ? 'Riattiva l\'audio' : 'Disattiva l\'audio',
                  size: 19,
                  onTap: () => _setVolume(volume == 0 ? 0.7 : 0),
                ),
                SizedBox(
                  width: 104,
                  child: _Bar(
                    label: 'Volume',
                    value: volume.clamp(0.0, 1.0),
                    max: 1,
                    onChanged: _setVolume,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin bar with a knob: white, and in the color of the app under the
/// mouse.
class _Bar extends StatelessWidget {
  const _Bar({
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
    final cs = Theme.of(context).colorScheme;
    return Hover(
      builder: (context, hovered) => SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: hovered ? 6 : 0),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          activeTrackColor: hovered ? cs.primary : Colors.white,
          thumbColor: Colors.white,
          inactiveTrackColor: Colors.white24,
          disabledActiveTrackColor: Colors.white24,
          disabledInactiveTrackColor: Colors.white12,
        ),
        child: Semantics(
          label: label,
          child: Slider(value: value, max: max, onChanged: onChanged, onChangeEnd: onChangeEnd),
        ),
      ),
    );
  }
}
