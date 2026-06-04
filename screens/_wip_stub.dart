import 'package:flutter/material.dart';

class WipScaffold extends StatelessWidget {
  final String title;
  final Widget? body;
  const WipScaffold({super.key, required this.title, this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body ??
          Center(
            child: Text(
              '$title (WIP)',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
    );
  }
}
