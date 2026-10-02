import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';
import 'app_controls.dart';
import 'daily_login_rewards.dart';
import 'game_launch.dart';
import 'game.dart'
    show
        gameVibrationEnabled,
        prewarmGameAudio,
        prewarmGameVisuals,
        setGameVibrationEnabled;
import 'game_mode_select.dart';
import 'game_navigation.dart';
import 'oda.dart' as oda;
import 'opponent_name_session.dart';
import 'performance_overlay.dart';
import 'player_progress.dart';
import 'route_activity.dart';
import 'store_cosmetics.dart';
import 'tournament.dart';

final _dailyTaskClock = _DailyTaskClock();
final _inboxNotifications = _InboxNotifications();

class _InboxNotifications extends ChangeNotifier {
  static const _tournamentReadKey = 'inbox.tournament_read_v1';
  static const _welcomeReadKey = 'inbox.welcome_read_v1';

  bool _tournamentUnread = true;
  bool _welcomeUnread = true;

  bool get tournamentUnread => _tournamentUnread;
  bool get welcomeUnread => _welcomeUnread;
  int get unreadCount => (_tournamentUnread ? 1 : 0) + (_welcomeUnread ? 1 : 0);

  Future<void> load() async {
    try {
      final preferences = SharedPreferencesAsync();
      _tournamentUnread = await preferences.getBool(_tournamentReadKey) != true;
      _welcomeUnread = await preferences.getBool(_welcomeReadKey) != true;
    } catch (_) {
      // Depolama kullanılamazsa mevcut oturumdaki okunma durumu korunur.
    }
    notifyListeners();
  }

  Future<void> markTournamentRead() async {
    if (!_tournamentUnread) return;
    _tournamentUnread = false;
    notifyListeners();
    try {
      await SharedPreferencesAsync().setBool(_tournamentReadKey, true);
    } catch (_) {}
  }

  Future<void> markWelcomeRead() async {
    if (!_welcomeUnread) return;
    _welcomeUnread = false;
    notifyListeners();
    try {
      await SharedPreferencesAsync().setBool(_welcomeReadKey, true);
    } catch (_) {}
  }
}

class _DailyTaskClock extends ChangeNotifier {
  static const _deadlineKey = 'tasks.deadline_ms';
  static const _cycleDuration = Duration(hours: 24);

  DateTime? _deadline;
  Timer? _rolloverTimer;
  Future<void>? _initializing;

  Future<void> initialize() => _initializing ??= _load();

  Future<void> _load() async {
    final now = DateTime.now();
    DateTime? deadline;
    try {
      final saved = await SharedPreferencesAsync().getInt(_deadlineKey);
      if (saved != null) {
        deadline = DateTime.fromMillisecondsSinceEpoch(saved);
      }
    } catch (_) {
      // Test veya geçici depolama erişimi olmadığında sayaç bellekte çalışır.
    }
    var effectiveDeadline = deadline ?? now.add(_cycleDuration);
    while (!effectiveDeadline.isAfter(now)) {
      effectiveDeadline = effectiveDeadline.add(_cycleDuration);
    }
    _deadline = effectiveDeadline;
    await _persist();
    _scheduleRollover();
    notifyListeners();
  }

  Future<void> _persist() async {
    final deadline = _deadline;
    if (deadline == null) return;
    try {
      await SharedPreferencesAsync().setInt(
        _deadlineKey,
        deadline.millisecondsSinceEpoch,
      );
    } catch (_) {
      // Sayaç depolama olmasa da mevcut oturumda çalışmaya devam eder.
    }
  }

  void _scheduleRollover() {
    _rolloverTimer?.cancel();
    final deadline = _deadline;
    if (deadline == null) return;
    final delay = deadline.difference(DateTime.now());
    _rolloverTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      var next = _deadline ?? DateTime.now();
      final now = DateTime.now();
      do {
        next = next.add(_cycleDuration);
      } while (!next.isAfter(now));
      _deadline = next;
      _persist();
      _scheduleRollover();
      notifyListeners();
    });
  }

  String get remainingText {
    final deadline = _deadline;
    if (deadline == null) return '--:--:--';
    final seconds = deadline
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, _cycleDuration.inSeconds);
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Büyük arka planlar ve masa görselleri arasında dolaşırken Flutter'ın resim
  // önbelleğinin oturum boyunca büyümesini sınırla. Sık kullanılan oyun
  // görselleri için 6 MB alan bırakırken RAM kullanımını sabit tutar.
  PaintingBinding.instance.imageCache
    ..maximumSize = 12
    ..maximumSizeBytes = 6 * 1024 * 1024;
  await Future.wait([
    playerProgress.load(),
    storeCosmetics.load(),
    _dailyTaskClock.initialize(),
    appLanguage.load(),
    dailyLogin.load(),
    _inboxNotifications.load(),
    initializeTournamentCycle(),
  ]);
  _appSettings.value = _appSettings.value.copyWith(language: appLanguage.value);
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const OkeyApp());
}

// ─── Renk Paleti ───────────────────────────────────────────────────────────────
class OkeyColors {
  static const Color tableMid = Color(0xFF1A3A2A);
  static const Color tableDark = Color(0xFF0F2219);
  static const Color tableLight = Color(0xFF245235);
  static const Color gold = Color(0xFFD4A017);
  static const Color goldLight = Color(0xFFF0CC5A);
  static const Color goldDark = Color(0xFF9A7010);
  static const Color cream = Color(0xFFF5EDD6);
  static const Color creamDark = Color(0xFFD9C9A0);
  static const Color buttonBrown = Color(0xFF5C3A1E);
  static const Color buttonBorder = Color(0xFF8B5E2A);
  static const Color redTile = Color(0xFFCC2222);
  static const Color blueTile = Color(0xFF1A3A8A);
  static const Color blackTile = Color(0xFF1A1A1A);
  static const Color yellowTile = Color(0xFFCC8800);
}

final ValueNotifier<_MenuSettings> _appSettings = ValueNotifier(
  const _MenuSettings(),
);

// ─── Ana Uygulama ─────────────────────────────────────────────────────────────
class OkeyApp extends StatelessWidget {
  final Widget? home;
  const OkeyApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '101 Okey',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [appRouteObserver],
      theme: ThemeData(
        fontFamily: 'Georgia',
        scaffoldBackgroundColor: OkeyColors.tableDark,
      ),
      builder: (context, child) {
        return ValueListenableBuilder<_MenuSettings>(
          valueListenable: _appSettings,
          child: child,
          builder: (context, settings, appChild) {
            final mediaQuery = MediaQuery.of(context);
            final content = MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(settings.fontScale),
              ),
              child: appChild ?? const SizedBox.shrink(),
            );
            return ValueListenableBuilder<bool>(
              valueListenable: performanceOverlayEnabled,
              child: content,
              builder: (_, enabled, overlayChild) => enabled
                  ? AppPerformanceOverlay(child: overlayChild!)
                  : overlayChild!,
            );
          },
        );
      },
      home: home ?? const SplashScreen(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPLASH EKRANI
// ═══════════════════════════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _shimmerController;
  late AnimationController _fadeController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _shimmerAnim;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ).drive(Tween<double>(begin: 0.3, end: 1.0));
    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeIn,
    ).drive(Tween<double>(begin: 0.0, end: 1.0));

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _shimmerAnim = _shimmerController.drive(
      Tween<double>(begin: -1.0, end: 2.0),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeOut = _fadeController.drive(Tween<double>(begin: 1.0, end: 0.0));

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 1800));
    await _fadeController.forward();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) =>
              const ActiveRouteScene(child: MainMenuScreen()),
          transitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _shimmerController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeOut,
      builder: (context, child) =>
          Opacity(opacity: _fadeOut.value, child: child),
      child: Scaffold(
        backgroundColor: OkeyColors.tableDark,
        body: Stack(
          children: [
            const _TablePattern(),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 320,
                  height: 500,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _logoController,
                          _shimmerController,
                        ]),
                        builder: (context, _) => Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: _OkeyTileGroup(progress: _shimmerAnim.value),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _logoController,
                          _shimmerController,
                        ]),
                        builder: (context, _) => Opacity(
                          opacity: _logoOpacity.value,
                          child: _ShimmerText(
                            shimmerProgress: _shimmerAnim.value,
                            text: '101',
                            subText: 'OKEY',
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, _) => Opacity(
                          opacity: _logoOpacity.value.clamp(0, 1),
                          child: const _LoadingDots(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Masa Desen Arkaplanı ─────────────────────────────────────────────────────
class _TablePattern extends StatelessWidget {
  const _TablePattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _TablePatternPainter(),
    );
  }
}

class _TablePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintBg = Paint()..color = OkeyColors.tableDark;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paintBg);

    final paintRing = Paint()
      ..color = OkeyColors.tableLight.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final cx = size.width / 2;
    final cy = size.height / 2;
    for (double r = 60; r < size.width * 1.2; r += 55) {
      canvas.drawCircle(Offset(cx, cy), r, paintRing);
    }

    final paintCorner = Paint()
      ..color = OkeyColors.gold.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    const inset = 24.0;
    const rr = 20.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          inset,
          inset,
          size.width - inset * 2,
          size.height - inset * 2,
        ),
        const Radius.circular(rr),
      ),
      paintCorner,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Okey Taş Grubu (Splash) ──────────────────────────────────────────────────
class _OkeyTileGroup extends StatelessWidget {
  final double progress;

  const _OkeyTileGroup({required this.progress});

