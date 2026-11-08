import 'package:flutter/widgets.dart';

import 'app_repository.dart';

/// どの画面からでも [AppRepository] を取り出せるようにする入れ物。
///
/// `AppScope.of(context)` で取り出すと、データが変わったときに
/// その画面が自動で描き直される。
class AppScope extends InheritedNotifier<AppRepository> {
  const AppScope({
    super.key,
    required AppRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static AppRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope が見つかりません');
    return scope!.notifier!;
  }
}
