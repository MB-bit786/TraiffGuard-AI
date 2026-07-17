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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? TariffColors.navyMid : const Color(0xFF1565C0),
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trash Bin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            Text('RECOVER OR ERASE AUDITS', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(invoiceListProvider.notifier).syncWithCloud();
              ref.read(trashListProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white.withValues(alpha: 0.1), height: 1),
        ),
      ),
      body: trashListAsync.when(
        data: (invoices) {
          if (invoices.isEmpty) return _buildEmptyState(context);
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: invoices.length,
            itemBuilder: (context, index) => _buildTrashCard(context, ref, invoices[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: TariffColors.amberPending)),
        error: (err, _) => Center(child: Text('Error loading trash: $err', style: TextStyle(color: isDark ? Colors.white : Colors.black))),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline_rounded, size: 64, color: isDark ? TariffColors.textMuted.withValues(alpha: 0.5) : Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Your Trash Bin is empty', style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black54, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Soft-deleted audits will appear here.', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[500], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTrashCard(BuildContext context, WidgetRef ref, InvoiceEntity invoice) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? TariffColors.navySurface : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: isDark ? TariffColors.cardBorder : Colors.grey[200]!, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(invoice.consignee, style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(invoice.cargoDescription, style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.black54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text('ID: ${invoice.id}', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[400], fontSize: 11, fontFamily: 'monospace')),
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
                    SnackBar(
                      content: const Text('Audit restored to Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? TariffColors.navyMid : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? TariffColors.cardBorder : Colors.grey[300]!)),
        title: Text('Erase Permanently?', style: TextStyle(color: isDark ? TariffColors.textPrimary : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text('This will hard-delete audit ${invoice.id} from local storage. This action cannot be undone.', style: TextStyle(color: isDark ? TariffColors.textSecondary : Colors.black54, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => context.pop(), child: Text('CANCEL', style: TextStyle(color: isDark ? TariffColors.textMuted : Colors.grey[600]))),
          TextButton(
            onPressed: () async {
              context.pop();
              await ref.read(trashListProvider.notifier).permanentlyDeleteInvoice(invoice.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Audit erased forever', style: TextStyle(fontWeight: FontWeight.w600)),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
