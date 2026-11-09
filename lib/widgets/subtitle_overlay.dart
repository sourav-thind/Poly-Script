// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:window_manager/legacy.dart';

/// Floating subtitle pill shown in the transparent, always-on-top overlay
/// window.
class SubtitleOverlay extends StatefulWidget {
  const SubtitleOverlay({super.key});

  @override
  State<SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends State<SubtitleOverlay> {
  bool _isListening = false;

  void _startListening() {
    if (_isListening) return;
    setState(() => _isListening = true);
  }

  void _stopListening() {
    if (!_isListening) return;
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const _DragHandle(),
              const SizedBox(width: 14),
              Expanded(child: _SubtitleText(isListening: _isListening)),
              const SizedBox(width: 14),
              _ControlButton(
                icon: Icons.mic,
                label: 'Start',
                color: const Color(0xFF34C759),
                enabled: !_isListening,
                onPressed: _startListening,
              ),
              const SizedBox(width: 8),
              _ControlButton(
                icon: Icons.stop,
                label: 'Stop',
                color: const Color(0xFFFF453A),
                enabled: _isListening,
                onPressed: _stopListening,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drag handle that lets the user reposition the overlay window.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Drag to move the subtitle window',
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => windowManager.startDragging(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Icon(
              Icons.drag_indicator,
              color: Colors.white.withOpacity(0.6),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtitleText extends StatelessWidget {
  const _SubtitleText({required this.isListening});

  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isListening
                    ? const Color(0xFF34C759)
                    : Colors.white.withOpacity(0.38),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isListening ? 'LISTENING' : 'IDLE',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isListening
              ? 'Listening for subtitles…'
              : 'Press Start to begin listening',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
