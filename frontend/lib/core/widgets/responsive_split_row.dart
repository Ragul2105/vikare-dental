import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class ResponsiveSplitRow extends StatelessWidget {
  const ResponsiveSplitRow({
    super.key,
    required this.children,
    this.flexes,
    this.breakpoint = 600,
    this.spacing = AppSpacing.md,
  }) : assert(children.length > 0),
       assert(flexes == null || flexes.length == children.length);

  final List<Widget> children;
  final List<int>? flexes;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackVertically = constraints.maxWidth < breakpoint;

        if (stackVertically) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) SizedBox(height: spacing),
                children[index],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(flex: flexes?[index] ?? 1, child: children[index]),
              if (index < children.length - 1) SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }
}
