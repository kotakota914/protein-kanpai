import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// ログインしている人
class AuthUser {
  const AuthUser({required this.uid, required this.name});

  final String uid;
  final String name;
}

/// 「誰としてログインしているか」と「API に付けるトークン」の窓口。
///
/// 本番は [FirebaseAuthGateway]（Google ログイン）。
/// ローカルでバックエンドを試すときは [DevAuthGateway]。
abstract class AuthGateway {
  /// 起動時に、前回のログインが残っていれば復元する
  Future<void> restoreSession();

  AuthUser? get currentUser;

  Future<AuthUser> signInWithGoogle();

  Future<void> signOut();

  /// API の `Authorization: Bearer` に付けるトークン。未ログインなら null
  Future<String?> idToken();
}

/// Firebase Authentication の Google ログイン。
class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<void> restoreSession() async {
    // Web では初期化直後の currentUser が null のまま、保存済みのログインが
    // 少し遅れて届く。最初の通知（null か User）を待ってから判断する。
    // 届かなければ未ログインとして進める（ログイン画面が出るだけ）。
    await _auth.authStateChanges().first.timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
  }

  @override
  AuthUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _toAuthUser(user);
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    // Web はポップアップ、iPhone アプリは OS のブラウザ画面で Google にログインする。
    // iPhone 側は GoogleService-Info.plist と URL スキームの設定が要る（docs/ios.md）。
    final credential = kIsWeb
        ? await _auth.signInWithPopup(provider)
        : await _auth.signInWithProvider(provider);
    final user = credential.user;
    if (user == null) throw StateError('ログインできませんでした');
    return _toAuthUser(user);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<String?> idToken() async {
    // getIdToken は期限が近ければ自動で取り直す
    return _auth.currentUser?.getIdToken();
  }

  static AuthUser _toAuthUser(User user) =>
      AuthUser(uid: user.uid, name: displayNameOf(user));
}

/// 表示名の決め方。バックエンドの auth.py（display_name_from_claims）と同じ順番
String displayNameOf(User user) {
  final name = user.displayName?.trim() ?? '';
  if (name.isNotEmpty) return name;
  final email = user.email ?? '';
  if (email.contains('@')) return email.split('@').first;
  return '名無し';
}

/// バックエンドの `AUTH_MODE=dev` 向け。
///
/// `dev:<uid>:<URL エンコードした名前>` をそのまま送る（サーバーは検証しない）。
/// ローカルでの動作確認専用。Cloud Run 上のサーバーはこの形を受け付けない。
class DevAuthGateway implements AuthGateway {
  DevAuthGateway({required String uid, required String name})
    : _user = AuthUser(uid: uid, name: name);

  AuthUser? _user;

  @override
  Future<void> restoreSession() async {}

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<AuthUser> signInWithGoogle() =>
      throw UnsupportedError('開発用ログインでは Google ログインは使えません');

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<String?> idToken() async {
    final user = _user;
    if (user == null) return null;
    return 'dev:${user.uid}:${Uri.encodeComponent(user.name)}';
  }
}
