import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const OkeyApp());
}

// ─── Renk Paleti ───────────────────────────────────────────────────────────────
class OkeyColors {
  static const Color tableMid     = Color(0xFF1A3A2A);   // koyu yeşil masa
  static const Color tableDark    = Color(0xFF0F2219);   // kenar karanlık
  static const Color tableLight   = Color(0xFF245235);   // hafif aydınlık
  static const Color gold         = Color(0xFFD4A017);   // altın vurgu
  static const Color goldLight    = Color(0xFFF0CC5A);   // parlak altın
  static const Color goldDark     = Color(0xFF9A7010);   // koyu altın
  static const Color cream        = Color(0xFFF5EDD6);   // taş/kemik rengi
  static const Color creamDark    = Color(0xFFD9C9A0);   // koyu krem
  static const Color buttonBrown  = Color(0xFF5C3A1E);   // ahşap buton
  static const Color buttonBorder = Color(0xFF8B5E2A);   // buton kenarlık
  static const Color redTile      = Color(0xFFCC2222);   // kırmızı taş
  static const Color blueTile     = Color(0xFF1A3A8A);   // mavi taş
  static const Color blackTile    = Color(0xFF1A1A1A);   // siyah taş
  static const Color yellowTile   = Color(0xFFCC8800);   // sarı taş
}

// ─── Ana Uygulama ─────────────────────────────────────────────────────────────
class OkeyApp extends StatelessWidget {
  const OkeyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '101 Okey',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Georgia',
        scaffoldBackgroundColor: OkeyColors.tableDark,
      ),
      home: const SplashScreen(),
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

    // Logo giriş animasyonu
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _logoScale = CurvedAnimation(parent: _logoController, curve: Curves.elasticOut)
        .drive(Tween<double>(begin: 0.3, end: 1.0));
    _logoOpacity = CurvedAnimation(parent: _logoController, curve: Curves.easeIn)
        .drive(Tween<double>(begin: 0.0, end: 1.0));

    // Parıltı döngüsü
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _shimmerAnim = _shimmerController.drive(Tween<double>(begin: -1.0, end: 2.0));

    // Sahne geçişi
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
          pageBuilder: (_, __, ___) => const MainMenuScreen(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, anim, __, child) =>
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
      builder: (context, child) => Opacity(
        opacity: _fadeOut.value,
        child: child,
      ),
      child: Scaffold(
        backgroundColor: OkeyColors.tableDark,
        body: Stack(
          children: [
            // Arka plan desen
            const _TablePattern(),
            // İçerik
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Taş görseli üstte
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, _) => Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: const _OkeyTileGroup(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  // Logo yazısı + parıltı
                  AnimatedBuilder(
                    animation: Listenable.merge([_logoController, _shimmerController]),
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
                  // Yükleniyor göstergesi
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

    // Vinyasa tarzı halka deseni
    final paintRing = Paint()
      ..color = OkeyColors.tableLight.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final cx = size.width / 2;
    final cy = size.height / 2;
    for (double r = 60; r < size.width * 1.2; r += 55) {
      canvas.drawCircle(Offset(cx, cy), r, paintRing);
    }

    // Köşe vurguları
    final paintCorner = Paint()
      ..color = OkeyColors.gold.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final inset = 24.0;
    final rr = 20.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
        Radius.circular(rr),
      ),
      paintCorner,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Okey Taş Grubu ───────────────────────────────────────────────────────────
class _OkeyTileGroup extends StatelessWidget {
  const _OkeyTileGroup();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arka taşlar (gölge efekti)
          Positioned(left: 0, top: 10,
            child: Transform.rotate(angle: -0.25, child: _buildTile(OkeyColors.blueTile, '5', shadow: true))),
          Positioned(right: 0, top: 10,
            child: Transform.rotate(angle: 0.25, child: _buildTile(OkeyColors.redTile, '7', shadow: true))),
          // Orta taş (joker / büyük)
          Center(child: _buildJokerTile()),
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
        boxShadow: shadow ? [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(2, 4)),
        ] : [],
      ),
      child: Center(
        child: Text(number,
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
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 12, offset: const Offset(0, 6)),
          BoxShadow(color: OkeyColors.gold.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 0)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('★', style: TextStyle(color: OkeyColors.gold, fontSize: 26)),
          Text('OK', style: TextStyle(
            color: OkeyColors.blackTile,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Georgia',
            letterSpacing: 2,
          )),
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
            colors: [
              OkeyColors.gold,
              OkeyColors.goldLight,
              OkeyColors.gold,
            ],
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
                color: OkeyColors.gold.withOpacity(opacity),
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
// ANA MENÜ EKRANI
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
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut)
        .drive(Tween<double>(begin: 0.0, end: 1.0));
    _slideIn = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut)
        .drive(Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OkeyColors.tableDark,
      body: Stack(
        children: [
          const _TablePattern(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideIn,
                child: Column(
                  children: [
                    // ── Üst Logo ──────────────────────
                    const SizedBox(height: 32),
                    _buildTopLogo(),
                    const SizedBox(height: 8),
                    _buildSubtitle(),
                    const SizedBox(height: 40),
                    // ── Taş Sıraları ──────────────────
                    _buildTileRow(),
                    const SizedBox(height: 32),
                    // ── Menü Butonları ────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _OkeyButton(
                              label: 'Oyna',
                              icon: Icons.play_arrow_rounded,
                              isPrimary: true,
                              onTap: () => _showSnack(context, 'Oyun başlıyor...'),
                            ),
                            const SizedBox(height: 14),
                            _OkeyButton(
                              label: 'Arkadaşlarla Oyna',
                              icon: Icons.people_rounded,
                              onTap: () => _showSnack(context, 'Arkadaş listesi açılıyor...'),
                            ),
                            const SizedBox(height: 14),
                            _OkeyButton(
                              label: 'Turnuva',
                              icon: Icons.emoji_events_rounded,
                              onTap: () => _showSnack(context, 'Turnuvalar yükleniyor...'),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _OkeyButton(
                                    label: 'Dükkan',
                                    icon: Icons.storefront_rounded,
                                    isSmall: true,
                                    onTap: () => _showSnack(context, 'Dükkan açılıyor...'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _OkeyButton(
                                    label: 'Ayarlar',
                                    icon: Icons.settings_rounded,
                                    isSmall: true,
                                    onTap: () => _showSnack(context, 'Ayarlar açılıyor...'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ── Alt bilgi ─────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'v1.0.0',
                        style: TextStyle(
                          color: OkeyColors.gold.withOpacity(0.35),
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Üst köşe chip'leri
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _CoinChip(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopLogo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '101',
          style: const TextStyle(
            color: OkeyColors.goldLight,
            fontSize: 44,
            fontWeight: FontWeight.bold,
            fontFamily: 'Georgia',
            letterSpacing: 4,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'OKEY',
          style: TextStyle(
            color: OkeyColors.cream,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            fontFamily: 'Georgia',
            letterSpacing: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 3),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: OkeyColors.gold.withOpacity(0.5), width: 1),
          bottom: BorderSide(color: OkeyColors.gold.withOpacity(0.5), width: 1),
        ),
      ),
      child: Text(
        'KLASİK TÜRK TAŞ OYUNU',
        style: TextStyle(
          color: OkeyColors.gold.withOpacity(0.8),
          fontSize: 11,
          letterSpacing: 4,
          fontFamily: 'Georgia',
        ),
      ),
    );
  }

  Widget _buildTileRow() {
    final tiles = [
      (OkeyColors.redTile, '3'),
      (OkeyColors.blackTile, '7'),
      (OkeyColors.blueTile, '11'),
      (OkeyColors.yellowTile, '5'),
      (OkeyColors.redTile, '9'),
      (OkeyColors.blackTile, '2'),
      (OkeyColors.blueTile, '13'),
    ];

    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (color, num) = tiles[i];
          return _MiniTile(color: color, number: num);
        },
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: OkeyColors.cream)),
      backgroundColor: OkeyColors.tableMid,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OkeyColors.gold, width: 1),
      ),
    ));
  }
}

// ─── Mini Taş ─────────────────────────────────────────────────────────────────
class _MiniTile extends StatelessWidget {
  final Color color;
  final String number;

  const _MiniTile({required this.color, required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 56,
      decoration: BoxDecoration(
        color: OkeyColors.cream,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: OkeyColors.creamDark, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(1, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Georgia',
          ),
        ),
      ),
    );
  }
}

