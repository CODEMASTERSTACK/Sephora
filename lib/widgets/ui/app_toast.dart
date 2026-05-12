import 'dart:async';
import 'package:flutter/material.dart';

/// Custom themed toast system that replaces default SnackBars.
/// Usage: AppToast.show(context, message: 'Hello', type: ToastType.success);
enum ToastType { success, error, info, warning }

class AppToast {
  static final List<OverlayEntry> _activeToasts = [];

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        icon: icon,
        duration: duration,
        onDismiss: () {
          entry.remove();
          _activeToasts.remove(entry);
        },
        index: _activeToasts.length,
      ),
    );

    _activeToasts.add(entry);
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final IconData? icon;
  final Duration duration;
  final VoidCallback onDismiss;
  final int index;

  const _ToastWidget({
    required this.message,
    required this.type,
    this.icon,
    required this.duration,
    required this.onDismiss,
    required this.index,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<double>(begin: -80, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _toastConfig(widget.type);
    final topPadding = MediaQuery.of(context).padding.top + 12 + (widget.index * 70);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Positioned(
          top: topPadding + _slideAnimation.value,
          left: 16,
          right: 16,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: GestureDetector(
              onHorizontalDragEnd: (_) => _dismiss(),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: config.bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: config.borderColor,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: config.glowColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: config.iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon ?? config.icon,
                          color: config.iconColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: config.textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _dismiss,
                        child: Icon(Icons.close,
                            color: Colors.white38, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Toast Configurations ─────────────────────────────────────────────────────

class _ToastConfig {
  final Color bgColor;
  final Color borderColor;
  final Color glowColor;
  final Color iconBg;
  final Color iconColor;
  final Color textColor;
  final IconData icon;

  const _ToastConfig({
    required this.bgColor,
    required this.borderColor,
    required this.glowColor,
    required this.iconBg,
    required this.iconColor,
    required this.textColor,
    required this.icon,
  });
}

_ToastConfig _toastConfig(ToastType type) {
  switch (type) {
    case ToastType.success:
      return const _ToastConfig(
        bgColor: Color(0xFF1A2E1A),
        borderColor: Color(0xFF2D5A2D),
        glowColor: Color(0xFF4CAF50),
        iconBg: Color(0xFF2D5A2D),
        iconColor: Color(0xFF81C784),
        textColor: Color(0xFFCCE5CC),
        icon: Icons.check_circle_outline,
      );
    case ToastType.error:
      return const _ToastConfig(
        bgColor: Color(0xFF2E1A1A),
        borderColor: Color(0xFF5A2D2D),
        glowColor: Color(0xFFF44336),
        iconBg: Color(0xFF5A2D2D),
        iconColor: Color(0xFFE57373),
        textColor: Color(0xFFE5CCCC),
        icon: Icons.error_outline,
      );
    case ToastType.warning:
      return const _ToastConfig(
        bgColor: Color(0xFF2E2A1A),
        borderColor: Color(0xFF5A4D2D),
        glowColor: Color(0xFFFF9800),
        iconBg: Color(0xFF5A4D2D),
        iconColor: Color(0xFFFFB74D),
        textColor: Color(0xFFE5DDCC),
        icon: Icons.warning_amber_rounded,
      );
    case ToastType.info:
      return const _ToastConfig(
        bgColor: Color(0xFF1A1F2E),
        borderColor: Color(0xFF2D3D5A),
        glowColor: Color(0xFFD4C462),
        iconBg: Color(0xFF2D3D5A),
        iconColor: Color(0xFFD4C462),
        textColor: Color(0xFFCCD4E5),
        icon: Icons.info_outline,
      );
  }
}
