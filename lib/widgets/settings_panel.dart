// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

/// Inline settings form shown inside the floating overlay.
///
/// Lets each user paste their own Gemini API key and opt into capturing
/// microphone audio alongside system audio.
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.hasSavedKey,
    required this.includeMicrophone,
    required this.onSave,
    required this.onRemove,
    required this.onCancel,
  });

  /// Whether a key is already stored for this user.
  final bool hasSavedKey;

  /// Whether microphone audio is currently enabled.
  final bool includeMicrophone;

  /// Called with a new key (or `null` to keep the existing one) and the mic
  /// preference.
  final void Function(String? apiKey, bool includeMicrophone) onSave;

  /// Called when the user removes the stored key.
  final VoidCallback onRemove;

  /// Called when the user dismisses the panel.
  final VoidCallback onCancel;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;
  late bool _includeMic = widget.includeMicrophone;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  bool get _canSave =>
      _controller.text.trim().isNotEmpty || widget.hasSavedKey;

  void _save() {
    if (!_canSave) return;
    final trimmed = _controller.text.trim();
    widget.onSave(trimmed.isEmpty ? null : trimmed, _includeMic);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.key, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              const Text(
                'Gemini API Key',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              _MicToggle(
                value: _includeMic,
                onChanged: (value) => setState(() => _includeMic = value),
              ),
              const Spacer(),
              Text(
                widget.hasSavedKey ? 'Key saved' : 'No key set',
                style: TextStyle(
                  color: widget.hasSavedKey
                      ? const Color(0xFF34C759)
                      : Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: Colors.white,
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.hasSavedKey
                        ? 'Enter a new key to replace the saved one'
                        : 'Paste your Gemini API key',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: _obscure ? 'Show key' : 'Hide key',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 4),
              _PanelButton(
                label: 'Save',
                color: const Color(0xFF34C759),
                onPressed: _canSave ? _save : null,
              ),
              if (widget.hasSavedKey) ...[
                const SizedBox(width: 8),
                _PanelButton(
                  label: 'Remove',
                  color: const Color(0xFFFF453A),
                  onPressed: widget.onRemove,
                ),
              ],
              const SizedBox(width: 8),
              _PanelButton(
                label: 'Cancel',
                color: Colors.white.withOpacity(0.18),
                onPressed: widget.onCancel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MicToggle extends StatelessWidget {
  const _MicToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: value,
                onChanged: (checked) => onChanged(checked ?? false),
                activeColor: const Color(0xFF34C759),
                checkColor: Colors.black,
                side: BorderSide(color: Colors.white.withOpacity(0.4)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Include microphone',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