  @override
  Widget build(BuildContext context) {
    final wave = sin(progress * pi * 2 / 3);
    return SizedBox(
      width: 200,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            top: 10,
            child: Transform.translate(
              offset: Offset(0, wave * 5),
              child: Transform.rotate(
                angle: -0.25 - wave * 0.045,
                child: _buildTile(OkeyColors.blueTile, '5', shadow: true),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 10,
            child: Transform.translate(
              offset: Offset(0, -wave * 5),
              child: Transform.rotate(
                angle: 0.25 + wave * 0.045,
                child: _buildTile(OkeyColors.redTile, '7', shadow: true),
              ),
            ),
          ),
          Center(
            child: Transform.scale(
              scale: 1 + wave.abs() * 0.045,
              child: _buildJokerTile(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(Color color, String number, {bool shadow = false}) {
    return Container(
      width: 58,
      height: 78,
      decoration: BoxDecoration(
        color: OkeyColors.cream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OkeyColors.creamDark, width: 2),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(2, 4),
                ),
              ]
            : [],
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'Georgia',
          ),
        ),
      ),
    );
  }

  Widget _buildJokerTile() {
    return Container(
      width: 68,
      height: 90,
      decoration: BoxDecoration(
        color: OkeyColors.cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OkeyColors.gold, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: OkeyColors.gold.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('★', style: TextStyle(color: OkeyColors.gold, fontSize: 26)),
          Text(
            'OK',
            style: TextStyle(
              color: OkeyColors.blackTile,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Parıltılı Logo Yazısı ────────────────────────────────────────────────────
class _ShimmerText extends StatelessWidget {
  final double shimmerProgress;
  final String text;
  final String subText;

  const _ShimmerText({
    required this.shimmerProgress,
    required this.text,
    required this.subText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [
              (shimmerProgress - 0.3).clamp(0.0, 1.0),
              shimmerProgress.clamp(0.0, 1.0),
              (shimmerProgress + 0.3).clamp(0.0, 1.0),
            ],
            colors: [OkeyColors.gold, OkeyColors.goldLight, OkeyColors.gold],
          ).createShader(bounds),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 80,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
              letterSpacing: 8,
              height: 1.0,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: OkeyColors.gold, width: 1.5),
              bottom: BorderSide(color: OkeyColors.gold, width: 1.5),
            ),
          ),
          child: Text(
            subText,
            style: const TextStyle(
              color: OkeyColors.goldLight,
              fontSize: 22,
              letterSpacing: 12,
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Yükleniyor Noktaları ─────────────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = (((_ctrl.value - delay) % 1.0 + 1.0) % 1.0);
            final opacity = (sin(t * pi)).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: OkeyColors.gold.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANA MENÜ EKRANI — Görsel referansa göre: Landscape layout
//   Sol üst: Seviye rozeti + Profil chip
//   Sağ üst: Coin + İkon butonları
//   Orta: Büyük 101 OKEY logosu + 3 taş + HEMEN OYNA
//   Sağ sütun: ODA SEÇ / ÖZEL MASA / TURNUVALAR / ARKADAŞLAR
// ═══════════════════════════════════════════════════════════════════════════════
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late AnimationController _walletRewardCtrl;
  late Animation<double> _fadeIn;
  late _MenuSettings _settings;
  int _walletAnimationFrom = 0;
  int _walletAnimationTo = 0;
  int _walletRewardGain = 0;
  bool _navigating = false;
  bool _visualsPrewarmed = false;

  @override
  void initState() {
    super.initState();
    _settings = _appSettings.value.copyWith(language: appLanguage.value);
    _walletAnimationFrom = playerProgress.coins;
    _walletAnimationTo = playerProgress.coins;
    _enterCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(
      parent: _enterCtrl,
      curve: Curves.easeOut,
    ).drive(Tween<double>(begin: 0.0, end: 1.0));
    _enterCtrl.forward();
    _walletRewardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    unawaited(_inboxNotifications.load());
    prewarmGameAudio();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_visualsPrewarmed) return;
    _visualsPrewarmed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (mounted && !_navigating) prewarmGameVisuals(context);
      });
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _walletRewardCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigateToGame([
    GameLaunchConfig config = const GameLaunchConfig.quickPlay(),
  ]) async {
    await _withPausedScene(() async {
      await Future.wait<void>([
        prewarmGameAudio(),
        prewarmGameVisuals(context),
      ]);
      if (!mounted) return;
      await openGameScreen<void>(context, config: config);
      opponentNameSession.reset();
    });
  }

  Future<void> _withPausedScene(Future<dynamic> Function() navigation) async {
    if (_navigating) return;
    setState(() => _navigating = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await navigation();
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  Future<void> _navigateToRoomSelect() async {
    await _withPausedScene(
      () => Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) =>
              const ActiveRouteScene(child: oda.RoomSelectScreen()),
          transitionDuration: const Duration(milliseconds: 120),
          transitionsBuilder: (_, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.035, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        ),
      ),
    );
    opponentNameSession.reset();
  }

  Future<void> _navigateToGameModeSelect() async {
    await _withPausedScene(
      () => Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) =>
              const ActiveRouteScene(child: GameModeSelectScreen()),
          transitionDuration: const Duration(milliseconds: 120),
          transitionsBuilder: (_, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.035, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        ),
      ),
    );
    opponentNameSession.reset();
  }

  Future<void> _navigateToTournament() async {
    await _withPausedScene(
      () => Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) =>
              const ActiveRouteScene(child: TournamentScreen()),
          transitionDuration: const Duration(milliseconds: 120),
          transitionsBuilder: (_, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.035, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        ),
      ),
    );
    opponentNameSession.reset();
  }

  Future<void> _navigateToStore() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    try {
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) =>
              const ActiveRouteScene(child: _StoreScreen()),
          transitionDuration: const Duration(milliseconds: 120),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  Future<void> _openFeaturePopup({
    required IconData icon,
    required String title,
    required String description,
    ValueChanged<String>? onEntryTap,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '$title penceresini kapat',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, _, _) => _FeatureDialog(
        icon: icon,
        title: title,
        description: description,
        onEntryTap: onEntryTap,
      ),
      transitionBuilder: (_, animation, _, child) {
        final scale = animation.drive(
          TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(begin: 1.05, end: 0.988),
              weight: 52,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 0.988, end: 1.008),
              weight: 28,
            ),
            TweenSequenceItem(tween: Tween(begin: 1.008, end: 1), weight: 20),
          ]),
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }

  Future<void> _openDailyReward() async {
    final balanceBefore = playerProgress.coins;
    await _openFeaturePopup(
      icon: Icons.card_giftcard_rounded,
      title: 'GÜNLÜK GİRİŞ ÖDÜLÜ',
      description:
          'Her gün giriş yaparak jeton ve özel ödüller kazanabilirsin.',
    );
    if (!mounted) return;
    final balanceAfter = playerProgress.coins;
    if (balanceAfter <= balanceBefore) return;
    setState(() {
      _walletAnimationFrom = balanceBefore;
      _walletAnimationTo = balanceAfter;
      _walletRewardGain = balanceAfter - balanceBefore;
    });
    await _walletRewardCtrl.forward(from: 0);
  }

  Future<void> _openProfile() => _openFeaturePopup(
    icon: Icons.person_rounded,
    title: 'PROFİLİM',
    description: 'Oyuncu bilgilerin, seviyen, başarıların ve istatistiklerin burada gösterilecek.',
  );

  Future<void> _openInbox() async {
    String? selectedEntry;
    await _openFeaturePopup(
      icon: Icons.mail_rounded,
      title: 'GELEN KUTUSU',
      description:
          'Sistem mesajların ve ödül bildirimlerin burada gösterilecek.',
      onEntryTap: (entry) {
        selectedEntry = entry;
        if (entry.startsWith('Turnuva')) {
          unawaited(_inboxNotifications.markTournamentRead());
        } else if (entry.startsWith('Hoş geldin')) {
          unawaited(_inboxNotifications.markWelcomeRead());
        }
        Navigator.of(context).pop();
      },
    );
    if (!mounted || selectedEntry == null) return;
    if (selectedEntry!.startsWith('Günlük')) {
      await _openDailyReward();
    } else if (selectedEntry!.startsWith('Turnuva')) {
      await _navigateToTournament();
    } else if (selectedEntry!.startsWith('Hoş geldin')) {
      await _openProfile();
    }
  }

  void _showWalletComingSoon() {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF123C2E),
          content: Text(
            appText(
              'Cüzdan yapım aşamasında.',
              'Wallet is under construction.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OkeyColors.cream,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
  }

  Future<void> _openSettings() async {
    final updatedSettings = await showGeneralDialog<_MenuSettings>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Ayarları kapat',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => _SettingsDialog(
        initial: _settings.copyWith(
          showPerformance: performanceOverlayEnabled.value,
          vibration: gameVibrationEnabled,
        ),
      ),
      transitionBuilder: (_, animation, _, child) {
        final scale = animation.drive(
          TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(begin: 1.05, end: 0.988),
              weight: 52,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 0.988, end: 1.008),
              weight: 28,
            ),
            TweenSequenceItem(tween: Tween(begin: 1.008, end: 1), weight: 20),
          ]),
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );

    if (updatedSettings != null && mounted) {
      setState(() => _settings = updatedSettings);
      _appSettings.value = updatedSettings;
      setGameVibrationEnabled(updatedSettings.vibration);
      performanceOverlayEnabled.value = updatedSettings.showPerformance;
      await appLanguage.setLanguage(updatedSettings.language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inheritedTheme = Theme.of(context);
    final homeTheme = inheritedTheme.copyWith(
      textTheme: inheritedTheme.textTheme.apply(fontFamily: 'Baloo 2'),
      primaryTextTheme: inheritedTheme.primaryTextTheme.apply(
        fontFamily: 'Baloo 2',
      ),
    );
    return Theme(
      data: homeTheme,
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          fontFamily: 'Baloo 2',
          fontWeight: FontWeight.w800,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.black, offset: Offset(-0.8, 0), blurRadius: 1),
            Shadow(color: Colors.black, offset: Offset(0.8, 0), blurRadius: 1),
            Shadow(color: Colors.black, offset: Offset(0, -0.8), blurRadius: 1),
            Shadow(color: Colors.black, offset: Offset(0, 0.8), blurRadius: 1),
          ],
        ),
        child: Scaffold(
          backgroundColor: OkeyColors.tableDark,
          body: TickerMode(
            enabled: !_navigating,
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: Image.asset(
                      'images/anamenu/menubg.png',
                      fit: BoxFit.cover,
                      cacheWidth: 1440,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.18),
                        radius: 1.08,
                        colors: [
                          const Color(0xFF08763E).withValues(alpha: 0.12),
                          const Color(0xFF001B10).withValues(alpha: 0.42),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(child: _HomeTableFrame()),
                SafeArea(
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: 1100,
                          height: 500,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: _HomeTileDecorations(
                                  enabled: _settings.homeEdgeTiles,
                                ),
                              ),
                              Positioned(
                                top: 16,
                                left: 20,
                                child: _ProfileChip(onTap: _openProfile),
                              ),
                              Positioned(
                                top: 18,
                                right: 20,
                                child: AnimatedBuilder(
                                  animation: _walletRewardCtrl,
                                  builder: (context, _) {
                                    final progress = Curves.easeOutCubic
                                        .transform(_walletRewardCtrl.value);
                                    final animatedBalance =
                                        _walletAnimationFrom +
                                        ((_walletAnimationTo -
                                                    _walletAnimationFrom) *
                                                progress)
                                            .round();
                                    return _TopRightBar(
                                      coinBalance: animatedBalance,
                                      onSettings: _openSettings,
                                      onStore: _navigateToStore,
                                      onWallet: _showWalletComingSoon,
                                      onMessages: _openInbox,
                                    );
                                  },
                                ),
                              ),
                              if (_walletRewardGain > 0)
                                Positioned(
                                  top: 69,
                                  right: 304,
                                  child: AnimatedBuilder(
                                    animation: _walletRewardCtrl,
                                    builder: (context, child) {
                                      final value = _walletRewardCtrl.value;
                                      return Transform.translate(
                                        offset: Offset(0, -18 * value),
                                        child: Opacity(
                                          opacity: sin(pi * value)
                                              .clamp(0.0, 1.0),
                                          child: Transform.scale(
                                            scale:
                                                0.88 + 0.22 * sin(pi * value),
                                            child: child,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      key: const ValueKey(
                                        'main-wallet-reward-animation',
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0A3A24),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: OkeyColors.goldLight,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black54,
                                            blurRadius: 7,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '+${formatGameNumber(_walletRewardGain)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Baloo 2',
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 20,
                                top: 116,
                                child: _DailyRewardButton(
                                  onTap: _openDailyReward,
                                ),
                              ),
                              const Positioned(
                                left: 145,
                                top: 118,
                                child: _HomeLogoArtwork(),
                              ),
                              Positioned(
                                right: 20,
                                top: 170,
                                width: 444,
                                child: Column(
                                  children: [
                                    _RightButtonColumn(
                                      onSelectRoom: _navigateToRoomSelect,
                                      onSelectMode: _navigateToGameModeSelect,
                                      onTournament: _navigateToTournament,
                                      onOpen: (icon, title, description) =>
                                          _openFeaturePopup(
                                            icon: icon,
                                            title: title,
                                            description: description,
                                          ),
                                    ),
                                    const SizedBox(height: 28),
                                    _HemenOynaButton(
                                      onTap: () => _navigateToGame(),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTableFrame extends StatelessWidget {
  const _HomeTableFrame();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        height: 44,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE4A64E), width: 1.5)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFA9682F), Color(0xFF6E3B18), Color(0xFF3B1E0C)],
          ),
        ),
      ),
    ),
  );
}

class _HomeTileDecorations extends StatelessWidget {
  final bool enabled;
  const _HomeTileDecorations({required this.enabled});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -60,
              top: 250,
              child: Transform.rotate(
                angle: -0.56,
                child: Image.asset(
                  'images/store/tiles/tile0.png',
                  width: 142,
                  height: 104,
                  fit: BoxFit.contain,
                  color: Colors.white.withValues(alpha: 0.34),
                  colorBlendMode: BlendMode.modulate,
                  cacheWidth: 260,
                  cacheHeight: 190,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
            Positioned(
              right: -60,
              top: 142,
              child: Transform.rotate(
                angle: 0.56,
                child: Image.asset(
                  'images/store/tiles/tile0.png',
                  width: 142,
                  height: 104,
                  fit: BoxFit.contain,
                  color: Colors.white.withValues(alpha: 0.34),
                  colorBlendMode: BlendMode.modulate,
                  cacheWidth: 260,
                  cacheHeight: 190,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyRewardButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DailyRewardButton({required this.onTap});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: dailyLogin,
    builder: (context, _) => GestureDetector(
      key: const ValueKey('daily-reward-button'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 90,
        height: 90,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF17351F).withValues(alpha: 0.9),
                border: Border.all(color: OkeyColors.goldLight, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 7,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Image.asset(
                'images/ui/icons/gunluk_odul_opt.png',
                width: 48,
                height: 58,
                cacheWidth: 96,
                cacheHeight: 96,
                filterQuality: FilterQuality.medium,
              ),
            ),
            if (dailyLogin.canClaimToday)
              Positioned(
                top: 4,
                right: 3,
                child: Container(
                  key: const ValueKey('daily-reward-badge'),
                  width: 19,
                  height: 19,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF2A2A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _StoreItem {
  final String id;
  final String name;
  final String subtitle;
  final String asset;
  final Color? color;
  final int price;

  const _StoreItem({
    required this.id,
    required this.name,
    required this.subtitle,
    this.asset = '',
    this.color,
    required this.price,
  });
}

const _storeRacks = [
  _StoreItem(
    id: 'rack0',
    name: 'KLASİK AHŞAP',
    subtitle: 'Sıcak ceviz dokusu',
    asset: 'images/store/racks/rack0.png',
    price: 0,
  ),
  _StoreItem(
    id: 'rack1',
    name: 'KOYU CEVİZ',
    subtitle: 'Koyu ve sade görünüm',
    asset: 'images/store/racks/rack1.png',
    price: 2500,
  ),
  _StoreItem(
    id: 'rack2',
    name: 'BAL RENGİ',
    subtitle: 'Parlak ahşap yüzey',
    asset: 'images/store/racks/rack2.png',
    price: 3500,
  ),
  _StoreItem(
    id: 'rack3',
    name: 'GECE',
    subtitle: 'Derin siyah kaplama',
    asset: 'images/store/racks/rack3.png',
    price: 5000,
  ),
  _StoreItem(
    id: 'rack4',
    name: 'USTA SERİSİ',
    subtitle: 'Özel masa koleksiyonu',
    asset: 'images/store/racks/rack4.png',
    price: 7500,
  ),
];

const _storeTiles = [
  _StoreItem(
    id: 'tile0',
    name: 'KLASİK TAŞ',
    subtitle: 'Geleneksel 101 görünümü',
    asset: 'images/store/tiles/tile0.png',
    price: 0,
  ),
  _StoreItem(
    id: 'tile1',
    name: 'YUMUŞAK KÖŞE',
    subtitle: 'Pastel ve yuvarlak hatlar',
    asset: 'images/store/tiles/tile1.png',
    price: 2000,
  ),
  _StoreItem(
    id: 'tile2',
    name: 'MODERN',
    subtitle: 'Net sayı ve güçlü renk',
    asset: 'images/store/tiles/tile2.png',
    price: 3000,
  ),
  _StoreItem(
    id: 'tile3',
    name: 'GECE TAŞI',
    subtitle: 'Koyu masa için özel set',
    asset: 'images/store/tiles/tile3.png',
    price: 4500,
  ),
  _StoreItem(
    id: 'tile4',
    name: 'ALTIN SERİ',
    subtitle: 'Premium turnuva seti',
    asset: 'images/store/tiles/tile4.png',
    price: 6500,
  ),
];

const _storeBackgrounds = [
  _StoreItem(
    id: 'bg_menu',
    name: 'ANA MENÜ',
    subtitle: 'Ana sayfanın özel masa deseni',
    asset: 'images/anamenu/menubg.png',
    price: 4500,
  ),
  _StoreItem(
    id: 'bg24',
    name: 'GECE MAVİSİ',
    subtitle: 'Sakin ve koyu masa',
    asset: 'images/store/backgrounds/bg24.jpg',
    price: 0,
  ),
  _StoreItem(
    id: 'bg25',
    name: 'MOR SALON',
    subtitle: 'Yumuşak mor desen',
    asset: 'images/store/backgrounds/bg25.jpg',
    price: 1800,
  ),
  _StoreItem(
    id: 'bg26',
    name: 'BORDO KLASİK',
    subtitle: 'Klasik oyun salonu',
    asset: 'images/store/backgrounds/bg26.jpg',
    price: 2400,
  ),
  _StoreItem(
    id: 'bg27',
    name: 'TURKUAZ',
    subtitle: 'Canlı keçe dokusu',
    asset: 'images/store/backgrounds/bg27.jpg',
    price: 3200,
  ),
  _StoreItem(
    id: 'bg28',
    name: 'BUZ MAVİSİ',
    subtitle: 'Modern geometrik desen',
    asset: 'images/store/backgrounds/bg28.jpg',
    price: 4000,
  ),
  _StoreItem(
    id: 'bg29',
    name: 'KIZIL GECE',
    subtitle: 'Koyu kırmızı salon',
    asset: 'images/store/backgrounds/bg29.jpg',
    price: 5200,
  ),
  _StoreItem(
    id: 'bg30',
    name: 'ALTIN SARAY',
    subtitle: 'Premium işlemeli yüzey',
    asset: 'images/store/backgrounds/bg30.jpg',
    price: 7000,
  ),
  _StoreItem(
    id: 'solid_green',
    name: 'DÜZ YEŞİL',
    subtitle: 'Sade koyu yeşil masa',
    color: Color(0xFF075733),
    price: 1200,
  ),
  _StoreItem(
    id: 'solid_blue',
    name: 'DÜZ LACİVERT',
    subtitle: 'Sade lacivert masa',
    color: Color(0xFF123D5A),
    price: 1200,
  ),
  _StoreItem(
    id: 'solid_burgundy',
    name: 'DÜZ BORDO',
    subtitle: 'Sade bordo masa',
    color: Color(0xFF54252B),
    price: 1200,
  ),
  _StoreItem(
    id: 'solid_black',
    name: 'DÜZ SİYAH',
    subtitle: 'Sade antrasit masa',
    color: Color(0xFF151917),
    price: 1200,
  ),
];

class _StoreScreen extends StatefulWidget {
  const _StoreScreen();

  @override
  State<_StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<_StoreScreen> {
  int _selectedTab = 0;

  List<_StoreItem> _itemsForTab(int index) => switch (index) {
    0 => _storeRacks,
    1 => _storeTiles,
    _ => _storeBackgrounds,
  };

  void _evictPreviews(Iterable<_StoreItem> items) {
    for (final item in items) {
      if (item.asset.isEmpty) continue;
      PaintingBinding.instance.imageCache.evict(
        ResizeImage(AssetImage(item.asset), width: 220),
      );
    }
  }

  void _changeTab(int index) {
    if (index == _selectedTab) return;
    _evictPreviews(_itemsForTab(_selectedTab));
    setState(() => _selectedTab = index);
  }

  @override
  void dispose() {
    // Mağaza kartları yalnız bu sahnede kullanılır. Oyun sahnesine geçerken
    // küçük önizleme bitmaplerini önbellekte tutmayarak RAM ve GPU texture
    // belleğini seçilen gerçek oyun görsellerine bırak.
    _evictPreviews([..._storeRacks, ..._storeTiles, ..._storeBackgrounds]);
    unawaited(requestMemoryTrim());
    super.dispose();
  }

  void _selectOrBuy(_StoreItem item, CosmeticKind kind) {
    if (!storeCosmetics.owns(kind, item.id) &&
        !playerProgress.trySpendCoins(item.price)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu ürün için yeterli altının yok.')),
      );
      return;
    }
    storeCosmetics.unlockAndSelect(kind, item.id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      key: const ValueKey('store-screen'),
      backgroundColor: OkeyColors.tableDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'images/anamenu/menubg.png',
              fit: BoxFit.cover,
              cacheWidth: 960,
              filterQuality: FilterQuality.low,
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.30)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      AppBackButton(onTap: () => Navigator.of(context).pop()),
                      const SizedBox(width: 12),
                      const Text(
                        'MAĞAZA',
                        style: TextStyle(
                          color: OkeyColors.goldLight,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Georgia',
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Spacer(),
                      AnimatedBuilder(
                        animation: playerProgress,
                        builder: (context, _) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: OkeyColors.gold),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'images/ui/coin.png',
                                width: 19,
                                height: 19,
                                cacheWidth: 38,
                                cacheHeight: 38,
                                filterQuality: FilterQuality.low,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                formatGameNumber(playerProgress.coins),
                                style: const TextStyle(
                                  color: OkeyColors.cream,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 540,
                    height: 42,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: OkeyColors.gold.withValues(alpha: 0.65),
                      ),
                    ),
                    child: TabBar(
                      onTap: _changeTab,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: OkeyColors.goldDark,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white60,
                      labelStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                      tabs: const [
                        Tab(
                          key: ValueKey('store-racks-tab'),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Text('ISTAKALAR')],
                            ),
                          ),
                        ),
                        Tab(
                          key: ValueKey('store-tiles-tab'),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Text('TAŞLAR')],
                            ),
                          ),
                        ),
                        Tab(
                          key: ValueKey('store-backgrounds-tab'),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Text('ARKA PLAN')],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: switch (_selectedTab) {
                      0 => _StoreItemList(
                        key: const ValueKey('store-racks-list'),
                        items: _storeRacks,
                        ownedIds: storeCosmetics.owned(CosmeticKind.rack),
                        selectedId: storeCosmetics.selected(CosmeticKind.rack),
                        onPressed: (item) =>
                            _selectOrBuy(item, CosmeticKind.rack),
                      ),
                      1 => _StoreItemList(
                        key: const ValueKey('store-tiles-list'),
                        items: _storeTiles,
                        ownedIds: storeCosmetics.owned(CosmeticKind.tile),
                        selectedId: storeCosmetics.selected(CosmeticKind.tile),
                        onPressed: (item) =>
                            _selectOrBuy(item, CosmeticKind.tile),
                      ),
                      _ => _StoreItemList(
                        key: const ValueKey('store-backgrounds-list'),
                        items: _storeBackgrounds,
                        ownedIds: storeCosmetics.owned(CosmeticKind.background),
                        selectedId: storeCosmetics.selected(
                          CosmeticKind.background,
                        ),
                        onPressed: (item) =>
                            _selectOrBuy(item, CosmeticKind.background),
                      ),
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StoreItemList extends StatelessWidget {
  final List<_StoreItem> items;
  final Set<String> ownedIds;
  final String selectedId;
  final ValueChanged<_StoreItem> onPressed;

  const _StoreItemList({
    super.key,
    required this.items,
    required this.ownedIds,
    required this.selectedId,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cardWidth = box.maxWidth >= 1100
          ? (box.maxWidth - 48) / 5
          : box.maxWidth >= 760
          ? (box.maxWidth - 30) / 3.4
          : (box.maxWidth - 16) / 2.25;
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: cardWidth.clamp(175.0, 250.0),
            child: _StoreItemCard(
              item: item,
              owned: ownedIds.contains(item.id),
              selected: selectedId == item.id,
              onPressed: () => onPressed(item),
            ),
          );
        },
      );
    },
  );
}

class _StoreItemCard extends StatelessWidget {
  final _StoreItem item;
  final bool owned;
  final bool selected;
  final VoidCallback onPressed;

  const _StoreItemCard({
    required this.item,
    required this.owned,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: const Color(0xEE102C22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? OkeyColors.goldLight : const Color(0xFF466652),
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: item.color != null
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              item.asset,
                              fit: BoxFit.contain,
                              cacheWidth: 220,
                              filterQuality: FilterQuality.low,
                            ),
                          ),
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: _SelectedStoreBadge(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: FilledButton(
              key: ValueKey('store-action-${item.id}'),
              onPressed: selected ? null : onPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                backgroundColor: owned
                    ? const Color(0xFF3F7C43)
                    : OkeyColors.buttonBrown,
                disabledBackgroundColor: OkeyColors.goldDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                  side: const BorderSide(color: OkeyColors.gold),
                ),
              ),
              child: owned
                  ? Text(selected ? 'SEÇİLİ' : 'KULLAN')
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'images/ui/coin.png',
                          width: 15,
                          height: 15,
                          cacheWidth: 30,
                          cacheHeight: 30,
                        ),
                        const SizedBox(width: 5),
                        Text(formatGameNumber(item.price)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SelectedStoreBadge extends StatelessWidget {
  const _SelectedStoreBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: OkeyColors.goldDark,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: OkeyColors.goldLight),
    ),
    child: const Text(
      'AKTİF',
      style: TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

// ─── Sol Üst Profil Chip ──────────────────────────────────────────────────────
class _ProfileChip extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playerProgress,
      builder: (context, _) => GestureDetector(
        key: const ValueKey('main-xp-chip'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 286,
          height: 96,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                left: 48,
                top: 5,
                right: 0,
                bottom: 5,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(48, 5, 14, 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.84),
                        const Color(0xFF043A20).withValues(alpha: 0.82),
                      ],
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(34),
                    ),
                    border: Border.all(
                      color: OkeyColors.gold.withValues(alpha: 0.24),
                    ),
                  ),
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 168,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              playerProgress.playerName,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                height: 1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Image.asset(
                              'images/ui/home/level_icon.png',
                              width: 17,
                              height: 17,
                              cacheWidth: 32,
                              cacheHeight: 32,
                              filterQuality: FilterQuality.low,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${playerProgress.title} • SV. ${playerProgress.level}',
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: OkeyColors.goldLight,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: playerProgress.isMaxLevel
                                      ? 1
                                      : playerProgress.levelProgress,
                                  minHeight: 9,
                                  color: OkeyColors.goldLight,
                                  backgroundColor: const Color(0xFF28352B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              playerProgress.isMaxLevel
                                  ? 'MAKS.'
                                  : '${playerProgress.levelXp} / ${playerProgress.xpForNextLevel} XP',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'images/ui/home/avatar_frame.png',
                      width: 94,
                      height: 94,
                      cacheWidth: 144,
                      cacheHeight: 148,
                      filterQuality: FilterQuality.low,
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: OkeyColors.goldLight,
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        playerProgress.playerAvatarAsset,
                        fit: BoxFit.cover,
                        cacheWidth: 96,
                        cacheHeight: 96,
                        filterQuality: FilterQuality.low,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopRightBar extends StatelessWidget {
  final int coinBalance;
  final VoidCallback onSettings;
  final VoidCallback onStore;
  final VoidCallback onWallet;
  final VoidCallback onMessages;
  const _TopRightBar({
    required this.coinBalance,
    required this.onSettings,
    required this.onStore,
    required this.onWallet,
    required this.onMessages,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        playerProgress,
        dailyLogin,
        _inboxNotifications,
      ]),
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            key: const ValueKey('main-wallet-button'),
            onTap: onWallet,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 190,
              height: 54,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'images/ui/home/gold_bar.png',
                      fit: BoxFit.fill,
                      cacheWidth: 336,
                      cacheHeight: 64,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                  Positioned(
                    left: 5,
                    child: Image.asset(
                      'images/ui/home/gold_icon.png',
                      width: 43,
                      height: 45,
                      cacheWidth: 80,
                      cacheHeight: 88,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                  Positioned(
                    left: 52,
                    right: 37,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatGameNumber(coinBalance),
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 42,
            margin: const EdgeInsets.symmetric(horizontal: 13),
            color: OkeyColors.goldLight.withValues(alpha: 0.65),
          ),
          _IconBtn(
            key: const ValueKey('main-store-button'),
            icon: Icons.shopping_cart_rounded,
            onTap: onStore,
          ),
          const SizedBox(width: 13),
          _IconBtn(
            icon: Icons.mail_outlined,
            displayIcon: Icons.notifications_rounded,
            badgeCount:
                _inboxNotifications.unreadCount +
                (dailyLogin.canClaimToday ? 1 : 0),
            onTap: onMessages,
          ),
          const SizedBox(width: 13),
          _IconBtn(icon: Icons.settings_outlined, onTap: onSettings),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final IconData? displayIcon;
  final int badgeCount;
  final VoidCallback onTap;
  const _IconBtn({
    super.key,
    required this.icon,
    this.displayIcon,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF061D12).withValues(alpha: 0.92),
                shape: BoxShape.circle,
                border: Border.all(color: OkeyColors.goldLight, width: 1.4),
              ),
              child: Icon(
                displayIcon ?? icon,
                color: OkeyColors.goldLight,
                size: 29,
              ),
            ),
            if (displayIcon != null)
              Opacity(opacity: 0.001, child: Icon(icon, size: 28)),
            if (badgeCount > 0)
              Positioned(
                top: -4,
                left: -3,
                child: Container(
                  key: const ValueKey('main-notification-badge'),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE62424),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Baloo 2',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileNameEditor extends StatefulWidget {
  const _ProfileNameEditor();

  @override
  State<_ProfileNameEditor> createState() => _ProfileNameEditorState();
}

class _ProfileNameEditorState extends State<_ProfileNameEditor> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: playerProgress.playerName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final saved = playerProgress.updatePlayerName(_controller.text);
    setState(() {
      _errorText = saved ? null : 'İsim 1-18 karakter arasında olmalı.';
    });
    if (saved) {
      _controller.text = playerProgress.playerName;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('profile-name-editor'),
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF184C37), Color(0xFF0A2A20)],
      ),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: OkeyColors.gold.withValues(alpha: 0.45)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.46),
          blurRadius: 7,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('profile-name-field'),
            controller: _controller,
            maxLength: 18,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            style: const TextStyle(
              color: OkeyColors.cream,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: 'Oyuncu adı',
              labelStyle: const TextStyle(color: OkeyColors.goldLight),
              errorText: _errorText,
              counterStyle: const TextStyle(color: Colors.white38),
              isDense: true,
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white30),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: OkeyColors.goldLight, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: FilledButton(
            key: const ValueKey('profile-name-save'),
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: OkeyColors.gold,
              foregroundColor: OkeyColors.buttonBrown,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            ),
            child: const Text(
              'KAYDET',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProfileSplitPanel extends StatelessWidget {
  final List<_FeatureEntry> careerEntries;

  const _ProfileSplitPanel({required this.careerEntries});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: playerProgress,
    builder: (context, _) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Container(
              key: const ValueKey('profile-overview-card'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF174C36), Color(0xFF09271E)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: OkeyColors.gold.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.52),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: OkeyColors.goldLight.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'PROFİL BİLGİLERİ',
                      style: TextStyle(
                        color: OkeyColors.goldLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 110,
                    height: 110,
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [OkeyColors.goldLight, OkeyColors.goldDark],
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        playerProgress.playerAvatarAsset,
                        fit: BoxFit.cover,
                        cacheWidth: 150,
                        cacheHeight: 150,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(playerAvatarAssets.length, (index) {
                      final selected =
                          index == playerProgress.playerAvatarIndex;
                      return GestureDetector(
                        key: ValueKey('profile-avatar-$index'),
                        onTap: () => playerProgress.updatePlayerAvatar(index),
                        child: Container(
                          width: 46,
                          height: 46,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? OkeyColors.goldLight
                                  : Colors.white24,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              playerAvatarAssets[index],
                              fit: BoxFit.cover,
                              cacheWidth: 72,
                              cacheHeight: 72,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 7),
                  const _ProfileNameEditor(),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF174C36), Color(0xFF09271E)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: OkeyColors.gold.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.52),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: OkeyColors.goldLight.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      appText('KARİYER İSTATİSTİKLERİ', 'CAREER STATISTICS'),
                      style: const TextStyle(
                        color: OkeyColors.goldLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  ...careerEntries.indexed.expand(
                    (item) => [
                      if (item.$1 > 0) const SizedBox(height: 7),
                      _FeatureEntryCard(entry: item.$2, compact: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FeatureDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final ValueChanged<String>? onEntryTap;

  const _FeatureDialog({
    required this.icon,
    required this.title,
    required this.description,
    this.onEntryTap,
  });

  String get _displayTitle => switch (title) {
    'PROFİLİM' => appText('PROFİLİM', 'MY PROFILE'),
    'CÜZDAN' => appText('CÜZDAN', 'WALLET'),
    'GELEN KUTUSU' => appText('GELEN KUTUSU', 'INBOX'),
    'GÖREVLER' => appText('GÖREVLER', 'MISSIONS'),
    'GÜNLÜK GİRİŞ ÖDÜLÜ' => appText(
      '7 GÜNLÜK GİRİŞ ÖDÜLÜ',
      '7-DAY LOGIN REWARD',
    ),
    _ => title,
  };

  List<_FeatureEntry> get _entries => switch (title) {
    'GÜNLÜK GİRİŞ ÖDÜLÜ' => const [],
    'PROFİLİM' => [
      _FeatureEntry(
        Icons.military_tech_rounded,
        '${appText('Seviye', 'Level')} ${playerProgress.level} • ${playerProgress.title}',
        playerProgress.isMaxLevel
            ? appText('En yüksek seviyeye ulaşıldı', 'Maximum level reached')
            : '${playerProgress.levelXp} / ${playerProgress.xpForNextLevel} XP',
        playerProgress.isMaxLevel
            ? 'MAX'
            : '%${(playerProgress.levelProgress * 100).round()}',
      ),
      _FeatureEntry(
        Icons.sports_esports_rounded,
        '${playerProgress.gamesPlayed} ${appText('oyun', 'games')}',
        '${playerProgress.gamesWon} ${appText('galibiyet', 'wins')} · ${playerProgress.gamesPlayed - playerProgress.gamesWon} ${appText('mağlubiyet', 'losses')}',
        null,
      ),
      _FeatureEntry(
        Icons.trending_up_rounded,
        appText('Kazanma Oranı', 'Win Rate'),
        '%${(playerProgress.winRate * 100).round()} · ${appText('Toplam', 'Total')} ${playerProgress.totalXpEarned} XP',
        null,
      ),
      _FeatureEntry(
        Icons.workspace_premium_rounded,
        appText('Tur İstatistikleri', 'Round Statistics'),
        '${playerProgress.handsOpened} ${appText('el açıldı', 'hands opened')} · ${playerProgress.handsFinished} ${appText('el bitirildi', 'hands finished')}',
        null,
      ),
    ],
    'CÜZDAN' => [
      _FeatureEntry(
        Icons.monetization_on_rounded,
        '${formatGameNumber(playerProgress.coins)} Altın',
        'Kullanılabilir bakiye',
        null,
      ),
      _FeatureEntry(
        Icons.card_giftcard_rounded,
        'Günlük Bonus',
        '+500 jeton almaya hazır',
        null,
      ),
      _FeatureEntry(
        Icons.receipt_long_rounded,
        'Oda Girişleri',
        'Oda ücreti giriş sırasında bakiyeden düşülür',
        null,
      ),
    ],
    'GELEN KUTUSU' => [
      if (dailyLogin.canClaimToday)
        const _FeatureEntry(
          Icons.card_giftcard_rounded,
          'Günlük ödülün hazır',
          '',
          'YENİ',
        ),
      if (_inboxNotifications.tournamentUnread)
        const _FeatureEntry(
          Icons.emoji_events_rounded,
          'Turnuva ilerlemeni kontrol et',
          '',
          'YENİ',
        ),
      if (_inboxNotifications.welcomeUnread)
        const _FeatureEntry(
          Icons.waving_hand_rounded,
          'Hoş geldin!',
          '',
          'YENİ',
        ),
    ],
    'OYUN MODLARI' => const [
      _FeatureEntry(
        Icons.looks_one_rounded,
        'Klasik 101',
        'Tekli oyun · Standart kurallar',
        null,
      ),
      _FeatureEntry(
        Icons.timer_rounded,
        'Zamanlı 101',
        'Her hamle için 7 saniye',
        null,
      ),
      _FeatureEntry(
        Icons.palette_rounded,
        'Renkli 101',
        'Her elde bir rengin perleri 2 kat puan',
        null,
      ),
      _FeatureEntry(
        Icons.add_chart_rounded,
        'Katlamalı',
        'Risk ve ödülün giderek arttığı mod',
        null,
      ),
    ],
    'TURNUVALAR' => const [
      _FeatureEntry(
        Icons.nightlight_round,
        'Akşam Kupası',
        '20.00 · 64 oyuncu · 50.000 jeton',
        '42/64',
      ),
      _FeatureEntry(
        Icons.calendar_month_rounded,
        'Hafta Sonu Ligi',
        'Cumartesi 18.00 · Kayıtlar açık',
        '18/32',
      ),
      _FeatureEntry(
        Icons.leaderboard_rounded,
        'Sezon Sıralaması',
        'Şu anki sıran: 128',
        null,
      ),
    ],
    'GÖREVLER' => const [
      _FeatureEntry(
        Icons.casino_rounded,
        '3 oyun oyna',
        'Ödül: 350 jeton',
        '1/3',
      ),
      _FeatureEntry(
        Icons.grid_view_rounded,
        '5 kez per aç',
        'Ödül: 500 jeton',
        '2/5',
      ),
      _FeatureEntry(
        Icons.emoji_events_rounded,
        'Bir oyun kazan',
        'Ödül: 750 jeton',
        '0/1',
      ),
    ],
    _ => const [
      _FeatureEntry(
        Icons.info_outline_rounded,
        'Yakında',
        'Bu bölüm geliştirme aşamasında.',
        null,
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isDailyReward = title == 'GÜNLÜK GİRİŞ ÖDÜLÜ';
    final isProfile = title == 'PROFİLİM';
    final dialogWidth = isDailyReward
        ? min(640.0, screenSize.width - 24)
        : isProfile
        ? min(720.0, screenSize.width - 24)
        : min(430.0, screenSize.width - 44);
    final dailyRewardHeight = min(360.0, screenSize.height - 16);
    final maxHeight = isDailyReward
        ? dailyRewardHeight
        : isProfile
        ? max(300.0, min(540.0, screenSize.height - 32))
        : max(300.0, min(590.0, screenSize.height - 32));
    final standardDialogContent = Column(
      children: [
        if (title != 'GÖREVLER') ...[
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (title == 'GÖREVLER') ...[
          const _DailyTaskCountdown(),
          const SizedBox(height: 12),
        ],
        if (isDailyReward) ...[
          const _DailyLoginRewardPanel(),
          const SizedBox(height: 4),
        ],
        if (!isProfile)
          ..._entries.map(
            (entry) => title == 'GÖREVLER'
                ? _MissionEntryCard(entry: entry)
                : _FeatureEntryCard(
                    entry: entry,
                    onTap: onEntryTap == null
                        ? null
                        : () => onEntryTap!(entry.title),
                  ),
          ),
        if (title == 'GELEN KUTUSU' && _entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              appText('Yeni bildirimin yok.', 'No new notifications.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          key: ValueKey('feature-dialog-$title'),
          width: dialogWidth,
          constraints: BoxConstraints(maxHeight: maxHeight),
          margin: EdgeInsets.symmetric(horizontal: isDailyReward ? 8 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isProfile
                  ? const [Color(0xFF123C2E), Color(0xFF071B14)]
                  : const [Color(0xFF0E3528), Color(0xFF061B14)],
            ),
            borderRadius: BorderRadius.circular(isProfile ? 24 : 20),
            border: Border.all(
              color: OkeyColors.gold,
              width: isProfile ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isProfile ? 0.74 : 0.68),
                blurRadius: isProfile ? 34 : 30,
                spreadRadius: isProfile ? 4 : 3,
                offset: Offset(0, isProfile ? 14 : 0),
              ),
              BoxShadow(
                color: OkeyColors.gold.withValues(alpha: 0.14),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: isProfile ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Container(
                height: isProfile ? 62 : 72,
                padding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  border: Border(
                    bottom: BorderSide(
                      color: OkeyColors.gold.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: isProfile ? 46 : 54,
                      height: isProfile ? 46 : 54,
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(
                          colors: [Color(0xFF0A593B), Color(0xFF032A1D)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: OkeyColors.goldLight.withValues(alpha: 0.7),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: OkeyColors.goldLight,
                        size: isProfile ? 25 : 29,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _displayTitle,
                        style: TextStyle(
                          color: OkeyColors.cream,
                          fontSize: isProfile ? 19 : 23,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Georgia',
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    AppCloseButton(
                      onTap: () => Navigator.of(context).pop(),
                      size: isProfile ? 40 : 42,
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: OkeyColors.gold.withValues(alpha: 0.25),
              ),
              Flexible(
                fit: isProfile ? FlexFit.loose : FlexFit.tight,
                child: isProfile
                    ? Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                          child: _ProfileSplitPanel(careerEntries: _entries),
                        ),
                      )
                    : isDailyReward
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        child: Center(child: standardDialogContent),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                        child: standardDialogContent,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: isProfile ? 42 : 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: OkeyColors.goldLight,
                      foregroundColor: OkeyColors.buttonBrown,
                      elevation: isProfile ? 7 : 0,
                      shadowColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        side: isProfile
                            ? BorderSide(
                                color: OkeyColors.gold.withValues(alpha: 0.95),
                                width: 1.4,
                              )
                            : BorderSide.none,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      appText('TAMAM', 'DONE'),
                      style: TextStyle(
                        fontSize: isProfile ? 14 : 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyLoginRewardPanel extends StatefulWidget {
  const _DailyLoginRewardPanel();

  @override
  State<_DailyLoginRewardPanel> createState() => _DailyLoginRewardPanelState();
}

class _DailyLoginRewardPanelState extends State<_DailyLoginRewardPanel>
    with SingleTickerProviderStateMixin {
  bool _claiming = false;
  final GlobalKey _activeRewardKey = GlobalKey();
  late final AnimationController _coinFlightController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  OverlayEntry? _coinFlightEntry;

  Offset? _activeRewardCenter() {
    final source = _activeRewardKey.currentContext?.findRenderObject();
    if (source is! RenderBox || !source.hasSize) return null;
    return source.localToGlobal(source.size.center(Offset.zero));
  }

  Future<void> _playCoinFlight(Offset start) async {
    final overlay = Overlay.of(context);
    final screen = MediaQuery.sizeOf(context);
    final end = Offset(screen.width - 205, 42);
    _coinFlightEntry?.remove();
    _coinFlightEntry = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: _coinFlightController,
        builder: (_, child) {
          final progress = Curves.easeInOutCubic.transform(
            _coinFlightController.value,
          );
          final position = Offset.lerp(start, end, progress)!;
          final arc = sin(progress * pi) * 48;
          return Positioned(
            left: position.dx - 17,
            top: position.dy - 17 - arc,
            child: IgnorePointer(
              child: Opacity(
                opacity: (1 - progress * 0.55).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 1 + sin(progress * pi) * 0.28,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: RepaintBoundary(
          child: Image.asset(
            'images/ui/coin.png',
            width: 34,
            height: 34,
            cacheWidth: 68,
            cacheHeight: 68,
          ),
        ),
      ),
    );
    overlay.insert(_coinFlightEntry!);
    await _coinFlightController.forward(from: 0);
    _coinFlightEntry?.remove();
    _coinFlightEntry = null;
  }

  @override
  void dispose() {
    _coinFlightEntry?.remove();
    _coinFlightController.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    if (_claiming || !dailyLogin.canClaimToday) return;
    final flightStart = _activeRewardCenter();
    setState(() => _claiming = true);
    final reward = await dailyLogin.claim();
    if (!mounted) return;
    setState(() => _claiming = false);
    if (reward != null) {
      if (flightStart != null) await _playCoinFlight(flightStart);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reward.xp == 0
                ? '+${reward.coins} Altın kazandın'
                : '+${reward.coins} Altın ve +${reward.xp} XP kazandın',
          ),
          backgroundColor: OkeyColors.tableMid,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: dailyLogin,
    builder: (context, _) {
      final currentDay = dailyLogin.displayDay;
      return Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 5,
            runSpacing: 8,
            children: List.generate(dailyLoginRewards.length, (index) {
              final day = index + 1;
              final reward = dailyLoginRewards[index];
              final active = day == currentDay;
              final completed = !dailyLogin.canClaimToday && day == currentDay;
              return GestureDetector(
                key: ValueKey('daily-login-day-$day'),
                onTap: active && dailyLogin.canClaimToday && !_claiming
                    ? _claim
                    : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  key: active ? _activeRewardKey : null,
                  width: 82,
                  height: 130,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? OkeyColors.gold.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? OkeyColors.goldLight : Colors.white12,
                      width: active ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          appText('$day. GÜN', 'DAY $day'),
                          maxLines: 1,
                          style: TextStyle(
                            color: active
                                ? OkeyColors.goldLight
                                : Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Image.asset(
                        'images/ui/coin.png',
                        width: 30,
                        height: 30,
                        cacheWidth: 60,
                        cacheHeight: 60,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '+${reward.coins}',
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          reward.xp == 0 ? 'ALTIN' : '+${reward.xp} XP',
                          maxLines: 1,
                          style: TextStyle(
                            color: reward.xp == 0
                                ? Colors.white54
                                : const Color(0xFF8FEAFF),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        key: ValueKey('daily-login-collect-$day'),
                        height: 24,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active && dailyLogin.canClaimToday
                              ? OkeyColors.gold
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: active && dailyLogin.canClaimToday
                                ? OkeyColors.goldLight
                                : Colors.white12,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (completed) ...[
                                const Icon(
                                  Icons.check_rounded,
                                  color: Color(0xFF66DB75),
                                  size: 13,
                                ),
                                const SizedBox(width: 2),
                              ],
                              Text(
                                appText('TOPLA', 'CLAIM'),
                                style: TextStyle(
                                  color: active && dailyLogin.canClaimToday
                                      ? OkeyColors.buttonBrown
                                      : Colors.white38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      );
    },
  );
}

class _DailyTaskCountdown extends StatefulWidget {
  const _DailyTaskCountdown();

  @override
  State<_DailyTaskCountdown> createState() => _DailyTaskCountdownState();
}

class _DailyTaskCountdownState extends State<_DailyTaskCountdown> {
  Timer? _displayTimer;

  @override
  void initState() {
    super.initState();
    _dailyTaskClock.initialize();
    _displayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && TickerMode.valuesOf(context).enabled) setState(() {});
    });
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _dailyTaskClock,
    builder: (context, _) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: OkeyColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OkeyColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.timer_outlined,
            color: OkeyColors.goldLight,
            size: 19,
          ),
          const SizedBox(width: 8),
          Text(
            'YENİLENME  ${_dailyTaskClock.remainingText}',
            style: const TextStyle(
              color: OkeyColors.goldLight,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FeatureEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;

  const _FeatureEntry(this.icon, this.title, this.subtitle, this.badge);
}

class _FeatureEntryCard extends StatelessWidget {
  final _FeatureEntry entry;
  final VoidCallback? onTap;
  final bool compact;

  const _FeatureEntryCard({
    required this.entry,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('feature-entry-${entry.title}'),
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      margin: EdgeInsets.only(bottom: compact ? 6 : 9),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 13,
        vertical: compact ? 7 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: onTap == null ? 0.055 : 0.085),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: OkeyColors.gold.withValues(alpha: onTap == null ? 0.2 : 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            entry.icon,
            color: OkeyColors.goldLight,
            size: compact ? 21 : 25,
          ),
          SizedBox(width: compact ? 8 : 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: TextStyle(
                    color: OkeyColors.cream,
                    fontSize: compact ? 12.5 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (entry.subtitle.isNotEmpty) ...[
                  SizedBox(height: compact ? 1 : 3),
                  Text(
                    entry.subtitle,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: compact ? 9.5 : 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (entry.badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: OkeyColors.gold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                entry.badge!,
                style: TextStyle(
                  color: OkeyColors.goldLight,
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _MissionEntryCard extends StatelessWidget {
  final _FeatureEntry entry;

  const _MissionEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final values = entry.badge?.split('/') ?? const <String>[];
    final current = values.isNotEmpty ? int.tryParse(values.first) ?? 0 : 0;
    final target = values.length > 1 ? int.tryParse(values[1]) ?? 1 : 1;
    final progress = (current / max(1, target)).clamp(0.0, 1.0);
    final rewardText = entry.subtitle.replaceFirst('Ödül:', '').trim();
    return Container(
      key: ValueKey('mission-progress-${entry.title}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2D22),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: OkeyColors.gold.withValues(alpha: 0.34)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: OkeyColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(entry.icon, color: OkeyColors.goldLight, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    color: OkeyColors.cream,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.card_giftcard_rounded,
                      color: OkeyColors.goldLight,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      rewardText,
                      style: const TextStyle(
                        color: OkeyColors.goldLight,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    key: ValueKey('mission-progress-bar-${entry.title}'),
                    value: progress,
                    minHeight: 9,
                    backgroundColor: Colors.black38,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      OkeyColors.gold,
                    ),
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

class _MenuSettings {
  final bool soundEffects;
  final bool music;
  final bool vibration;
  final bool homeEdgeTiles;
  final bool showPerformance;
  final double fontScale;
  final AppLanguage language;

  const _MenuSettings({
    this.soundEffects = true,
    this.music = true,
    this.vibration = true,
    this.homeEdgeTiles = true,
    this.showPerformance = false,
    this.fontScale = 1,
    this.language = AppLanguage.turkish,
  });

  _MenuSettings copyWith({
    bool? soundEffects,
    bool? music,
    bool? vibration,
    bool? homeEdgeTiles,
    bool? showPerformance,
    double? fontScale,
    AppLanguage? language,
  }) {
    return _MenuSettings(
      soundEffects: soundEffects ?? this.soundEffects,
      music: music ?? this.music,
      vibration: vibration ?? this.vibration,
      homeEdgeTiles: homeEdgeTiles ?? this.homeEdgeTiles,
      showPerformance: showPerformance ?? this.showPerformance,
      fontScale: (fontScale ?? this.fontScale).clamp(0.85, 1.25),
      language: language ?? this.language,
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  final _MenuSettings initial;
  const _SettingsDialog({required this.initial});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late _MenuSettings _settings;

  String _st(String tr, String en) =>
      _settings.language == AppLanguage.english ? en : tr;

  @override
  void initState() {
    super.initState();
    _settings = widget.initial;
  }

  String get _fontScaleLabel {
    if (_settings.fontScale < 0.95) return _st('Küçük', 'Small');
    if (_settings.fontScale > 1.05) return _st('Büyük', 'Large');
    return _st('Normal', 'Normal');
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.height < 520;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          key: const ValueKey('settings-dialog'),
          width: compact ? screen.width - 8 : min(1140, screen.width - 48),
          height: compact
              ? max(300, screen.height - 8)
              : max(300, min(610, screen.height - 24)),
          child: Transform.scale(
            scale: compact ? 0.82 : 0.86,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF123C2E), Color(0xFF071B14)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: OkeyColors.gold, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.72),
                    blurRadius: 32,
                    spreadRadius: 4,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: OkeyColors.gold.withValues(alpha: 0.18),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(compact ? 4 : 8),
                        child: LayoutBuilder(
                          builder: (context, constraints) => FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: compact
                                  ? constraints.maxWidth
                                  : min(800, constraints.maxWidth),
                              height: compact ? 248 : 472,
                              child: Column(
                                children: [
                                  _settingsGridRow(
                                    _toggleCard(
                                      title: _st(
                                        'Ses Efektleri',
                                        'Sound Effects',
                                      ),
                                      value: _settings.soundEffects,
                                      icon: Icons.volume_up_rounded,
                                      onChanged: (value) => setState(() {
                                        _settings = _settings.copyWith(
                                          soundEffects: value,
                                        );
                                      }),
                                    ),
                                    _toggleCard(
                                      title: _st('MÜZİK', 'MUSIC'),
                                      value: _settings.music,
                                      icon: Icons.music_note_rounded,
                                      onChanged: (value) => setState(() {
                                        _settings = _settings.copyWith(
                                          music: value,
                                        );
                                      }),
                                    ),
                                    _toggleCard(
                                      title: _st('TİTREŞİM', 'VIBRATION'),
                                      value: _settings.vibration,
                                      icon: Icons.vibration_rounded,
                                      onChanged: (value) => setState(() {
                                        _settings = _settings.copyWith(
                                          vibration: value,
                                        );
                                      }),
                                    ),
                                  ),
                                  SizedBox(height: compact ? 4 : 10),
                                  _settingsGridRow(
                                    _toggleCard(
                                      title: _st('KENAR TAŞLARI', 'EDGE TILES'),
                                      value: _settings.homeEdgeTiles,
                                      icon: Icons.style_rounded,
                                      onChanged: (value) => setState(() {
                                        _settings = _settings.copyWith(
                                          homeEdgeTiles: value,
                                        );
                                      }),
                                    ),
                                    _toggleCard(
                                      title: _st('PERFORMANS', 'PERFORMANCE'),
                                      value: _settings.showPerformance,
                                      icon: Icons.monitor_heart_rounded,
                                      showOffBadge: true,
                                      onChanged: (value) => setState(() {
                                        _settings = _settings.copyWith(
                                          showPerformance: value,
                                        );
                                      }),
                                    ),
                                    _buildLanguageGridCard(),
                                  ),
                                  SizedBox(height: compact ? 4 : 10),
                                  SizedBox(
                                    height: compact ? 88 : 156,
                                    child: _buildFontScaleSetting(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _compactLayout => MediaQuery.sizeOf(context).height < 520;

  Widget _buildHeader() => Container(
    height: _compactLayout ? 46 : 64,
    padding: EdgeInsets.fromLTRB(18, _compactLayout ? 3 : 5, 10, 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.24),
      border: Border(
        bottom: BorderSide(color: OkeyColors.gold.withValues(alpha: 0.42)),
      ),
    ),
    child: Row(
      children: [
        Image.asset(
          'images/ui/settings.png',
          width: _compactLayout ? 38 : 44,
          height: _compactLayout ? 38 : 44,
          cacheWidth: 72,
          cacheHeight: 72,
          filterQuality: FilterQuality.low,
        ),
        SizedBox(width: _compactLayout ? 9 : 12),
        Expanded(
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _st('AYARLAR', 'SETTINGS'),
                  style: TextStyle(
                    color: OkeyColors.goldLight,
                    fontSize: _compactLayout ? 17 : 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Georgia',
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        AppCloseButton(
          onTap: () => Navigator.of(context).pop(),
          size: _compactLayout ? 30 : 38,
        ),
      ],
    ),
  );

  Widget _settingsGridRow(Widget left, Widget middle, Widget right) => SizedBox(
    height: _compactLayout ? 76 : 148,
    child: Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 8),
        Expanded(child: middle),
        const SizedBox(width: 8),
        Expanded(child: right),
      ],
    ),
  );

  Widget _buildLanguageGridCard() => Container(
    key: const ValueKey('language-setting'),
    height: _compactLayout ? 76 : 148,
    padding: EdgeInsets.fromLTRB(
      _compactLayout ? 7 : 12,
      _compactLayout ? 5 : 10,
      _compactLayout ? 7 : 12,
      _compactLayout ? 5 : 10,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E6847), Color(0xFF0E432F)],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: OkeyColors.gold.withValues(alpha: 0.52),
        width: 1.4,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.55),
          blurRadius: 8,
          offset: const Offset(0, 5),
        ),
        BoxShadow(
          color: OkeyColors.goldLight.withValues(alpha: 0.12),
          blurRadius: 3,
          offset: const Offset(0, -1),
        ),
      ],
    ),
    child: Column(
      children: [
        SizedBox(
          width: _compactLayout ? 42 : 78,
          height: _compactLayout ? 42 : 78,
          child: _settingsIconCircle(icon: Icons.public_rounded, enabled: true),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _st('DİL', 'LANGUAGE'),
              style: TextStyle(
                color: OkeyColors.cream,
                fontSize: _compactLayout ? 12 : 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(width: _compactLayout ? 6 : 10),
            _LanguageChoice(
              label: 'TR',
              selected: _settings.language == AppLanguage.turkish,
              onTap: () => setState(() {
                _settings = _settings.copyWith(language: AppLanguage.turkish);
              }),
            ),
            const SizedBox(width: 4),
            _LanguageChoice(
              label: 'EN',
              selected: _settings.language == AppLanguage.english,
              onTap: () => setState(() {
                _settings = _settings.copyWith(language: AppLanguage.english);
              }),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _toggleCard({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? icon,
    String? activeAsset,
    String? inactiveAsset,
    bool showOffBadge = false,
  }) {
    final iconAsset = value ? activeAsset : inactiveAsset;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: _compactLayout ? 76 : 148,
        padding: EdgeInsets.fromLTRB(
          _compactLayout ? 7 : 12,
          _compactLayout ? 5 : 10,
          _compactLayout ? 7 : 12,
          _compactLayout ? 5 : 10,
        ),
        decoration: BoxDecoration(
          gradient: value
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E6847), Color(0xFF0E432F)],
                )
              : const LinearGradient(
                  colors: [Color(0xFF12392B), Color(0xFF0A271E)],
                ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value
                ? OkeyColors.gold.withValues(alpha: 0.52)
                : Colors.white10,
            width: value ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 8,
              offset: const Offset(0, 5),
            ),
            if (value)
              BoxShadow(
                color: OkeyColors.goldLight.withValues(alpha: 0.12),
                blurRadius: 3,
                offset: const Offset(0, -1),
              ),
          ],
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: _compactLayout ? 42 : 78,
                height: _compactLayout ? 42 : 78,
                child: iconAsset != null
                    ? Image.asset(
                        iconAsset,
                        cacheWidth: _compactLayout ? 72 : 120,
                        cacheHeight: _compactLayout ? 72 : 120,
                        filterQuality: FilterQuality.low,
                      )
                    : _settingsIconCircle(icon: icon, enabled: value),
              ),
            ),
            if (!value && showOffBadge)
              Positioned(
                top: 2,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _compactLayout ? 6 : 9,
                    vertical: _compactLayout ? 2 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    'OFF',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: _compactLayout ? 7 : 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: OkeyColors.cream,
                  fontSize: _compactLayout ? 12 : 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsIconCircle({required IconData? icon, required bool enabled}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          colors: [Color(0xFF0A593B), Color(0xFF032A1D)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: OkeyColors.gold, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(
        icon,
        color: enabled ? OkeyColors.goldLight : Colors.white54,
        size: _compactLayout ? 25 : 42,
      ),
    );
  }

  Widget _buildFontScaleSetting() => Container(
    padding: EdgeInsets.fromLTRB(
      _compactLayout ? 10 : 18,
      _compactLayout ? 6 : 16,
      _compactLayout ? 10 : 18,
      _compactLayout ? 6 : 12,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF154833), Color(0xFF092A1F)],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: OkeyColors.gold.withValues(alpha: 0.42),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.55),
          blurRadius: 8,
          offset: const Offset(0, 5),
        ),
        BoxShadow(
          color: OkeyColors.goldLight.withValues(alpha: 0.1),
          blurRadius: 3,
          offset: const Offset(0, -1),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.text_fields_rounded,
              color: OkeyColors.goldLight,
              size: _compactLayout ? 18 : 25,
            ),
            SizedBox(width: _compactLayout ? 7 : 10),
            Expanded(
              child: Text(
                _st('Yazı Boyutu', 'Text Size'),
                style: TextStyle(
                  color: OkeyColors.cream,
                  fontSize: _compactLayout ? 11 : 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: _compactLayout ? 7 : 10,
                vertical: _compactLayout ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color: OkeyColors.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: OkeyColors.gold.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                '$_fontScaleLabel • ${(_settings.fontScale * 100).round()}%',
                style: TextStyle(
                  color: OkeyColors.goldLight,
                  fontSize: _compactLayout ? 8 : 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text(
              'A',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: OkeyColors.gold,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: OkeyColors.goldLight,
                  overlayColor: OkeyColors.gold.withValues(alpha: 0.12),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _settings.fontScale,
                  min: 0.85,
                  max: 1.25,
                  divisions: 8,
                  onChanged: (value) => setState(() {
                    _settings = _settings.copyWith(fontScale: value);
                  }),
                ),
              ),
            ),
            const Text(
              'A',
              style: TextStyle(
                color: OkeyColors.cream,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (!_compactLayout)
          Text(
            _st('101 Okey yazı önizlemesi', '101 Okey text preview'),
            textScaler: TextScaler.linear(_settings.fontScale),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontFamily: 'Georgia',
            ),
          ),
      ],
    ),
  );

  Widget _buildFooter() => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1,
    child: Container(
      height: _compactLayout ? 46 : 58,
      padding: EdgeInsets.fromLTRB(
        _compactLayout ? 8 : 14,
        _compactLayout ? 4 : 7,
        _compactLayout ? 8 : 14,
        _compactLayout ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        border: Border(
          top: BorderSide(color: OkeyColors.gold.withValues(alpha: 0.28)),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _settings = const _MenuSettings();
            }),
            icon: Icon(
              Icons.restart_alt_rounded,
              size: _compactLayout ? 15 : 18,
            ),
            label: Text(_st('VARSAYILAN', 'DEFAULT')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: OkeyColors.gold.withValues(alpha: 0.38)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: _compactLayout ? 150 : 172,
            height: _compactLayout ? 34 : 40,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_settings),
              style: FilledButton.styleFrom(
                backgroundColor: OkeyColors.goldLight,
                foregroundColor: OkeyColors.buttonBrown,
                elevation: 7,
                shadowColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: OkeyColors.gold.withValues(alpha: 0.95),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(Icons.check_rounded, size: _compactLayout ? 18 : 21),
              label: Text(
                _st('KAYDET', 'SAVE'),
                style: TextStyle(
                  fontSize: _compactLayout ? 12 : 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LanguageChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 520;
    return GestureDetector(
      key: ValueKey('language-$label'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: compact ? 32 : 44,
        height: compact ? 20 : 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? OkeyColors.gold : Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? OkeyColors.goldLight : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF2D1B05) : Colors.white70,
            fontSize: compact ? 8 : 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _HomeLogoArtwork extends StatelessWidget {
  const _HomeLogoArtwork();

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Image.asset(
      'images/ui/home/logoasil.png',
      width: 310,
      height: 296,
      fit: BoxFit.contain,
      cacheWidth: 620,
      cacheHeight: 592,
      filterQuality: FilterQuality.medium,
    ),
  );
}

class _HemenOynaButton extends StatefulWidget {
  final VoidCallback onTap;
  const _HemenOynaButton({required this.onTap});

  @override
  State<_HemenOynaButton> createState() => _HemenOynaButtonState();
}

class _HemenOynaButtonState extends State<_HemenOynaButton>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 90),
      vsync: this,
    );
    _pressScale = _pressController.drive(Tween<double>(begin: 1, end: 0.97));
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1450),
      vsync: this,
    )..repeat(reverse: true);
    _pulseScale = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    ).drive(Tween<double>(begin: 1, end: 1.025));
  }

  @override
  void dispose() {
    _pressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pressScale, _pulseScale]),
        builder: (_, child) => Transform.scale(
          scale: _pressScale.value * _pulseScale.value,
          child: child,
        ),
        child: GestureDetector(
          onTapDown: (_) => _pressController.forward(),
          onTapUp: (_) async {
            await _pressController.reverse();
            widget.onTap();
          },
          onTapCancel: () => _pressController.reverse(),
          child: Container(
            width: 352,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              image: const DecorationImage(
                image: ResizeImage(
                  AssetImage('images/ui/home/glossy_green_pill_opt.png'),
                  width: 872,
                  height: 210,
                ),
                fit: BoxFit.fill,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                SizedBox(
                  width: 59,
                  height: 56,
                  child: Image.asset(
                    'images/ui/home/hemenoyna2.png',
                    width: 54,
                    height: 56,
                    fit: BoxFit.contain,
                    cacheWidth: 120,
                    // Yalnız genişliği sınırla; iki ekseni birlikte zorlamak
                    // kaynak görselin oranını bozuyordu.
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        appLanguage.isEnglish ? 'PLAY NOW' : 'HEMEN OYNA',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFFFFF4E8),
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.25,
                          shadows: _homeButtonTextShadows,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RightButtonColumn extends StatelessWidget {
  final VoidCallback onSelectRoom;
  final VoidCallback onSelectMode;
  final VoidCallback onTournament;
  final void Function(IconData icon, String title, String description) onOpen;
  const _RightButtonColumn({
    required this.onSelectRoom,
    required this.onSelectMode,
    required this.onTournament,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = [
      (
        Icons.table_restaurant_rounded,
        'images/ui/icons/masa_sec.png',
        appText('MASA SEÇ', 'SELECT TABLE'),
        appText(
          'Aktif masaları, oyuncu sayılarını ve giriş ücretlerini buradan inceleyebilirsin.',
          'Browse active tables, player counts and entry fees.',
        ),
      ),
      (
        Icons.category_rounded,
        'images/ui/icons/oyun_modlari_yeni_opt.png',
        appText('OYUN MODLARI', 'GAME MODES'),
        appText(
          'Klasik 101, zamanlı, renkli ve katlamalı oyun seçeneklerini buradan seçebilirsin.',
          'Choose Classic, Timed, Color Bonus or Progressive mode.',
        ),
      ),
      (
        Icons.emoji_events_rounded,
        'images/ui/icons/turnuva.png',
        appText('TURNUVALAR', 'TOURNAMENTS'),
        appText(
          'Turnuva aşamalarını, ödülleri ve sıralamayı burada takip edebilirsin.',
          'Follow tournament stages, rewards and standings.',
        ),
      ),
      (
        Icons.task_alt_rounded,
        'images/ui/icons/gorevler.png',
        appText('GÖREVLER', 'MISSIONS'),
        appText(
          'Günlük görevlerini tamamlayarak jeton ve tecrübe kazanabilirsin.',
          'Complete daily missions to earn coins and experience.',
        ),
      ),
    ];

    Widget buttonAt(int index) {
      final (icon, assetPath, label, description) = buttons[index];
      return _RightSideButton(
        icon: icon,
        assetPath: assetPath,
        label: label,
        onTap: index == 0
            ? onSelectRoom
            : index == 1
            ? onSelectMode
            : index == 2
            ? onTournament
            : () => onOpen(icon, 'GÖREVLER', description),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [buttonAt(3), buttonAt(1)],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [buttonAt(0), buttonAt(2)],
        ),
      ],
    );
  }
}

class _RightSideButton extends StatefulWidget {
  final IconData icon;
  final String? assetPath;
  final String label;
  final VoidCallback onTap;

  const _RightSideButton({
    required this.icon,
    this.assetPath,
    required this.label,
    required this.onTap,
  });

  @override
  State<_RightSideButton> createState() => _RightSideButtonState();
}

const _homeButtonTextShadows = <Shadow>[
  Shadow(color: Color(0xFF37251C), offset: Offset(-1.1, -1.1)),
  Shadow(color: Color(0xFF37251C), offset: Offset(1.1, -1.1)),
  Shadow(color: Color(0xFF37251C), offset: Offset(-1.1, 1.1)),
  Shadow(color: Color(0xFF37251C), offset: Offset(1.1, 1.1)),
  Shadow(color: Color(0xB3000000), offset: Offset(0, 3), blurRadius: 1.5),
];

class _RightSideButtonState extends State<_RightSideButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 80),
      vsync: this,
    );
    _scale = _controller.drive(Tween<double>(begin: 1, end: 0.97));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) async {
          await _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: Container(
          width: 220,
          height: 68,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF24513D), Color(0xFF0A3222), Color(0xFF052418)],
              stops: [0, 0.58, 1],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: OkeyColors.goldLight.withValues(alpha: 0.75),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF02140C).withValues(alpha: 0.95),
                blurRadius: 0,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 9,
                offset: const Offset(0, 7),
              ),
              BoxShadow(
                color: OkeyColors.goldLight.withValues(alpha: 0.10),
                blurRadius: 5,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 7, right: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width:
                      widget.assetPath ==
                          'images/ui/icons/oyun_modlari_yeni_opt.png'
                      ? 68
                      : 46,
                  height: 44,
                  child: widget.assetPath == null
                      ? Icon(widget.icon, color: OkeyColors.goldLight, size: 32)
                      : Image.asset(
                          widget.assetPath!,
                          width:
                              widget.assetPath ==
                                  'images/ui/icons/oyun_modlari_yeni_opt.png'
                              ? 68
                              : 46,
                          height: 44,
                          fit: BoxFit.contain,
                          cacheWidth:
                              widget.assetPath ==
                                  'images/ui/icons/oyun_modlari_yeni_opt.png'
                              ? 136
                              : 92,
                          cacheHeight: 88,
                          filterQuality: FilterQuality.low,
                        ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width:
                          widget.assetPath ==
                              'images/ui/icons/oyun_modlari_yeni_opt.png'
                          ? 72
                          : double.infinity,
                      child: Text(
                        widget.label,
                        maxLines: 2,
                        softWrap: true,
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFF4E8),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 0.88,
                          letterSpacing: 0.05,
                          shadows: _homeButtonTextShadows,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
