import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuditFilter { all, synced, offlineDraft }

final auditFilterProvider = StateProvider<AuditFilter>((ref) => AuditFilter.all);
