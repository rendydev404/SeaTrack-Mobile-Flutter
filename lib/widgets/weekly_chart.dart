import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../providers/transaction_provider.dart';

/// Grafik batang 7 hari terakhir. Digambar dengan CustomPainter tunggal
/// sehingga ringan dan tanpa dependensi chart.
class WeeklyChart extends StatelessWidget {
  const WeeklyChart({super.key, required this.days});

  final List<DayStat> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    double max = 0;
    for (final d in days) {
      if (d.income > max) max = d.income;
      if (d.expense > max) max = d.expense;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('7 Hari Terakhir', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Spacer(),
            _Legend(color: AppColors.income, label: 'Masuk'),
            SizedBox(width: 12),
            _Legend(color: AppColors.expense, label: 'Keluar'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BarsPainter(days: days, max: max, track: scheme.outlineVariant.withValues(alpha: 0.25)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final d in days)
              Expanded(
                child: Text(
                  Fmt.weekday(d.day),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
        if (max > 0) ...[
          const SizedBox(height: 6),
          Text(
            'Puncak ${Fmt.compact(max)}',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.days, required this.max, required this.track});

  final List<DayStat> days;
  final double max;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final slot = size.width / days.length;
    final barW = (slot * 0.28).clamp(4.0, 14.0);
    const gap = 3.0;
    final r = Radius.circular(barW / 2);
    final inPaint = Paint()..color = AppColors.income;
    final outPaint = Paint()..color = AppColors.expense;
    final trackPaint = Paint()..color = track;

    for (var i = 0; i < days.length; i++) {
      final cx = slot * i + slot / 2;
      final xIn = cx - barW - gap / 2;
      final xOut = cx + gap / 2;
      canvas.drawRRect(RRect.fromLTRBR(xIn, 0, xIn + barW, size.height, r), trackPaint);
      canvas.drawRRect(RRect.fromLTRBR(xOut, 0, xOut + barW, size.height, r), trackPaint);
      if (max <= 0) continue;
      final hIn = (days[i].income / max * size.height).clamp(0.0, size.height);
      final hOut = (days[i].expense / max * size.height).clamp(0.0, size.height);
      if (hIn > 0) {
        canvas.drawRRect(RRect.fromLTRBR(xIn, size.height - hIn.clamp(barW, size.height), xIn + barW, size.height, r), inPaint);
      }
      if (hOut > 0) {
        canvas.drawRRect(RRect.fromLTRBR(xOut, size.height - hOut.clamp(barW, size.height), xOut + barW, size.height, r), outPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.days != days || old.max != max || old.track != track;
}
