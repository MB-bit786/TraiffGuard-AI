import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/config/theme/tariff_colors.dart';
import '../../../invoice/domain/entities/invoice_entity.dart';
import '../providers/trash_list_provider.dart';
import '../providers/invoice_list_provider.dart';
import 'package:go_router/go_router.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashListAsync = ref.watch(trashListProvider);

    return Scaffold(
      backgroundColor: TariffColors.navyDeep,
      appBar: AppBar(
        backgroundColor: TariffColors.navyMid,
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trash Bin',
              style: TextStyle(
                color: TariffColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'RECOVER OR ERASE AUDITS',
              style: TextStyle(
                color: TariffColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(invoiceListProvider.notifier).syncWithCloud();
              ref.read(trashListProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh_rounded, color: TariffColors.textMuted, size: 22),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: TariffColors.divider, height: 1),
        ),
      ),
      body: trashListAsync.when(
        data: (invoices) {
          if (invoices.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: invoices.length,
            itemBuilder: (context, index) => _buildTrashCard(context, ref, invoices[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: TariffColors.amberPending)),
        error: (err, _) => Center(
          child: Text('Error loading trash: $err', style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_outline_rounded,
            size: 64,
            color: TariffColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your Trash Bin is empty',
            style: TextStyle(
              color: TariffColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Soft-deleted audits will appear here.',
            style: TextStyle(color: TariffColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashCard(BuildContext context, WidgetRef ref, InvoiceEntity invoice) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: TariffColors.navySurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: TariffColors.cardBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.consignee,
                    style: const TextStyle(
                      color: TariffColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    invoice.cargoDescription,
                    style: const TextStyle(color: TariffColors.textSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID: ${invoice.id}',
                    style: const TextStyle(
                      color: TariffColors.textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.restore_rounded, color: TariffColors.greenVerified),
              tooltip: 'Restore',
              onPressed: () async {
                await ref.read(trashListProvider.notifier).restoreInvoice(invoice.id);
                ref.read(invoiceListProvider.notifier).fetchInvoices();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Audit restored to Dashboard'),
                      backgroundColor: Color(0xFFFFB300),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: TariffColors.crimsonRisk),
              tooltip: 'Delete Permanently',
              onPressed: () => _confirmHardDelete(context, ref, invoice),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmHardDelete(BuildContext context, WidgetRef ref, InvoiceEntity invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TariffColors.navyMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Erase Permanently?',
          style: TextStyle(color: TariffColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will hard-delete audit ${invoice.id} from local storage. This action cannot be undone.',
          style: const TextStyle(color: TariffColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('CANCEL', style: TextStyle(color: TariffColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              context.pop();
              await ref.read(trashListProvider.notifier).permanentlyDeleteInvoice(invoice.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Audit erased forever'),
                    backgroundColor: Color(0xFFFFB300),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('ERASE', style: TextStyle(color: TariffColors.crimsonRisk, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
