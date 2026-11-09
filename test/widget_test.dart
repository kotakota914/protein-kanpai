import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_app/app/theme.dart';
import 'package:protein_app/data/app_repository.dart';
import 'package:protein_app/data/growth.dart';
import 'package:protein_app/main.dart';

/// 2026-11-07（土）を「今日」として固定する
DateTime fixedNow() => DateTime(2026, 11, 7, 12);

AppRepository newRepo() => AppRepository(clock: fixedNow, random: Random(1));

void main() {
  group('AppRepository', () {
    test('仮データでは昨日までの 3 日連続になっている', () {
      final repo = newRepo();
      expect(repo.shookToday, isFalse);
      expect(repo.streak, 3);
    });

    test('今日はじめて振るとスタンプ・連続日数・ボーナスが増える', () async {
      final repo = newRepo();
      final before = repo.points;
      final result = await repo.recordShake();
      expect(result.firstToday, isTrue);
      expect(result.streak, 4);
      expect(result.bonusPoints, greaterThan(0));
      expect(repo.points, before + result.bonusPoints);
      // はなこさんが振っている最中なので乾杯が成立する
      expect(result.cheerWith, 'はなこ');
    });

    test('同じ日に 2 回目に振ってもボーナスは増えない', () async {
      final repo = newRepo();
      await repo.recordShake();
      final points = repo.points;
      final second = await repo.recordShake();
      expect(second.firstToday, isFalse);
      expect(second.bonusPoints, 0);
      expect(repo.points, points);
    });

    test('アイコンの写真を設定・解除できる', () async {
      final repo = newRepo();
      expect(repo.avatar, isNull);
      await repo.setAvatar(Uint8List.fromList([1, 2, 3]));
      expect(repo.avatar, isNotNull);
      repo.clearAvatar();
      expect(repo.avatar, isNull);
    });

    test('大きすぎる写真・空の写真はアイコンにできない', () async {
      final repo = newRepo();
      final tooBig = Uint8List(AppRepository.maxAvatarBytes + 1);
      expect(() => repo.setAvatar(tooBig), throwsArgumentError);
      expect(() => repo.setAvatar(Uint8List(0)), throwsArgumentError);
      expect(repo.avatar, isNull);
    });

    test('今週振った日数を数える', () {
      // 2026-11-07（土）。仮データでは今週は 11/2・11/4・11/5・11/6 の 4 日
      expect(newRepo().daysThisWeek, 4);
    });

    test('フォローを切り替えられる', () {
      final repo = newRepo();
      final kenta = repo.friends.firstWhere((f) => f.name == 'けんた');
      expect(kenta.following, isFalse);
      repo.toggleFollow(kenta.id);
      expect(
        repo.friends.firstWhere((f) => f.id == kenta.id).following,
        isTrue,
      );
    });
  });

  group('キャラ育成・味の色', () {
    test('振った日数の合計で段階が決まる', () {
      expect(stageFor(0).name, 'ひよっこ');
      expect(stageFor(2).name, 'ひよっこ');
      expect(stageFor(3).name, 'ちょいマッチョ');
      expect(stageFor(7).name, '細マッチョ');
      expect(stageFor(14).name, 'マッチョ');
      expect(stageFor(30).name, 'ムキムキ');
      expect(nextStageAfter(stageFor(30)), isNull);
    });

    test('14日目に振るとマッチョに成長する（同じ日に何回振っても1日分）', () async {
      var now = fixedNow();
      final repo = AppRepository(clock: () => now, random: Random(1));
      expect(repo.stage.name, '細マッチョ'); // 仮データは 7 日分
      final levelUps = <String>[];
      for (var day = 0; day < 7; day++) {
        final first = await repo.recordShake();
        final second = await repo.recordShake();
        expect(second.levelUpTo, isNull);
        if (first.levelUpTo != null) levelUps.add(first.levelUpTo!.name);
        now = now.add(const Duration(days: 1));
      }
      expect(repo.totalDays, 14);
      expect(levelUps, ['マッチョ']);
    });

    test('味でシェイクの色が変わる', () {
      expect(AppColors.flavor('ココア味'), AppColors.cocoa);
      expect(AppColors.flavor(null), AppColors.cocoa);
      expect(AppColors.flavor('ストロベリー味'), isNot(AppColors.cocoa));
      expect(AppColors.flavor('抹茶味'), isNot(AppColors.flavor('バニラ味')));
    });

    test('袋の写真を読むと好きなプロテインが入り、色が変わる', () async {
      final repo = newRepo();
      await repo.scanProtein();
      final first = repo.liquidColor;
      await repo.scanProtein();
      expect(repo.favoriteProtein, isNotNull);
      expect(repo.liquidColor, isNot(first));
    });
  });

  group('画面', () {
    Future<AppRepository> pumpSignedIn(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = newRepo();
      await tester.pumpWidget(ProteinApp(repository: repo));
      await tester.tap(find.text('Google でログイン'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('ログインするとホームが表示される', (tester) async {
      await pumpSignedIn(tester);
      expect(find.text('今日のプロテイン'), findsOneWidget);
      expect(find.text('3日連続'), findsOneWidget);
      expect(find.text('はなこさんが振っています'), findsOneWidget);
      expect(find.text('細マッチョ'), findsOneWidget);
    });

    testWidgets('振ると乾杯の結果シートが出る', (tester) async {
      await pumpSignedIn(tester);
      await tester.scrollUntilVisible(
        find.text('（開発用）振ったことにする'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('（開発用）振ったことにする'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('はなこさんと乾杯！'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('4日連続'), findsOneWidget);
    });

    testWidgets('下のタブで各画面に移動できる', (tester) async {
      await pumpSignedIn(tester);
      await tester.tap(find.text('カレンダー').last);
      await tester.pumpAndSettle();
      expect(find.text('2026年 11月'), findsOneWidget);

      await tester.tap(find.text('友達').last);
      await tester.pumpAndSettle();
      expect(find.text('いま振っている友達'), findsOneWidget);

      await tester.tap(find.text('プロフィール').last);
      await tester.pumpAndSettle();
      expect(find.text('好きなプロテイン'), findsOneWidget);
    });
  });
}
