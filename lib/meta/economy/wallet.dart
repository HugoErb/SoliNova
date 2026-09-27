import '../../engine/game_result.dart';
import '../json.dart';

/// Règles des Points, la monnaie locale de la boutique.
abstract final class PointsRules {
  /// Points fixes d'une victoire.
  static const winBase = 10;

  /// 1 point par tranche de 100 points de score.
  static const scorePerPoint = 100;

  /// Points offerts à chaque niveau atteint.
  static const perLevelUp = 50;

  static int forGame(GameResult r) =>
      r.won ? winBase + r.score.total ~/ scorePerPoint : 0;
}

/// Solde de points du joueur.
final class Wallet {
  const Wallet({this.balance = 0});

  final int balance;

  bool canAfford(int price) => balance >= price;

  Wallet credit(int points) {
    assert(points >= 0);
    return Wallet(balance: balance + points);
  }

  /// Débite [price] ; lève une erreur si le solde est insuffisant.
  Wallet debit(int price) {
    if (!canAfford(price)) throw StateError('Solde insuffisant');
    return Wallet(balance: balance - price);
  }

  Json toJson() => {'balance': balance};

  static Wallet fromJson(Json j) => Wallet(balance: readInt(j, 'balance'));
}
