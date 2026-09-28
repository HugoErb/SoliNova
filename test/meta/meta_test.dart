import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:solinova/data/repositories.dart';
import 'package:solinova/data/storage.dart';
import 'package:solinova/engine/game_result.dart';
import 'package:solinova/engine/model/game_mode.dart';
import 'package:solinova/engine/model/move.dart';
import 'package:solinova/engine/scoring/score_calculator.dart';
import 'package:solinova/engine/session/game_session.dart';
import 'package:solinova/meta/achievements/achievements.dart';
import 'package:solinova/meta/daily/daily_challenge.dart';
import 'package:solinova/meta/economy/wallet.dart';
import 'package:solinova/meta/profile/game_completion.dart';
import 'package:solinova/meta/profile/profile.dart';
import 'package:solinova/meta/progression/player_progress.dart';
import 'package:solinova/meta/settings/settings.dart';
import 'package:solinova/meta/shop/inventory.dart';
import 'package:solinova/meta/shop/shop_item.dart';
import 'package:solinova/meta/stats/statistics.dart';

final _now = DateTime(2026, 9, 27, 15);

GameResult result({
  GameMode mode = GameMode.klondike1,
  bool won = true,
  int elapsedMs = 240000,
  int moves = 120,
  int hints = 0,
  int assistedMoves = 0,
  int undos = 0,
  int gamePoints = 600,
  int previousStreak = 0,
  String? challengeId,
  DateTime? at,
}) => GameResult(
  mode: mode,
  seed: 1,
  won: won,
  score: ScoreCalculator.compute(
    mode: mode,
    won: won,
    gamePoints: gamePoints,
    elapsedMs: elapsedMs,
    moves: moves,
    hints: hints,
    assistedMoves: assistedMoves,
    undos: undos,
    previousStreak: previousStreak,
  ),
  elapsedMs: elapsedMs,
  moves: moves,
  hints: hints,
  assistedMoves: assistedMoves,
  undos: undos,
  finishedAt: at ?? _now,
  challengeId: challengeId,
);

