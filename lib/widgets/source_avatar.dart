import 'package:flutter/material.dart';

import '../core/sources.dart';
import '../core/theme.dart';
import '../models/transaction.dart';

/// Lingkaran berwarna sesuai sumber, dengan panah arah transaksi.
class SourceAvatar extends StatelessWidget {
  const SourceAvatar({super.key, required this.source, required this.type, this.size = 44});

  final TxSource source;
  final TxType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = source == TxSource.manual
        ? (type == TxType.income ? AppColors.income : AppColors.expense)
        : source.color;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(size * 0.32),
            ),
            child: Center(
              child: Text(
                source == TxSource.manual ? 'M' : source.label.substring(0, 1),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.4,
                ),
              ),
            ),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: size * 0.42,
              height: size * 0.42,
              decoration: BoxDecoration(
                color: type == TxType.income ? AppColors.income : AppColors.expense,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
              ),
              child: Icon(
                type == TxType.income ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                size: size * 0.24,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
