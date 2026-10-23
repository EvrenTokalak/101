import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';
import 'app_colors.dart';
import 'store_screen.dart';

import 'avatar_picker.dart';
import 'profile_name_dialog.dart';
import 'app_controls.dart';
import 'app_settings_dialog.dart';
import 'daily_login_rewards.dart';
import 'daily_reward_card.dart';
import 'daily_challenge.dart';
import 'daily_challenge_card.dart';
import 'saved_game.dart';
import 'game_launch.dart';
import 'game.dart'
    show
        GameScreen,
        gameAutoArrangeRackEnabled,
        gameOpponentPicturesEnabled,
        gameSoundEffectsEnabled,
        gameVibrationEnabled,
        prewarmGameAudio,
        prewarmGameVisuals,
        setGameAutoArrangeRackEnabled,
        setGameOpponentPicturesEnabled,
        setGameSoundEffectsEnabled,
        setGameVibrationEnabled;
import 'game_mode_select.dart';
import 'game_navigation.dart';
import 'game_help_dialog.dart';
import 'oda.dart' as oda;
import 'opponent_name_session.dart';
import 'performance_overlay.dart';
import 'player_progress.dart';
import 'progress_notifications.dart';
import 'route_activity.dart';
import 'store_cosmetics.dart';
import 'startup_tutorial.dart';
import 'daily_league.dart';
import 'league_screen.dart';

export 'app_colors.dart' show OkeyColors;

final _dailyTaskClock = _DailyTaskClock();
final _inboxNotifications = _InboxNotifications();
final _walletRewardTargetKey = GlobalKey();
final _xpRewardTargetKey = GlobalKey();

class _InboxNotifications extends ChangeNotifier {
  static const _tournamentReadKey = 'inbox.tournament_read_v1';
  static const _welcomeReadKey = 'inbox.welcome_read_v1';
  static const _dailyRewardReadKey = 'inbox.daily_reward_read_v1';

  bool _tournamentUnread = true;
  bool _welcomeUnread = true;
  String? _dailyRewardReadToken;
  bool tournamentDismissed = false;
  bool welcomeDismissed = false;
  String? _dailyRewardDismissedToken;
  bool get dailyRewardDismissed =>
      _dailyRewardDismissedToken == _dailyRewardToken;

