import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../app.dart';
import '../kit.dart';
import '../pages/home.dart';
import '../pages/search.dart';
import '../pages/settings.dart';

/// The top of the window. It is the title bar too: the window is moved by
/// dragging it, and its buttons (minimize, maximize, close) are at its end.
/// In it: back and forward through the pages that were opened, the Home,
/// the search field, the settings.
class TitleBar extends StatefulWidget {
  const TitleBar({super.key, required this.searchFocus});

  /// The focus of the search field, so that a key can bring the cursor there.
  final FocusNode searchFocus;

  static const double height = 64;

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> with WindowListener {
  final TextEditingController _field = TextEditingController();
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    App.query.addListener(_onQuery);
    App.nav.addListener(_onPage);
    widget.searchFocus.addListener(_onFocus);
    windowManager.addListener(this);
    _readMaximized();
  }

  @override
  void dispose() {
    App.query.removeListener(_onQuery);
    App.nav.removeListener(_onPage);
    widget.searchFocus.removeListener(_onFocus);
    windowManager.removeListener(this);
    _field.dispose();
    super.dispose();
  }

  Future<void> _readMaximized() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted) setState(() => _maximized = maximized);
    } catch (_) {
      // No window to ask (the screens are being drawn in a test).
    }
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  /// The search was set from elsewhere (a recent one was chosen).
  void _onQuery() {
    if (_field.text != App.query.value) {
      _field.value = TextEditingValue(
        text: App.query.value,
        selection: TextSelection.collapsed(offset: App.query.value.length),
      );
    }
    _showSearch();
    setState(() {});
  }

  /// The field shows what was searched only on the page of its results:
  /// on any other page it is empty, and it fills again going back there.
  void _onPage() {
    final wanted = App.nav.showing<SearchPage>() ? App.query.value : '';
    if (_field.text == wanted) return;
    _field.value = TextEditingValue(
      text: wanted,
      selection: TextSelection.collapsed(offset: wanted.length),
    );
    setState(() {});
  }

  void _onFocus() {
    if (widget.searchFocus.hasFocus) {
      // A search starts from what the field shows, not from the last one.
      if (App.query.value != _field.text) App.query.value = _field.text;
      _showSearch();
    }
    setState(() {});
  }

  /// What is typed is searched on the search page: it is opened, unless it
  /// is the page already in sight.
  void _showSearch() {
    if (!App.nav.showing<SearchPage>()) App.nav.open(const SearchPage());
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.searchFocus.hasFocus;
    return SizedBox(
      height: TitleBar.height,
      child: Stack(
        children: [
          // Anywhere that is not a button moves the window.
          const Positioned.fill(child: DragToMoveArea(child: SizedBox.expand())),
          ListenableBuilder(
            listenable: App.nav,
            builder: (context, _) {
              final home = App.nav.showing<HomePage>();
              final browsing = App.nav.showing<SearchPage>();
              return LayoutBuilder(
                builder: (context, constraints) {
                  // The Home and the search stay in the middle of the window.
                  final middle = (constraints.maxWidth - 2 * 250).clamp(280.0, 546.0);
                  return Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const SizedBox(width: 20),
                            IconBtn(
                              Ic.back,
                              tip: 'Indietro',
                              size: 16,
                              disc: true,
                              color: Tk.text,
                              onTap: App.nav.canGoBack ? App.nav.back : null,
                            ),
                            const SizedBox(width: 8),
                            IconBtn(
                              Ic.forward,
                              tip: 'Avanti',
                              size: 16,
                              disc: true,
                              color: Tk.text,
                              onTap: App.nav.canGoForward ? App.nav.forward : null,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: middle,
                        child: Row(
                          children: [
                            Tooltip(
                              message: 'Home',
                              child: Hover(
                                cursor: SystemMouseCursors.click,
                                builder: (context, hovered) => GestureDetector(
                                  onTap: () {
                                    if (!home) App.nav.open(const HomePage());
                                  },
                                  child: AnimatedScale(
                                    scale: hovered ? 1.04 : 1,
                                    duration: Tk.quick,
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: hovered ? Tk.hover : Tk.raised,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        home ? Ic.homeOn : Ic.home,
                                        size: 24,
                                        color: home || hovered ? Tk.text : Tk.subdued,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // ── What to look for ─────────────────────────────
                            Expanded(
                              child: Hover(
                                cursor: SystemMouseCursors.text,
                                builder: (context, hovered) => Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: hovered || focused ? Tk.hover : Tk.raised,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: focused
                                          ? Tk.text
                                          : (hovered
                                                ? const Color(0x33FFFFFF)
                                                : Colors.transparent),
                                      width: focused ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 12),
                                      Tooltip(
                                        message: 'Cerca',
                                        child: Icon(
                                          Ic.search,
                                          size: 24,
                                          color: hovered || focused ? Tk.text : Tk.subdued,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _field,
                                          focusNode: widget.searchFocus,
                                          onChanged: (text) => App.query.value = text,
                                          textInputAction: TextInputAction.search,
                                          style: const TextStyle(fontSize: 15.5, color: Tk.text),
                                          decoration: const InputDecoration(
                                            isCollapsed: true,
                                            border: InputBorder.none,
                                            hintText: 'Cosa vuoi ascoltare?',
                                            hintStyle: TextStyle(fontSize: 15.5, color: Tk.subdued),
                                          ),
                                        ),
                                      ),
                                      if (_field.text.isNotEmpty)
                                        IconBtn(
                                          Ic.close,
                                          tip: 'Cancella il campo di ricerca',
                                          size: 16,
                                          onTap: () {
                                            _field.clear();
                                            App.query.value = '';
                                            widget.searchFocus.requestFocus();
                                          },
                                        ),
                                      Container(width: 1, height: 24, color: Tk.faint),
                                      const SizedBox(width: 4),
                                      IconBtn(
                                        browsing && _field.text.isEmpty ? Ic.browseOn : Ic.browse,
                                        tip: 'Sfoglia',
                                        size: 22,
                                        color: browsing && _field.text.isEmpty ? Tk.text : null,
                                        onTap: () {
                                          _field.clear();
                                          App.query.value = '';
                                          _showSearch();
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 16, right: 8),
                              child: IconBtn(
                                Ic.settings,
                                tip: 'Impostazioni',
                                size: 19,
                                disc: true,
                                on: App.nav.showing<SettingsPage>(),
                                onTap: () {
                                  if (!App.nav.showing<SettingsPage>()) {
                                    App.nav.open(const SettingsPage());
                                  }
                                },
                              ),
                            ),
                            // ── The buttons of the window ──────────────────────
                            WindowCaptionButton.minimize(
                              brightness: Brightness.dark,
                              onPressed: windowManager.minimize,
                            ),
                            if (_maximized)
                              WindowCaptionButton.unmaximize(
                                brightness: Brightness.dark,
                                onPressed: windowManager.unmaximize,
                              )
                            else
                              WindowCaptionButton.maximize(
                                brightness: Brightness.dark,
                                onPressed: windowManager.maximize,
                              ),
                            WindowCaptionButton.close(
                              brightness: Brightness.dark,
                              onPressed: windowManager.close,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
