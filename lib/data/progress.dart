import 'achievements.dart';
import 'growth.dart';
import 'models.dart';

/// 振る前と後の数字から、画面に出す「振った結果」を組み立てる。
///
/// シェイカーくんの成長とバッジの変化はサーバーが返さない
/// （docs/api-contract.md の POST /shakes）。前後の数字を見比べて、
/// 段階が上がったか・新しく取ったバッジは何かをここで決める。
ShakeResult composeShakeResult({
  required AchievementStats before,
  required AchievementStats after,
  required bool firstToday,
  required int streak,
  required int bonusPoints,
  String? cheerWith,
}) {
  final stageBefore = stageFor(before.totalDays);
  final stageAfter = stageFor(after.totalDays);
  return ShakeResult(
    firstToday: firstToday,
    streak: streak,
    bonusPoints: bonusPoints,
    cheerWith: cheerWith,
    levelUpTo: stageAfter.level > stageBefore.level ? stageAfter : null,
    newAchievements: [
      for (final a in achievements)
        if (!a.earned(before) && a.earned(after)) a.name,
    ],
  );
}
