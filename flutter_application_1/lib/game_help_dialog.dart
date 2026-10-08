import 'package:flutter/material.dart';

import 'app_controls.dart';
import 'app_language.dart';

String _helpText(String tr, String en, {String? de}) =>
    appText(tr, en, german: de);

class GameHelpDialog extends StatefulWidget {
  const GameHelpDialog({super.key});

  @override
  State<GameHelpDialog> createState() => _GameHelpDialogState();
}

class _GameHelpDialogState extends State<GameHelpDialog> {
  static const _gold = Color(0xFFF0CC5A);
  final PageController _controller = PageController();
  int page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final popupSize = appPopupSize(context);
    return Dialog(
      key: const ValueKey('game-help-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: popupSize.width,
        height: popupSize.height,
        decoration: BoxDecoration(
          color: const Color(0xFF07100F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold, width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 28)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 58,
              padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
              color: const Color(0xFF123C2E),
              child: Row(
                children: [
                  const Icon(Icons.help_rounded, color: _gold, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _helpText(
                        '101 OKEY NASIL OYNANIR?',
                        'HOW TO PLAY 101 OKEY?',
                        de: 'WIE SPIELT MAN 101 OKEY?',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  AppCloseButton(onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (value) => setState(() => page = value),
                children: const [
                  _QuickGuide(),
                  _MeldExamples(),
                  _GeneralRules(),
                ],
              ),
            ),
            Container(
              height: 54,
              color: Colors.black26,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    key: const ValueKey('help-previous'),
                    onPressed: page == 0
                        ? null
                        : () => _controller.previousPage(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          ),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  for (var index = 0; index < 3; index++)
                    Container(
                      key: ValueKey('help-dot-$index'),
                      width: 11,
                      height: 11,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: page == index ? Colors.white : Colors.white24,
                        shape: BoxShape.circle,
                      ),
                    ),
                  IconButton(
                    key: const ValueKey('help-next'),
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
      ),
    );
  }
}

class _QuickGuide extends StatelessWidget {
  const _QuickGuide();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        Expanded(
          flex: 5,
          child: _HelpPanel(
            child: LayoutBuilder(
              builder: (context, constraints) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Step(
                        '1.',
                        _helpText(
                          'AÇILIŞ değerine ulaşın.',
                          'Reach the opening requirement.',
                          de: 'Erreiche den Eröffnungswert.',
                        ),
                      ),
                      _Step(
                        '2.',
                        _helpText(
                          'SERİ ve ÇİFT butonları ile perleri açın.',
                          'Use OPEN MELD or OPEN PAIRS to open your hand.',
                          de: 'Öffne deine Hand mit SATZ oder PAARE.',
                        ),
                      ),
                      _Step(
                        '3.',
                        _helpText(
                          'İŞLE butonu ile işler taşlarınızı işleyin.',
                          'Use ADD to place matching tiles on open melds.',
                          de: 'Lege passende Steine mit ANLEGEN an.',
                        ),
                      ),
                      _Step(
                        '4.',
                        _helpText(
                          'Son taşınızı yan tarafa atarak bitin.',
                          'Finish by discarding your last tile to the side.',
                          de: 'Beende die Runde, indem du den letzten Stein ablegst.',
                        ),
                      ),
                      _Step(
                        '5.',
                        _helpText(
                          'İşler taşlarınızı elle işleyebilirsiniz.',
                          'You can also add matching tiles manually.',
                          de: 'Passende Steine kannst du auch manuell anlegen.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(flex: 4, child: _ButtonGuide()),
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  final String number;
  final String text;
  const _Step(this.number, this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: Color(0xFFF0CC5A),
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ButtonGuide extends StatelessWidget {
  const _ButtonGuide();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: _HelpPanel(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                children: [
                  _GuideButton(
                    Icons.view_week_rounded,
                    _helpText('SERİ', 'MELD', de: 'SATZ'),
                  ),
                  _GuideButton(
                    Icons.filter_2_rounded,
                    _helpText('ÇİFT', 'PAIRS', de: 'PAARE'),
                  ),
                  _GuideButton(
                    Icons.add_box_rounded,
                    _helpText('İŞLE', 'ADD', de: 'ANLEGEN'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _helpText(
                  'Butonları Göster / Sakla',
                  'Show / Hide Buttons',
                  de: 'Tasten ein-/ausblenden',
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Icon(
                Icons.arrow_downward_rounded,
                color: Colors.white70,
                size: 32,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _GuideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _GuideButton(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CircleAvatar(
        radius: 27,
        backgroundColor: const Color(0xFF123C2E),
        child: Icon(icon, color: Colors.white, size: 31),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFFF0CC5A),
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _MeldExamples extends StatelessWidget {
  const _MeldExamples();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      children: [
        Text(
          _helpText('PER ÖRNEKLERİ', 'MELD EXAMPLES', de: 'SATZBEISPIELE'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
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
  Widget build(BuildContext context) => Row(
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

  @override
  Widget build(BuildContext context) {
    final rules = [
      _helpText(
        'Oyun sonu en az puana sahip oyuncu oyunu kazanır.',
        'The player with the lowest score wins the game.',
        de: 'Der Spieler mit den wenigsten Punkten gewinnt.',
      ),
      _helpText(
        'El açmayan oyuncu 202 ceza puanı alır.',
        'A player who has not opened receives 202 penalty points.',
        de: 'Wer nicht eröffnet hat, erhält 202 Strafpunkte.',
      ),
      _helpText(
        'Çift açan oyuncu, oyunda biten varsa ıstakada kalanın 2 katını alır.',
        'A player who opened pairs receives twice the value left on the rack when someone finishes.',
        de: 'Wer mit Paaren eröffnet hat, erhält beim Rundenende den doppelten Restwert.',
      ),
      _helpText(
        'Çifte veya okey ile biten varsa puanlar 2’şer katına çıkar.',
        'Finishing with a pair or an okey doubles the scores.',
        de: 'Ein Abschluss mit Paar oder Okey verdoppelt die Punkte.',
      ),
      _helpText(
        'İşler taş veya okey taşını yere atan oyuncu 101 ceza alır.',
        'Discarding a playable tile or an okey costs 101 penalty points.',
        de: 'Das Ablegen eines anlegbaren Steins oder Okeys kostet 101 Strafpunkte.',
      ),
      _helpText(
        'Çift açılış yapan oyuncu daha sonra seri açamaz.',
        'A player who opens pairs cannot open melds later.',
        de: 'Wer mit Paaren eröffnet, kann später keine Sätze eröffnen.',
      ),
      _helpText(
        'Tüm taşlar dizili ise her durumda elden bitebilirsiniz.',
        'You may finish directly from your hand when all tiles are arranged.',
        de: 'Sind alle Steine geordnet, kannst du direkt aus der Hand beenden.',
      ),
      _helpText(
        'Katlamalı oyunda açılış değerleri, el açan oyuncunun +1 fazlası olur.',
        'In progressive mode, the next opening must exceed the previous opening by one.',
        de: 'Im progressiven Modus muss die nächste Eröffnung um eins höher sein.',
      ),
      _helpText(
        'El açtıktan sonra ıstakada kalan okey taşı 101 puan sayılır.',
        'After opening, an okey left on the rack counts as 101 points.',
        de: 'Nach dem Eröffnen zählt ein Okey auf der Ablage 101 Punkte.',
      ),
      _helpText(
        'El açan oyuncu biterse -101, bitemezse ıstakada kalan puanı alır.',
        'A player who opened scores -101 when finishing; otherwise the rack value is added.',
        de: 'Ein eröffneter Spieler erhält beim Beenden -101, sonst den Restwert der Ablage.',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      child: Column(
        children: [
          Text(
            _helpText(
              'GENEL KURALLAR',
              'GENERAL RULES',
              de: 'ALLGEMEINE REGELN',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: _RuleColumn(
                          startIndex: 0,
                          rules: rules.take(5).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  color: Colors.white24,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: _RuleColumn(
                          startIndex: 5,
                          rules: rules.skip(5).toList(),
                        ),
                      ),
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

class _RuleColumn extends StatelessWidget {
  final int startIndex;
  final List<String> rules;

  const _RuleColumn({required this.startIndex, required this.rules});

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
                  style: const TextStyle(
                    color: Color(0xFFF0CC5A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  rules[index],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
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

class _HelpPanel extends StatelessWidget {
  final Widget child;
  const _HelpPanel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF171D1B),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white10),
    ),
    child: child,
  );
}
