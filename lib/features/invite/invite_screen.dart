import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/app_scope.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/shaker.dart';

/// 07 招待を受け取る：友達から送られた `/invite/<code>` を開いたときの画面。
///
/// 開いたらすぐに招待を受け取り（お互いにフォローした状態になる）、結果を見せる。
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, required this.code});

  final String code;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  Future<Friend>? _accepting;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 一度だけ呼ぶ（描き直しのたびに受け取り直さない）
    _accepting ??= AppScope.of(context).acceptInvite(widget.code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: FutureBuilder<Friend>(
            future: _accepting,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _Message(
                  icon: const Icon(
                    Icons.link_off_rounded,
                    size: 56,
                    color: AppColors.muted,
                  ),
                  title: '招待を受け取れませんでした',
                  body: _reasonFor(snapshot.error!),
                );
              }
              final friend = snapshot.data;
              if (friend == null) {
                return const _Message(
                  icon: SizedBox.square(
                    dimension: 56,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  title: '招待を受け取っています…',
                  body: '',
                  showHomeButton: false,
                );
              }
              return _Message(
                icon: Avatar(
                  initial: friend.initial,
                  color: Avatar.colorFor(friend.name),
                  size: 72,
                ),
                title: '${friend.name}さんと友達になりました！',
                body: '同じタイミングでシェイカーを振ると「乾杯」になります。\nいま振っていれば、ホームに表示されます。',
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 契約のエラー表の文言に、この画面でだけ起きる 400（自分の招待）の説明を足す
String _reasonFor(Object error) {
  if (error is ApiException && error.statusCode == 400) {
    return '自分で作った招待リンクは受け取れません。友達に送ってください。';
  }
  if (error is ApiException && error.statusCode == 404) {
    return 'この招待リンクは見つからないか、期限（7 日）が切れています。';
  }
  return messageForError(error);
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.showHomeButton = true,
  });

  final Widget icon;
  final String title;
  final String body;
  final bool showHomeButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        const ShakerBottle(mix: 1, height: 72),
        const SizedBox(height: 28),
        icon,
        const SizedBox(height: 20),
        Text(title, style: AppFonts.heading(24), textAlign: TextAlign.center),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.muted,
              height: 1.6,
            ),
          ),
        ],
        const Spacer(),
        if (showHomeButton)
          FilledButton(
            onPressed: () => context.go('/home'),
            child: const Text('ホームへ'),
          ),
      ],
    );
  }
}
