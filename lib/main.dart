import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app_dependencies.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/home/views/home_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(UniversalRemoteApp(dependencies: AppDependencies.production()));
}

class UniversalRemoteApp extends StatelessWidget {
  const UniversalRemoteApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Universal Remote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomeView(dependencies: dependencies),
    );
  }
}
