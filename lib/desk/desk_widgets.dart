import 'package:flutter/material.dart';
import 'package:kreate_ios/models/song.dart';
import 'package:kreate_ios/services/storage_service.dart';
import 'package:kreate_ios/ui/theme/app_icons.dart';
import 'package:kreate_ios/ui/widgets/app_cover.dart';

import 'desk.dart';
import 'desk_menus.dart';

/// A cover with a title and a line under it: a playlist, an album, an
/// artist, a mix. Under the mouse it lights up and offers to play.
class DeskCard extends StatelessWidget {
  const DeskCard({
    super.key,
    required this.title,
    required this.cover,
    required this.onOpen,
    this.subtitle = '',
    this.round = false,
    this.onPlay,
    this.onMenu,
  });

  final String title;
  final String subtitle;

  /// Draws the cover at the side it is given.
  final Widget Function(double size) cover;
  final bool round;
  final VoidCallback onOpen;

  /// Plays it without opening it; no button when null.
  final VoidCallback? onPlay;
  final void Function(Offset at)? onMenu;

  @override
  Widget build(BuildContext context) {
    return Hover(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        onSecondaryTapUp: onMenu == null ? null : (details) => onMenu!(details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hovered ? Desk.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
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
                      Container(
                        decoration: BoxDecoration(
                          shape: round ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: round ? null : BorderRadius.circular(6),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 6)),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(width: side, height: side, child: cover(side)),
                      ),
                      if (onPlay != null)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: AnimatedOpacity(
                            opacity: hovered ? 1 : 0,
                            duration: const Duration(milliseconds: 120),
                            child: AnimatedSlide(
                              offset: hovered ? Offset.zero : const Offset(0, 0.15),
                              duration: const Duration(milliseconds: 120),
                              child: IgnorePointer(
                                ignoring: !hovered,
                                child: DeskPlayButton(onTap: onPlay!, size: 44),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 34,
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, height: 1.3, color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled row of cards: as many as fit the width, never cut in half. The
/// rest is behind "Mostra tutto", when there is somewhere to show it.
class DeskShelf extends StatelessWidget {
  const DeskShelf({
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

  /// How many rows of cards at most.
  final int rows;

  static const double _cardWidth = 176;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final perRow = (constraints.maxWidth / _cardWidth).floor().clamp(2, 10);
          final shown = count.clamp(0, perRow * rows);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (onShowAll != null && count > shown) DeskLink('Mostra tutto', onShowAll!),
                  ],
                ),
              ),
              const SizedBox(height: 6),
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

/// A word that is a link: underlined under the mouse.
class DeskLink extends StatelessWidget {
  const DeskLink(this.label, this.onTap, {super.key, this.style});

  final String label;
  final VoidCallback onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Hover(
    cursor: SystemMouseCursors.click,
    builder: (context, hovered) => GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            (style ??
                    const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white60,
                    ))
                .copyWith(
                  decoration: hovered ? TextDecoration.underline : TextDecoration.none,
                  color: hovered ? Colors.white : null,
                ),
      ),
    ),
  );
}

/// The square that stands for the liked songs.
class DeskLikedCover extends StatelessWidget {
  const DeskLikedCover({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(cs.primary, const Color(0xFF3B1FA8), 0.75)!, cs.primary],
        ),
      ),
      child: Icon(AppIcons.heartFilled, size: size * 0.4, color: Colors.white),
    );
  }
}

/// The names of the columns above a list of songs.
class DeskTrackHeader extends StatelessWidget {
  const DeskTrackHeader({super.key, this.showAlbum = true});

  final bool showAlbum;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12.5, color: Colors.white54);
    return Container(
      height: 34,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 34,
            child: Text('#', textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: 12),
          const Expanded(flex: 6, child: Text('Titolo', style: style)),
          if (showAlbum) const Expanded(flex: 4, child: Text('Album', style: style)),
          const SizedBox(width: 40),
          const SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerRight,
              child: Icon(AppIcons.time, size: 16, color: Colors.white54),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// A song in a list: its place, its cover and names, the album, how long it
/// is. Under the mouse the place becomes a play button, and the heart and
/// the three dots appear. A double click plays it; the right button opens
/// its menu.
class DeskTrackRow extends StatelessWidget {
  const DeskTrackRow({
    super.key,
    required this.song,
    required this.number,
    required this.onPlay,
    this.queue,
    this.playlistId,
    this.showAlbum = true,
    this.showCover = true,
  });

  final Song song;
  final int number;
  final VoidCallback onPlay;

  /// The list it is played in, for its menu.
  final List<Song>? queue;
  final String? playlistId;
  final bool showAlbum;
  final bool showCover;

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final handler = Desk.handler;
    void menu(Offset at) => deskSongMenu(context, at, song, queue: queue, playlistId: playlistId);

    return ValueListenableBuilder<(String?, bool)>(
      valueListenable: handler.playbackIndicator,
      builder: (context, indicator, _) {
        final current = indicator.$1 == song.id;
        final playing = current && indicator.$2;
        return Hover(
          builder: (context, hovered) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: onPlay,
            onSecondaryTapUp: (details) => menu(details.globalPosition),
            child: Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: hovered ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Center(
                      child: hovered
                          ? Tooltip(
                              message: playing ? 'Pausa' : 'Riproduci',
                              waitDuration: const Duration(milliseconds: 500),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: playing
                                      ? handler.pause
                                      : (current ? handler.play : onPlay),
                                  child: Icon(
                                    playing ? AppIcons.pause : AppIcons.play,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : current
                          ? Icon(
                              playing ? AppIcons.equalizer : AppIcons.pause,
                              size: 16,
                              color: cs.primary,
                            )
                          : Text(
                              '$number',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white60,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: Row(
                      children: [
                        if (showCover) ...[
                          AppCover(url: song.thumbnailUrl, size: 40),
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
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  color: current ? cs.primary : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: hovered ? Colors.white : Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showAlbum)
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          song.album ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: hovered ? Colors.white : Colors.white60,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: 40,
                    child: ValueListenableBuilder<List<Song>>(
                      valueListenable: StorageService.instance.favoritesNotifier,
                      builder: (context, _, _) {
                        final liked = StorageService.instance.isFavorite(song.id);
                        if (!liked && !hovered) return const SizedBox.shrink();
                        return DeskIconButton(
                          icon: liked ? AppIcons.heartFilled : AppIcons.heart,
                          tooltip: liked
                              ? 'Togli dai brani che ti piacciono'
                              : 'Salva nei brani che ti piacciono',
                          active: liked,
                          size: 17,
                          onTap: () => StorageService.instance.toggleFavorite(song),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      song.duration > Duration.zero ? Desk.clock(song.duration) : '',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: hovered
                        ? Builder(
                            builder: (context) => DeskIconButton(
                              icon: AppIcons.more,
                              tooltip: 'Altre opzioni',
                              size: 18,
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
          ),
        );
      },
    );
  }
}
