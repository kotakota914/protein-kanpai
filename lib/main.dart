import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'data/app_repository.dart';
import 'data/app_scope.dart';

/// アプリ名（仮）。決まったらここを変える。
const appTitle = 'プロテインで乾杯';

void main() {
  runApp(ProteinApp(repository: AppRepository()));
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