  bool get tournamentUnread => _tournamentUnread;
  bool get welcomeUnread => _welcomeUnread;
  int get unreadCount => (_tournamentUnread ? 1 : 0) + (_welcomeUnread ? 1 : 0);
  String get _dailyRewardToken {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}:${dailyLogin.streak}';
  }

  bool get dailyRewardUnread =>
      dailyLogin.canClaimToday && _dailyRewardReadToken != _dailyRewardToken;

  Future<void> load() async {
    try {
      final preferences = SharedPreferencesAsync();
      _tournamentUnread = await preferences.getBool(_tournamentReadKey) != true;
      _welcomeUnread = await preferences.getBool(_welcomeReadKey) != true;
      _dailyRewardReadToken = await preferences.getString(_dailyRewardReadKey);
      tournamentDismissed =
          await preferences.getBool('inbox.tournament_dismissed_v1') == true;
      welcomeDismissed =
          await preferences.getBool('inbox.welcome_dismissed_v1') == true;
      _dailyRewardDismissedToken = await preferences.getString(
        'inbox.daily_reward_dismissed_v1',
      );
    } catch (_) {
      // Depolama kullanılamazsa mevcut oturumdaki okunma durumu korunur.
    }
    notifyListeners();
  }

  Future<void> markDailyRewardRead() async {
    await load();
    _dailyRewardReadToken = _dailyRewardToken;
    notifyListeners();
    try {
      await SharedPreferencesAsync().setString(
        _dailyRewardReadKey,
        _dailyRewardReadToken!,
      );
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    await load();
    _tournamentUnread = false;
    _welcomeUnread = false;
    _dailyRewardReadToken = _dailyRewardToken;
    notifyListeners();
    try {
      final preferences = SharedPreferencesAsync();
      await Future.wait([
        preferences.setBool(_tournamentReadKey, true),
        preferences.setBool(_welcomeReadKey, true),
        preferences.setString(_dailyRewardReadKey, _dailyRewardReadToken!),
      ]);
    } catch (_) {}
  }

  Future<void> markTournamentRead() async {
    if (!_tournamentUnread) return;
    _tournamentUnread = false;
    notifyListeners();
    try {
      await SharedPreferencesAsync().setBool(_tournamentReadKey, true);
    } catch (_) {}
  }

  Future<void> dismiss(String id) async {
    final preferences = SharedPreferencesAsync();
    if (id == 'inbox-daily') {
      _dailyRewardDismissedToken = _dailyRewardToken;
      _dailyRewardReadToken = _dailyRewardToken;
      notifyListeners();
      try {
        await Future.wait([
          preferences.setString(
            'inbox.daily_reward_dismissed_v1',
            _dailyRewardToken,
          ),
          preferences.setString(_dailyRewardReadKey, _dailyRewardToken),
        ]);
      } catch (_) {}
    } else if (id == 'inbox-league') {
      tournamentDismissed = true;
      _tournamentUnread = false;
      notifyListeners();
      try {
        await Future.wait([
          preferences.setBool('inbox.tournament_dismissed_v1', true),
          preferences.setBool(_tournamentReadKey, true),
        ]);
      } catch (_) {}
    } else if (id == 'inbox-welcome') {
      welcomeDismissed = true;
      _welcomeUnread = false;
      notifyListeners();
      try {
        await Future.wait([
          preferences.setBool('inbox.welcome_dismissed_v1', true),
          preferences.setBool(_welcomeReadKey, true),
        ]);
      } catch (_) {}
    } else {
      await progressNotifications.dismissNotice(id);
    }
    notifyListeners();
  }

  Future<void> clearAll() async {
    // Sequential writes keep read-state reloads from restoring dismissed entries.
    await dismiss('inbox-daily');
    await dismiss('inbox-league');
    await dismiss('inbox-welcome');
    await progressNotifications.clearNotices();
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

  Future<void> initialize() {
    if (_deadline != null) {
      if (_rolloverTimer == null) _scheduleRollover();
      return Future.value();
    }
    return _initializing ??= _load();
  }

  void pause() {
    _rolloverTimer?.cancel();
    _rolloverTimer = null;
  }

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
      progressNotifications.refresh();
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
  // Keep the settings frame, background and rack cached together. The former
  // 6 MB limit evicted these textures between routes and forced fresh decoding.
  // Bound decoded image memory to 32 MB instead of Flutter's larger default.
  PaintingBinding.instance.imageCache
    ..maximumSize = 64
    ..maximumSizeBytes = 32 * 1024 * 1024;
  await Future.wait([
    playerProgress.load(),
    storeCosmetics.load(),
    _dailyTaskClock.initialize(),
    appLanguage.load(),
    dailyLogin.load(),
    _inboxNotifications.load(),
    savedGame.load(),
  ]);
  await progressNotifications.load();
  await dailyChallenge.load();
  await dailyLeague.load();
  await dailyLeague.setNotificationsEnabled(appSettings.value.notifications);
  appSettings.value = appSettings.value.copyWith(language: appLanguage.value);
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
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          width: 300,
          backgroundColor: const Color(0xFF123C2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: OkeyColors.gold, width: 1.5),
          ),
        ),
      ),
      builder: (context, child) {
        return ValueListenableBuilder<AppSettings>(
          valueListenable: appSettings,
          child: child,
          builder: (context, settings, appChild) {
            final mediaQuery = MediaQuery.of(context);
            final content = SettingsArtworkWarmup(
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: appTextScaler(settings.fontScale),
                ),
                child: appChild ?? const SizedBox.shrink(),
              ),
            );
            return ValueListenableBuilder<bool>(
              valueListenable: performanceOverlayEnabled,
              child: content,
              builder: (_, enabled, overlayChild) =>
                  AppPerformanceOverlay(enabled: enabled, child: overlayChild!),
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
  final bool showTutorialPrompt;

  const MainMenuScreen({super.key, this.showTutorialPrompt = false});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late AnimationController _walletRewardCtrl;
  late Animation<double> _fadeIn;
  late AppSettings _settings;
  int _walletAnimationFrom = 0;
  int _walletAnimationTo = 0;
  int _walletRewardGain = 0;
  bool _navigating = false;
  final ValueNotifier<bool> _panelOpen = ValueNotifier(false);
  bool _visualsPrewarmed = false;
  bool _tutorialPromptScheduled = false;

  @override
  void initState() {
    super.initState();
    _settings = appSettings.value.copyWith(language: appLanguage.value);
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
    progressNotifications.addListener(_onProgressNotice);
    unawaited(progressNotifications.load());
    unawaited(dailyChallenge.load());
    unawaited(savedGame.load());
    prewarmGameAudio();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.showTutorialPrompt && !_tutorialPromptScheduled) {
      _tutorialPromptScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!mounted || _navigating) return;
        _panelOpen.value = true;
        final showTutorial =
            await showGeneralDialog<bool>(
              context: context,
              barrierDismissible: false,
              barrierLabel: 'Öğretici sorusu',
              barrierColor: Colors.black.withValues(alpha: 0.68),
              transitionDuration: const Duration(milliseconds: 200),
              pageBuilder: (_, _, _) => const TutorialPromptDialog(),
              transitionBuilder: appSettingsTransition,
            ).whenComplete(() {
              if (mounted) _panelOpen.value = false;
            });
        if (showTutorial == true && mounted) {
          await _launchTutorialGame();
          if (mounted) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
            if (mounted) await _showHomeFeatureTour();
          }
        }
      });
    }
    if (_visualsPrewarmed) return;
    _visualsPrewarmed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (mounted && !_navigating && !_panelOpen.value) {
          prewarmGameVisuals(context);
        }
      });
    });
  }

  Future<void> _launchTutorialGame() async {
    var completed = false;
    await _withPausedScene(() async {
      if (!mounted) return;
      completed =
          await Navigator.of(context).push<bool>(
            AppSceneRoute<bool>(
              builder: (_) =>
                  const GameScreen(launchConfig: GameLaunchConfig.tutorial()),
              curve: Curves.linear,
              reverseDuration: const Duration(milliseconds: 100),
            ),
          ) ==
          true;
      opponentNameSession.reset();
    });
    if (completed && mounted) await _openProfile(requestName: true);
  }

  Future<void> _launchTutorialFromSettings() async {
    if (!mounted) return;
    final completed =
        await Navigator.of(context).push<bool>(
          AppSceneRoute<bool>(
            builder: (_) =>
                const GameScreen(launchConfig: GameLaunchConfig.tutorial()),
            curve: Curves.linear,
            reverseDuration: const Duration(milliseconds: 100),
          ),
        ) ==
        true;
    opponentNameSession.reset();
    if (completed && mounted) await _openProfile(requestName: true);
  }

  @override
  void dispose() {
    progressNotifications.removeListener(_onProgressNotice);
    _panelOpen.dispose();
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
      if (mounted) {
        setState(() => _navigating = false);
        _onProgressNotice();
      }
    }
  }

  Future<void> _resumeGame() async {
    final state = savedGame.snapshot;
    final config = savedGame.config;
    if (state == null || config == null) return;
    await _withPausedScene(() async {
      await Future.wait<void>([
        prewarmGameAudio(),
        prewarmGameVisuals(context),
      ]);
      if (!mounted) return;
      await openGameScreen<void>(context, config: config, savedState: state);
      opponentNameSession.reset();
    });
  }

  void _onProgressNotice() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _navigating ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final notices = progressNotifications.takeToasts();
      if (!_settings.notifications) return;
      for (final notice in notices) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            dismissDirection: DismissDirection.horizontal,
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF174C36),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                Icon(
                  notice.room
                      ? Icons.table_restaurant_rounded
                      : Icons.task_alt_rounded,
                  color: OkeyColors.goldLight,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(notice.title)),
              ],
            ),
          ),
        );
      }
    });
  }

  Future<void> _navigateToRoomSelect() async {
    await _withPausedScene(
      () => Navigator.of(
        context,
      ).push(AppSceneRoute<void>(builder: (_) => const oda.RoomSelectScreen())),
    );
    opponentNameSession.reset();
  }

  Future<void> _navigateToGameModeSelect() async {
    await _withPausedScene(
      () => Navigator.of(
        context,
      ).push(AppSceneRoute<void>(builder: (_) => const GameModeSelectScreen())),
    );
    opponentNameSession.reset();
  }

  Future<void> _navigateToTournament() async {
    await _withPausedScene(
      () =>
          Navigator.of(context)
              .push(AppSceneRoute<void>(builder: (_) => const LeagueScreen())),
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
              const ActiveRouteScene(child: StoreScreen()),
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
    bool requestProfileName = false,
  }) async {
    if (!mounted || _panelOpen.value) return;
    _panelOpen.value = true;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '$title penceresini kapat',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, _, _) => AnimatedBuilder(
        animation: Listenable.merge([
          progressNotifications,
          _inboxNotifications,
          dailyLogin,
        ]),
        builder: (_, _) => SafeArea(
          maintainBottomViewPadding: title == 'PROFİLİM',
          child: _FeatureDialog(
            icon: icon,
            title: title,
            description: description,
            onEntryTap: onEntryTap,
            requestProfileName: requestProfileName,
            onMissionReward: _animateMissionReward,
          ),
        ),
      ),
      transitionBuilder: appSettingsTransition,
    ).whenComplete(() {
      if (mounted) _panelOpen.value = false;
    });
  }

  Future<void> _openDailyReward() async {
    final balanceBefore = playerProgress.coins;
    await _openFeaturePopup(
      icon: Icons.card_giftcard_rounded,
      title: 'GÜNLÜK GİRİŞ ÖDÜLÜ',
      description: '',
    );
    _onProgressNotice();
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

  Future<void> _animateMissionReward(int coins) async {
    if (!mounted) return;
    setState(() {
      _walletAnimationFrom = playerProgress.coins - coins;
      _walletAnimationTo = playerProgress.coins;
      _walletRewardGain = coins;
    });
    try {
      await _walletRewardCtrl.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Closing the scene must not interrupt the already granted reward.
    }
  }

  Future<HomeFeatureTourAction?> _showHomeFeatureStep({required bool daily}) =>
      showGeneralDialog<HomeFeatureTourAction>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Ana menü özellikleri',
        barrierColor: Colors.black.withValues(alpha: 0.58),
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => HomeFeatureTourDialog(daily: daily),
        transitionBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      );

  Future<void> _showHomeFeatureTour() async {
    final firstAction = await _showHomeFeatureStep(daily: true);
    if (!mounted || firstAction != HomeFeatureTourAction.openDailyReward) {
      return;
    }

    await _openDailyReward();
    if (!mounted) return;

    final secondAction = await _showHomeFeatureStep(daily: false);
    if (!mounted || secondAction != HomeFeatureTourAction.openMissions) return;
    await _openFeaturePopup(
      icon: Icons.task_alt_rounded,
      title: 'GÖREVLER',
      description:
          'Günlük görevlerini tamamlayarak altın ve tecrübe kazanabilirsin.',
    );
  }

  Future<void> _openProfile({bool requestName = false}) => _openFeaturePopup(
    icon: Icons.person_rounded,
    title: 'PROFİLİM',
    description: 'Oyuncu bilgilerin, seviyen, başarıların ve istatistiklerin burada gösterilecek.',
    requestProfileName: requestName,
  );

  Future<void> _openInbox() async {
    await dailyChallenge.load();
    dailyChallenge.refresh();
    if (!mounted) return;
    String? selectedEntry;
    await _openFeaturePopup(
      icon: Icons.mail_rounded,
      title: 'GELEN KUTUSU',
      description: '',
      onEntryTap: (entry) {
        selectedEntry = entry;
        progressNotifications.markRead(entry);
        if (entry.startsWith('Lig')) {
          unawaited(_inboxNotifications.markTournamentRead());
        } else if (entry.startsWith('Hoş geldin')) {
          unawaited(_inboxNotifications.markWelcomeRead());
        } else if (entry.startsWith('Günlük')) {
          unawaited(_inboxNotifications.markDailyRewardRead());
        }
        Navigator.of(context).pop();
      },
    );
    if (!mounted || selectedEntry == null) return;
    if (selectedEntry!.startsWith('Günlük')) {
      await _openDailyReward();
    } else if (selectedEntry!.startsWith('Lig')) {
      await _navigateToTournament();
    } else if (selectedEntry!.contains('masası açıldı')) {
      await _navigateToRoomSelect();
    } else if (selectedEntry!.startsWith('Görev tamamlandı')) {
      await _openFeaturePopup(
        icon: Icons.task_alt_rounded,
        title: 'GÖREVLER',
        description: 'Günlük görevlerin',
      );
    }
  }

  void _showWalletComingSoon() {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          dismissDirection: DismissDirection.horizontal,
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
    if (_panelOpen.value || !mounted) return;
    _panelOpen.value = true;
    final updatedSettings =
        await showGeneralDialog<AppSettings>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Ayarları kapat',
          barrierColor: Colors.black.withValues(alpha: 0.72),
          transitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, _, _) => AppSettingsDialog(
            initial: _settings.copyWith(
              soundEffects: gameSoundEffectsEnabled,
              vibration: gameVibrationEnabled,
              showOpponentPictures: gameOpponentPicturesEnabled,
              autoArrangeRack: gameAutoArrangeRackEnabled,
            ),
            onTutorial: () => unawaited(_launchTutorialFromSettings()),
          ),
          transitionBuilder: appSettingsTransition,
        ).whenComplete(() {
          if (mounted) _panelOpen.value = false;
        });

    if (updatedSettings != null && mounted) {
      setState(() => _settings = updatedSettings);
      appSettings.value = updatedSettings;
      unawaited(
        dailyLeague.setNotificationsEnabled(updatedSettings.notifications),
      );
      setGameVibrationEnabled(updatedSettings.vibration);
      setGameSoundEffectsEnabled(updatedSettings.soundEffects);
      setGameOpponentPicturesEnabled(updatedSettings.showOpponentPictures);
      setGameAutoArrangeRackEnabled(updatedSettings.autoArrangeRack);
      await appLanguage.setLanguage(updatedSettings.language);
    }
  }

  Future<void> _openHelp() async {
    if (!mounted || _panelOpen.value) return;
    _panelOpen.value = true;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Yardımı kapat',
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => const GameHelpDialog(),
      transitionBuilder: appSettingsTransition,
    ).whenComplete(() {
      if (mounted) _panelOpen.value = false;
    });
  }

  Widget _portraitHome() => SingleChildScrollView(
    key: const ValueKey('responsive-home-scroll'),
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileChip(onTap: _openProfile),
            const SizedBox(height: 14),
            _DailyRewardButton(
              onTap: _openDailyReward,
              showNotifications: _settings.notifications,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _IconBtn(
              key: const ValueKey('main-wallet-button'),
              destinationKey: _walletRewardTargetKey,
              icon: Icons.account_balance_wallet_rounded,
              onTap: _showWalletComingSoon,
            ),
            _IconBtn(
              key: const ValueKey('main-store-button'),
              icon: Icons.shopping_cart_rounded,
              onTap: _navigateToStore,
            ),
            AnimatedBuilder(
              animation: Listenable.merge([
                progressNotifications,
                _inboxNotifications,
                dailyLogin,
              ]),
              builder: (_, _) => _IconBtn(
                icon: Icons.mail_outlined,
                badgeCount: _settings.notifications
                    ? _inboxNotifications.unreadCount +
                          progressNotifications.unread.length +
                          (_inboxNotifications.dailyRewardUnread ? 1 : 0)
                    : 0,
                onTap: _openInbox,
              ),
            ),
            _IconBtn(
              key: const ValueKey('main-help-button'),
              icon: Icons.help_rounded,
              onTap: _openHelp,
            ),
            _IconBtn(
              key: const ValueKey('main-settings-button'),
              icon: Icons.settings_outlined,
              onTap: _openSettings,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: Image.asset('images/ui/home/logoasil.png'),
        ),
        _RightButtonColumn(
          onSelectRoom: _navigateToRoomSelect,
          onSelectMode: _navigateToGameModeSelect,
          onTournament: _navigateToTournament,
          onOpen: (icon, title, description) => _openFeaturePopup(
            icon: icon,
            title: title,
            description: description,
          ),
        ),
        const SizedBox(height: 18),
        _HomePlayActions(onNew: () => _navigateToGame(), onResume: _resumeGame),
        HomeLeagueSummary(onTap: _navigateToTournament),
      ],
    ),
  );

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
          // The separate name editor handles the keyboard. Keep the scene
          // behind it at its normal size instead of fitting it above the IME.
          resizeToAvoidBottomInset: false,
          body: SettingsSceneActivity(
            panelOpen: _panelOpen,
            enabled: !_navigating,
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: StoreBackground(cacheWidth: 1440),
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
                  maintainBottomViewPadding: true,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: LayoutBuilder(
                      builder: (context, viewport) {
                        final aspectRatio =
                            viewport.maxWidth / viewport.maxHeight;
                        final designHeight = (1100 / aspectRatio).clamp(
                          500.0,
                          900.0,
                        );
                        final headerCenterY =
                            72 +
                            (MediaQuery.textScalerOf(context).scale(64) - 64) /
                                2;
                        return aspectRatio < 1.2
                            ? _portraitHome()
                            : SizedBox.expand(
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    key: const ValueKey(
                                      'landscape-home-layout',
                                    ),
                                    width: 1100,
                                    height: designHeight,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: _HomeTileDecorations(
                                            enabled: true,
                                          ),
                                        ),
                                        Positioned(
                                          top: 18,
                                          left: 20,
                                          child: _ProfileChip(
                                            onTap: _openProfile,
                                          ),
                                        ),
                                        Positioned(
                                          top: headerCenterY - 28,
                                          right: 20,
                                          child: AnimatedBuilder(
                                            animation: _walletRewardCtrl,
                                            builder: (context, _) {
                                              final progress = Curves
                                                  .easeOutCubic
                                                  .transform(
                                                    _walletRewardCtrl.value,
                                                  );
                                              final animatedBalance =
                                                  _walletAnimationFrom +
                                                  ((_walletAnimationTo -
                                                              _walletAnimationFrom) *
                                                          progress)
                                                      .round();
                                              return _TopRightBar(
                                                coinBalance: animatedBalance,
                                                animateBalance:
                                                    _walletRewardCtrl
                                                        .isAnimating,
                                                notificationsEnabled:
                                                    _settings.notifications,
                                                onSettings: _openSettings,
                                                onHelp: _openHelp,
                                                onStore: _navigateToStore,
                                                onWallet: _showWalletComingSoon,
                                                onMessages: _openInbox,
                                              );
                                            },
                                          ),
                                        ),
                                        if (_walletRewardGain > 0)
                                          Positioned(
                                            top: headerCenterY + 31,
                                            right: 304,
                                            child: AnimatedBuilder(
                                              animation: _walletRewardCtrl,
                                              builder: (context, child) {
                                                final value =
                                                    _walletRewardCtrl.value;
                                                return Transform.translate(
                                                  offset: Offset(
                                                    0,
                                                    -18 * value,
                                                  ),
                                                  child: Opacity(
                                                    opacity: sin(pi * value)
                                                        .clamp(0.0, 1.0),
                                                    child: Transform.scale(
                                                      scale:
                                                          0.88 +
                                                          0.22 *
                                                              sin(pi * value),
                                                      child: child,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                key: const ValueKey(
                                                  'main-wallet-reward-animation',
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 11,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF0A3A24,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
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
                                          left: 24,
                                          top:
                                              142 +
                                              (MediaQuery.textScalerOf(context)
                                                      .scale(64) -
                                                  64),
                                          child: _DailyRewardButton(
                                            onTap: _openDailyReward,
                                            showNotifications:
                                                _settings.notifications,
                                          ),
                                        ),
                                        Positioned(
                                          left: 145,
                                          top: designHeight / 2 - 120,
                                          child: const _HomeLogoArtwork(),
                                        ),
                                        Positioned(
                                          right: 20,
                                          top: designHeight / 2 - 80,
                                          width: 444,
                                          child: Column(
                                            children: [
                                              _RightButtonColumn(
                                                onSelectRoom:
                                                    _navigateToRoomSelect,
                                                onSelectMode:
                                                    _navigateToGameModeSelect,
                                                onTournament:
                                                    _navigateToTournament,
                                                onOpen:
                                                    (
                                                      icon,
                                                      title,
                                                      description,
                                                    ) => _openFeaturePopup(
                                                      icon: icon,
                                                      title: title,
                                                      description: description,
                                                    ),
                                              ),
                                              const SizedBox(height: 22),
                                              _HomePlayActions(
                                                onNew: () => _navigateToGame(),
                                                onResume: _resumeGame,
                                              ),
                                              HomeLeagueSummary(
                                                onTap: _navigateToTournament,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                      },
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
  final bool showNotifications;
  const _DailyRewardButton({
    required this.onTap,
    required this.showNotifications,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: dailyLogin,
    builder: (context, _) => AppPressable(
      key: const ValueKey('daily-reward-button'),
      onTap: onTap,
      child: SizedBox(
        width: 90,
        height: 90,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Image.asset(
              'images/ui/home/daily_reward.png',
              width: 90,
              height: 90,
              cacheWidth: 256,
              filterQuality: FilterQuality.medium,
            ),
            if (showNotifications && dailyLogin.canClaimToday)
              Positioned(
                top: 4,
                right: 3,
                child: Container(
                  key: const ValueKey('daily-reward-badge'),
                  constraints: const BoxConstraints(
                    minWidth: 23,
                    minHeight: 23,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE62424),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                  child: const Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Baloo 2',
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w900,
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

class _ProfileChip extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([playerProgress, appLanguage]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final panelWidth = min(326.0, constraints.maxWidth);
          final panelHeight =
              108.0 + (MediaQuery.textScalerOf(context).scale(64) - 64);
          return AppPressable(
            key: const ValueKey('main-xp-chip'),
            onTap: onTap,
            child: SizedBox(
              width: panelWidth,
              height: panelHeight,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: panelWidth * .07,
                    top: panelHeight * .17,
                    width: panelWidth * .215,
                    height: panelHeight * .66,
                    child: ClipOval(
                      child: Image.asset(
                        playerProgress.playerAvatarAsset,
                        fit: BoxFit.cover,
                        cacheWidth: 144,
                        cacheHeight: 144,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Image.asset(
                      'images/ui/home/profile_panel.png',
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  Positioned(
                    left: panelWidth * .35,
                    top: panelHeight * .22,
                    right: panelWidth * .115,
                    bottom: panelHeight * .23,
                    child: Container(
                      key: const ValueKey('home-profile-content'),
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.25,
                        child: LayoutBuilder(
                          builder: (context, area) => ClipRect(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: area.maxWidth,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          playerProgress.playerName,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
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
                                          width: 15,
                                          height: 15,
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
                                              '${playerProgress.levelBand.localizedTitle(appLanguage.value)} · ${appText('Seviye', 'Level', german: 'Stufe')} ${playerProgress.level}',
                                              maxLines: 1,
                                              style: const TextStyle(
                                                color: OkeyColors.goldLight,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    ClipRRect(
                                      key: _xpRewardTargetKey,
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        key: const ValueKey('home-xp-progress'),
                                        value: playerProgress.isMaxLevel
                                            ? 1
                                            : playerProgress.levelProgress
                                                  .clamp(0.0, 1.0),
                                        minHeight: 7,
                                        color: OkeyColors.goldLight,
                                        backgroundColor: const Color(
                                          0xFF28352B,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopRightBar extends StatelessWidget {
  final int coinBalance;
  final bool animateBalance;
  final bool notificationsEnabled;
  final VoidCallback onSettings;
  final VoidCallback onHelp;
  final VoidCallback onStore;
  final VoidCallback onWallet;
  final VoidCallback onMessages;
  const _TopRightBar({
    required this.coinBalance,
    this.animateBalance = false,
    required this.notificationsEnabled,
    required this.onSettings,
    required this.onHelp,
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
        progressNotifications,
      ]),
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppPressable(
            key: const ValueKey('main-wallet-button'),
            onTap: onWallet,
            child: SizedBox(
              key: _walletRewardTargetKey,
              width: 190,
              height: 54,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF252525), Color(0xFF090909)],
                        ),
                        border: Border.all(
                          color: const Color(0xFF8C8C8C),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
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
                    right: 42,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatGameNumber(
                          animateBalance ? coinBalance : playerProgress.coins,
                        ),
                        key: const ValueKey('home-coin-balance'),
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 38,
                    top: 9,
                    bottom: 9,
                    child: Container(width: 1, color: Colors.white54),
                  ),
                  const Positioned(
                    right: 7,
                    child: Icon(
                      Icons.add_rounded,
                      size: 29,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black87, offset: Offset(0, 2)),
                      ],
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
            badgeCount: notificationsEnabled
                ? _inboxNotifications.unreadCount +
                      progressNotifications.unread.length +
                      (_inboxNotifications.dailyRewardUnread ? 1 : 0)
                : 0,
            onTap: onMessages,
          ),
          const SizedBox(width: 13),
          _IconBtn(
            key: const ValueKey('main-help-button'),
            icon: Icons.help_rounded,
            onTap: onHelp,
          ),
          const SizedBox(width: 13),
          _IconBtn(
            key: const ValueKey('main-settings-button'),
            icon: Icons.settings_outlined,
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final Key? destinationKey;
  final IconData icon;
  final IconData? displayIcon;
  final int badgeCount;
  final VoidCallback onTap;
  const _IconBtn({
    super.key,
    this.destinationKey,
    required this.icon,
    this.displayIcon,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final asset = switch (icon) {
      Icons.shopping_cart_rounded => 'images/ui/home/store.png',
      Icons.mail_outlined => 'images/ui/home/inbox.png',
      Icons.help_rounded => 'images/ui/home/help.png',
      Icons.settings_outlined => 'images/ui/home/settings.png',
      _ => null,
    };
    return AppPressable(
      onTap: onTap,
      pressedScale: .92,
      child: SizedBox(
        key: destinationKey,
        width: 56,
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (asset != null)
              Image.asset(asset, width: 54, height: 54, fit: BoxFit.contain)
            else
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
            if (displayIcon != null || asset != null)
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

class _ProfileSplitPanel extends StatefulWidget {
  final List<_FeatureEntry> careerEntries;
  final bool requestName;

  const _ProfileSplitPanel({
    required this.careerEntries,
    this.requestName = false,
  });

  @override
  State<_ProfileSplitPanel> createState() => _ProfileSplitPanelState();
}

class _ProfileSplitPanelState extends State<_ProfileSplitPanel> {
  bool _editingName = false;
  @override
  void initState() {
    super.initState();
    if (widget.requestName) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editName(requestName: true);
      });
    }
  }

  Future<void> _editName({bool requestName = false}) async {
    if (_editingName) return;
    _editingName = true;
    final selected = await showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ProfileNameDialog(
        initialName:
            requestName && playerProgress.playerName == defaultPlayerProfileName
            ? ''
            : playerProgress.playerName,
      ),
    );
    _editingName = false;
    if (mounted && selected != null) playerProgress.updatePlayerName(selected);
  }

  Future<void> _showAvatarPicker(BuildContext context) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (_) =>
          AvatarPickerDialog(selectedIndex: playerProgress.playerAvatarIndex),
    );
    if (mounted && selected != null) {
      playerProgress.updatePlayerAvatar(selected);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: playerProgress,
    builder: (context, _) => LayoutBuilder(
      builder: (context, bounds) {
        final avatarSize = (bounds.maxHeight * .43).clamp(90.0, 158.0);
        final stats = [
          (
            'games',
            appText('Oynanan Oyun', 'Games Played'),
            formatGameNumber(playerProgress.gamesPlayed),
            Icons.casino_rounded,
          ),
          (
            'results',
            appText('Galibiyet / Mağlubiyet', 'Wins / Losses'),
            '${playerProgress.gamesWon} / ${playerProgress.gamesPlayed - playerProgress.gamesWon}',
            Icons.emoji_events_rounded,
          ),
          (
            'opening',
            appText(
              'En Yüksek Açılış',
              'Highest Opening',
              german: 'Höchste Eröffnung',
            ),
            formatGameNumber(playerProgress.highestOpening),
            Icons.local_fire_department_rounded,
          ),
          (
            'xp',
            appText('Toplam XP', 'Total XP'),
            formatGameNumber(playerProgress.totalXpEarned),
            Icons.star_rounded,
          ),
          (
            'opened',
            appText('Açılan El', 'Hands Opened'),
            formatGameNumber(playerProgress.handsOpened),
            Icons.view_week_rounded,
          ),
          (
            'finished',
            appText('Bitirilen El', 'Hands Finished'),
            formatGameNumber(playerProgress.handsFinished),
            Icons.done_all_rounded,
          ),
        ];
        final avatar = SizedBox(
          width: avatarSize,
          height: avatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: OkeyColors.goldLight, width: 3),
                ),
                child: ClipOval(
                  child: Image.asset(
                    playerAvatarAssets[playerProgress.playerAvatarIndex],
                    key: const ValueKey('profile-draft-avatar'),
                    width: avatarSize,
                    height: avatarSize,
                    fit: BoxFit.cover,
                    cacheWidth: 320,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  key: const ValueKey('profile-avatar-edit'),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF074435),
                    foregroundColor: OkeyColors.cream,
                    side: const BorderSide(
                      color: OkeyColors.goldLight,
                      width: 2,
                    ),
                  ),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _showAvatarPicker(context);
                  },
                  icon: const Icon(Icons.edit_rounded),
                ),
              ),
            ],
          ),
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                key: const ValueKey('profile-overview-card'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  avatar,
                  const SizedBox(height: 12),
                  InkWell(
                    key: const ValueKey('profile-name-edit'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: _editName,
                    child: Container(
                      key: const ValueKey('profile-name-underline'),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: OkeyColors.goldLight,
                            width: 1.4,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                playerProgress.playerName,
                                style: const TextStyle(
                                  color: OkeyColors.cream,
                                  fontFamily: 'Baloo 2',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.edit_rounded,
                            size: 22,
                            color: OkeyColors.goldLight,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const VerticalDivider(
              width: 2,
              thickness: 2,
              color: Color(0xFF397765),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 22),
                child: Column(
                  key: const ValueKey('profile-career-panel'),
                  children: [
                    for (final (index, entry) in stats.indexed)
                      Expanded(
                        child: Container(
                          key: ValueKey('profile-stat-separator-$index'),
                          decoration: BoxDecoration(
                            color: index.isEven
                                ? Colors.white.withValues(alpha: .045)
                                : Colors.transparent,
                            border: const Border(
                              top: BorderSide(
                                color: Color(0xFF397765),
                                width: 2,
                              ),
                            ),
                          ),
                          child: _ProfileStatCard(
                            id: entry.$1,
                            label: entry.$2,
                            value: entry.$3,
                            icon: entry.$4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ProfileStatCard extends StatelessWidget {
  final String id, label, value;
  final IconData icon;
  const _ProfileStatCard({
    required this.id,
    required this.label,
    required this.value,
    required this.icon,
  });

  Widget _statVisual() {
    final index = switch (id) {
      'games' => 0,
      'results' => 1,
      'opening' => 2,
      'xp' => 3,
      'opened' => 4,
      _ => 5,
    };
    return Center(
      child: SizedBox.square(
        dimension: 50,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: OverflowBox(
            alignment: Alignment((index % 3) - 1.0, index < 3 ? -1 : 1),
            minWidth: 150,
            maxWidth: 150,
            minHeight: 100,
            maxHeight: 100,
            child: Image.asset(
              'images/ui/icons/profile_stats.png',
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('profile-stat-$id'),
    padding: const EdgeInsets.fromLTRB(10, 5, 26, 5),
    child: Row(
      children: [
        SizedBox(width: 58, height: 52, child: _statVisual()),
        const SizedBox(width: 12),
        Expanded(
          flex: 7,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(
                color: OkeyColors.cream,
                fontSize: 26,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: const TextStyle(
                color: OkeyColors.goldLight,
                fontSize: 26,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProfileDialog extends StatelessWidget {
  final bool requestName;
  const _ProfileDialog({this.requestName = false});

  @override
  Widget build(BuildContext context) => MediaQuery.removeViewInsets(
    context: context,
    removeBottom: true,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final panelSize = appSettingsPanelSize(bounds);
            return Center(
              child: SizedBox(
                key: const ValueKey('feature-dialog-PROFİLİM'),
                width: panelSize.width,
                height: panelSize.height,
                child: AppArtworkReady(
                  image: appPopupArtwork('images/ui/panels/profilim.png'),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FittedBox(
                          child: SizedBox(
                            width: 900,
                            height: 600,
                            child: Material(
                              color: Colors.transparent,
                              child: AppPopupSurface(
                                width: 900,
                                height: 600,
                                frameWidth: 5,
                                artworkAsset: 'images/ui/panels/profilim.png',

                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    42,
                                    38,
                                    42,
                                    72,
                                  ),
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 92),
                                      Expanded(
                                        child: _ProfileSplitPanel(
                                          careerEntries: const [],
                                          requestName: requestName,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: AppArtworkTitle(
                          asset: 'images/ui/panels/profilim.png',
                          child: Text(
                            appText('PROFİLİM', 'MY PROFILE'),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: AppArtworkClose(
                          asset: 'images/ui/panels/profilim.png',
                          buttonKey: const ValueKey('profile-close-button'),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _FeatureDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final ValueChanged<String>? onEntryTap;
  final bool requestProfileName;
  final Future<void> Function(int)? onMissionReward;

  const _FeatureDialog({
    required this.icon,
    required this.title,
    required this.description,
    this.onEntryTap,
    this.requestProfileName = false,
    this.onMissionReward,
  });

  String get _displayTitle => switch (title) {
    'PROFİLİM' => appText('PROFİLİM', 'MY PROFILE'),
    'CÜZDAN' => appText('CÜZDAN', 'WALLET'),
    'GELEN KUTUSU' => appText('GELEN KUTUSU', 'INBOX'),
    'GÖREVLER' => appText('GÖREVLER', 'MISSIONS'),
    'GÜNLÜK GİRİŞ ÖDÜLÜ' => appText('GÜNLÜK ÖDÜL', 'DAILY REWARD'),
    _ => title,
  };

  Widget _entryCard(_FeatureEntry entry, {required bool inbox}) {
    final card = _FeatureEntryCard(
      entry: entry,
      compact: inbox,
      onTap: onEntryTap == null ? null : () => onEntryTap!(entry.title),
    );
    if (!inbox) return card;
    return Dismissible(
      key: ValueKey('inbox-dismiss-${entry.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => unawaited(_inboxNotifications.dismiss(entry.id!)),
      background: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
        ),
      ),
      secondaryBackground: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Align(
          alignment: Alignment.centerRight,
          child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
        ),
      ),
      child: Opacity(
        key: ValueKey('inbox-opacity-${entry.id}'),
        opacity: entry.badge == 'YENİ' ? 1 : .5,
        child: card,
      ),
    );
  }

  List<_FeatureEntry> get _entries => switch (title) {
    'GÜNLÜK GİRİŞ ÖDÜLÜ' => const [],
    'PROFİLİM' => [
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
        '+500 altın almaya hazır',
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
      for (final notice in progressNotifications.notices.reversed)
        _FeatureEntry(
          notice.room ? Icons.table_restaurant_rounded : Icons.task_alt_rounded,
          notice.title,
          '',
          progressNotifications.unread.any((entry) => entry.id == notice.id)
              ? 'YENİ'
              : null,
          id: notice.id,
        ),
      if (dailyLogin.canClaimToday && !_inboxNotifications.dailyRewardDismissed)
        _FeatureEntry(
          Icons.card_giftcard_rounded,
          'Günlük ödülün hazır',
          '',
          _inboxNotifications.dailyRewardUnread ? 'YENİ' : null,
          id: 'inbox-daily',
        ),
      if (!_inboxNotifications.tournamentDismissed)
        _FeatureEntry(
          Icons.emoji_events_rounded,
          'Lig sıralamanı kontrol et',
          '',
          _inboxNotifications.tournamentUnread ? 'YENİ' : null,
          id: 'inbox-league',
        ),
      if (!_inboxNotifications.welcomeDismissed)
        _FeatureEntry(
          Icons.waving_hand_rounded,
          'Hoş geldin!',
          '',
          _inboxNotifications.welcomeUnread ? 'YENİ' : null,
          id: 'inbox-welcome',
        ),
    ],
    'OYUN MODLARI' => const [
      _FeatureEntry(
        Icons.looks_one_rounded,
        'Kuralı Sen Belirle',
        'Kendi masan, kendi kuralların',
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
    'GÖREVLER' => [
      for (final mission in progressNotifications.missions)
        _FeatureEntry(
          mission.complete ? Icons.task_alt_rounded : Icons.casino_rounded,
          mission.title,
          'Ödül: ${mission.reward} altın',
          '${mission.current}/${mission.target}',
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, viewport) {
      if (title == 'PROFİLİM') {
        return _ProfileDialog(requestName: requestProfileName);
      }
      final isDailyReward = title == 'GÜNLÜK GİRİŞ ÖDÜLÜ';
      final isMissions = title == 'GÖREVLER';
      final isInbox = title == 'GELEN KUTUSU';
      final asset = switch (title) {
        'GÖREVLER' => 'images/ui/panels/gorevler.png',
        'GELEN KUTUSU' => 'images/ui/panels/gelen-kutusu.png',
        'GÜNLÜK GİRİŞ ÖDÜLÜ' => 'images/ui/panels/gunluk-odul.png',
        _ => appGenericPanelAsset,
      };
      final availableWidth = max(0.0, viewport.maxWidth - 24);
      final availableHeight = max(0.0, viewport.maxHeight - 24);
      final portrait = viewport.maxWidth < viewport.maxHeight;
      final dailyWidth = min(
        1280.0,
        min(availableWidth, availableHeight * 2.35),
      );
      final size = isDailyReward
          ? portrait
                ? Size(min(620.0, availableWidth), min(760.0, availableHeight))
                : Size(dailyWidth, dailyWidth / 2.35)
          : appArtworkPanelSize(
              BoxConstraints(
                maxWidth: availableWidth,
                maxHeight: availableHeight,
              ),
            );
      return Center(
        child: Material(
          color: Colors.transparent,
          child: AppPopupSurface(
            key: ValueKey('feature-dialog-$title'),
            width: size.width,
            height: size.height,
            artworkAsset: asset,
            artworkTitle: Text(_displayTitle, maxLines: 1, softWrap: false),
            closeOnFrame: true,
            onOutsideClose: () => Navigator.of(context).pop(),
            padding: EdgeInsets.fromLTRB(
              size.width * (isInbox || isMissions ? .075 : .035),
              size.height *
                  (isDailyReward
                      ? .22
                      : isInbox || isMissions
                      ? .235
                      : .24),
              size.width * (isInbox || isMissions ? .075 : .035),
              size.height *
                  (isInbox || isMissions
                      ? .18
                      : isDailyReward
                      ? .10
                      : .12),
            ),
            child: isDailyReward
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: const _DailyLoginRewardPanel(),
                  )
                : ClipRRect(
                    key: ValueKey('feature-content-viewport-$title'),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        Expanded(
                          child: AppPanelScrollView(
                            showScrollbar: false,
                            showScrollHint: isMissions,
                            padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isMissions && description.isNotEmpty) ...[
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
                                if (isMissions)
                                  _MissionPanel(onReward: onMissionReward)
                                else
                                  ..._entries.map(
                                    (entry) =>
                                        _entryCard(entry, inbox: isInbox),
                                  ),
                                if (title == 'GELEN KUTUSU' && _entries.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 28,
                                    ),
                                    child: Text(
                                      appText(
                                        'Yeni bildirimin yok.',
                                        'No new notifications.',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (isInbox)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 5, 18, 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: AppArtworkButton(
                                    key: const ValueKey('inbox-mark-all-read'),
                                    enabled: _entries.isNotEmpty,
                                    yellow: true,
                                    width: 196,
                                    height: 34,
                                    fontSize: 11,
                                    fontFamily: 'Baloo 2',
                                    label: appText(
                                      'Tümünü okundu işaretle',
                                      'Mark all as read',
                                    ),
                                    onPressed: () async {
                                      await Future.wait([
                                        progressNotifications.markAllRead(),
                                        _inboxNotifications.markAllRead(),
                                      ]);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AppArtworkButton(
                                  key: const ValueKey('inbox-clear-all'),
                                  enabled: _entries.isNotEmpty,
                                  yellow: true,
                                  width: 92,
                                  height: 34,
                                  fontSize: 11,
                                  fontFamily: 'Baloo 2',
                                  label: appText('Temizle', 'Clear'),
                                  onPressed: _inboxNotifications.clearAll,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      );
    },
  );
}

Future<void> _playRewardCoinFlight(
  BuildContext context,
  AnimationController controller,
  Offset start, {
  bool withXp = false,
}) async {
  final overlay = Overlay.of(context);
  final overlayBox = overlay.context.findRenderObject() as RenderBox;
  final origin = overlayBox.globalToLocal(start);
  Offset? destination(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return overlayBox.globalToLocal(
      box.localToGlobal(box.size.center(Offset.zero)),
    );
  }

  final wallet = destination(_walletRewardTargetKey);
  final xp = withXp ? destination(_xpRewardTargetKey) : null;
  if (wallet == null && xp == null) return;
  Widget flight(Offset end, bool isXp) => AnimatedBuilder(
    animation: controller,
    child: RepaintBoundary(
      key: ValueKey(isXp ? 'reward-xp-flight' : 'reward-coin-flight'),
      child: isXp
          ? CustomPaint(
              size: const Size(34, 34),
              painter: _XpRewardParticlesPainter(controller),
            )
          : Image.asset(
              'images/ui/coin.png',
              width: 34,
              height: 34,
              cacheWidth: 68,
              cacheHeight: 68,
            ),
    ),
    builder: (_, child) {
      final progress = Curves.easeInOutCubic.transform(controller.value);
      final position = Offset.lerp(origin, end, progress)!;
      return Positioned(
        left: position.dx - 17,
        top: position.dy - 17 - sin(progress * pi) * 48,
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
  );
  final entry = OverlayEntry(
    builder: (_) => Stack(
      children: [
        if (wallet != null) flight(wallet, false),
        if (xp != null) flight(xp, true),
      ],
    ),
  );
  overlay.insert(entry);
  try {
    await controller.forward(from: 0).orCancel;
  } finally {
    entry.remove();
    entry.dispose();
  }
}

class _XpRewardParticlesPainter extends CustomPainter {
  final Animation<double> animation;
  _XpRewardParticlesPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < 11; i++) {
      final phase = (animation.value * 1.7 + i * .13) % 1;
      final angle = i * 2.4 + animation.value * 2;
      final radius = 3 + phase * 11;
      final point = center + Offset(cos(angle), sin(angle)) * radius;
      final color =
          (i.isEven ? const Color(0xFF63C7FF) : const Color(0xFFE0FAFF))
              .withValues(alpha: .95 - phase * .55);
      final extent = 1 + (1 - phase) * 1.6;
      canvas.drawCircle(
        point,
        extent + 1,
        Paint()
          ..color = color.withValues(alpha: .4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(point, extent, Paint()..color = color);
      if (i % 3 == 0) {
        final paint = Paint()
          ..color = color
          ..strokeWidth = 1;
        canvas.drawLine(
          point - Offset(extent + 1.5, 0),
          point + Offset(extent + 1.5, 0),
          paint,
        );
        canvas.drawLine(
          point - Offset(0, extent + 1.5),
          point + Offset(0, extent + 1.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_XpRewardParticlesPainter oldDelegate) =>
      animation != oldDelegate.animation;
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

  Offset? _activeRewardCenter() {
    final source = _activeRewardKey.currentContext?.findRenderObject();
    if (source is! RenderBox || !source.hasSize) return null;
    return source.localToGlobal(source.size.center(Offset.zero));
  }

  Future<void> _playCoinFlight(Offset start, {required bool withXp}) async {
    try {
      await _playRewardCoinFlight(
        context,
        _coinFlightController,
        start,
        withXp: withXp,
      );
    } on TickerCanceled {
      // The popup was closed while its reward animation was running.
    }
  }

  @override
  void dispose() {
    _coinFlightController.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    if (_claiming || !dailyLogin.canClaimToday) return;
    final flightStart = _activeRewardCenter();
    setState(() => _claiming = true);
    final reward = await dailyLogin.claim();
    if (!mounted) return;
    if (reward != null) {
      if (flightStart != null) {
        await _playCoinFlight(flightStart, withXp: reward.xp > 0);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          dismissDirection: DismissDirection.horizontal,
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
    if (mounted) setState(() => _claiming = false);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: dailyLogin,
    builder: (context, _) {
      final currentDay = dailyLogin.displayDay;
      return LayoutBuilder(
        builder: (context, bounds) {
          const gap = 8.0;
          const finalRewardScale = 1.5;
          const cardWidth = 104.0;
          const cardHeight = 236.0;
          final portrait =
              MediaQuery.sizeOf(context).width <
              MediaQuery.sizeOf(context).height;
          final contentWidth = portrait
              ? cardWidth * 3 + gap * 2
              : cardWidth * 7.5 + gap * 6;
          final contentHeight = portrait
              ? cardHeight * 3 + gap * 2
              : cardHeight;
          final cards = Wrap(
            alignment: WrapAlignment.center,
            spacing: gap,
            runSpacing: gap,
            children: List.generate(dailyLoginRewards.length, (index) {
              final day = index + 1;
              final reward = dailyLoginRewards[index];
              final active = day == currentDay;
              final completed = dailyLogin.isDayClaimed(day);
              return GestureDetector(
                key: ValueKey('daily-login-day-$day'),
                onTap: active && dailyLogin.canClaimToday && !_claiming
                    ? _claim
                    : null,
                behavior: HitTestBehavior.opaque,
                child: DailyLoginRewardCard(
                  key: active ? _activeRewardKey : null,
                  day: day,
                  reward: reward,
                  active: active,
                  completed: completed,
                  tomorrow: !dailyLogin.canClaimToday && day == currentDay + 1,
                  width:
                      cardWidth *
                      (day == dailyLoginRewards.length ? finalRewardScale : 1),
                  height: cardHeight,
                ),
              );
            }),
          );
          return Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: contentWidth,
                height: contentHeight,
                child: cards,
              ),
            ),
          );
        },
      );
    },
  );
}

class _FeatureEntry {
  final String? id;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;

  const _FeatureEntry(
    this.icon,
    this.title,
    this.subtitle,
    this.badge, {
    this.id,
  });
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
      constraints: compact ? const BoxConstraints(minHeight: 40) : null,
      margin: EdgeInsets.only(bottom: compact ? 7 : 9),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 13,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: entry.badge == 'YENİ'
              ? 0.13
              : onTap == null
              ? 0.055
              : 0.085,
        ),
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
            size: compact ? 20 : 25,
          ),
          SizedBox(width: compact ? 8 : 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    color: OkeyColors.cream,
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (entry.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.subtitle,
                    maxLines: compact ? 2 : null,
                    overflow: compact ? TextOverflow.ellipsis : null,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: compact ? 10.5 : 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (entry.badge != null && entry.badge != 'YENİ') ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: OkeyColors.gold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                entry.badge!,
                style: const TextStyle(
                  color: OkeyColors.goldLight,
                  fontSize: 10,
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

class _MissionPanel extends StatefulWidget {
  final Future<void> Function(int)? onReward;
  const _MissionPanel({this.onReward});
  @override
  State<_MissionPanel> createState() => _MissionPanelState();
}

class _MissionPanelState extends State<_MissionPanel>
    with TickerProviderStateMixin {
  final Map<String, AnimationController> _flights = {};
  final List<GlobalKey> _claimKeys = List.generate(3, (_) => GlobalKey());
  final Set<String> _claiming = {};
  final Set<String> _removing = {};

  @override
  void initState() {
    super.initState();
    // A previously interrupted claim has already credited its coins.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final mission in progressNotifications.missions) {
        if (mission.claimed) {
          progressNotifications.replaceClaimedMission(mission.id);
        }
      }
    });
  }

  Future<void> _claim(DailyMission mission) async {
    if (_claiming.contains(mission.id)) return;
    final box = _claimKeys[mission.slot].currentContext?.findRenderObject();
    final start = box is RenderBox
        ? box.localToGlobal(box.size.center(Offset.zero))
        : null;
    final reward = progressNotifications.claimMission(mission.id);
    if (reward == null) return;
    final flight = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _flights[mission.id] = flight;
    setState(() => _claiming.add(mission.id));
    try {
      if (start != null) await _playRewardCoinFlight(context, flight, start);
      if (!mounted) return;
      if (widget.onReward != null) {
        unawaited(widget.onReward!(reward.reward));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          dismissDirection: DismissDirection.horizontal,
          content: Text('+${reward.reward} Altın kazandın'),
          backgroundColor: OkeyColors.tableMid,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _removing.add(mission.id));
      await Future<void>.delayed(const Duration(milliseconds: 180));
    } on TickerCanceled {
      // Coins were credited once; finalize the replacement on dismissal.
    } finally {
      _flights.remove(mission.id)?.dispose();
      progressNotifications.replaceClaimedMission(mission.id);
      if (mounted) {
        setState(() {
          _claiming.remove(mission.id);
          _removing.remove(mission.id);
        });
      }
    }
  }

  @override
  void dispose() {
    for (final flight in _flights.values) {
      flight.dispose();
    }
    _flights.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progressNotifications,
    builder: (context, _) => Padding(
      key: const ValueKey('mission-card-inset'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const DailyChallengeCard(),
          for (final mission in progressNotifications.missions)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              reverseDuration: Duration.zero,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.12, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: AnimatedOpacity(
                key: ValueKey('mission-generation-${mission.id}'),
                opacity: _removing.contains(mission.id) ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: AnimatedSlide(
                  offset: _removing.contains(mission.id)
                      ? const Offset(-0.12, 0)
                      : Offset.zero,
                  duration: const Duration(milliseconds: 180),
                  child: _MissionEntryCard(
                    entry: _FeatureEntry(
                      mission.complete
                          ? Icons.task_alt_rounded
                          : Icons.casino_rounded,
                      mission.title,
                      'Ödül: ${mission.reward} altın',
                      '${mission.current}/${mission.target}',
                    ),
                    claimKey: _claimKeys[mission.slot],
                    claimed: mission.claimed,
                    onClaim:
                        mission.complete &&
                            !mission.claimed &&
                            !_claiming.contains(mission.id)
                        ? () => _claim(mission)
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _MissionEntryCard extends StatelessWidget {
  final _FeatureEntry entry;
  final GlobalKey? claimKey;
  final VoidCallback? onClaim;
  final bool claimed;

  const _MissionEntryCard({
    required this.entry,
    this.claimKey,
    this.onClaim,
    this.claimed = false,
  });

  @override
  Widget build(BuildContext context) {
    final values = entry.badge?.split('/') ?? const <String>[];
    final current = values.isNotEmpty ? int.tryParse(values.first) ?? 0 : 0;
    final target = values.length > 1 ? int.tryParse(values[1]) ?? 1 : 1;
    final progress = (current / max(1, target)).clamp(0.0, 1.0);
    final rewardText = entry.subtitle.replaceFirst('Ödül:', '').trim();
    return LayoutBuilder(
      builder: (context, bounds) => Container(
        key: ValueKey('mission-progress-${entry.title}'),
        constraints: const BoxConstraints(minHeight: 40),
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0B2D22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OkeyColors.gold.withValues(alpha: .34)),
        ),
        child: Row(
          children: [
            Icon(entry.icon, color: OkeyColors.goldLight, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: OkeyColors.cream,
                      fontSize: 13,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Image.asset('images/ui/coin.png', width: 12, height: 12),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          rewardText,
                          key: ValueKey('mission-reward-${entry.title}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: OkeyColors.goldLight,
                            fontSize: 10,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            key: ValueKey(
                              'mission-progress-bar-${entry.title}',
                            ),
                            value: progress,
                            minHeight: 5,
                            backgroundColor: Colors.black38,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              OkeyColors.gold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (current >= target) ...[
              const SizedBox(width: 8),
              SizedBox(
                key: claimKey,
                width: bounds.maxWidth < 300 ? 64 : 80,
                child: FilledButton(
                  key: ValueKey('mission-claim-${entry.title}'),
                  onPressed: onClaim,
                  style: FilledButton.styleFrom(
                    backgroundColor: claimed
                        ? const Color(0xFF2E7D32)
                        : OkeyColors.goldLight,
                    foregroundColor: claimed
                        ? Colors.white
                        : OkeyColors.buttonBrown,
                    disabledBackgroundColor: claimed
                        ? const Color(0xFF2E7D32)
                        : null,
                    disabledForegroundColor: claimed ? Colors.white : null,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    elevation: 4,
                    shadowColor: Colors.black87,
                  ),
                  child: Text(
                    claimed ? 'ALINDI ✓' : 'ÖDÜLÜ AL',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ],
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

class _HomePlayActions extends StatelessWidget {
  final VoidCallback onNew;
  final VoidCallback onResume;
  const _HomePlayActions({required this.onNew, required this.onResume});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: savedGame,
    builder: (context, _) => savedGame.hasGame
        ? SizedBox(
            width: 318,
            child: Row(
              key: const ValueKey('home-resume-actions'),
              children: [
                Expanded(child: _HemenOynaButton(onTap: onNew, compact: true)),
                const SizedBox(width: 10),
                Expanded(
                  child: _HemenOynaButton(
                    onTap: onResume,
                    resume: true,
                    compact: true,
                  ),
                ),
              ],
            ),
          )
        : _HemenOynaButton(onTap: onNew),
  );
}

class _HemenOynaButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool resume;
  final bool compact;
  const _HemenOynaButton({
    required this.onTap,
    this.resume = false,
    this.compact = false,
  });

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
          scale: _pressScale.value * (widget.compact ? 1 : _pulseScale.value),
          child: child,
        ),
        child: GestureDetector(
          onTapDown: (_) => _pressController.forward(),
          onTapUp: (_) async {
            await _pressController.reverse();
            widget.onTap();
          },
          onTapCancel: () => _pressController.reverse(),
          child: SizedBox(
            width: 318,
            height: 60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const AppHomeButtonArtwork(play: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.resume
                            ? appText('DEVAM ET', 'CONTINUE')
                            : appText('HEMEN OYNA', 'PLAY NOW'),
                        maxLines: 1,
                        style: TextStyle(
                          color: const Color(0xFFFFF4E8),
                          fontSize: widget.compact ? 17 : 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.25,
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
        'görseller/icon/oyun_modlari_kompakt.png',
        appText('OYUN\nMODLARI', 'GAME\nMODES', german: 'SPIEL\nMODI'),
        appText(
          'Kuralı Sen Belirle, zamanlı, renkli ve katlamalı oyun seçeneklerini buradan seçebilirsin.',
          'Choose Set Your Rules, Timed, Color Bonus or Progressive mode.',
        ),
      ),
      (
        Icons.emoji_events_rounded,
        'images/ui/icons/turnuva.png',
        appText('LİG', 'LEAGUE'),
        appText(
          'Hemen Oyna ile süre bitene kadar günlük ligde yarış, sıralamanı ve ödüllerini takip et.',
          'Play 20 daily rounds with Play Now and follow standings and rewards.',
        ),
      ),
      (
        Icons.task_alt_rounded,
        'images/ui/icons/gorevler.png',
        appText('GÖREVLER', 'MISSIONS'),
        appText(
          'Günlük görevlerini tamamlayarak altın ve tecrübe kazanabilirsin.',
          'Complete daily missions to earn coins and experience.',
        ),
      ),
    ];

    Widget buttonAt(int index) {
      final (icon, assetPath, label, description) = buttons[index];
      final button = _RightSideButton(
        key: index == 3 ? const ValueKey('home-missions-button') : null,
        icon: icon,
        assetPath: assetPath,
        label: label,
        showIcon: true,
        onTap: index == 0
            ? onSelectRoom
            : index == 1
            ? onSelectMode
            : index == 2
            ? onTournament
            : () => onOpen(icon, 'GÖREVLER', description),
      );
      if (index != 3) return button;
      return AnimatedBuilder(
        animation: progressNotifications,
        child: button,
        builder: (context, child) {
          final count = progressNotifications.missions
              .where((mission) => mission.complete && !mission.claimed)
              .length;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              child!,
              if (count > 0)
                Positioned(
                  top: -6,
                  right: -4,
                  child: IgnorePointer(
                    child: Container(
                      key: const ValueKey('home-missions-badge'),
                      constraints: const BoxConstraints(
                        minWidth: 23,
                        minHeight: 23,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE62424),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                      child: Text(
                        '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, bounds) {
        if (bounds.maxWidth < 400) {
          return Column(
            children: [
              for (final index in [3, 1, 0, 2])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: buttonAt(index),
                  ),
                ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: buttonAt(3)),
                const SizedBox(width: 8),
                Expanded(child: buttonAt(1)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: buttonAt(0)),
                const SizedBox(width: 8),
                Expanded(child: buttonAt(2)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RightSideButton extends StatefulWidget {
  final IconData icon;
  final String? assetPath;
  final String label;
  final VoidCallback onTap;
  final bool showIcon;

  const _RightSideButton({
    super.key,
    required this.icon,
    this.assetPath,
    required this.label,
    required this.onTap,
    this.showIcon = true,
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
        child: SizedBox(
          width: 220,
          height: 68,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const AppHomeButtonArtwork(play: false),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: double.infinity,
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
                    if (widget.showIcon) ...[
                      const SizedBox(width: 8),
                      Container(
                        key: ValueKey('home-action-icon-${widget.label}'),
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(2),
                        child: widget.assetPath == null
                            ? Icon(
                                widget.icon,
                                color: OkeyColors.goldLight,
                                size: 32,
                              )
                            : Image.asset(
                                widget.assetPath!,
                                fit: BoxFit.contain,
                                cacheWidth: 168,
                                filterQuality: FilterQuality.medium,
                              ),
                      ),
                    ],
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
