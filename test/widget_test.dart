import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_app/data/app_repository.dart';
import 'package:protein_app/main.dart';

/// 2026-11-07（土）を「今日」として固定する
DateTime fixedNow() => DateTime(2026, 11, 7, 12);

AppRepository newRepo() =>
    AppRepository(clock: fixedNow, random: Random(1));

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
      expect(repo.friends.firstWhere((f) => f.id == kenta.id).following, isTrue);
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
      expect(find.text('3'), findsOneWidget);
      expect(find.text('日連続'), findsOneWidget);
      expect(find.text('はなこが振ってる'), findsOneWidget);
    });

    testWidgets('振ると乾杯の結果シートが出る', (tester) async {
      await pumpSignedIn(tester);
      await tester.ensureVisible(find.text('（開発用）振ったことにする'));
      await tester.tap(find.text('（開発用）振ったことにする'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('乾杯！'), findsOneWidget);
      expect(find.text('はなこと同時に振った。今日の筋トレ、ふたりで完了。'), findsOneWidget);
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('4'), findsWidgets);
      expect(find.text('今日の分は記録済み'), findsOneWidget);
    });

    testWidgets('下のタブで各画面に移動できる', (tester) async {
      await pumpSignedIn(tester);
      await tester.tap(find.text('カレンダー').last);
      await tester.pumpAndSettle();
      expect(find.text('2026年11月'), findsOneWidget);

      await tester.tap(find.text('友達').last);
      await tester.pumpAndSettle();
      expect(find.text('いま振ってる'), findsOneWidget);

      await tester.tap(find.text('プロフィール').last);
      await tester.pumpAndSettle();
      expect(find.text('好きなプロテイン'), findsOneWidget);
    });
  });
}
