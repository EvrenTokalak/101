import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/opponent_name_session.dart';

void main() {
  test('rakip isimleri resetlenene kadar ayni kalir', () {
    final session = OpponentNameSession(random: Random(7));

    final firstGame = session.names;
    expect(session.names, same(firstGame));
    expect(firstGame.toSet(), hasLength(3));

    session.reset();
    final nextGame = session.names;
    expect(nextGame, isNot(same(firstGame)));
    expect(nextGame.toSet(), hasLength(3));
  });
}
