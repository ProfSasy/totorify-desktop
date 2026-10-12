import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The look of the computer app, in one place: its colors and measures,
/// its icons, its theme, and the small pieces every screen is made of.
///
/// It follows the conventions of the music apps for computers (Spotify's
/// above all): a black window, content on panels a shade lighter and a
/// little apart, grey text that turns white under the mouse, one color for
/// what is active.
class Tk {
  Tk._();

  static const String font = 'Figtree';

  static const Color base = Color(0xFF000000);
  static const Color panel = Color(0xFF121212);
  static const Color raised = Color(0xFF1F1F1F);
  static const Color hover = Color(0xFF2A2A2A);
  static const Color menu = Color(0xFF282828);
  static const Color menuHover = Color(0xFF3E3E3E);
  static const Color text = Color(0xFFFFFFFF);
  static const Color subdued = Color(0xFFB3B3B3);
  static const Color faint = Color(0xFF7A7A7A);
  static const Color line = Color(0x1FFFFFFF);

  static const double gap = 8;
  static const double radius = 8;

  static const Duration quick = Duration(milliseconds: 110);

  static TextStyle title(double size) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w800,
    letterSpacing: size >= 40 ? -size * 0.035 : -0.4,
    height: 1.08,
    color: text,
  );

  static const TextStyle body = TextStyle(fontSize: 14, color: text);
  static const TextStyle small = TextStyle(fontSize: 13, color: subdued);
  static const TextStyle label = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text);

  static ThemeData theme(Color accent) {
    final scheme = ColorScheme.dark(
      primary: accent,
      onPrimary: Colors.black,
      secondary: accent,
      surface: panel,
      onSurface: text,
      onSurfaceVariant: subdued,
      error: const Color(0xFFF15E6C),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: font,
      scaffoldBackgroundColor: Tk.base,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
    );
    return base.copyWith(
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: text,
        selectionColor: accent.withValues(alpha: 0.45),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: menu, borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(
          fontFamily: font,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: text,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(10),
        radius: Radius.zero,
        crossAxisMargin: 0,
        mainAxisMargin: 0,
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged)
              ? const Color(0x99FFFFFF)
              : const Color(0x4DFFFFFF),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: menu,
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(fontFamily: font, fontSize: 14, color: text),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: menu,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        titleTextStyle: const TextStyle(
          fontFamily: font,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: text,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: font,
          fontSize: 14,
          height: 1.45,
          color: subdued,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(backgroundColor: text),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
    );
  }
}

/// The icons of the computer app: thin outlines, filled when the thing is
/// on or is where one is.
///
/// They are glyphs of the Phosphor icon fonts (MIT license), which come
/// with the app in `assets/fonts`: the numbers are theirs.
class Ic {
  Ic._();

  static const IconData home = IconData(0xe2c2, fontFamily: 'PhosphorRegular');
  static const IconData homeOn = IconData(0xe2c2, fontFamily: 'PhosphorFill');
  static const IconData search = IconData(0xe30c, fontFamily: 'PhosphorRegular');
  static const IconData searchBold = IconData(0xe30c, fontFamily: 'PhosphorBold');
  static const IconData browse = IconData(0xe464, fontFamily: 'PhosphorRegular');
  static const IconData browseOn = IconData(0xe464, fontFamily: 'PhosphorFill');
  static const IconData library = IconData(0xe758, fontFamily: 'PhosphorRegular');
  static const IconData libraryOn = IconData(0xe758, fontFamily: 'PhosphorFill');
  static const IconData plus = IconData(0xe3d4, fontFamily: 'PhosphorBold');
  static const IconData back = IconData(0xe138, fontFamily: 'PhosphorBold');
  static const IconData forward = IconData(0xe13a, fontFamily: 'PhosphorBold');
  static const IconData down = IconData(0xe136, fontFamily: 'PhosphorBold');
  static const IconData close = IconData(0xe4f6, fontFamily: 'PhosphorBold');
  static const IconData more = IconData(0xe1fe, fontFamily: 'PhosphorBold');
  static const IconData settings = IconData(0xe270, fontFamily: 'PhosphorRegular');
  static const IconData user = IconData(0xe4c2, fontFamily: 'PhosphorRegular');

  static const IconData play = IconData(0xe3d0, fontFamily: 'PhosphorFill');
  static const IconData pause = IconData(0xe39e, fontFamily: 'PhosphorFill');
  static const IconData next = IconData(0xe5a6, fontFamily: 'PhosphorFill');
  static const IconData previous = IconData(0xe5a4, fontFamily: 'PhosphorFill');
  static const IconData shuffle = IconData(0xe422, fontFamily: 'PhosphorRegular');
  static const IconData repeat = IconData(0xe3f6, fontFamily: 'PhosphorRegular');
  static const IconData repeatOne = IconData(0xe3f8, fontFamily: 'PhosphorRegular');
  static const IconData queue = IconData(0xe6ac, fontFamily: 'PhosphorRegular');
  static const IconData lyrics = IconData(0xe75c, fontFamily: 'PhosphorRegular');
  static const IconData nowPlaying = IconData(0xec24, fontFamily: 'PhosphorRegular');
  static const IconData devices = IconData(0xeba4, fontFamily: 'PhosphorRegular');
  static const IconData volumeHigh = IconData(0xe44a, fontFamily: 'PhosphorRegular');
  static const IconData volumeLow = IconData(0xe44c, fontFamily: 'PhosphorRegular');
  static const IconData volumeOff = IconData(0xe45c, fontFamily: 'PhosphorRegular');