void main() {
  test('les coups assistés sont comptés et exclus des objectifs sans aide', () {
    final assisted = result(assistedMoves: 1);
    expect(const ChallengeObjective(noHints: true).isMetBy(assisted), isFalse);
    final (profile, report) = GameCompletion.apply(const Profile(), assisted);
    expect(report.unlocked.map((a) => a.id), isNot(contains('no_hint')));
    expect(report.unlocked.map((a) => a.id), isNot(contains('purist')));
    final restored = Profile.fromJson(profile.toJson());
    expect(restored.stats.global.assistedMovesUsed, 1);
    expect(restored.stats.global.hintsUsed, 0);
  });

  group('Statistiques', () {
    test('parties, victoires, moyennes et records', () {
      var s = const ModeStats();
      s = s.record(result(elapsedMs: 200000, moves: 100));
      s = s.record(result(won: false, elapsedMs: 50000, moves: 30));
      s = s.record(result(elapsedMs: 100000, moves: 140));
      expect(s.games, 3);
      expect(s.wins, 2);
      expect(s.winRate, closeTo(2 / 3, 1e-9));
      expect(s.bestTimeMs, 100000);
      expect(s.averageTimeMs, 150000);
      expect(s.fewestMoves, 100);
      expect(s.averageMoves, 120);
      expect(s.timePlayedMs, 350000);
      expect(s.totalMoves, 270);
      expect(s.bestScore, isNotNull);
    });

    test('séries : une défaite remet la série à zéro', () {
      var s = const ModeStats();
      for (var i = 0; i < 4; i++) {
        s = s.record(result());
      }
      expect(s.currentStreak, 4);
      s = s.record(result(won: false));
      expect(s.currentStreak, 0);
      expect(s.longestStreak, 4);
      s = s.record(result());
      expect(s.currentStreak, 1);
      expect(s.longestStreak, 4);
    });

    test('global et par mode séparés, sérialisation', () {
      var st = const Statistics();
      (st, _) = st.record(result(mode: GameMode.spider1));
      (st, _) = st.record(result(mode: GameMode.freecell, won: false));
      expect(st.global.games, 2);
      expect(st.of(GameMode.spider1).wins, 1);
      expect(st.of(GameMode.freecell).wins, 0);
      expect(st.of(GameMode.klondike3).games, 0);
      final back = Statistics.fromJson(
        (jsonDecode(jsonEncode(st.toJson())) as Map).cast<String, Object?>(),
      );
      expect(back.toJson(), st.toJson());
    });

    test('détection des nouveaux records', () {
      var st = const Statistics();
      NewRecords rec;
      (st, rec) = st.record(result(elapsedMs: 300000));
      expect(
        rec.bestTime,
        isFalse,
        reason: 'premier temps : pas un record battu',
      );
      (st, rec) = st.record(result(elapsedMs: 200000));
      expect(rec.bestTime, isTrue);
    });
  });

  group('XP et niveaux', () {
    test('courbe de niveaux', () {
      expect(XpRules.levelFor(0).level, 1);
      expect(XpRules.levelFor(99).level, 1);
      expect(XpRules.levelFor(100).level, 2);
      expect(XpRules.levelFor(250).level, 3);
      final info = XpRules.levelFor(120);
      expect(info.xpIntoLevel, 20);
      expect(info.xpForNextLevel, 150);
    });

    test('victoire : base du mode + score / 20', () {
      final r = result(mode: GameMode.spider4);
      expect(XpRules.forGame(r), 150 + r.score.total ~/ 20);
    });

    test('défaite : XP seulement si réellement jouée', () {
      expect(
        XpRules.forGame(result(won: false, moves: 5, elapsedMs: 10000)),
        0,
      );
      expect(
        XpRules.forGame(result(won: false, moves: 40, elapsedMs: 120000)),
        XpRules.lossXp,
      );
    });
  });

  group('Points', () {
    test('victoire : 10 + score / 100 ; défaite : 0', () {
      final r = result();
      expect(PointsRules.forGame(r), 10 + r.score.total ~/ 100);
      expect(PointsRules.forGame(result(won: false)), 0);
    });

    test('porte-monnaie : débit impossible sans fonds', () {
      const w = Wallet(balance: 100);
      expect(w.credit(50).balance, 150);
      expect(() => w.debit(200), throwsStateError);
    });
  });

  group('Défis quotidiens', () {
    test('trois défis par jour, identiques toute la journée', () {
      final morning = DailyChallengeGenerator.forDay(DateTime(2026, 9, 27, 7));
      final evening = DailyChallengeGenerator.forDay(DateTime(2026, 9, 27, 23));
      expect(morning.length, 3);
      expect([
        for (final c in morning) c.difficulty,
      ], ChallengeDifficulty.values);
      for (var i = 0; i < 3; i++) {
        expect(morning[i].id, evening[i].id);
        expect(morning[i].seed, evening[i].seed);
        expect(morning[i].mode, evening[i].mode);
        expect(
          morning[i].objective.describe(),
          evening[i].objective.describe(),
        );
      }
    });

    test('change d\'un jour à l\'autre', () {
      final a = DailyChallengeGenerator.forDay(DateTime(2026, 9, 27));
      final b = DailyChallengeGenerator.forDay(DateTime(2026, 9, 28));
      expect(a.map((c) => c.seed), isNot(b.map((c) => c.seed)));
    });

    test('byId reconstruit exactement le même défi', () {
      for (final c in DailyChallengeGenerator.forDay(DateTime(2026, 1, 5))) {
        final again = DailyChallengeGenerator.byId(c.id)!;
        expect(again.seed, c.seed);
        expect(again.mode, c.mode);
      }
      expect(DailyChallengeGenerator.byId('n-importe-quoi'), isNull);
    });

    test('récompenses croissantes', () {
      expect(
        ChallengeDifficulty.hard.rewardPoints,
        greaterThan(ChallengeDifficulty.medium.rewardPoints),
      );
      expect(
        ChallengeDifficulty.medium.rewardPoints,
        greaterThan(ChallengeDifficulty.easy.rewardPoints),
      );
    });

    test('objectif : contraintes vérifiées', () {
      const o = ChallengeObjective(maxSeconds: 300, noHints: true);
      expect(o.isMetBy(result(elapsedMs: 200000)), isTrue);
      expect(o.isMetBy(result(elapsedMs: 400000)), isFalse);
      expect(o.isMetBy(result(elapsedMs: 200000, hints: 1)), isFalse);
      expect(o.isMetBy(result(won: false)), isFalse);
      expect(o.describe(), 'Gagner en moins de 5 min, sans indice');
    });

    test('tentatives illimitées, récompense unique', () {
      final c = DailyChallengeGenerator.forDay(_now).first;
      var log = const DailyChallengeLog();
      bool first;
      (log, first) = log.recordAttempt(
        c,
        result(won: false, challengeId: c.id),
      );
      expect(first, isFalse);
      expect(log.of(c.id).status, ChallengeStatus.inProgress);
      (log, first) = log.recordAttempt(c, result(challengeId: c.id));
      expect(first, isTrue);
      (log, first) = log.recordAttempt(c, result(challengeId: c.id));
      expect(first, isFalse);
      expect(log.of(c.id).attempts, 3);
      expect(log.of(c.id).status, ChallengeStatus.succeeded);
    });
  });

  group('Boutique', () {
    test('achat définitif, débit et refus si fonds insuffisants', () {
      var inv = const Inventory();
      var wallet = const Wallet(balance: 500);
      PurchaseOutcome out;
      (inv, wallet, out) = inv.purchase('theme.oled', wallet);
      expect(out, PurchaseOutcome.success);
      expect(wallet.balance, 100);
      expect(inv.owns('theme.oled'), isTrue);
      (inv, wallet, out) = inv.purchase('theme.oled', wallet);
      expect(out, PurchaseOutcome.alreadyOwned);
      expect(wallet.balance, 100);
      (inv, wallet, out) = inv.purchase('theme.wood', wallet);
      expect(out, PurchaseOutcome.insufficientFunds);
      expect(inv.owns('theme.wood'), isFalse);
      (inv, wallet, out) = inv.purchase('inconnu', wallet);
      expect(out, PurchaseOutcome.unknownItem);
    });

    test('gratuits possédés d\'office, équipement réservé aux possédés', () {
      var inv = const Inventory();
      expect(inv.owns('theme.emerald'), isTrue);
      expect(inv.isEquipped('theme.emerald'), isTrue);
      inv = inv.equip('theme.pastel');
      expect(inv.isEquipped('theme.pastel'), isFalse);
      inv = inv.equip('theme.midnight');
      expect(inv.isEquipped('theme.midnight'), isTrue);
    });

    test('équiper un thème remet tapis et dos « selon le thème »', () {
      var inv = const Inventory(owned: {'table.velvet', 'back.dots'});
      inv = inv.equip('table.velvet').equip('back.dots').equip('face.large');
      expect(inv.equippedIn(ShopCategory.table), 'table.velvet');
      inv = inv.equip('theme.minimal');
      expect(inv.equippedIn(ShopCategory.table), isNull);
      expect(inv.equippedIn(ShopCategory.cardBack), isNull);
      expect(inv.equippedIn(ShopCategory.cardFace), 'face.large');
    });

    test('chaque catégorie a au moins un élément gratuit', () {
      for (final cat in ShopCategory.values) {
        expect(
          ShopCatalog.ofCategory(cat).any((i) => i.isFree) || cat.followsTheme,
          isTrue,
          reason: cat.label,
        );
      }
      expect(
        ShopCatalog.ofCategory(ShopCategory.theme).where((t) => !t.isFree),
        isNotEmpty,
        reason: 'des thèmes doivent être achetables',
      );
    });

    test('styles d\'accessibilité gratuits', () {
      expect(ShopCatalog.byId('face.large')!.isFree, isTrue);
      expect(ShopCatalog.byId('face.fourColor')!.isFree, isTrue);
    });

    test('identifiants uniques et sérialisation sûre', () {
      final ids = ShopCatalog.items.map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length);
      final inv = const Inventory(owned: {'theme.oled'}).equip('theme.oled');
      final back = Inventory.fromJson(
        (jsonDecode(jsonEncode(inv.toJson())) as Map).cast<String, Object?>(),
      );
      expect(back.isEquipped('theme.oled'), isTrue);
      // Un élément équipé mais non possédé (fichier modifié) est ignoré.
      final forged = Inventory.fromJson({
        'owned': <String>[],
        'equipped': {'theme': 'theme.aurora'},
      });
      expect(forged.isEquipped('theme.aurora'), isFalse);
    });
  });

  group('Fin de partie et succès', () {
    test('première victoire : score, XP, points, succès, niveau', () {
      final r = result(hints: 0, undos: 0);
      final (profile, report) = GameCompletion.apply(const Profile(), r);
      expect(profile.stats.global.wins, 1);
      final ids = report.unlocked.map((a) => a.id).toSet();
      expect(ids, containsAll(['first_win', 'no_hint', 'purist']));
      expect(profile.achievements.keys, containsAll(ids));
      expect(profile.progress.totalXp, report.totalXp);
      expect(profile.wallet.balance, report.totalPoints);
      expect(profile.stats.pointsEarned, report.totalPoints);
      expect(report.levelAfter.level, greaterThanOrEqualTo(1));
    });

    test('un succès n\'est débloqué qu\'une fois', () {
      final (p, _) = GameCompletion.apply(const Profile(), result());
      final (_, report) = GameCompletion.apply(p, result());
      expect(report.unlocked.map((a) => a.id), isNot(contains('first_win')));
    });

    test('défi réussi : récompense une seule fois', () {
      final c = DailyChallengeGenerator.forDay(_now).first;
      final r = result(mode: c.mode, challengeId: c.id);
      var (p, rep) = GameCompletion.apply(const Profile(), r);
      expect(rep.challengeCompletedNow, isTrue);
      expect(p.stats.challengesSucceeded, 1);
      expect(p.stats.challengesFinished, 1);
      (p, rep) = GameCompletion.apply(p, r);
      expect(rep.challengeCompletedNow, isFalse);
      expect(rep.pointsFromChallenge, 0);
      expect(p.stats.challengesSucceeded, 1);
      expect(p.stats.challengesFinished, 2);
    });

    test('achats : succès Collectionneur hors partie', () {
      var p = const Profile(
        inventory: Inventory(
          owned: {
            'table.graphite',
            'table.sand',
            'back.dots',
            'back.lines',
            'anim.snappy',
          },
        ),
      );
      List<Achievement> unlocked;
      (p, unlocked) = GameCompletion.checkAchievements(p, _now);
      expect(unlocked.map((a) => a.id), contains('collector'));
      expect(p.wallet.balance, greaterThan(0));
    });

    test('pipeline complet depuis une session', () {
      var session = GameSession.start(GameMode.klondike1, 42);
      session = session.play(const DrawMove())!.withElapsed(30000);
      final r = GameCompletion.resultOf(
        session,
        const Profile(),
        won: false,
        now: _now,
      );
      expect(r.moves, 1);
      final (p, report) = GameCompletion.apply(const Profile(), r);
      expect(p.stats.global.games, 1);
      expect(p.stats.global.wins, 0);
      expect(report.totalXp, 0);
    });
  });

  group('Persistance', () {
    test('profil : aller-retour complet', () async {
      final store = MemoryStore();
      final repo = ProfileRepository(store);
      var (p, _) = GameCompletion.apply(const Profile(), result());
      p = p.copyWith(settings: const Settings(sound: false, showTimer: false));
      await repo.save(p);
      final loaded = await ProfileRepository(store).load();
      expect(jsonEncode(loaded.toJson()), jsonEncode(p.toJson()));
      expect(loaded.settings.sound, isFalse);
    });

    test('partie en cours : restauration exacte', () async {
      final store = MemoryStore();
      var s = GameSession.start(GameMode.spider2, 9, challengeId: 'x');
      s = s.play(const DrawMove())!.withElapsed(1234);
      await GameRepository(store).save(s);
      final back = (await GameRepository(store).loadOrNull())!;
      expect(back.state.toJson(), s.state.toJson());
      expect(back.elapsedMs, 1234);
      expect(back.challengeId, 'x');
      expect(back.canUndo, isTrue);
    });

    test('fichier corrompu : mis de côté, profil par défaut', () async {
      final store = MemoryStore()..data['profile'] = '{pas du json';
      final p = await ProfileRepository(store).load();
      expect(p.stats.global.games, 0);
      expect(store.quarantined.containsKey('profile'), isTrue);
    });

    test('champs manquants : valeurs par défaut', () {
      final p = Profile.fromJson({'v': 1});
      expect(p.settings.sound, isTrue);
      expect(p.wallet.balance, 0);
    });

    test(
      'écritures regroupées : seule la dernière valeur est écrite',
      () async {
        final written = <int>[];
        final saver = DebouncedSaver<int>((v) async => written.add(v));
        saver
          ..schedule(1)
          ..schedule(2)
          ..schedule(3);
        await saver.flush();
        expect(written, [3]);
      },
    );

    test('effacement exécuté après une écriture en cours', () async {
      final log = <String>[];
      final gate = Completer<void>();
      final saver = DebouncedSaver<int>((v) async {
        await gate.future;
        log.add('write $v');
      });
      saver.schedule(1);
      final writing = saver.flush();
      final clearing = saver.cancelThen(() async => log.add('clear'));
      gate.complete();
      await writing;
      await clearing;
      expect(log, ['write 1', 'clear']);
    });
  });
}
