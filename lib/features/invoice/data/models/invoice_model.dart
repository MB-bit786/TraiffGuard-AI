import 'package:hscode_auditor/features/invoice/domain/entities/invoice_entity.dart';

class InvoiceModel extends InvoiceEntity {
  const InvoiceModel({
    required super.id,
    required super.userId,
    required super.consignee,
    required super.cargoDescription,
    required super.hsCode,
    required super.dutyRate,
    required super.status,
    required super.timestamp,
    super.recordId = '',
    super.isDeleted = false,
    super.syncAttempts = 0,
    super.updatedAt = '',
    super.isHidden = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'record_id': recordId,
      'userId': userId,
      'consignee': consignee,
      'cargoDescription': cargoDescription,
      'hsCode': hsCode,
      'dutyRate': dutyRate,
      'status': status,
      'timestamp': timestamp,
      'isDeleted': isDeleted ? 1 : 0,
      'syncAttempts': syncAttempts,
      'updatedAt': updatedAt,
      'is_hidden': isHidden ? 1 : 0,
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id'] as String,
      recordId: map['record_id'] as String? ?? '',
      userId: map['userId'] as String? ?? 'anonymous',
      consignee: map['consignee'] as String,
      cargoDescription: map['cargoDescription'] as String,
      hsCode: map['hsCode'] as String,
      dutyRate: map['dutyRate'] as String,
      status: map['status'] as String,
      timestamp: map['timestamp'] as String,
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
      syncAttempts: map['syncAttempts'] as int? ?? 0,
      updatedAt: map['updatedAt'] as String? ?? '',
      isHidden: (map['is_hidden'] as int? ?? 0) == 1,
    );
  }

  InvoiceModel copyWith({
    String? id,
    String? recordId,
    String? userId,
    String? consignee,
    String? cargoDescription,
    String? hsCode,
    String? dutyRate,
    String? status,
    String? timestamp,
    bool? isDeleted,
    int? syncAttempts,
    String? updatedAt,
    bool? isHidden,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      userId: userId ?? this.userId,
      consignee: consignee ?? this.consignee,
      cargoDescription: cargoDescription ?? this.cargoDescription,
      hsCode: hsCode ?? this.hsCode,
      dutyRate: dutyRate ?? this.dutyRate,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      isDeleted: isDeleted ?? this.isDeleted,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      updatedAt: updatedAt ?? this.updatedAt,
      isHidden: isHidden ?? this.isHidden,
    );
  }
}
