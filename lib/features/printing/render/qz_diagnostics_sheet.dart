import 'package:flutter/material.dart';

import '../services/qz_print_service.dart';

Future<void> retryQzBridge(
  BuildContext context,
  QzPrintService service,
) async {
  if (!service.isEnabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ฟีเจอร์ QZ Tray ใช้ได้เฉพาะบนเว็บ')),
    );
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  try {
    await service.ensureReady();
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('โหลดบริดจ์ QZ Tray สำเร็จ')),
    );
  } on QzPrintException catch (error) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(error.message)),
    );
  } catch (error) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('โหลดบริดจ์ QZ Tray ไม่สำเร็จ: $error')),
    );
  }
}

Future<void> showQzDiagnosticsSheet(
  BuildContext context,
  QzPrintService service,
) async {
  if (!service.isEnabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ฟีเจอร์ QZ Tray ใช้ได้เฉพาะบนเว็บ')),
    );
    return;
  }

  final messenger = ScaffoldMessenger.of(context);

  try {
    await service.ensureReady();
  } on QzPrintException catch (error) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(error.message)),
    );
    return;
  } catch (error) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('เชื่อมต่อ QZ Tray ไม่สำเร็จ: $error')),
    );
    return;
  }

  QzSelfTestReport? report;
  try {
    report = await service.diagnose();
  } on QzPrintException catch (error) {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('ตรวจสอบ QZ Tray ไม่สำเร็จ: ${error.message}')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('ตรวจสอบ QZ Tray ไม่สำเร็จ: $error')),
      );
    }
  }

  if (!context.mounted) {
    return;
  }

  final QzStatusSnapshot status = service.currentStatus;
  final String origin = Uri.base.origin;
  final String endpointLabel = _resolveEndpoint(report?.triedEndpoints ?? const <QzEndpointAttempt>[]);
  final String environmentLabel = status.environment ?? '-';
  final String certificateSubject = status.certificateSubject ?? '-';
  final String certificateIssuer = status.certificateIssuer ?? '-';
  final String certificateExpiry = status.certificateExpiresAt != null
      ? status.certificateExpiresAt!.toLocal().toString()
      : '-';
  final String version = report?.version ?? '-';
  final bool trusted = status.isTrusted ?? false;
  final bool? certificateValid = status.isCertificateValid;
  final bool whitelistOk = status.isWhitelisted;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      final ThemeData theme = Theme.of(sheetContext);
      final List<String> allowTips = <String>[
        'เปิด QZ Tray → Settings → Security → Allowed Origins',
        'เพิ่ม origin ปัจจุบัน: $origin',
        'เพิ่ม http://localhost:55390 (โหมดพัฒนา)',
        'เพิ่ม http://127.0.0.1:55390 หากใช้งานผ่าน loopback',
      ];

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('QZ Diagnostics', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                _InfoRow(label: 'Origin', value: origin),
                _InfoRow(label: 'Environment', value: environmentLabel),
                _InfoRow(label: 'QZ Endpoint', value: endpointLabel),
                _InfoRow(label: 'QZ Tray Version', value: version),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _StatusChip(label: 'Trusted', value: trusted),
                    _StatusChip(
                      label: 'Certificate',
                      value: certificateValid,
                    ),
                    _StatusChip(label: 'Whitelist', value: whitelistOk),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Certificate Subject', value: certificateSubject),
                _InfoRow(label: 'Certificate Issuer', value: certificateIssuer),
                _InfoRow(label: 'Certificate Expiry', value: certificateExpiry),
                if (status.whitelistError != null && status.whitelistError!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Whitelist error: ${status.whitelistError}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    final bool success = await service.openSiteManager();
                    if (!sheetContext.mounted) {
                      return;
                    }
                    if (!success) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('เปิด QZ Tray Site Manager ไม่สำเร็จ')),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('เปิด QZ Tray Site Manager'),
                ),
                const SizedBox(height: 24),
                Text('คำแนะนำ Allowed Origins', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ...allowTips.map(
                  (String tip) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('• '),
                        Expanded(child: Text(tip)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _resolveEndpoint(List<QzEndpointAttempt> attempts) {
  for (final QzEndpointAttempt attempt in attempts) {
    if (attempt.success == true && attempt.url.isNotEmpty) {
      return attempt.url;
    }
  }
  for (final QzEndpointAttempt attempt in attempts) {
    if (!attempt.skipped && attempt.url.isNotEmpty) {
      return attempt.url;
    }
  }
  if (attempts.isNotEmpty) {
    return attempts.last.url;
  }
  return 'ยังไม่เชื่อมต่อ';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.value});

  final String label;
  final bool? value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    late final Color background;
    late final IconData icon;
    late final String text;

    if (value == null) {
      background = theme.colorScheme.surfaceContainerHighest;
      icon = Icons.help_outline;
      text = '$label: ไม่ทราบ';
    } else if (value!) {
      background = theme.colorScheme.secondaryContainer;
      icon = Icons.check_circle_outline;
      text = '$label: พร้อม';
    } else {
      background = theme.colorScheme.errorContainer;
      icon = Icons.error_outline;
      text = '$label: มีปัญหา';
    }

    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(text),
      backgroundColor: background,
    );
  }
}