  static const IconData save = IconData(0xe3d6, fontFamily: 'PhosphorRegular');
  static const IconData saved = IconData(0xe184, fontFamily: 'PhosphorFill');
  static const IconData heart = IconData(0xe2a8, fontFamily: 'PhosphorFill');
  static const IconData pin = IconData(0xe3e2, fontFamily: 'PhosphorFill');
  static const IconData clock = IconData(0xe19a, fontFamily: 'PhosphorRegular');
  static const IconData history = IconData(0xe1a0, fontFamily: 'PhosphorRegular');
  static const IconData verified = IconData(0xe606, fontFamily: 'PhosphorFill');
  static const IconData note = IconData(0xe340, fontFamily: 'PhosphorRegular');
  static const IconData playlist = IconData(0xe6aa, fontFamily: 'PhosphorRegular');
  static const IconData album = IconData(0xecac, fontFamily: 'PhosphorRegular');
  static const IconData artist = IconData(0xe4c2, fontFamily: 'PhosphorRegular');
  static const IconData addToQueue = IconData(0xe6ac, fontFamily: 'PhosphorRegular');
  static const IconData playNext = IconData(0xe06c, fontFamily: 'PhosphorRegular');
  static const IconData edit = IconData(0xe3b4, fontFamily: 'PhosphorRegular');
  static const IconData trash = IconData(0xe4a6, fontFamily: 'PhosphorRegular');
  static const IconData link = IconData(0xe2e6, fontFamily: 'PhosphorRegular');
  static const IconData check = IconData(0xe182, fontFamily: 'PhosphorBold');
  static const IconData computer = IconData(0xe586, fontFamily: 'PhosphorRegular');
  static const IconData phone = IconData(0xe1e0, fontFamily: 'PhosphorRegular');
  static const IconData tv = IconData(0xe754, fontFamily: 'PhosphorRegular');
  static const IconData folder = IconData(0xe256, fontFamily: 'PhosphorRegular');
  static const IconData info = IconData(0xe2ce, fontFamily: 'PhosphorRegular');
}

/// Builds with whether the mouse is over it.
class Hover extends StatefulWidget {
  const Hover({super.key, required this.builder, this.cursor = MouseCursor.defer});

  final Widget Function(BuildContext context, bool hovered) builder;
  final MouseCursor cursor;

  @override
  State<Hover> createState() => _HoverState();
}

class _HoverState extends State<Hover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.cursor,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: widget.builder(context, _hovered),
  );
}

/// A glyph that is a button: grey, white under the mouse, the color of the
/// app (with a dot under it) when what it stands for is on.
class IconBtn extends StatelessWidget {
  const IconBtn(
    this.icon, {
    super.key,
    required this.tip,
    required this.onTap,
    this.size = 18,
    this.on = false,
    this.dot = false,
    this.disc = false,
    this.color,
  });

  final IconData icon;
  final String tip;
  final VoidCallback? onTap;
  final double size;

  /// Drawn in the color of the app.
  final bool on;

  /// A dot under it while [on], as under shuffle and repeat.
  final bool dot;

