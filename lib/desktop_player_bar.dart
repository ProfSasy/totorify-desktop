import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:kreate_ios/services/audio_handler.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/services/storage_service.dart';
import 'package:kreate_ios/ui/theme/app_icons.dart';
import 'package:kreate_ios/ui/widgets/app_cover.dart';
import 'package:kreate_ios/ui/widgets/devices_sheet.dart';
import 'package:kreate_ios/ui/widgets/favorite_button.dart';
import 'package:kreate_ios/ui/widgets/player_sheet.dart';

/// The player at the foot of the window: what is playing, the controls with
/// the bar of the song, and on the right the device that plays and how
/// loud. Clicking the song opens the full player (text, queue and the rest).
class DesktopPlayerBar extends StatelessWidget {
  const DesktopPlayerBar({super.key, required this.handler});

  final AudioPlayerHandler handler;

  static const double height = 86;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<MediaItem?>(
        stream: handler.mediaItem,
        initialData: handler.mediaItem.value,
        builder: (context, snapshot) {
          final item = snapshot.data;
          return Row(
            children: [
              Expanded(
                flex: 3,
                child: _NowPlaying(handler: handler, item: item),
              ),
              Expanded(
                flex: 4,
                child: _Transport(handler: handler, item: item),
              ),
              Expanded(
                flex: 3,
                child: _Output(handler: handler, hasSong: item != null),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.handler, required this.item});

  final AudioPlayerHandler handler;
  final MediaItem? item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = this.item;
    if (item == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Scegli qualcosa da ascoltare',
          style: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
        ),
      );
    }
    return Row(
      children: [
        Flexible(
          child: Tooltip(
            message: 'Apri il player',
            waitDuration: const Duration(milliseconds: 600),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => PlayerSheet.show(context, handler),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppCover(url: item.artUri?.toString(), size: 56),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        FavoriteButton(
          song: () => handler.currentSong,
          activeColor: cs.primary,
          size: 22,
          source: 'barra del player',
        ),
      ],
    );
  }
}

class _Transport extends StatefulWidget {
  const _Transport({required this.handler, required this.item});

  final AudioPlayerHandler handler;
  final MediaItem? item;

  @override
  State<_Transport> createState() => _TransportState();
}

class _TransportState extends State<_Transport> {
  // Where the knob is while it is being dragged; the song follows when it
  // is let go.
  double? _dragged;

  static String _clock(Duration d) {
    final seconds = d.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:${minutes.toString().padLeft(2, '0')}:$rest' : '$minutes:$rest';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final handler = widget.handler;
    final enabled = widget.item != null;
    final length = widget.item?.duration ?? Duration.zero;
    final time = TextStyle(
      fontSize: 11.5,
      color: cs.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Brano precedente',
              iconSize: 26,
              onPressed: enabled ? handler.skipToPrevious : null,
              icon: const Icon(AppIcons.previous),
            ),
            const SizedBox(width: 6),
            StreamBuilder<PlaybackState>(
              stream: handler.playbackState,
              initialData: handler.playbackState.value,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final playing = state?.playing ?? false;
                final busy =
                    state?.processingState == AudioProcessingState.loading ||
                    state?.processingState == AudioProcessingState.buffering;
                return SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (busy && playing)
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      IconButton.filled(
                        tooltip: playing ? 'Pausa' : 'Riproduci',
                        style: IconButton.styleFrom(
                          backgroundColor: cs.onSurface,
                          foregroundColor: cs.surface,
                          disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.2),
                          fixedSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                        ),
                        iconSize: 24,
                        onPressed: enabled
                            ? () {
                                PlaybackLogService.instance.log(
                                  'UI',
                                  'barra del player: ${playing ? 'pausa' : 'play'}',
                                );
                                playing ? handler.pause() : handler.play();
                              }
                            : null,
                        icon: Icon(playing ? AppIcons.pause : AppIcons.play),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Brano successivo',
              iconSize: 26,
              onPressed: enabled ? handler.skipToNext : null,
              icon: const Icon(AppIcons.next),
            ),
          ],
        ),
        SizedBox(
          height: 22,
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
                      enabled ? _clock(Duration(milliseconds: at.round())) : '',
                      textAlign: TextAlign.right,
                      style: time,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: cs.onSurface,
                        thumbColor: cs.onSurface,
                        inactiveTrackColor: cs.onSurface.withValues(alpha: 0.18),
                      ),
                      child: Slider(
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
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(enabled && total > 0 ? _clock(length) : '', style: time),
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

class _Output extends StatefulWidget {
  const _Output({required this.handler, required this.hasSong});

  final AudioPlayerHandler handler;
  final bool hasSong;

  @override
  State<_Output> createState() => _OutputState();
}

class _OutputState extends State<_Output> {
  Timer? _remember;

  @override
  void dispose() {
    _remember?.cancel();
    super.dispose();
  }

  void _setVolume(double value) {
    final handler = widget.handler;
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
    final handler = widget.handler;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Tooltip(
            message: 'Dove ascoltare',
            waitDuration: const Duration(milliseconds: 600),
            child: DevicesButton(
              remoteName: handler.remoteNameNotifier,
              accent: cs.primary,
              idle: cs.onSurfaceVariant,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 14),
        ValueListenableBuilder<double>(
          valueListenable: handler.outputVolumeNotifier,
          builder: (context, volume, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                volume == 0 ? Icons.volume_off_rounded : AppIcons.volumeUp,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              SizedBox(
                width: 120,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: cs.onSurface,
                    thumbColor: cs.onSurface,
                    inactiveTrackColor: cs.onSurface.withValues(alpha: 0.18),
                  ),
                  child: Semantics(
                    label: 'Volume',
                    child: Slider(value: volume.clamp(0.0, 1.0), onChanged: _setVolume),
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Apri il player',
          iconSize: 22,
          onPressed: widget.hasSong ? () => PlayerSheet.show(context, handler) : null,
          icon: const Icon(Icons.open_in_full_rounded),
        ),
      ],
    );
  }
}
