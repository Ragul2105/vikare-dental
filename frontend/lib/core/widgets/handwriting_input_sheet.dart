import 'package:flutter/material.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as mlkit;

import '../handwriting/digital_ink_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Opens the stylus handwriting pad as a modal bottom sheet and returns the
/// text the user confirmed, or `null` if they cancelled.
///
/// The user writes with a stylus (or finger), taps **Recognize** to transcribe
/// the strokes, reviews/edits the result in an editable field, then taps
/// **Insert**. Recognition is on-device via [DigitalInkService].
Future<String?> showHandwritingInputSheet(
  BuildContext context, {
  String? title,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (_) => _HandwritingInputSheet(title: title),
  );
}

class _HandwritingInputSheet extends StatefulWidget {
  const _HandwritingInputSheet({this.title});

  final String? title;

  @override
  State<_HandwritingInputSheet> createState() => _HandwritingInputSheetState();
}

enum _ModelState { preparing, ready, error }

class _HandwritingInputSheetState extends State<_HandwritingInputSheet> {
  final DigitalInkService _service = DigitalInkService();
  final TextEditingController _previewController = TextEditingController();

  /// Completed strokes plus the one currently being drawn (last element).
  final List<mlkit.Stroke> _strokes = [];
  mlkit.Stroke? _activeStroke;

  _ModelState _modelState = _ModelState.preparing;
  String _modelError = '';
  bool _recognizing = false;

  @override
  void initState() {
    super.initState();
    _prepareModel();
  }

  @override
  void dispose() {
    _previewController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _prepareModel() async {
    setState(() => _modelState = _ModelState.preparing);
    try {
      final ready = await _service.ensureModelReady();
      if (!mounted) return;
      setState(() {
        _modelState = ready ? _ModelState.ready : _ModelState.error;
        if (!ready) {
          _modelError =
              'Could not download the handwriting model. Connect to the '
              'internet once to enable handwriting.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _modelState = _ModelState.error;
        _modelError = 'Handwriting is unavailable on this device.';
      });
    }
  }

  bool get _hasStrokes => _strokes.isNotEmpty;

  void _onPointerDown(PointerDownEvent event) {
    if (_modelState != _ModelState.ready) return;
    final stroke = mlkit.Stroke()
      ..points = [_pointFrom(event.localPosition)];
    setState(() {
      _activeStroke = stroke;
      _strokes.add(stroke);
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    final stroke = _activeStroke;
    if (stroke == null) return;
    setState(() => stroke.points.add(_pointFrom(event.localPosition)));
  }

  void _onPointerUp(PointerUpEvent event) {
    _activeStroke = null;
  }

  mlkit.StrokePoint _pointFrom(Offset offset) => mlkit.StrokePoint(
    x: offset.dx,
    y: offset.dy,
    t: DateTime.now().millisecondsSinceEpoch,
  );

  void _undo() {
    if (!_hasStrokes) return;
    setState(() {
      _strokes.removeLast();
      _activeStroke = null;
    });
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _activeStroke = null;
    });
  }

  Future<void> _recognize() async {
    if (!_hasStrokes || _recognizing) return;
    setState(() => _recognizing = true);
    try {
      final ink = mlkit.Ink()..strokes = List.of(_strokes);
      final text = await _service.recognize(ink);
      if (!mounted) return;
      if (text.isEmpty) {
        setState(() => _recognizing = false);
        return;
      }
      // Append to whatever is already in the preview so the user can write and
      // recognize word-by-word, then clear the canvas for the next word.
      final existing = _previewController.text.trimRight();
      final combined = existing.isEmpty ? text : '$existing $text';
      _previewController
        ..text = combined
        ..selection = TextSelection.collapsed(offset: combined.length);
      setState(() {
        _strokes.clear();
        _activeStroke = null;
        _recognizing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _recognizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(theme),
            if (_modelState != _ModelState.ready) _statusBanner(theme),
            Flexible(child: _canvas()),
            _toolbar(theme),
            _preview(theme),
            _footer(theme),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.draw_rounded, color: AppColors.accentDeep),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              widget.title == null ? 'Write with stylus' : 'Write: ${widget.title}',
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner(ThemeData theme) {
    final isError = _modelState == _ModelState.error;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: (isError ? AppColors.error : AppColors.info).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          if (isError)
            const Icon(Icons.error_outline_rounded, color: AppColors.error)
          else
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isError ? _modelError : 'Preparing the handwriting model…',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (isError)
            TextButton(onPressed: _prepareModel, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _canvas() {
    return Container(
      height: 260,
      margin: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        child: CustomPaint(
          painter: _InkPainter(_strokes),
          child: _hasStrokes
              ? const SizedBox.expand()
              : Center(
                  child: Text(
                    'Write here',
                    style: TextStyle(color: AppColors.textSoft),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _toolbar(ThemeData theme) {
    final canAct = _modelState == _ModelState.ready;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: canAct && _hasStrokes ? _undo : null,
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Undo'),
          ),
          TextButton.icon(
            onPressed: canAct && _hasStrokes ? _clear : null,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Clear'),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: canAct && _hasStrokes && !_recognizing ? _recognize : null,
            icon: _recognizing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.text_fields_rounded),
            label: Text(_recognizing ? 'Reading…' : 'Recognize'),
          ),
        ],
      ),
    );
  }

  Widget _preview(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _previewController,
        maxLines: 3,
        minLines: 1,
        decoration: const InputDecoration(
          labelText: 'Recognized text (edit if needed)',
          hintText: 'Recognized text appears here',
        ),
      ),
    );
  }

  Widget _footer(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _previewController,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return FilledButton(
                  onPressed: hasText
                      ? () => Navigator.of(context).pop(value.text.trim())
                      : null,
                  child: const Text('Insert'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes);

  final List<mlkit.Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentDeep
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      final points = stroke.points;
      if (points.isEmpty) continue;
      if (points.length == 1) {
        // A tap/dot: render a small filled circle.
        canvas.drawCircle(
          Offset(points.first.x, points.first.y),
          1.5,
          Paint()..color = AppColors.accentDeep,
        );
        continue;
      }
      final path = Path()..moveTo(points.first.x, points.first.y);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].x, points[i].y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_InkPainter oldDelegate) => true;
}
