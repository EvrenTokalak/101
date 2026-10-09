// Compatibility for earlier routes; the tournament feature is now Daily League.
import 'daily_league.dart';
import 'league_screen.dart';

class TournamentScreen extends LeagueScreen {
  const TournamentScreen({super.key});
}

Future<DateTime> initializeTournamentCycle() async {
  await dailyLeague.load();
  dailyLeague.refresh();
  return dailyLeague.deadline!;
}