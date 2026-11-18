import 'package:flutter/material.dart';

class LocalFolderGridLayout extends StatelessWidget {
  const LocalFolderGridLayout({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Wrap(spacing: 30, runSpacing: 26, children: children),
  );
}