// ─── Okey Butonu ──────────────────────────────────────────────────────────────
class _OkeyButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isSmall;

  const _OkeyButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.isSmall = false,
  });

  @override
  State<_OkeyButton> createState() => _OkeyButtonState();
}

class _OkeyButtonState extends State<_OkeyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scale = _pressCtrl.drive(Tween<double>(begin: 1.0, end: 0.95));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.isSmall ? 52.0 : 60.0;

    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) async {
          await _pressCtrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: widget.isPrimary
                ? LinearGradient(
                    colors: [OkeyColors.goldDark, OkeyColors.gold, OkeyColors.goldLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [OkeyColors.buttonBrown.withOpacity(0.9), OkeyColors.buttonBrown],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border.all(
              color: widget.isPrimary ? OkeyColors.goldLight : OkeyColors.buttonBorder,
              width: widget.isPrimary ? 2.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.isPrimary ? OkeyColors.gold : Colors.black).withOpacity(0.3),
                blurRadius: widget.isPrimary ? 12 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                color: widget.isPrimary ? OkeyColors.buttonBrown : OkeyColors.cream,
                size: widget.isSmall ? 20 : 24,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isPrimary ? OkeyColors.buttonBrown : OkeyColors.cream,
                  fontSize: widget.isSmall ? 15 : 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Altın/Coin Chip ──────────────────────────────────────────────────────────
class _CoinChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: OkeyColors.buttonBrown.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OkeyColors.gold, width: 1),
        boxShadow: [
          BoxShadow(
            color: OkeyColors.gold.withOpacity(0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on, color: OkeyColors.gold, size: 18),
          const SizedBox(width: 6),
          const Text(
            '12.500',
            style: TextStyle(
              color: OkeyColors.cream,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),
        ],
      ),
    );
  }
}