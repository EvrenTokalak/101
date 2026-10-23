import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'app_controls.dart';
import 'app_language.dart';

String _helpText(String tr, String en, {String? de}) =>
    appText(tr, en, german: de);

Size gameHelpPanelSize(BoxConstraints bounds) {
  final base = appArtworkPanelSize(bounds);
  return Size(math.min(bounds.maxWidth, base.width * 1.16), base.height);
}

class GameHelpDialog extends StatefulWidget {
  const GameHelpDialog({super.key});

  @override
  State<GameHelpDialog> createState() => _GameHelpDialogState();
}

class _GameHelpDialogState extends State<GameHelpDialog> {
  final PageController _controller = PageController();
  int page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Dialog(
        key: const ValueKey('game-help-dialog'),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, bounds) =>
              _panel(context, gameHelpPanelSize(bounds)),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, Size popupSize) => AppPopupSurface(
    width: popupSize.width,
    height: popupSize.height,
    artworkAsset: appHelpPanelAsset,
    artworkTitle: Text(
      _helpText('NASIL OYNANIR', 'HOW TO PLAY', de: 'SPIELANLEITUNG'),
      maxLines: 1,
      softWrap: false,
    ),
    onOutsideClose: () => Navigator.of(context).pop(),
    closeOnFrame: true,
    padding: EdgeInsets.fromLTRB(
      popupSize.width * .055,
      popupSize.height * .235,
      popupSize.width * .055,
      popupSize.height * .09,
    ),
    child: Column(
      children: [
        Expanded(
          child: ClipRRect(
            key: const ValueKey('help-page-viewport'),
            borderRadius: BorderRadius.circular(12),
            child: PageView(
              controller: _controller,
              physics: const ClampingScrollPhysics(),
              clipBehavior: Clip.hardEdge,
              onPageChanged: (value) => setState(() => page = value),
              children: const [
                RepaintBoundary(child: _QuickGuide()),
                RepaintBoundary(child: _MeldExamples()),
                RepaintBoundary(child: _GeneralRules()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const ValueKey('help-previous'),
                color: const Color(0xFFFFDF74),
                disabledColor: Colors.white38,
                iconSize: 30,
                tooltip: _helpText(
                  'Önceki sayfa',
                  'Previous page',
                  de: 'Vorherige Seite',
                ),
                onPressed: page == 0
                    ? null
                    : () => _controller.previousPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      ),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: 16),
              IconButton(
                key: const ValueKey('help-next'),
                color: const Color(0xFFFFDF74),
                disabledColor: Colors.white38,
                iconSize: 30,
                tooltip: _helpText(
                  'Sonraki sayfa',
                  'Next page',
                  de: 'Nächste Seite',
                ),
                onPressed: page == 2
                    ? null
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      ),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _QuickGuide extends StatelessWidget {
  const _QuickGuide();

  static List<String> get rules => [
    _helpText(
      'Her tur taş çekin; seri için en az 101 puan veya çift için 5 çift toplayın.',
      'Draw each turn; collect 101 meld points or five pairs.',
      de: 'Ziehe pro Zug; sammle 101 Satzpunkte oder fünf Paare.',
    ),
    _helpText(
      'SERİ / ÇİFT DİZ ile taşları düzenleyin; AÇ ile uygun perleri masaya indirin.',
      'Arrange with MELD / PAIRS; use OPEN to lay them on the table.',
      de: 'Ordne mit SATZ / PAARE; öffne passende Sätze am Tisch.',
    ),
    _helpText(
      'Elinizi açtıktan sonra İŞLE ile uygun taşları masadaki açık perlere ekleyin.',
      'After opening, use ADD to extend suitable melds on the table.',
      de: 'Lege nach dem Öffnen passende Steine mit ANLEGEN an.',
    ),
    _helpText(
      'Her turu bir taş atarak tamamlayın; elinizdeki son taşı atarak eli bitirin.',
      'End each turn by discarding; discard your last tile to finish.',
      de: 'Lege am Zugende einen Stein ab; der letzte beendet die Runde.',
    ),
    _helpText(
      'Taşları elle dizebilir, uygun taşları açık perlere sürükleyip bırakarak işleyebilirsiniz.',
      'Reorder tiles by hand or drag matching tiles onto open melds.',
      de: 'Ordne Steine per Hand oder ziehe passende an offene Sätze.',
    ),
  ];

  static double _fontSize(BuildContext context, BoxConstraints bounds) {
    final columnWidth = (bounds.maxWidth - 12) / 2;
    bool fits(double font) {
      final left = rules.fold<double>(
        0,
        (total, rule) =>
            total +
            5 +
            math.max(
              _helpTextHeight(context, rule, font, columnWidth - 25, 1.22),
              (font + 1) * 1.22,
            ),
      );
      final right = _ButtonGuide.controls.fold<double>(
        14,
        (total, control) =>
            total +
            _ButtonGuide.rowHeight(context, columnWidth, control.$4, font),
      );
      return math.max(left, right) <= bounds.maxHeight - 2;
    }

    var lower = 1.0;
    var upper = _GeneralRules._fontSize(context, bounds, _GeneralRules.rules);
    if (fits(upper)) return upper;
    for (var attempt = 0; attempt < 14; attempt++) {
      final font = (lower + upper) / 2;
      if (fits(font)) {
        lower = font;
      } else {
        upper = font;
      }
    }
    return lower;
  }

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('quick-guide-page'),
    padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final fontSize = _fontSize(context, bounds);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: _RuleColumn(
                startIndex: 0,
                keyPrefix: 'quick-rule',
                fontSize: fontSize,
                rules: rules,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _ButtonGuide(fontSize: fontSize)),
          ],
        );
      },
    ),
  );
}

class _ButtonGuide extends StatelessWidget {
  final double fontSize;
  const _ButtonGuide({required this.fontSize});
  static double rowHeight(
    BuildContext context,
    double width,
    String text,
    double font,
  ) =>
      math.max(
        font * 1.6,
        _helpTextHeight(context, text, font, (width - 21) * 6 / 11, 1.05),
      ) +
      2;

  static List<(String, String, String, String)> get controls => [
    (
      'open-run',
      _helpText('SERİ AÇ', 'OPEN MELD', de: 'SATZ ÖFFNEN'),
      'green',
      _helpText(
        'Serileri masaya açar.',
        'Opens your melds.',
        de: 'Öffnet deine Sätze.',
      ),
    ),
    (
      'sort-run',
      _helpText('SERİ DİZ', 'SORT MELDS', de: 'SÄTZE ORDNEN'),
      'green',
      _helpText(
        'Taşları seri dizer.',
        'Sorts tiles into melds.',
        de: 'Ordnet die Sätze.',
      ),
    ),
    (
      'open-pairs',
      _helpText('ÇİFT AÇ', 'OPEN PAIRS', de: 'PAARE ÖFFNEN'),
      'gold',
      _helpText(
        'Çiftleri masaya açar.',
        'Opens your pairs.',
        de: 'Öffnet deine Paare.',
      ),
    ),
    (
      'sort-pairs',
      _helpText('ÇİFT DİZ', 'SORT PAIRS', de: 'PAARE ORDNEN'),
      'gold',
      _helpText(
        'Eş taşları yan yana dizer.',
        'Groups matching tiles.',
        de: 'Ordnet gleiche Steine.',
      ),
    ),
    (
      'process',
      _helpText('İŞLE', 'ADD', de: 'ANLEGEN'),
      'blue',
      _helpText(
        'Açık perlere taş ekler.',
        'Adds tiles to open melds.',
        de: 'Erweitert offene Sätze.',
      ),
    ),
    (
      'draw',
      _helpText('TAŞ ÇEK', 'DRAW', de: 'ZIEHEN'),
      'blue',
      _helpText(
        'Ortadan bir taş çeker.',
        'Draws from the pile.',
        de: 'Zieht vom Stapel.',
      ),
    ),
  ];
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      return Container(
        key: const ValueKey('help-game-controls'),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFF0B352A).withValues(alpha: .85),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFBBA95F).withValues(alpha: .45),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final (index, control) in controls.indexed)
              SizedBox(
                height: rowHeight(
                  context,
                  bounds.maxWidth,
                  control.$4,
                  fontSize,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      if (index.isEven) ...[
                        Expanded(
                          flex: 5,
                          child: _GuideButton(
                            id: control.$1,
                            label: control.$2,
                            color: control.$3,
                          ),
                        ),
                        const SizedBox(width: 7),
                      ],
                      Expanded(
                        flex: 6,
                        child: Text(
                          control.$4,
                          key: ValueKey(
                            'help-control-description-${control.$1}',
                          ),
                          textAlign: index.isEven
                              ? TextAlign.left
                              : TextAlign.right,
                          style: TextStyle(
                            color: const Color(0xFFFFF3CF),
                            fontSize: fontSize,
                            height: 1.05,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (index.isOdd) ...[
                        const SizedBox(width: 7),
                        Expanded(
                          flex: 5,
                          child: _GuideButton(
                            id: control.$1,
                            label: control.$2,
                            color: control.$3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _GuideButton extends StatelessWidget {
  final String id;
  final String label;
  final String color;
  const _GuideButton({
    required this.id,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: true,
    child: DecoratedBox(
      key: ValueKey('help-control-$id'),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('images/ui/action_$color.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: .25,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MeldExamples extends StatelessWidget {
  const _MeldExamples();

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('meld-examples-page'),
    padding: const EdgeInsets.all(8),
    child: Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _ExampleColumn(
                  correct: true,
                  title: _helpText('DOĞRU', 'VALID', de: 'RICHTIG'),
                  examples: const [
                    [(1, Colors.red), (2, Colors.red), (3, Colors.red)],
                    [(11, Colors.blue), (12, Colors.blue), (13, Colors.blue)],
                    [
                      (8, Colors.black),
                      (8, Colors.amber),
                      (8, Colors.red),
                      (8, Colors.blue),
                    ],
                    [
                      (4, Colors.amber),
                      (5, Colors.amber),
                      (6, Colors.amber),
                      (7, Colors.amber),
                    ],
                  ],
                ),
              ),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: Colors.white24,
              ),
              Expanded(
                child: _ExampleColumn(
                  correct: false,
                  title: _helpText('YANLIŞ', 'INVALID', de: 'FALSCH'),
                  examples: const [
                    [(1, Colors.red), (3, Colors.red), (4, Colors.red)],
                    [(12, Colors.blue), (13, Colors.blue), (1, Colors.blue)],
                    [
                      (8, Colors.black),
                      (8, Colors.red),
                      (8, Colors.red),
                      (8, Colors.blue),
                    ],
                    [
                      (4, Colors.amber),
                      (5, Colors.blue),
                      (6, Colors.amber),
                      (7, Colors.amber),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ExampleColumn extends StatelessWidget {
  final bool correct;
  final String title;
  final List<List<(int, Color)>> examples;

  const _ExampleColumn({
    required this.correct,
    required this.title,
    required this.examples,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        title,
        style: TextStyle(
          color: correct ? Colors.greenAccent : Colors.redAccent,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 4),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth,
              height: examples.length * 74,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final tiles in examples) _Example(correct, tiles),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _Example extends StatelessWidget {
  final bool correct;
  final List<(int, Color)> tiles;
  const _Example(this.correct, this.tiles);

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          correct ? Icons.check_rounded : Icons.close_rounded,
          color: correct ? Colors.greenAccent : Colors.redAccent,
          size: 38,
        ),
        const SizedBox(width: 12),
        for (final tile in tiles) _HelpTile(tile.$1, tile.$2),
      ],
    ),
  );
}

class _HelpTile extends StatelessWidget {
  final int number;
  final Color color;
  const _HelpTile(this.number, this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    height: 68,
    margin: const EdgeInsets.only(right: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F0E8),
      borderRadius: BorderRadius.circular(5),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2)),
      ],
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$number',
              style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GeneralRules extends StatelessWidget {
  const _GeneralRules();

  static double _fontSize(
    BuildContext context,
    BoxConstraints bounds,
    List<String> rules,
  ) {
    final textWidth = ((bounds.maxWidth - 19) / 2 - 25).clamp(
      1.0,
      double.infinity,
    );
    final baseStyle = DefaultTextStyle.of(context).style;
    double height(String text, double font, FontWeight weight, double width) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: baseStyle.merge(
            TextStyle(fontSize: font, height: 1.22, fontWeight: weight),
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: width);
      final result = painter.height;
      painter.dispose();
      return result;
    }

    bool fits(double font) {
      for (final start in [0, 5]) {
        var total = 0.0;
        for (var index = start; index < start + 5; index++) {
          total +=
              5 +
              math.max(
                height(rules[index], font, FontWeight.w700, textWidth),
                height('${index + 1}.', font + 1, FontWeight.w900, 25),
              );
        }
        if (total > bounds.maxHeight - 1) return false;
      }
      return true;
    }

    if (fits(16)) return 16;
    var lower = 1.0;
    var upper = 16.0;
    for (var attempt = 0; attempt < 12; attempt++) {
      final candidate = (lower + upper) / 2;
      if (fits(candidate)) {
        lower = candidate;
      } else {
        upper = candidate;
      }
    }
    return lower;
  }

  static List<String> get rules => [
    _helpText(
      'Oyun sonu en az puana sahip oyuncu oyunu kazanır.',
      'The player with the lowest score wins the game.',
      de: 'Der Spieler mit den wenigsten Punkten gewinnt.',
    ),
    _helpText(
      'Biten −101, açmayan 202; diğerleri kalan puanı alır.',
      'Finish: −101; unopened: 202; others score their rack.',
      de: 'Beendet: −101; ungeöffnet: 202; sonst zählt der Rest.',
    ),
    _helpText(
      'Çift açanın kalan taşları, biri bitince iki kat sayılır.',
      'After a pair opening, remaining rack points count double.',
      de: 'Nach einer Paareröffnung zählen die Restpunkte doppelt.',
    ),
    _helpText(
      'Çift veya okeyle bitişte ceza puanları ikiye katlanır.',
      'Finishing with a pair or okey doubles penalty points.',
      de: 'Ein Abschluss mit Paar oder Okey verdoppelt Strafpunkte.',
    ),
    _helpText(
      'İşler taş ya da okey atmak 101 ceza puanı getirir.',
      'Discarding a playable tile or okey adds 101 points.',
      de: 'Anlegbaren Stein oder Okey ablegen: 101 Strafpunkte.',
    ),
    _helpText(
      'Gösterge, yalnız ilk çift açılışında her taşla eşleşir.',
      'The indicator pairs freely only in the first pair opening.',
      de: 'Die Anzeige paart sich nur beim ersten Öffnen beliebig.',
    ),
    _helpText(
      'Çift açan oyuncu daha sonra seri açılışı yapamaz.',
      'Opening pairs prevents a later run or group opening.',
      de: 'Nach Paaren sind Reihen- und Gruppeneröffnungen gesperrt.',
    ),
    _helpText(
      'Tüm taşlar uygun diziliyse elden bitiş yapılabilir.',
      'With all tiles in valid melds, you can finish from hand.',
      de: 'Mit passend geordneten Steinen ist ein Handabschluss möglich.',
    ),
    _helpText(
      'Katlamalıda sonraki açılış, önceki değerden 1 fazladır.',
      'In progressive mode, each opening raises the limit by 1.',
      de: 'Progressiv: Jede Eröffnung erhöht die Grenze um 1.',
    ),
    _helpText(
      'El açtıktan sonra elde kalan her okey 101 puandır.',
      'After opening, each okey left on the rack is worth 101.',
      de: 'Nach dem Öffnen zählt jeder übrige Okey 101 Punkte.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final rules = _GeneralRules.rules;
    return Padding(
      key: const ValueKey('general-rules-page'),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fontSize = _fontSize(context, constraints, rules);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _RuleColumn(
                        fontSize: fontSize,
                        startIndex: 0,
                        rules: rules.take(5).toList(),
                      ),
                    ),
                    const VerticalDivider(
                      width: 19,
                      thickness: 1,
                      color: Colors.white24,
                    ),
                    Expanded(
                      child: _RuleColumn(
                        fontSize: fontSize,
                        startIndex: 5,
                        rules: rules.skip(5).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleColumn extends StatelessWidget {
  final String keyPrefix;
  final double fontSize;
  final int startIndex;
  final List<String> rules;

  const _RuleColumn({
    this.keyPrefix = 'general-rule',
    required this.startIndex,
    required this.rules,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < rules.length; index++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 25,
                child: Text(
                  '${startIndex + index + 1}.',
                  style: TextStyle(
                    color: Color(0xFFF0CC5A),
                    fontSize: fontSize + 1,
                    height: 1.22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  rules[index],
                  key: ValueKey('$keyPrefix-${startIndex + index + 1}'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    height: 1.22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

double _helpTextHeight(
  BuildContext context,
  String text,
  double font,
  double width,
  double height,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(
        TextStyle(fontSize: font, fontWeight: FontWeight.w700, height: height),
      ),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: math.max(1, width));
  final result = painter.height;
  painter.dispose();
  return result;
}
