import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game.dart' as game;
import 'oda.dart' as oda;
import 'tournament.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(settings.fontScale),
              ),
              child: appChild ?? const SizedBox.shrink(),
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
          pageBuilder: (_, _, _) => const MainMenuScreen(),
          transitionDuration: const Duration(milliseconds: 500),
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
    with SingleTickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late Animation<double> _fadeIn;
  _MenuSettings _settings = _appSettings.value;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(
      parent: _enterCtrl,
      curve: Curves.easeOut,
    ).drive(Tween<double>(begin: 0.0, end: 1.0));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigateToGame() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const game.GameScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ),
      ),
    );
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _navigateToRoomSelect() async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const oda.RoomSelectScreen(),
        transitionDuration: const Duration(milliseconds: 420),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _navigateToTournament() async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const TournamentScreen(),
        transitionDuration: const Duration(milliseconds: 480),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _openFeaturePopup({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '$title penceresini kapat',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) =>
          _FeatureDialog(icon: icon, title: title, description: description),
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.84, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _openSettings() async {
    final updatedSettings = await showGeneralDialog<_MenuSettings>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Ayarları kapat',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => _SettingsDialog(initial: _settings),
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.82, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (updatedSettings != null && mounted) {
      setState(() => _settings = updatedSettings);
      _appSettings.value = updatedSettings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OkeyColors.tableDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'images/anamenu/menubg.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.08)),
          ),

          // Ana içerik
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Stack(
                children: [
                  // ── Sol üst: Seviye rozeti + Profil ─────────────────
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _ProfileChip(
                      onTap: () => _openFeaturePopup(
                        icon: Icons.person_rounded,
                        title: 'PROFİLİM',
                        description: 'Oyuncu bilgilerin, seviyen, başarıların ve istatistiklerin burada gösterilecek.',
                      ),
                    ),
                  ),

                  // ── Sağ üst: Coin + İkon butonları ──────────────────
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _TopRightBar(
                      onSettings: _openSettings,
                      onWallet: () => _openFeaturePopup(
                        icon: Icons.monetization_on_rounded,
                        title: 'CÜZDAN',
                        description: 'Jeton bakiyen, günlük ödüllerin ve mağaza işlemlerin burada yer alacak.',
                      ),
                      onMessages: () => _openFeaturePopup(
                        icon: Icons.mail_rounded,
                        title: 'GELEN KUTUSU',
                        description: 'Sistem mesajların, ödül bildirimlerin ve arkadaş mesajların burada gösterilecek.',
                      ),
                    ),
                  ),

                  // ── Merkez: Logo + Taşlar + HEMEN OYNA ──────────────
                  // Sağ sütun için 200px yer bırak
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 200),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _BigLogo(),
                          const SizedBox(height: 22),
                          const _MenuTileRow(),
                          const SizedBox(height: 22),
                          _HemenOynaButton(onTap: _navigateToGame),
                        ],
                      ),
                    ),
                  ),

                  // ── Sağ sütun: 4 dikey buton ────────────────────────
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: 196,
                    child: _RightButtonColumn(
                      onSelectRoom: _navigateToRoomSelect,
                      onTournament: _navigateToTournament,
                      onOpen: (icon, title, description) => _openFeaturePopup(
                        icon: icon,
                        title: title,
                        description: description,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sol Üst Profil Chip ──────────────────────────────────────────────────────
class _ProfileChip extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seviye rozeti (yuvarlak)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: OkeyColors.buttonBrown,
              shape: BoxShape.circle,
              border: Border.all(color: OkeyColors.gold, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: OkeyColors.gold.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '9',
                style: TextStyle(
                  color: OkeyColors.goldLight,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar + isim + yıldız puanı + rozet
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: OkeyColors.gold.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: OkeyColors.tableMid,
                    border: Border.all(color: OkeyColors.gold, width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person,
                      color: OkeyColors.cream,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Evren',
                      style: TextStyle(
                        color: OkeyColors.cream,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: OkeyColors.gold,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '12.350',
                          style: const TextStyle(
                            color: OkeyColors.goldLight,
                            fontSize: 11,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: OkeyColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '101',
                        style: TextStyle(
                          color: OkeyColors.goldLight,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sağ Üst Bar (Coin + İkonlar) ────────────────────────────────────────────
class _TopRightBar extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onWallet;
  final VoidCallback onMessages;
  const _TopRightBar({
    required this.onSettings,
    required this.onWallet,
    required this.onMessages,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Coin chip
        GestureDetector(
          onTap: onWallet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: OkeyColors.gold, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: OkeyColors.gold,
                  size: 18,
                ),
                const SizedBox(width: 5),
                const Text(
                  '25.600',
                  style: TextStyle(
                    color: OkeyColors.cream,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.add_circle,
                  color: OkeyColors.goldLight,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // İkon butonları
        _IconBtn(icon: Icons.mail_outlined, onTap: onMessages),
        const SizedBox(width: 6),
        _IconBtn(icon: Icons.settings_outlined, onTap: onSettings),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: OkeyColors.gold.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Icon(icon, color: OkeyColors.cream, size: 18),
      ),
    );
  }
}

// ─── Büyük 101 OKEY Logosu ────────────────────────────────────────────────────
class _FeatureDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureDialog({
    required this.icon,
    required this.title,
    required this.description,
  });

  List<_FeatureEntry> get _entries => switch (title) {
    'PROFİLİM' => const [
      _FeatureEntry(
        Icons.military_tech_rounded,
        'Seviye 18',
        '12.450 / 15.000 XP',
        '83%',
      ),
      _FeatureEntry(
        Icons.sports_esports_rounded,
        '64 oyun',
        '37 galibiyet · 27 mağlubiyet',
        null,
      ),
      _FeatureEntry(
        Icons.trending_up_rounded,
        'Kazanma Oranı',
        '%58 · En iyi seri: 6',
        null,
      ),
      _FeatureEntry(
        Icons.workspace_premium_rounded,
        'Başarımlar',
        'İlk 101 · Seri Ustası · Keskin Göz',
        null,
      ),
    ],
    'CÜZDAN' => const [
      _FeatureEntry(
        Icons.monetization_on_rounded,
        '25.600 Jeton',
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
        'Son İşlem',
        'Masa ödülü · +1.250 jeton',
        null,
      ),
    ],
    'GELEN KUTUSU' => const [
      _FeatureEntry(
        Icons.card_giftcard_rounded,
        'Günlük ödülün hazır',
        'Bugün · Ödülünü almayı unutma',
        null,
      ),
      _FeatureEntry(
        Icons.emoji_events_rounded,
        'Turnuva duyurusu',
        'Akşam Kupası saat 20.00’de başlıyor',
        null,
      ),
      _FeatureEntry(
        Icons.waving_hand_rounded,
        'Hoş geldin!',
        '101 Okey masalarında bol şans',
        null,
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
        Icons.groups_2_rounded,
        'Eşli 101',
        'Takımınla birlikte mücadele et',
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
    final maxHeight = max(
      300.0,
      min(590.0, MediaQuery.sizeOf(context).height - 32),
    );
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: 430, maxHeight: maxHeight),
          margin: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: OkeyColors.tableDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: OkeyColors.gold, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.68),
                blurRadius: 30,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: OkeyColors.gold.withValues(alpha: 0.14),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 8, 8),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: OkeyColors.gold.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: OkeyColors.goldLight.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Icon(icon, color: OkeyColors.goldLight, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: OkeyColors.cream,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: OkeyColors.gold.withValues(alpha: 0.25),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                  child: Column(
                    children: [
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ..._entries.map(
                        (entry) => _FeatureEntryCard(entry: entry),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: OkeyColors.gold,
                      foregroundColor: OkeyColors.buttonBrown,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'TAMAM',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
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

class _FeatureEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;

  const _FeatureEntry(this.icon, this.title, this.subtitle, this.badge);
}

class _FeatureEntryCard extends StatelessWidget {
  final _FeatureEntry entry;

  const _FeatureEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: OkeyColors.gold.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        Icon(entry.icon, color: OkeyColors.goldLight, size: 22),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: const TextStyle(
                  color: OkeyColors.cream,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                entry.subtitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10.5,
                  height: 1.3,
                ),
              ),
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
  );
}

class _MenuSettings {
  final bool soundEffects;
  final bool music;
  final bool vibration;
  final bool notifications;
  final bool animations;
  final double fontScale;

  const _MenuSettings({
    this.soundEffects = true,
    this.music = true,
    this.vibration = true,
    this.notifications = true,
    this.animations = true,
    this.fontScale = 1,
  });

  _MenuSettings copyWith({
    bool? soundEffects,
    bool? music,
    bool? vibration,
    bool? notifications,
    bool? animations,
    double? fontScale,
  }) {
    return _MenuSettings(
      soundEffects: soundEffects ?? this.soundEffects,
      music: music ?? this.music,
      vibration: vibration ?? this.vibration,
      notifications: notifications ?? this.notifications,
      animations: animations ?? this.animations,
      fontScale: fontScale ?? this.fontScale,
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

  @override
  void initState() {
    super.initState();
    _settings = widget.initial;
  }

  String get _fontScaleLabel {
    if (_settings.fontScale < 0.95) return 'Küçük';
    if (_settings.fontScale > 1.12) return 'Büyük';
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: min(screenHeight - 32, 610),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: OkeyColors.tableDark,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: OkeyColors.gold, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: OkeyColors.gold.withValues(alpha: 0.15),
                  blurRadius: 24,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('SES VE GERİ BİLDİRİM'),
                          _settingSwitch(
                            icon: Icons.volume_up_rounded,
                            title: 'Ses Efektleri',
                            subtitle: 'Taş ve buton sesleri',
                            value: _settings.soundEffects,
                            onChanged: (value) => setState(() {
                              _settings = _settings.copyWith(
                                soundEffects: value,
                              );
                            }),
                          ),
                          _settingSwitch(
                            icon: Icons.music_note_rounded,
                            title: 'Arka Plan Müziği',
                            subtitle: 'Menü ve oyun müzikleri',
                            value: _settings.music,
                            onChanged: (value) => setState(() {
                              _settings = _settings.copyWith(music: value);
                            }),
                          ),
                          _settingSwitch(
                            icon: Icons.vibration_rounded,
                            title: 'Titreşim',
                            subtitle: 'Hamlelerde dokunsal geri bildirim',
                            value: _settings.vibration,
                            onChanged: (value) => setState(() {
                              _settings = _settings.copyWith(vibration: value);
                            }),
                          ),
                          const SizedBox(height: 14),
                          _sectionTitle('GÖRÜNÜM'),
                          _buildFontScaleSetting(),
                          _settingSwitch(
                            icon: Icons.animation_rounded,
                            title: 'Akıcı Animasyonlar',
                            subtitle: 'Geçiş ve taş animasyonları',
                            value: _settings.animations,
                            onChanged: (value) => setState(() {
                              _settings = _settings.copyWith(animations: value);
                            }),
                          ),
                          const SizedBox(height: 14),
                          _sectionTitle('BİLDİRİMLER'),
                          _settingSwitch(
                            icon: Icons.notifications_active_outlined,
                            title: 'Bildirimler',
                            subtitle: 'Turnuva ve ödül hatırlatmaları',
                            value: _settings.notifications,
                            onChanged: (value) => setState(() {
                              _settings = _settings.copyWith(
                                notifications: value,
                              );
                            }),
                          ),
                        ],
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
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            OkeyColors.tableMid,
            OkeyColors.tableDark.withValues(alpha: 0.96),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: OkeyColors.gold.withValues(alpha: 0.45)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: OkeyColors.gold.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: OkeyColors.gold.withValues(alpha: 0.55),
              ),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: OkeyColors.goldLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AYARLAR',
                  style: TextStyle(
                    color: OkeyColors.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Oyun deneyimini kişiselleştir',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kapat',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: OkeyColors.goldLight,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.3,
        ),
      ),
    );
  }

  Widget _settingSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(12, 7, 5, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value ? OkeyColors.goldLight : Colors.white38,
            size: 19,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: OkeyColors.cream,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: OkeyColors.goldLight,
            activeTrackColor: OkeyColors.gold.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }

  Widget _buildFontScaleSetting() {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.text_fields_rounded,
                color: OkeyColors.goldLight,
                size: 19,
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Yazı Boyutu',
                  style: TextStyle(
                    color: OkeyColors.cream,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _fontScaleLabel,
                style: const TextStyle(
                  color: OkeyColors.goldLight,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: OkeyColors.gold,
              inactiveTrackColor: Colors.white12,
              thumbColor: OkeyColors.goldLight,
              overlayColor: OkeyColors.gold.withValues(alpha: 0.15),
              trackHeight: 3,
            ),
            child: Slider(
              value: _settings.fontScale,
              min: 0.85,
              max: 1.25,
              divisions: 4,
              onChanged: (value) => setState(() {
                _settings = _settings.copyWith(fontScale: value);
              }),
            ),
          ),
          Text(
            '101 Okey yazı önizlemesi',
            textScaler: TextScaler.linear(_settings.fontScale),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontFamily: 'Georgia',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        border: Border(
          top: BorderSide(color: OkeyColors.gold.withValues(alpha: 0.25)),
        ),
      ),
      child: OverflowBar(
        alignment: MainAxisAlignment.spaceBetween,
        overflowAlignment: OverflowBarAlignment.center,
        spacing: 8,
        overflowSpacing: 8,
        children: [
          TextButton(
            onPressed: () => setState(() {
              _settings = const _MenuSettings();
            }),
            child: const Text(
              'Varsayılana Dön',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_settings),
            style: FilledButton.styleFrom(
              backgroundColor: OkeyColors.gold,
              foregroundColor: OkeyColors.buttonBrown,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text(
              'KAYDET',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            OkeyColors.tableMid.withValues(alpha: 0.95),
            OkeyColors.tableDark.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: OkeyColors.gold.withValues(alpha: 0.65),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: OkeyColors.gold.withValues(alpha: 0.2),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '101',
            style: TextStyle(
              color: OkeyColors.goldLight,
              fontSize: 58,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
              letterSpacing: 6,
              height: 1.0,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: OkeyColors.gold.withValues(alpha: 0.7),
                  width: 1,
                ),
                bottom: BorderSide(
                  color: OkeyColors.gold.withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
            ),
            child: const Text(
              'OKEY',
              style: TextStyle(
                color: OkeyColors.cream,
                fontSize: 20,
                letterSpacing: 10,
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Orta Taş Sırası (7, 10, 13) ─────────────────────────────────────────────
class _MenuTileRow extends StatelessWidget {
  const _MenuTileRow();

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (OkeyColors.blackTile, '7'),
      (OkeyColors.redTile, '10'),
      (OkeyColors.blueTile, '13'),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: tiles.map((t) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 50,
          height: 68,
          decoration: BoxDecoration(
            color: OkeyColors.cream,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: OkeyColors.creamDark, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 6,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              t.$2,
              style: TextStyle(
                color: t.$1,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── HEMEN OYNA Butonu ────────────────────────────────────────────────────────
class _HemenOynaButton extends StatefulWidget {
  final VoidCallback onTap;
  const _HemenOynaButton({required this.onTap});

  @override
  State<_HemenOynaButton> createState() => _HemenOynaButtonState();
}

class _HemenOynaButtonState extends State<_HemenOynaButton>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _pulseController;
  late Animation<double> _pressScale;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _pressScale = _pressController.drive(Tween<double>(begin: 1.0, end: 0.95));
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1700),
      vsync: this,
    )..repeat(reverse: true);
    _pulseScale = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ).drive(Tween<double>(begin: 1.0, end: 1.03));
  }

  @override
  void dispose() {
    _pressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
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
          width: 210,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFF5A260B), Color(0xFF2A0E05), Color(0xFF481A08)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: OkeyColors.goldLight, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.68),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
              BoxShadow(
                color: OkeyColors.gold.withValues(alpha: 0.32),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'HEMEN OYNA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sağ Sütun 4 Buton ───────────────────────────────────────────────────────
class _RightButtonColumn extends StatelessWidget {
  final VoidCallback onSelectRoom;
  final VoidCallback onTournament;
  final void Function(IconData icon, String title, String description) onOpen;
  const _RightButtonColumn({
    required this.onSelectRoom,
    required this.onTournament,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = [
      (
        Icons.people_alt_outlined,
        'ODA SEÇ',
        'Aktif masaları, oyuncu sayılarını ve giriş ücretlerini buradan inceleyebilirsin.',
      ),
      (
        Icons.lock_outline,
        'OYUN MODLARI',
        'Klasik 101, eşli oyun ve farklı masa kurallarını buradan seçebilirsin.',
      ),
      (
        Icons.emoji_events_outlined,
        'TURNUVALAR',
        'Yaklaşan turnuvalar, ödül havuzları ve sıralamalar burada gösterilecek.',
      ),
      (
        Icons.task_alt_rounded,
        'GÖREVLER',
        'Günlük ve haftalık görevlerini tamamlayarak jeton ve özel ödüller kazanabilirsin.',
      ),
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 14, left: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(buttons.length, (i) {
            final (icon, label, description) = buttons[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i < buttons.length - 1 ? 10 : 0),
              child: _RightSideButton(
                icon: icon,
                label: label,
                onTap: i == 0
                    ? onSelectRoom
                    : i == 2
                    ? onTournament
                    : () => onOpen(icon, label, description),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _RightSideButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RightSideButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_RightSideButton> createState() => _RightSideButtonState();
}

class _RightSideButtonState extends State<_RightSideButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scale = _ctrl.drive(Tween<double>(begin: 1.0, end: 0.93));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) async {
          await _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: Container(
          width: 172,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.65),
                OkeyColors.buttonBrown.withValues(alpha: 0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: OkeyColors.gold.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: OkeyColors.gold.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: OkeyColors.gold, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      style: const TextStyle(
                        color: OkeyColors.cream,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        letterSpacing: 0.8,
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
