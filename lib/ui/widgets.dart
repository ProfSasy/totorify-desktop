import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:kreate_ios/models/song.dart';
import 'package:kreate_ios/services/spotify_catalog_service.dart';
import 'package:kreate_ios/services/storage_service.dart';

import 'app.dart';
import 'kit.dart';
import 'menus.dart';
import 'pages/collection.dart';

/// The card of the computer app: a picture, a name, a line under it. It has
/// no surface of its own; under the mouse it gets one, and the button that
/// plays slides up over the picture.
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.title,
    required this.art,
    required this.onOpen,
    this.subtitle = '',
    this.onPlay,
    this.onMenu,
    this.round = false,
  });

  final String title;
  final String subtitle;

  /// The picture is a circle (an artist): its shadow is one too.
  final bool round;

  /// Draws the picture at the side it is given.
  final Widget Function(double side) art;
  final VoidCallback onOpen;

  /// Plays it without opening it; no button when null.
  final VoidCallback? onPlay;
  final void Function(Offset at)? onMenu;

  @override
  Widget build(BuildContext context) => Hover(
    cursor: SystemMouseCursors.click,
    builder: (context, hovered) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      onSecondaryTapUp: onMenu == null ? null : (details) => onMenu!(details.globalPosition),
      child: AnimatedContainer(
        duration: Tk.quick,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hovered ? Tk.raised : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.maxWidth;
                return Stack(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: round ? BoxShape.circle : BoxShape.rectangle,
                        boxShadow: const [
                          BoxShadow(color: Color(0x80000000), blurRadius: 18, offset: Offset(0, 8)),
                        ],
                      ),
                      child: art(side),
                    ),
                    if (onPlay != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: AnimatedSlide(
                          offset: hovered ? Offset.zero : const Offset(0, 0.18),
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          child: AnimatedOpacity(
                            opacity: hovered ? 1 : 0,
                            duration: const Duration(milliseconds: 160),
                            child: IgnorePointer(
                              ignoring: !hovered,
                              child: PlayFab(onTap: onPlay!, size: 48),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Tk.text),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 36,
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.35, color: Tk.subdued),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A titled row of cards: as many as fit the width, never one cut in half.
/// The title leads to all of them, when there is somewhere to show them.
class Shelf extends StatelessWidget {
  const Shelf({
    super.key,
    required this.title,
    required this.count,
    required this.builder,
    this.onShowAll,
    this.rows = 1,
  });

  final String title;
  final int count;
  final Widget Function(BuildContext context, int index) builder;
  final VoidCallback? onShowAll;
  final int rows;

  static const double _cardWidth = 180;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 34),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final perRow = (constraints.maxWidth / _cardWidth).floor().clamp(2, 10);
          final shown = count.clamp(0, perRow * rows);
          final more = onShowAll != null && count > shown;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: more
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: LinkText(title, onTap: onShowAll!, style: Tk.title(24)),
                            )
                          : Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Tk.title(24),
                            ),
                    ),
                    if (more)
                      LinkText(
                        'Mostra tutto',
                        onTap: onShowAll!,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Tk.subdued,
                        ),
                      ),
                  ],
                ),
              ),
              for (var start = 0; start < shown; start += perRow)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = start; i < start + perRow; i++)
                      Expanded(child: i < shown ? builder(context, i) : const SizedBox.shrink()),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A strip with a small picture and a name: what the Home offers to go
/// back to.
class QuickTile extends StatelessWidget {
  const QuickTile({
    super.key,
    required this.title,
    required this.art,
    required this.onOpen,
    this.onPlay,
    this.onMenu,
  });

  final String title;
  final Widget art;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;
  final void Function(Offset at)? onMenu;

  static const double height = 56;

  @override
  Widget build(BuildContext context) => Hover(
    cursor: SystemMouseCursors.click,
    builder: (context, hovered) => GestureDetector(
      onTap: onOpen,
      onSecondaryTapUp: onMenu == null ? null : (details) => onMenu!(details.globalPosition),
      child: AnimatedContainer(
        duration: Tk.quick,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: hovered ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            SizedBox(width: height, height: height, child: art),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: Tk.text,
                ),
              ),
            ),
            if (onPlay != null && hovered)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PlayFab(onTap: onPlay!, size: 34),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    ),
  );
}

/// A genre as a block of its color, its name at the top and its picture
/// tilted in the corner.
class GenreTile extends StatelessWidget {
  const GenreTile({super.key, required this.genre, required this.width});

  final SpotifyCategoryItem genre;
  final double width;

