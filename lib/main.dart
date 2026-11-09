import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'app/config.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/api_repository.dart';
import 'data/app_repository.dart';
import 'data/app_scope.dart';
import 'data/auth.dart';
import 'data/mock_repository.dart';

/// アプリ名（仮）。決まったらここを変える。
const appTitle = 'プロテインで乾杯';

Future<void> main() async {
  // 招待リンク（https://…/invite/abc）を「#」なしの URL で受け取るため。
  // Web 以外では何もしない
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProteinApp(repository: await createRepository()));
}

/// 起動時の設定（--dart-define）に合わせて、仮データかバックエンド API かを選ぶ。
Future<AppRepository> createRepository() async {
  if (!AppConfig.usesApi) return MockAppRepository();

  final repository = ApiAppRepository(
    baseUrl: AppConfig.apiBaseUrl,
    googleAuth: await initializeGoogleAuth(),
    allowDevSignIn: AppConfig.devTools,
  );
  await repository.restoreSession();
  return repository;
}

/// Firebase を初期化して Google ログインの窓口を返す。設定が無ければ null（Google ログインは使えない）
Future<AuthGateway?> initializeGoogleAuth() async {
  try {
    if (AppConfig.hasFirebaseConfig) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: AppConfig.firebaseApiKey,
          appId: AppConfig.firebaseAppId,
          messagingSenderId: AppConfig.firebaseMessagingSenderId,
          projectId: AppConfig.firebaseProjectId,
          authDomain: AppConfig.firebaseAuthDomain.isEmpty
              ? null
              : AppConfig.firebaseAuthDomain,
        ),
      );
    } else if (!kIsWeb) {
      // iPhone アプリは ios/Runner/GoogleService-Info.plist があればそこから読む
      await Firebase.initializeApp();
    } else {
      return null;
    }
    return FirebaseAuthGateway(FirebaseAuth.instance);
  } catch (error) {
    debugPrint('Firebase を初期化できなかったので Google ログインは使えない: $error');
    return null;
  }
}

class ProteinApp extends StatefulWidget {
  const ProteinApp({super.key, required this.repository});

  final AppRepository repository;

  @override
  State<ProteinApp> createState() => _ProteinAppState();
}

class _ProteinAppState extends State<ProteinApp> {
  late final GoRouter _router = buildRouter(widget.repository);

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repository: widget.repository,
      child: MaterialApp.router(
        title: appTitle,
        theme: buildTheme(),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
