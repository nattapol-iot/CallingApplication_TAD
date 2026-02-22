import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_theme.dart';
import '../models/calling_job_model.dart';
import '../models/employee_model.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import '../widgets/summary_card.dart';
import '../widgets/status_filter.dart';
import 'server_settings_screen.dart';
import 'login_screen.dart';
import 'job_detail_screen.dart';
import '../services/foreground_calling_service.dart';
import '../services/wakelock_service.dart';

class CallingHomePage extends StatefulWidget {
  final EmployeeProfile employee;
  const CallingHomePage({super.key, required this.employee});

  @override
  State<CallingHomePage> createState() => _CallingHomePageState();
}

class _CallingHomePageState extends State<CallingHomePage> {
  final WebSocketService _wsService = WebSocketService();
  final NotificationService _notiService = NotificationService.instance;

  List<CallingJob> _jobs = [];
  String _statusFilter = 'ALL';
  bool _isConnected = false;
  String? _lastError;
  List<CallingJob> _cachedDisplayJobs = [];

  int _lastCallingCount = 0;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _notiService.init();
    await _notiService.requestPermissionsIfNeeded();

    // Request to disable battery optimization for reliable background operation
    await WakeLockService.requestDisableBatteryOptimization();

    _connectServer();
  }

  Future<void> _connectServer() async {
    final prefs = await SharedPreferences.getInstance();
    final url =
        prefs.getString('ws_url') ?? 'ws://192.168.1.132:5020/ws/calling';

    _wsService.onMessage = _handleWSMessage;
    _wsService.onError = (err) {
      if (!mounted) return;
      setState(() => _lastError = err);
    };

    _wsService.onStatusChange = (status) {
      if (!mounted) return;
      setState(() => _isConnected = status);

      if (status) {
        // ✅ Connected แล้วขอข้อมูลทันที
        _wsService.sendJson({"type": "GET_HISTORY"});
      }
    }; // ✅ start foreground หลังเข้าหน้า Home (คุณบอกว่า login ok แล้ว)
    await ForegroundCallingService.start(wsUrl: url);

    _wsService.connect(url);
  }

  Future<void> _handleMenu(String v) async {
    if (v == 'logout') {
      await ForegroundCallingService.stop(); // ✅ หยุด service ก่อน
      _wsService.dispose();
      _notiService.stopCallingOngoing();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (r) => false,
      );
    } else if (v == 'refresh') {
      _wsService.sendJson({"type": "GET_HISTORY"});
    } else if (v == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ServerSettingPage()),
      ).then((_) => _connectServer());
    }
  }

  @override
  void dispose() {
    _wsService.dispose();
    _notiService.stopCallingOngoing();
    super.dispose();
  }

  void _handleWSMessage(dynamic message) {
    try {
      final obj = jsonDecode(message.toString());
      final type = obj['type'];

      if (type == 'CALLING_UPDATE' || type == 'CALLING_HISTORY') {
        final List<dynamic> jobsJson = obj['jobs'] ?? [];
        final newJobs = jobsJson.map((e) => CallingJob.fromJson(e)).toList();

        if (!mounted) return;
        setState(() {
          _jobs = newJobs;
          _updateFilteredList();
          _lastError = null;
        });

        _syncCallingAlert();
      } else if (type == 'ACK') {
        final msg = obj['message']?.toString() ?? '';
        final success = obj['success'] == true;
        final cmd = obj['cmd']?.toString() ?? '';

        // ✅ รับงานสำเร็จ -> หยุดเสียง/สั่นทันที (ตาม requirement)
        if (success && cmd == 'START_JOB') {
          _notiService.stopCallingOngoing();
          _lastCallingCount = 0; // reset local state ด้วย
        }

        // กรองข้อความที่ไม่จำเป็น
        if (msg.isNotEmpty && msg != 'PONG' && msg != 'Job started.') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }

        // ✅ รีโหลดข้อมูลหลัง ACK
        if (success && (cmd == 'START_JOB' || cmd == 'FINISH_JOB')) {
          _wsService.sendJson({"type": "GET_HISTORY"});
        }
      }
    } catch (e) {
      debugPrint('Error parse: $e');
    }
  }

  // ✅ คุม alert ตาม rule:
  // - CALLING ค้าง >0 => ดัง+สั่นทุก 10 วิ
  // - =0 => หยุดทันที
  // - ถ้าจำนวนเปลี่ยน ให้ restart loop เพื่อให้ count ไม่ค้างค่าเก่า
  void _syncCallingAlert() {
    final callingCount = _jobs.where((j) => j.status == 1).length;

    if (callingCount <= 0) {
      if (_lastCallingCount != 0) {
        _notiService.stopCallingOngoing();
      }
      _lastCallingCount = 0;
      return;
    }

    // ถ้าจำนวนเปลี่ยน -> restart เพื่อให้ timer ใช้ count ล่าสุดแน่นอน
    if (callingCount != _lastCallingCount) {
      _notiService.stopCallingOngoing();
      _notiService.showCallingOngoing(callingCount);
      _lastCallingCount = callingCount;
    } else {
      // จำนวนเท่าเดิม -> แค่ ensure ว่ามันรันอยู่
      _notiService.showCallingOngoing(callingCount);
    }
  }

  void _updateFilteredList() {
    final list = _jobs.where((job) {
      if (_statusFilter == 'ALL') return true;
      if (_statusFilter == 'CALLING') return job.status == 1;
      if (_statusFilter == 'WORKING') return job.status == 3;
      if (_statusFilter == 'COMPLETED') return job.status == 4;
      if (_statusFilter == 'CLOSED') return job.status == 9;
      return true;
    }).toList();

    list.sort((a, b) {
      final sa = a.status == 1 ? 0 : 1;
      final sb = b.status == 1 ? 0 : 1;
      if (sa != sb) return sa.compareTo(sb);
      return b.startTime.compareTo(a.startTime);
    });

    _cachedDisplayJobs = list;
  }

  void _onFilterChanged(String newFilter) {
    setState(() {
      _statusFilter = newFilter;
      _updateFilteredList();
    });
  }

  void _onJobTap(CallingJob job) {
    if (job.status == 1) {
      _showStartJobDialog(job);
    } else if (job.status == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(
            job: job,
            employee: widget.employee,
            onSendCommand: (data) {
              _wsService.sendJson(data);
            },
          ),
        ),
      );
    }
  }

  // -----------------------------
  // ✅ EMP ID Helper (สำคัญ)
  // - ถ้า userId เป็นตัวเลข -> ใช้ได้เลย
  // - ถ้าเป็น GUID -> อ่านจาก cache emp_id_<username>
  // -----------------------------
  Future<int?> _getEmpIdOrNull() async {
    final direct = int.tryParse(widget.employee.userId);
    if (direct != null && direct > 0) return direct;

    final prefs = await SharedPreferences.getInstance();
    final key = 'emp_id_${widget.employee.username}';
    final cached = prefs.getInt(key);
    if (cached != null && cached > 0) return cached;

    return null;
  }

  // ------------------------------------------------------------------
  // ✅ START_JOB Dialog (UI ปรับตาม requirement)
  // ------------------------------------------------------------------
  Future<void> _showStartJobDialog(CallingJob job) async {
    final formKey = GlobalKey<FormState>();

    final machineCodeCtrl = TextEditingController();
    final machineNameCtrl = TextEditingController();
    final detailActionCtrl = TextEditingController();
    final causeDetailCtrl = TextEditingController();

    // prefill จาก server
    if (job.itemName.isNotEmpty) machineNameCtrl.text = job.itemName;
    if (job.cause.isNotEmpty) causeDetailCtrl.text = job.cause;

    // ใช้ Position Name จาก User โดยตรง
    String positionName = widget.employee.positionName.isNotEmpty
        ? widget.employee.positionName
        : widget.employee.positionCode;

    String repairType = 'REPAIR'; // REPAIR / PM
    bool canSelfRepair = true;
    bool needSupport = false;

    String _fmtTime(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    Widget infoRow(String label, String value, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '-' : value,
                style: GoogleFonts.kanit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
      );
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final statusColor = AppTheme.statusColor(job.status);

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: AppTheme.primaryRed),
                  const SizedBox(width: 8),
                  Text(
                    'เริ่มงานซ่อม',
                    style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // =========================
                      // 1) Job Detail from Server
                      // =========================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status badge + time
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: statusColor.withOpacity(0.25),
                                    ),
                                  ),
                                  child: Text(
                                    job.statusName ?? 'CALLING',
                                    style: GoogleFonts.kanit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                                Text(
                                  _fmtTime(job.startTime),
                                  style: GoogleFonts.kanit(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Text(
                              '${job.workOrder} : ${job.itemName}',
                              style: GoogleFonts.kanit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 10),

                            infoRow('Calling ID', job.callingId.toString()),
                            infoRow('Doc No', job.docNo),
                            infoRow('Job ID', job.jobId),
                            infoRow('Line', job.lineNo.toString()),
                            infoRow('Start', job.startTime.toIso8601String()),
                            infoRow(
                              'Cause',
                              job.cause,
                              valueColor: AppTheme.primaryRed,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
                      Text(
                        'ข้อมูลเริ่มงาน (Start Job)',
                        style: GoogleFonts.kanit(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 1) Machine Code
                      TextFormField(
                        controller: machineCodeCtrl,
                        style: GoogleFonts.kanit(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Machine Code *',
                          labelStyle: GoogleFonts.kanit(fontSize: 13),
                          hintText: 'เช่น MC-PRS-001',
                          hintStyle: GoogleFonts.kanit(fontSize: 13),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.code, size: 20),
                        ),
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'กรุณาระบุ Machine Code'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // 2) Machine Name
                      TextFormField(
                        controller: machineNameCtrl,
                        style: GoogleFonts.kanit(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Machine Name *',
                          labelStyle: GoogleFonts.kanit(fontSize: 13),
                          hintText: 'เช่น Press-01',
                          hintStyle: GoogleFonts.kanit(fontSize: 13),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(
                            Icons.precision_manufacturing,
                            size: 20,
                          ),
                        ),
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'กรุณาระบุ Machine Name'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // 3) Position (แสดงอัตโนมัติจาก User - ไม่ให้แก้ไข)
                      TextFormField(
                        initialValue: positionName,
                        enabled: false,
                        style: GoogleFonts.kanit(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Position *',
                          labelStyle: GoogleFonts.kanit(fontSize: 13),
                          helperText: 'ตำแหน่งจากข้อมูล User',
                          helperStyle: GoogleFonts.kanit(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.work_outline, size: 20),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 4) Repair Type (Repair / PM)
                      DropdownButtonFormField<String>(
                        value: repairType,
                        style: GoogleFonts.kanit(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Repair Type *',
                          labelStyle: GoogleFonts.kanit(fontSize: 13),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(
                            Icons.build_circle_outlined,
                            size: 20,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'REPAIR',
                            child: Text(
                              'Repair',
                              style: GoogleFonts.kanit(fontSize: 14),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'PM',
                            child: Text(
                              'PM',
                              style: GoogleFonts.kanit(fontSize: 14),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setLocalState(() => repairType = v ?? 'REPAIR'),
                      ),
                      const SizedBox(height: 12),

                      // 5) can_self_repair
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            'ซ่อมเองได้',
                            style: GoogleFonts.kanit(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            canSelfRepair
                                ? 'สถานะ: ซ่อมเองได้'
                                : 'สถานะ: ไม่สามารถซ่อมเองได้',
                            style: GoogleFonts.kanit(
                              fontSize: 12,
                              color: canSelfRepair ? Colors.green : Colors.red,
                            ),
                          ),
                          value: canSelfRepair,
                          onChanged: (v) =>
                              setLocalState(() => canSelfRepair = v),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 6) need_support
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            'ต้องการ Support',
                            style: GoogleFonts.kanit(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            needSupport
                                ? 'สถานะ: ต้องการ'
                                : 'สถานะ: ไม่ต้องการ',
                            style: GoogleFonts.kanit(
                              fontSize: 12,
                              color: needSupport ? Colors.orange : Colors.grey,
                            ),
                          ),
                          value: needSupport,
                          onChanged: (v) =>
                              setLocalState(() => needSupport = v),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 7) detail_action
                      TextFormField(
                        controller: detailActionCtrl,
                        maxLines: 2,
                        style: GoogleFonts.kanit(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Detail Action *',
                          labelStyle: GoogleFonts.kanit(fontSize: 13),
                          hintText: 'รายละเอียดการดำเนินการ',
                          hintStyle: GoogleFonts.kanit(fontSize: 13),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(
                            Icons.description_outlined,
                            size: 20,
                          ),
                        ),
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'กรุณาระบุ Detail Action'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // 8) cause_detail
                      TextFormField(
                        controller: causeDetailCtrl,
                        maxLines: 2,
                        style: GoogleFonts.kanit(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Cause Detail *',
                          labelStyle: GoogleFonts.kanit(fontSize: 13),
                          hintText: 'สาเหตุของปัญหา',
                          hintStyle: GoogleFonts.kanit(fontSize: 13),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(
                            Icons.report_problem_outlined,
                            size: 20,
                          ),
                        ),
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'กรุณาระบุ Cause Detail'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'ยกเลิก',
                    style: GoogleFonts.kanit(fontSize: 15, color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    // ใช้ emp_id จาก employee profile หรือ cached value
                    int empIdInt;
                    final direct = int.tryParse(widget.employee.userId);
                    if (direct != null && direct > 0) {
                      empIdInt = direct;
                    } else {
                      // ถ้า userId เป็น GUID ให้ใช้ค่าที่ cache ไว้
                      final cached = await _getEmpIdOrNull();
                      if (cached != null && cached > 0) {
                        empIdInt = cached;
                      } else {
                        // ถ้ายังไม่มี ให้ใช้ค่า default (ควรมีการตั้งค่าไว้ก่อนหน้า)
                        empIdInt = 0; // หรือแสดง error
                      }
                    }

                    final payload = {
                      "type": "START_JOB",
                      "calling_id": job.callingId,
                      "emp_id": empIdInt,
                      "work_type":
                          positionName, // ส่ง Position Name แทน PD/ENGINEER
                      "can_self_repair": canSelfRepair,
                      "need_support": needSupport,
                      "repair_type": repairType,
                      "detail_action": detailActionCtrl.text.trim(),
                      "cause_detail": causeDetailCtrl.text.trim(),
                      "start_time": DateTime.now().toIso8601String(),
                      "machine_name": machineNameCtrl.text.trim(),
                      "machine_code": machineCodeCtrl.text.trim(),
                    };

                    _wsService.sendJson(payload);

                    Navigator.pop(ctx);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'กำลังบันทึกข้อมูลเริ่มงาน...',
                          style: GoogleFonts.kanit(),
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'ยืนยันเริ่มงาน',
                    style: GoogleFonts.kanit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int _countByStatus(int status) =>
      _jobs.where((j) => j.status == status).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Image.asset(
                'assets/images/asahi_denso_logo.png',
                height: 28,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.person, size: 28, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.employee.displayName,
                  style: GoogleFonts.kanit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  widget.employee.positionName.isNotEmpty
                      ? widget.employee.positionName
                      : 'Position: ${widget.employee.positionCode}',
                  style: GoogleFonts.kanit(
                    fontSize: 12,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _isConnected
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? 'ONLINE' : 'OFFLINE',
                  style: GoogleFonts.kanit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textGrey),
            onSelected: (v) async {
              _handleMenu(v); // ไม่ await ตรงนี้
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('Reload Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _wsService.sendJson({'type': 'GET_HISTORY'});
          await Future.delayed(const Duration(seconds: 1));
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          itemCount:
              2 + (_cachedDisplayJobs.isEmpty ? 1 : _cachedDisplayJobs.length),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                children: [
                  if (_lastError != null)
                    Container(
                      width: double.infinity,
                      color: Colors.red.shade50,
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '⚠️ $_lastError',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        SummaryCard(
                          title: 'ทั้งหมด',
                          value: _jobs.length.toString(),
                          color: AppTheme.textDark,
                          icon: Icons.folder_copy_outlined,
                        ),
                        const SizedBox(width: 12),
                        SummaryCard(
                          title: 'Calling',
                          value: _countByStatus(1).toString(),
                          color: AppTheme.primaryRed,
                          icon: Icons.notifications_active_outlined,
                        ),
                        const SizedBox(width: 12),
                        SummaryCard(
                          title: 'Working',
                          value: _countByStatus(3).toString(),
                          color: Colors.orange,
                          icon: Icons.engineering_outlined,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            if (index == 1) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        StatusFilterChip(
                          label: 'ทั้งหมด',
                          value: 'ALL',
                          selected: _statusFilter == 'ALL',
                          onTap: () => _onFilterChanged('ALL'),
                        ),
                        StatusFilterChip(
                          label: 'CALLING',
                          value: 'CALLING',
                          selected: _statusFilter == 'CALLING',
                          color: AppTheme.primaryRed,
                          onTap: () => _onFilterChanged('CALLING'),
                        ),
                        StatusFilterChip(
                          label: 'WORKING',
                          value: 'WORKING',
                          selected: _statusFilter == 'WORKING',
                          color: Colors.orange,
                          onTap: () => _onFilterChanged('WORKING'),
                        ),
                        StatusFilterChip(
                          label: 'DONE',
                          value: 'COMPLETED',
                          selected: _statusFilter == 'COMPLETED',
                          color: Colors.green,
                          onTap: () => _onFilterChanged('COMPLETED'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            if (_cachedDisplayJobs.isEmpty) {
              return SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ไม่มีรายการงาน',
                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            }

            final jobIndex = index - 2;
            final job = _cachedDisplayJobs[jobIndex];
            final color = AppTheme.statusColor(job.status);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _onJobTap(job),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(width: 6, color: color),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // badge + time (เหมือนเดิม)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          job.statusName ?? 'UNKNOWN',
                                          style: GoogleFonts.kanit(
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${job.startTime.hour}:${job.startTime.minute.toString().padLeft(2, '0')}',
                                        style: GoogleFonts.kanit(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  // ✅ Line + JobID (เพิ่ม)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Line: ${job.lineNo}',
                                        style: GoogleFonts.kanit(
                                          color: Colors.grey[700],
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.confirmation_number_outlined,
                                        size: 14,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'JobID: ${job.jobId.isNotEmpty ? job.jobId : "-"}',
                                          style: GoogleFonts.kanit(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // ✅ WorkOrder (ชัดๆ)
                                  Text(
                                    'WO: ${job.workOrder}',
                                    style: GoogleFonts.kanit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppTheme.textDark,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  // ✅ Item (เพิ่ม)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        size: 14,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Item: ${job.itemName.isNotEmpty ? job.itemName : "-"}',
                                          style: GoogleFonts.kanit(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  // ✅ Cause (เหมือนเดิมแต่จัดให้ชัดขึ้น)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 14,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          job.cause.isNotEmpty
                                              ? job.cause
                                              : "-",
                                          style: GoogleFonts.kanit(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // action hint (เหมือนเดิม)
                                  if (job.status == 1 || job.status == 3)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            job.status == 1
                                                ? 'แตะเพื่อเริ่มงาน'
                                                : 'แตะเพื่ออัปเดตงาน',
                                            style: GoogleFonts.kanit(
                                              color: job.status == 1
                                                  ? AppTheme.primaryRed
                                                  : Colors.orange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_forward,
                                            size: 14,
                                            color: job.status == 1
                                                ? AppTheme.primaryRed
                                                : Colors.orange,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