  @override
  Widget build(BuildContext context) => Hover(
    cursor: SystemMouseCursors.click,
    builder: (context, hovered) => GestureDetector(
      onTap: () => CollectionPage.openEditorial(
        id: genre.playlistId,
        title: genre.title,
        coverUrl: genre.coverUrl.isEmpty ? null : genre.coverUrl,
      ),
      child: Container(
        width: width,
        height: width * 0.56,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Color.lerp(genre.color, Colors.white, hovered ? 0.08 : 0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -width * 0.07,
              bottom: -width * 0.02,
              child: Transform.rotate(
                angle: 0.44,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
                  ),
                  child: Artwork(
                    url: genre.coverUrl.isEmpty ? null : genre.coverUrl,
                    seed: genre.title,
                    size: width * 0.42,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                genre.title,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.4,
                  color: Tk.text,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The button that keeps a song among the liked ones: a plus in a circle,
/// a tick on the color of the app once it is there.
class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.song, this.size = 17, this.showWhenOff = true});

  final Song? Function() song;
  final double size;

  /// When false the button is there only for a song already kept.
  final bool showWhenOff;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<Song>>(
    valueListenable: StorageService.instance.favoritesNotifier,
    builder: (context, _, _) {
      final current = song();
      final saved = current != null && StorageService.instance.isFavorite(current.id);
      if (!saved && !showWhenOff) return SizedBox(width: size + 14, height: size + 14);
      return IconBtn(
        saved ? Ic.saved : Ic.save,
        tip: saved ? 'Rimuovi da Brani che ti piacciono' : 'Aggiungi a Brani che ti piacciono',
        size: size,
        on: saved,
        onTap: current == null
            ? null
            : () async {
                await StorageService.instance.toggleFavorite(current);
                App.toast(
                  saved ? 'Rimosso da Brani che ti piacciono' : 'Aggiunto a Brani che ti piacciono',
                );
              },
      );
    },
  );
}

/// The names of the columns above a list of songs.
class TrackHeader extends StatelessWidget {
  const TrackHeader({super.key, this.album = true});

  final bool album;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 13.5, color: Tk.subdued);
    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Tk.line)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 28,
            child: Text('#', textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: 14),
          const Expanded(flex: 6, child: Text('Titolo', style: style)),
          if (album) const Expanded(flex: 4, child: Text('Album', style: style)),
          const SizedBox(width: 36),
          const SizedBox(
            width: 56,
            child: Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: 'Durata',
                child: Icon(Ic.clock, size: 17, color: Tk.subdued),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// A song in a list. Under the mouse its number becomes the button that
/// plays it, and the buttons to keep it and for its menu appear. A double
/// click plays; the right button opens the menu.
class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.song,
    required this.number,
    required this.onPlay,
    this.queue,
    this.playlistId,
    this.album = true,
    this.art = true,
  });

  final Song song;
  final int number;
  final VoidCallback onPlay;

  /// The list it is played in, for its menu.
  final List<Song>? queue;
  final String? playlistId;
  final bool album;
  final bool art;

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final player = App.player;
    void menu(Offset at) => songMenu(context, at, song, queue: queue, playlistId: playlistId);

    return ValueListenableBuilder<(String?, bool)>(
      valueListenable: player.playbackIndicator,
      builder: (context, indicator, _) {
        final current = indicator.$1 == song.id;
        final playing = current && indicator.$2;
        return Hover(
          builder: (context, hovered) {
            final grey = hovered ? Tk.text : Tk.subdued;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: onPlay,
              onSecondaryTapUp: (details) => menu(details.globalPosition),
              child: Container(
                height: height,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: hovered ? const Color(0x1AFFFFFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Center(
                        child: hovered
                            ? Tooltip(
                                message: playing ? 'Pausa' : 'Riproduci ${song.title}',
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: playing
                                        ? player.pause
                                        : (current ? player.play : onPlay),
                                    child: Icon(
                                      playing ? Ic.pause : Ic.play,
                                      size: 15,
                                      color: Tk.text,
                                    ),
                                  ),
                                ),
                              )
                            : playing
                            ? Equalizer(color: accent)
                            : Text(
                                '$number',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: current ? accent : Tk.subdued,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 6,
                      child: Row(
                        children: [
                          if (art) ...[
                            Artwork(url: song.thumbnailUrl, seed: song.title, size: 40),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 15, color: current ? accent : Tk.text),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13.5, color: grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (album)
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            song.album ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, color: grey),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: 36,
                      child: SaveButton(song: () => song, showWhenOff: hovered),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        song.duration > Duration.zero ? App.clock(song.duration) : '',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Tk.subdued,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: hovered
                          ? Builder(
                              builder: (context) => IconBtn(
                                Ic.more,
                                tip: 'Altre opzioni per ${song.title}',
                                size: 20,
                                color: Tk.text,
                                onTap: () {
                                  final box = context.findRenderObject()! as RenderBox;
                                  menu(box.localToGlobal(Offset(0, box.size.height)));
                                },
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// The bars that move beside what is playing; still while it is paused.
class Equalizer extends StatefulWidget {
  const Equalizer({super.key, required this.color, this.size = 14});

  final Color color;
  final double size;

  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer> with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<PlaybackState>(
    stream: App.player.playbackState,
    initialData: App.player.playbackState.value,
    builder: (context, snapshot) {
      final moving = snapshot.data?.playing ?? false;
      if (moving && !_beat.isAnimating) _beat.repeat();
      if (!moving && _beat.isAnimating) _beat.stop();
      return RepaintBoundary(
        child: CustomPaint(size: Size.square(widget.size), painter: _Bars(_beat, widget.color)),
      );
    },
  );
}

class _Bars extends CustomPainter {
  _Bars(this.beat, this.color) : super(repaint: beat);

  final Animation<double> beat;
  final Color color;

  static const List<double> _phases = [0, 0.37, 0.71, 0.18];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const count = 4;
    final width = size.width / (count * 2 - 1);
    for (var i = 0; i < count; i++) {
      final wave = math.sin((beat.value + _phases[i]) * 2 * math.pi) * 0.5 + 0.5;
      final height = size.height * (0.28 + 0.72 * wave);
      canvas.drawRect(Rect.fromLTWH(i * width * 2, size.height - height, width, height), paint);
    }
  }

  @override
  bool shouldRepaint(_Bars old) => old.color != color;
}

/// The name of a part of a page.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 34, 12, 12),
    child: Text(text, style: Tk.title(24)),
  );
}
