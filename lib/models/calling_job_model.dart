class CallingJob {
  final int callingId;
  final String docNo;
  final String jobId;
  final int lineNo;
  final String workOrder;
  final String itemName;
  final int status; // 1=CALLING, 3=WORKING, 4=COMPLETED, 9=CLOSED
  final String? statusName;
  final DateTime startTime;
  final DateTime? endTime;
  final int? totalTime;
  final String cause;

  // Action / History
  final int? empIdAction;
  final String? workType;
  final bool? canSelfRepair;
  final bool? needSupport;
  final String? repairType;
  final String? detailAction;
  final String? causeDetail;
  final DateTime? startTimeApp;
  final DateTime? endTimeApp;
  final String? sparePartUsed;
  final double? estimateCost;
  final int? estimateTime;
  final String? machineCondition;
  final String? resultAction;
  final bool? canUse;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CallingJob({
    required this.callingId,
    required this.docNo,
    required this.jobId,
    required this.lineNo,
    required this.workOrder,
    required this.itemName,
    required this.status,
    this.statusName,
    required this.startTime,
    this.endTime,
    this.totalTime,
    required this.cause,
    this.empIdAction,
    this.workType,
    this.canSelfRepair,
    this.needSupport,
    this.repairType,
    this.detailAction,
    this.causeDetail,
    this.startTimeApp,
    this.endTimeApp,
    this.sparePartUsed,
    this.estimateCost,
    this.estimateTime,
    this.machineCondition,
    this.resultAction,
    this.canUse,
    this.createdAt,
    this.updatedAt,
  });

  static int _toInt(dynamic v, {int def = 0}) {
    if (v == null) return def;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? def;
  }

  static int? _toIntN(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static double? _toDoubleN(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static bool? _toBoolN(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;

    final s = v.toString().toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'y' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'n' || s == 'no') return false;

    return null;
  }

  static DateTime? _toDateTimeN(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  factory CallingJob.fromJson(Map<String, dynamic> json) {
    final start = _toDateTimeN(json['start_time']) ?? DateTime.now();

    return CallingJob(
      callingId: _toInt(json['calling_id']),
      docNo: json['doc_no']?.toString() ?? '',
      jobId: json['job_id']?.toString() ?? '',
      lineNo: _toInt(json['line_no']),
      workOrder: json['work_order']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      status: _toInt(json['status'], def: 1),
      statusName: json['status_name']?.toString(),
      startTime: start,
      endTime: _toDateTimeN(json['end_time']),
      totalTime: _toIntN(json['total_time']),
      cause: json['cause']?.toString() ?? '',

      empIdAction: _toIntN(json['emp_id_action']),
      workType: json['work_type']?.toString(),
      canSelfRepair: _toBoolN(json['can_self_repair']),
      needSupport: _toBoolN(json['need_support']),
      repairType: json['repair_type']?.toString(),
      detailAction: json['detail_action']?.toString(),
      causeDetail: json['cause_detail']?.toString(),
      startTimeApp: _toDateTimeN(json['start_time_app']),
      endTimeApp: _toDateTimeN(json['end_time_app']),
      sparePartUsed: json['spare_part_used']?.toString(),
      estimateCost: _toDoubleN(json['estimate_cost']),
      estimateTime: _toIntN(json['estimate_time']),
      machineCondition: json['machine_condition']?.toString(),
      resultAction: json['result_action']?.toString(),
      canUse: _toBoolN(json['can_use']),
      createdAt: _toDateTimeN(json['created_at']),
      updatedAt: _toDateTimeN(json['updated_at']),
    );
  }
}
