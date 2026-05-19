import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: SmPlayerApp()));
}

class SmPlayerApp extends StatelessWidget {
  const SmPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Simple Melody Player',
      home: SizedBox.shrink(),
    );
  }
}
