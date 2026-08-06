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
    this.recordId = '',
    this.isDeleted = false,
    this.syncAttempts = 0,
    this.updatedAt = '',
    this.isHidden = false,
  });

  final String id; // Local Primary Key (legacy compatible)
  final String recordId; // Globally unique UUID for Firestore and sync
  final String userId;
  final String consignee;
  final String cargoDescription;
  final String hsCode;
  final String dutyRate;
  final String status;
  final String timestamp;
  final bool isDeleted;
  final int syncAttempts;
  final String updatedAt;
  final bool isHidden;
}
