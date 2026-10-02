import 'package:card_game/features/profile/domain/models/achievements.dart';
import 'package:flutter/widgets.dart';

/// Tells every `PlayingCardView` below it which card back to draw.
///
/// An `InheritedWidget` (rather than reading `ProfileCubit` inside the
/// card widget) so the card view keeps working with no provider at all —
/// in widget tests, golden tests and the UI-kit showcase it simply falls
/// back to [CardBackStyle.classic].
class CardBackScope extends InheritedWidget {
  const CardBackScope({required this.style, required super.child, super.key});

  final CardBackStyle style;

  static CardBackStyle of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CardBackScope>()?.style ?? CardBackStyle.classic;
  }

  @override
  bool updateShouldNotify(CardBackScope oldWidget) => oldWidget.style != style;
}
