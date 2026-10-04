import 'package:flutter/material.dart';

/// Envolve o [child] com uma borda que pulsa na [color].
/// Sem cor, mostra o conteúdo sem borda nem animação.
class PulsingBorder extends StatefulWidget {
  const PulsingBorder({
    super.key,
    required this.child,
    this.color,
    this.borderRadius = 12,
  });

  final Widget child;
  final Color? color;
  final double borderRadius;

  @override
  State<PulsingBorder> createState() => _PulsingBorderState();
}

class _PulsingBorderState extends State<PulsingBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PulsingBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _sync() {
    // Respeita a opção de reduzir animações do sistema.
    final animate = widget.color != null && !_reduceMotion;
    if (animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!animate) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    if (color == null) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _reduceMotion ? 1.0 : _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: color.withValues(alpha: 0.45 + 0.55 * t),
              width: 2 + 1.5 * t,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25 * t),
                blurRadius: 10 * t,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
