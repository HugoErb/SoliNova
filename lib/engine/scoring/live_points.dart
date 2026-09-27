/// Points de jeu gagnés ou perdus pendant la partie, coup par coup.
///
/// Ces valeurs sont affichées dans la page « Comment le score est calculé » :
/// toute modification doit y être reflétée (elle lit ces constantes).
abstract final class LivePoints {
  /// Carte posée sur une fondation (Klondike, FreeCell).
  static const toFoundation = 10;

  /// Carte de la défausse posée dans le tableau (Klondike).
  static const wasteToTableau = 5;

  /// Carte cachée du tableau retournée (Klondike, Spider).
  static const reveal = 5;

  /// Carte reprise d'une fondation vers le tableau (Klondike).
  static const foundationToTableau = -15;

  /// Pioche remise en place en tirage 1 carte (Klondike).
  static const recycleDraw1 = -20;

  /// Suite complète Roi → As retirée (Spider).
  static const spiderSuite = 100;
}
