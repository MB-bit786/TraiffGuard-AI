import 'package:flutter/foundation.dart';

enum InvoiceSyncStatus { synced, offlineDraft }

@immutable
class InvoiceModel {
  const InvoiceModel({
    required this.id,
    required this.consignee,
    required this.cargoDescription,
    required this.hsCode,
    required this.dutyRate,
    required this.status,
    required this.timestamp,
    this.isDeleted = false,
  });

  final String id;
  final String consignee;
  final String cargoDescription;
  final String hsCode;
  final String dutyRate;
  final InvoiceSyncStatus status;
  final String timestamp;
  final bool isDeleted;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'consignee': consignee,
      'cargoDescription': cargoDescription,
      'hsCode': hsCode,
      'dutyRate': dutyRate,
      'status': status.name,
      'timestamp': timestamp,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id'] as String,
      consignee: map['consignee'] as String,
      cargoDescription: map['cargoDescription'] as String,
      hsCode: map['hsCode'] as String,
      dutyRate: map['dutyRate'] as String,
      status: InvoiceSyncStatus.values.byName(map['status'] as String),
      timestamp: map['timestamp'] as String,
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
    );
  }

  InvoiceModel copyWith({
    String? id,
    String? consignee,
    String? cargoDescription,
    String? hsCode,
    String? dutyRate,
    InvoiceSyncStatus? status,
    String? timestamp,
    bool? isDeleted,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      consignee: consignee ?? this.consignee,
      cargoDescription: cargoDescription ?? this.cargoDescription,
      hsCode: hsCode ?? this.hsCode,
      dutyRate: dutyRate ?? this.dutyRate,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
