import 'package:flutter/material.dart';
import 'package:kreate_ios/ui/theme/app_icons.dart';

import 'desk.dart';
import 'desk_home.dart';
import 'desk_search.dart';

/// The bar at the top of the window: back and forward through the pages
/// that were opened, the Home and the search field in the middle, the
/// settings at the end.
class DeskTopBar extends StatefulWidget {
  const DeskTopBar({super.key, required this.onSettings, required this.searchFocus});

  final VoidCallback onSettings;

  /// The focus of the search field, so that a key can bring the cursor there.
  final FocusNode searchFocus;

  static const double height = 56;

  @override
  State<DeskTopBar> createState() => _DeskTopBarState();
}

class _DeskTopBarState extends State<DeskTopBar> {
  final TextEditingController _field = TextEditingController();

  @override
  void initState() {
    super.initState();
    Desk.query.addListener(_onQuery);
    widget.searchFocus.addListener(_onFocus);
  }

  @override
  void dispose() {
    Desk.query.removeListener(_onQuery);
    widget.searchFocus.removeListener(_onFocus);
    _field.dispose();
    super.dispose();
  }

  /// The search was set from elsewhere (a recent one was chosen).
  void _onQuery() {
    if (_field.text != Desk.query.value) {
      _field.value = TextEditingValue(
        text: Desk.query.value,
        selection: TextSelection.collapsed(offset: Desk.query.value.length),
      );
    }
    _showSearch();
    setState(() {});
  }

  void _onFocus() {
    if (widget.searchFocus.hasFocus) _showSearch();
    setState(() {});
  }

  /// What is typed is searched on the search page: it is opened, unless it
  /// is the page already in sight.
  void _showSearch() {
    if (!Desk.nav.showing<DeskSearchPage>()) Desk.nav.open(const DeskSearchPage());
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.searchFocus.hasFocus;
    return SizedBox(
      height: DeskTopBar.height,
      child: ListenableBuilder(
        listenable: Desk.nav,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            // The Home and the search stay in the middle of the window,
            // whatever is at their sides.
            final middle = (constraints.maxWidth - 2 * 190).clamp(260.0, 540.0);
            return Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      DeskIconButton(
                        icon: Icons.chevron_left_rounded,
                        tooltip: 'Indietro',
                        size: 26,
                        filled: true,
                        onTap: Desk.nav.canGoBack ? Desk.nav.back : null,
                      ),
                      const SizedBox(width: 8),
                      DeskIconButton(
                        icon: Icons.chevron_right_rounded,
                        tooltip: 'Avanti',
                        size: 26,
                        filled: true,
                        onTap: Desk.nav.canGoForward ? Desk.nav.forward : null,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: middle,
                  child: Row(
                    children: [
                      DeskIconButton(
                        icon: Icons.home_rounded,
                        tooltip: 'Home',
                        size: 26,
                        filled: true,
                        active: Desk.nav.showing<DeskHomePage>(),
                        onTap: () {
                          if (!Desk.nav.showing<DeskHomePage>()) {
                            Desk.nav.open(const DeskHomePage());
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      // ── What to look for ───────────────────────────────
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Desk.raised,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: focused ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _field,
                            focusNode: widget.searchFocus,
                            onChanged: (text) => Desk.query.value = text,
                            textInputAction: TextInputAction.search,
                            style: const TextStyle(fontSize: 14.5, color: Colors.white),
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: 'Cosa vuoi ascoltare?',
                              hintStyle: const TextStyle(fontSize: 14.5, color: Colors.white54),
                              contentPadding: const EdgeInsets.symmetric(vertical: 11),
                              prefixIcon: const Icon(
                                AppIcons.search,
                                size: 22,
                                color: Colors.white70,
                              ),
                              suffixIcon: _field.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Svuota',
                                      iconSize: 18,
                                      color: Colors.white70,
                                      onPressed: () {
                                        _field.clear();
                                        Desk.query.value = '';
                                        widget.searchFocus.requestFocus();
                                      },
                                      icon: const Icon(AppIcons.close),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: DeskIconButton(
                        icon: AppIcons.settings,
                        tooltip: 'Impostazioni',
                        size: 22,
                        filled: true,
                        onTap: widget.onSettings,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
