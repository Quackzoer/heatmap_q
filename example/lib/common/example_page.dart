import 'package:flutter/material.dart';

/// Shared page frame for every example: a title, a short explanation of
/// what it demonstrates, and the example content itself.
class ExamplePage extends StatelessWidget {
  const ExamplePage({
    required this.title,
    required this.description,
    required this.child,
    this.scrollableBody = true,
    super.key,
  });

  final String title;
  final String description;
  final Widget child;

  /// Set to false when [child] manages its own scrolling (e.g. wraps a
  /// `ListView` itself) — it gets a bounded region instead of being placed
  /// inside a `SingleChildScrollView`.
  final bool scrollableBody;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Text(description, style: Theme.of(context).textTheme.bodyMedium),
    );

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Expanded(
              child: scrollableBody
                  ? SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: content)
                  : content,
            ),
          ],
        ),
      ),
    );
  }
}
