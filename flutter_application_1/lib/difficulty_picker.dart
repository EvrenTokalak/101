import 'dart:math';

import 'package:flutter/material.dart';

import 'app_controls.dart';
import 'app_language.dart';
import 'game_launch.dart';

List<BotDifficulty> quickPlayDifficulties(Random random) {
  final first = random.nextBool() ? BotDifficulty.easy : BotDifficulty.medium;
  final remaining =
      BotDifficulty.values.where((level) => level != first).toList()
        ..shuffle(random);
  return [first, ...remaining];
}

Future<BotDifficulty?> pickBotDifficulty(BuildContext context) =>
    showDialog<BotDifficulty>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: AppGenericPanel(
          key: const ValueKey('difficulty-picker'),
          width: 520,
          height: 260,
          title: Text(appText('ZORLUK', 'DIFFICULTY')),
          onClose: () => Navigator.pop(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  for (final level in BotDifficulty.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Material(
                          color: const Color(0xFF0A5039),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            key: ValueKey('difficulty-${level.name}'),
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(context, level),
                            child: Container(
                              height: 92,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFDAB85B),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (
                                        var star = 0;
                                        star <= level.index;
                                        star++
                                      )
                                        const Flexible(
                                          child: Icon(
                                            Icons.star_rounded,
                                            color: Color(0xFFF2D36C),
                                            size: 22,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  FittedBox(
                                    child: Text(
                                      switch (level) {
                                        BotDifficulty.easy => appText(
                                          'KOLAY',
                                          'EASY',
                                        ),
                                        BotDifficulty.medium => appText(
                                          'ORTA',
                                          'MEDIUM',
                                        ),
                                        BotDifficulty.hard => appText(
                                          'ZOR',
                                          'HARD',
                                        ),
                                      },
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Baloo 2',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
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
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
