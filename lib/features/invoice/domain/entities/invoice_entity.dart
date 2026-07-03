import 'package:flutter/foundation.dart';

enum InvoiceSyncStatus { synced, offlineDraft }

@immutable
class InvoiceEntity {
  const InvoiceEntity({
    required this.id,
    required this.userId,
    required this.consignee,
    required this.cargoDescription,
    required this.hsCode,
    required this.dutyRate,
    required this.status,
    required this.timestamp,
    this.isDeleted = false,
  });

  final String id;
  final String userId;
  final String consignee;
  final String cargoDescription;
  final String hsCode;
  final String dutyRate;
  final String status; // Keep as string for DB but use enum for logic
  final String timestamp;
  final bool isDeleted;
}
