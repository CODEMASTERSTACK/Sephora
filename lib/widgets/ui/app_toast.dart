import 'dart:async';
import 'dart:ui';
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
    _slideAnimation = Tween<double>(begin: -100, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: config.bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: config.borderColor,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: config.glowColor.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: config.iconBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  widget.icon ?? config.icon,
                                  color: config.iconColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  widget.message,
                                  style: TextStyle(
                                    color: config.textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: _dismiss,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white70, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Progress bar line at the bottom
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 1.0, end: 0.0),
                          duration: widget.duration,
                          curve: Curves.linear,
                          builder: (context, value, child) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 3,
                                width: MediaQuery.of(context).size.width * value,
                                color: config.glowColor.withValues(alpha: 0.8),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
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
      return _ToastConfig(
        bgColor: const Color(0xFF1A2E1A).withValues(alpha: 0.75),
        borderColor: Colors.greenAccent.withValues(alpha: 0.3),
        glowColor: const Color(0xFF4CAF50),
        iconBg: const Color(0xFF2D5A2D).withValues(alpha: 0.5),
        iconColor: const Color(0xFF81C784),
        textColor: Colors.white,
        icon: Icons.check_circle_rounded,
      );
    case ToastType.error:
      return _ToastConfig(
        bgColor: const Color(0xFF2E1A1A).withValues(alpha: 0.75),
        borderColor: Colors.redAccent.withValues(alpha: 0.3),
        glowColor: const Color(0xFFF44336),
        iconBg: const Color(0xFF5A2D2D).withValues(alpha: 0.5),
        iconColor: const Color(0xFFE57373),
        textColor: Colors.white,
        icon: Icons.error_rounded,
      );
    case ToastType.warning:
      return _ToastConfig(
        bgColor: const Color(0xFF2E2A1A).withValues(alpha: 0.75),
        borderColor: Colors.orangeAccent.withValues(alpha: 0.3),
        glowColor: const Color(0xFFFF9800),
        iconBg: const Color(0xFF5A4D2D).withValues(alpha: 0.5),
        iconColor: const Color(0xFFFFB74D),
        textColor: Colors.white,
        icon: Icons.warning_rounded,
      );
    case ToastType.info:
      return _ToastConfig(
        bgColor: const Color(0xFF1A1F2E).withValues(alpha: 0.75),
        borderColor: Colors.blueAccent.withValues(alpha: 0.3),
        glowColor: const Color(0xFF42A5F5),
        iconBg: const Color(0xFF2D3D5A).withValues(alpha: 0.5),
        iconColor: const Color(0xFF64B5F6),
        textColor: Colors.white,
        icon: Icons.info_rounded,
      );
  }
}
