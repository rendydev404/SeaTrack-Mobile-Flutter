import 'package:flutter/material.dart';

/// Kartu ajakan memberi izin. Hanya tampil saat izin belum diberikan.
class PermissionCard extends StatelessWidget {
  const PermissionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
    this.tone = PermissionTone.primary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;
  final PermissionTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = tone == PermissionTone.primary ? scheme.primary : scheme.tertiaryContainer;
    final fg = tone == PermissionTone.primary ? scheme.onPrimary : scheme.onTertiaryContainer;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: fg.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, color: fg, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 13.5, height: 1.4)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: fg,
              foregroundColor: bg,
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

enum PermissionTone { primary, secondary }