  /// On a dark disc of its own, as the arrows of the top bar.
  final bool disc;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final enabled = onTap != null;
    return Tooltip(
      message: tip,
      child: Hover(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        builder: (context, hovered) {
          final ink = !enabled
              ? Tk.faint.withValues(alpha: 0.6)
              : on
              ? accent
              : (hovered ? Tk.text : (color ?? Tk.subdued));
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedScale(
              scale: hovered && enabled && !disc ? 1.06 : 1,
              duration: Tk.quick,
              child: Container(
                width: size + 14,
                height: size + 14,
                decoration: disc
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        color: hovered && enabled ? Tk.hover : Tk.raised,
                      )
                    : null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, size: size, color: ink),
                    if (dot && on)
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The round button that plays, in the color of the app.
class PlayFab extends StatelessWidget {
  const PlayFab({super.key, required this.onTap, this.size = 48, this.playing = false, this.tip});

  final VoidCallback onTap;
  final double size;
  final bool playing;
  final String? tip;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: tip ?? (playing ? 'Pausa' : 'Riproduci'),
      child: Hover(
        cursor: SystemMouseCursors.click,
        builder: (context, hovered) => GestureDetector(
          onTap: onTap,
          child: AnimatedScale(
            scale: hovered ? 1.05 : 1,
            duration: Tk.quick,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hovered ? Color.lerp(accent, Colors.white, 0.12) : accent,
                boxShadow: const [
                  BoxShadow(color: Color(0x80000000), blurRadius: 12, offset: Offset(0, 6)),
                ],
              ),
              child: Icon(playing ? Ic.pause : Ic.play, size: size * 0.42, color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill that filters: dark, white when it is the one chosen.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hover(
    cursor: SystemMouseCursors.click,
    builder: (context, hovered) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Tk.quick,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Tk.text : (hovered ? const Color(0xFF333333) : Tk.hover),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.black : Tk.text,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A word that leads somewhere: underlined under the mouse.
class LinkText extends StatelessWidget {
  const LinkText(this.text, {super.key, required this.onTap, this.style});

  final String text;
  final VoidCallback onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? Tk.small;
    return Hover(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(
            color: hovered ? Tk.text : style.color,
            decoration: hovered ? TextDecoration.underline : TextDecoration.none,
            decorationColor: Tk.text,
          ),
        ),
      ),
    );
  }
}

/// A picture: a cover, a portrait. What has none gets one drawn from its
/// name, two colors and its initial, so that no two look alike.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.url,
    required this.seed,
    required this.size,
    this.round = false,
    this.radius = 4,
  });

  final String? url;

  /// The name of the thing, for the picture drawn when there is none.
  final String seed;
  final double size;
  final bool round;
  final double radius;

  static const List<(Color, Color)> _pairs = [
    (Color(0xFF7B2FF7), Color(0xFFF107A3)),
    (Color(0xFF0F9B8E), Color(0xFF1D4ED8)),
    (Color(0xFFF97316), Color(0xFFDB2777)),
    (Color(0xFF16A34A), Color(0xFF0E7490)),
    (Color(0xFFDC2626), Color(0xFF7C2D12)),
    (Color(0xFF2563EB), Color(0xFF7C3AED)),
    (Color(0xFFCA8A04), Color(0xFFB91C1C)),
    (Color(0xFF0891B2), Color(0xFF4F46E5)),
  ];

  static (Color, Color) colorsOf(String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _pairs[hash % _pairs.length];
  }

  Widget _drawn() {
    final (from, to) = colorsOf(seed);
    final clean = seed.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [from, to],
        ),
      ),
      child: Text(
        clean.isEmpty ? '♪' : clean.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.44,
          fontWeight: FontWeight.w900,
          height: 1,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final Widget image;
    if (url == null || url.isEmpty) {
      image = _drawn();
    } else {
      final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
      image = CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: pixels,
        fadeInDuration: const Duration(milliseconds: 140),
        fadeOutDuration: const Duration(milliseconds: 60),
        placeholder: (_, _) => Container(width: size, height: size, color: Tk.hover),
        errorWidget: (_, _, _) => _drawn(),
      );
    }
    return round
        ? ClipOval(child: image)
        : ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}

/// The square that stands for the liked songs.
class LikedArt extends StatelessWidget {
  const LikedArt({super.key, required this.size, this.radius = 4});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF450AF5), Color(0xFF8E8EE5), Color(0xFFC4EFD9)],
          stops: [0, 0.62, 1],
        ),
      ),
      child: Icon(Ic.heart, size: size * 0.4, color: Colors.white),
    ),
  );
}

/// What a page shows while it loads (with no title), or when it has nothing
/// to show.
class Notice extends StatelessWidget {
  const Notice({super.key, this.icon, this.title, this.text, this.action, this.onAction});

  final IconData? icon;
  final String? title;
  final String? text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    if (title == null) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.6, color: Tk.subdued),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: Tk.faint),
              const SizedBox(height: 18),
            ],
            Text(title!, textAlign: TextAlign.center, style: Tk.title(24)),
            if (text != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: 430,
                child: Text(
                  text!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, height: 1.5, color: Tk.subdued),
                ),
              ),
            ],
            if (action != null && onAction != null) ...[
              const SizedBox(height: 24),
              WhiteButton(action!, onTap: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

/// The button of the answer that is wanted: a white pill.
class WhiteButton extends StatelessWidget {
  const WhiteButton(this.label, {super.key, required this.onTap, this.accent = false});

  final String label;
  final VoidCallback onTap;

  /// In the color of the app instead of white.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final fill = accent ? Theme.of(context).colorScheme.primary : Tk.text;
    return Hover(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: hovered ? 1.04 : 1,
          duration: Tk.quick,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The button of the other answer: an outlined pill.
class GhostButton extends StatelessWidget {
  const GhostButton(this.label, {super.key, required this.onTap, this.small = false});

  final String label;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) => Hover(
    cursor: SystemMouseCursors.click,
    builder: (context, hovered) => GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: hovered ? 1.04 : 1,
        duration: Tk.quick,
        child: Container(
          height: small ? 32 : 44,
          padding: EdgeInsets.symmetric(horizontal: small ? 16 : 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: hovered ? Tk.text : Tk.faint),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: small ? 13.5 : 14.5,
                fontWeight: FontWeight.w700,
                color: Tk.text,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
