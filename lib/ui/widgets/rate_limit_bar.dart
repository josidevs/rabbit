import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/services.dart';
import '../../utils/format.dart';

/// Thin bar pinned above the navigation bar showing how much of the current
/// OAuth rate-limit window remains, with a countdown to reset.
/// Color changes with usage, but the numbers are always shown too (color is
/// never the only signal).
class RateLimitBar extends StatefulWidget {
  const RateLimitBar({super.key});

  @override
  State<RateLimitBar> createState() => _RateLimitBarState();
}

class _RateLimitBarState extends State<RateLimitBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Tick to keep the reset countdown current.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && Services.rateLimit.hasData) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Services.rateLimit,
      builder: (context, _) {
        final rl = Services.rateLimit;
        final scheme = Theme.of(context).colorScheme;
        final frac = rl.fractionRemaining;
        // Okabe–Ito hues: green -> orange -> vermillion as budget drains.
        final color = frac > 0.5
            ? const Color(0xFF009E73)
            : frac > 0.2
                ? const Color(0xFFE69F00)
                : const Color(0xFFD55E00);
        final label = rl.hasData
            ? 'API ${rl.remaining.round()}/${rl.limit.round()} left · resets in ${formatDuration(rl.untilReset)}'
            : 'API rate limit: no requests yet';

        return Container(
          color: scheme.surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Row(
            children: [
              Icon(Icons.speed_rounded, size: 13, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: rl.hasData ? frac : 1,
                    minHeight: 4,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: rl.hasData ? color : scheme.outlineVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }
}
