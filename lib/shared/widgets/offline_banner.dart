import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/di/service_locator.dart';
import '../../core/network/connectivity_status.dart';
import '../../core/network/pending_actions_queue.dart';
import '../extensions/context_extensions.dart';
import 'status_banner.dart';

/// Slim status strip under the app bar:
///
/// * offline → red, saying whether work is waiting on the device;
/// * online with queued work → amber "syncing N actions", so the user knows
///   the work is on its way rather than lost;
/// * online with nothing queued → nothing at all (zero height, no shift).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = sl<ConnectivityStatus>();
    final queue = sl<PendingActionsQueue>();
    return ValueListenableBuilder<bool>(
      valueListenable: connectivity,
      builder: (context, online, _) {
        return ValueListenableBuilder<int>(
          valueListenable: queue.pendingCount,
          builder: (context, pending, __) {
            if (online && pending == 0) return const SizedBox.shrink();
            if (online) {
              return StatusBanner(
                color: context.x.warning,
                icon: Icons.sync_rounded,
                message: context.s.offlineSyncing(pending),
              );
            }
            return StatusBanner(
              color: context.colors.error,
              icon: Icons.cloud_off_rounded,
              message: pending > 0
                  ? context.s.offlineWithQueue(pending)
                  : context.s.offlineNoQueue,
            );
          },
        );
      },
    );
  }
}
