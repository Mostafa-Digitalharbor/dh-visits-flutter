import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/network/connectivity_status.dart';
import '../../core/network/pending_actions_queue.dart';
import '../extensions/context_extensions.dart';
import 'status_banner.dart';

/// Slim status strip that sits under the AppBar whenever connectivity
/// drops *or* the offline queue has pending writes. Two-line worst
/// case (offline + N pending actions). When everything is fine it
/// collapses to zero height so layout doesn't shift.
///
/// We deliberately don't show this when only `pendingCount > 0` and
/// already online — the queue flushes automatically within seconds, so
/// flashing a banner in that case would feel noisy. The cases where it
/// matters are "you're offline" and "you're offline AND have work
/// waiting to sync".
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
            // Online + no queue = render nothing. Online + queue >0 =
            // a tiny "syncing" pill so the user knows their work is in
            // flight rather than lost.
            if (online && pending == 0) return const SizedBox.shrink();
            if (online && pending > 0) {
              return StatusBanner(
                color: Colors.amber.shade700,
                icon: Icons.sync_rounded,
                message: context.s.offlineSyncing(pending),
              );
            }
            return StatusBanner(
              color: Colors.red.shade600,
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

