import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher, PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kreate_ios/main.dart' as phone;
import 'package:kreate_ios/services/audio_handler.dart';
import 'package:kreate_ios/services/auth_service.dart';
import 'package:kreate_ios/services/canvas_service.dart';
import 'package:kreate_ios/services/connect/connect_controller.dart';
import 'package:kreate_ios/services/connect/connect_host.dart';
import 'package:kreate_ios/services/connect/connect_protocol.dart';
import 'package:kreate_ios/services/playback_log_service.dart';
import 'package:kreate_ios/services/storage_service.dart';
import 'package:kreate_ios/ui/theme/app_theme.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'desk/desk.dart';
import 'desk/desk_shell.dart';

/// Totorify for a computer (Windows, Linux).
///
/// The player, the catalog, the library and what the devices say to each
/// other are the phone app's package, which this project depends on. The
/// screens are its own (`desk/`), made for a window, a mouse and a
/// keyboard: the library at the side, the page in the middle, the player
/// at the foot.
void main() {
  runZonedGuarded(_start, (error, stack) {
    PlaybackLogService.instance.error('ZONE', error, stack);
  });
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();
  final log = PlaybackLogService.instance;
  FlutterError.onError = (details) {
    // A cover that fails to load is noise, not a bug: one line, no stack.
    if (details.library == 'image resource service') {
      log.log('IMG', details.exceptionAsString());
    } else {
      log.error('FLUTTER', details.exceptionAsString(), details.stack);
    }
    if (kDebugMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.error('ASYNC', error, stack);
    return true;
  };
  final printToConsole = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && message.isNotEmpty) log.log('DBG', message);
    if (kDebugMode) printToConsole(message, wrapWidth: wrapWidth);
  };

  // The logo on black, at once: it is what the window shows while the app
  // gets ready, and for a moment after, so that it is seen and not flashed.
  runApp(const _Splash());
  final shown = Stopwatch()..start();

  // The player the phone app uses has no implementation for a computer:
  // this one takes its place, and the rest of the code does not notice.
  VideoPlayerMediaKit.ensureInitialized(windows: true, linux: true);

  await log.init();
  await StorageService.instance.init();
  log.log('INIT', 'storage pronto');

  // Signing in with Google is not there on a computer; the account is
  // optional everywhere.
  unawaited(AuthService.instance.init());
  // A Canvas is a vertical video made for a phone's screen.
  CanvasService.instance.isCanvasEnabledNotifier.value = false;

  // No system service to hand the player to: it lives with the window.
  final handler = AudioPlayerHandler();
  phone.audioHandler = handler;
  Desk.handler = handler;
  await handler.setOutputVolume(StorageService.instance.outputVolume);

  // The other devices running Totorify can play instead of this one, and
  // this one for them: it is found on the network, and plays for a device
  // only after the user said yes to it. A computer that has never been
  // asked starts with this on: a laptop taken elsewhere still asks first.
  ConnectHost.kind = ConnectDevice.kindComputer;
  ConnectHost.keepsLibrary = true;
  ConnectHost.defaultName = _computerName();
  if (!StorageService.instance.receivesPlaybackWasChosen) {
    await StorageService.instance.setReceivesPlayback(true);
  }
  ConnectController.instance.attach(handler, name: ConnectHost.deviceName);
  ConnectHost.instance.attach(handler);
  unawaited(ConnectHost.instance.apply());

  log.log('INIT', 'Totorify per computer pronto come "${ConnectHost.deviceName}"');
  final left = _Splash.atLeast - shown.elapsed;
  if (left > Duration.zero) await Future<void>.delayed(left);
  runApp(const TotorifyDesktopApp());
}

String _computerName() {
  try {
    final name = Platform.localHostname.trim();
    if (name.isNotEmpty) return name;
  } catch (e) {
    debugPrint('main._computerName: $e');
  }
  return 'Computer';
}

/// What the window shows while the app starts: the logo, on black.
class _Splash extends StatelessWidget {
  const _Splash();

  /// How long it stays at least.
  static const Duration atLeast = Duration(milliseconds: 1300);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: Colors.black,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          builder: (context, shown, child) => Opacity(
            opacity: shown,
            child: Transform.scale(scale: 0.94 + 0.06 * shown, child: child),
          ),
          // The icon of the app: its white mark, on the black of the window.
          child: Image.asset('assets/images/logo.png', width: 168, height: 168),
        ),
      ),
    ),
  );
}

class TotorifyDesktopApp extends StatefulWidget {
  const TotorifyDesktopApp({super.key});

  @override
  State<TotorifyDesktopApp> createState() => _TotorifyDesktopAppState();
}

class _TotorifyDesktopAppState extends State<TotorifyDesktopApp> {
  bool _isAmoled = StorageService.instance.isAmoledTheme;

  /// The phone app's colors, in the typeface of the computer app.
  ThemeData _theme(Color accent) {
    final base = AppTheme.getTheme(isAmoled: _isAmoled, customAccent: accent);
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: Desk.font),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: Desk.font),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(5),
        ),
        textStyle: const TextStyle(
          fontFamily: Desk.font,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: StorageService.instance.accentColorNotifier,
      builder: (context, accent, _) => MaterialApp(
        title: 'Totorify',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: Desk.messenger,
        scrollBehavior: const _DesktopScrolling(),
        theme: _theme(accent),
        home: DeskShell(
          onThemeChanged: () => setState(() => _isAmoled = StorageService.instance.isAmoledTheme),
        ),
      ),
    );
  }
}

/// Rows of covers are made to be dragged with a finger: with a mouse they
/// are dragged too, besides scrolling with the wheel.
class _DesktopScrolling extends MaterialScrollBehavior {
  const _DesktopScrolling();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
