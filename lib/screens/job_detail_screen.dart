import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_theme.dart';
import '../models/calling_job_model.dart';
import '../models/employee_model.dart';

class JobDetailScreen extends StatefulWidget {
  final CallingJob job;
  final EmployeeProfile employee;
  final Function(Map<String, dynamic>) onSendCommand;

  const JobDetailScreen({
    super.key,
    required this.job,
    required this.employee,
    required this.onSendCommand,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  // NEW fields
  final _sparePartCtrl = TextEditingController();
  final _estimateCostCtrl = TextEditingController();
  final _machineCondCtrl = TextEditingController();
  final _resultActionCtrl = TextEditingController();

  // Dropdown
  final List<String> _causeOptions = const [
    'ซ่อมเรียบร้อย',
    'รออะไหล่',
    'ตรวจเช็คแล้วใช้งานได้',
    'ส่งต่อให้ทีมอื่น',
    'อื่นๆ',
  ];
  String? _causeDetailSelected;

  // can_use dropdown
  bool? _canUse; // true=ใช้งานได้, false=ยังใช้งานไม่ได้

  // Photo (Required)
  final ImagePicker _picker = ImagePicker();
  XFile? _photo;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // Prefill (ถ้ามี)
    _sparePartCtrl.text = widget.job.sparePartUsed ?? '';
    _machineCondCtrl.text = widget.job.machineCondition ?? '';
    _resultActionCtrl.text = widget.job.resultAction ?? '';

    final oldCause = (widget.job.causeDetail ?? '').trim();
    if (oldCause.isNotEmpty && _causeOptions.contains(oldCause)) {
      _causeDetailSelected = oldCause;
    } else if (oldCause.isNotEmpty) {
      _causeDetailSelected = 'อื่นๆ';
    }

    _canUse = widget.job.canUse;
  }

  @override
  void dispose() {
    _sparePartCtrl.dispose();
    _estimateCostCtrl.dispose();
    _machineCondCtrl.dispose();
    _resultActionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60, // ลด size กันเกิน 5MB
        maxWidth: 1280,
      );
      if (!mounted) return;
      setState(() => _photo = img);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถเปิดกล้องได้', style: GoogleFonts.kanit()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double? _parseCostTHB(String s) {
    final cleaned = s.replaceAll(',', '').trim();
    return double.tryParse(cleaned);
  }

  Future<String?> _photoToBase64(XFile? file) async {
    if (file == null) return null;

    final bytes = await File(file.path).readAsBytes();

    // Validate file size (max 5MB)
    const maxSizeBytes = 5 * 1024 * 1024; // 5MB
    if (bytes.length > maxSizeBytes) {
      throw Exception('ไฟล์รูปภาพใหญ่เกินไป (เกิน 5MB) กรุณาลองใหม่');
    }

    return base64Encode(bytes);
  }

  Future<void> _finishAndCloseJob() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) return;

    // validate dropdowns
    if (_causeDetailSelected == null || _causeDetailSelected!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กรุณาเลือก Cause Detail', style: GoogleFonts.kanit()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_canUse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'กรุณาเลือกสถานะหลังซ่อม (ใช้งานได้/ไม่ได้)',
            style: GoogleFonts.kanit(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final cost = _parseCostTHB(_estimateCostCtrl.text);
    if (cost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'กรุณากรอก Estimate Cost เป็นตัวเลข',
            style: GoogleFonts.kanit(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ REQUIRED: ต้องแนบรูปทุกครั้ง
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'กรุณาถ่ายรูปหน้างานก่อนปิดงาน',
            style: GoogleFonts.kanit(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final callingId = widget.job.callingId;

      // 1) FINISH_JOB (ตามสเปก: ส่งข้อมูลซ่อม / ไม่ต้องส่ง machine / ไม่ต้องส่งรูปใน payload นี้)
      final finishPayload = <String, dynamic>{
        "type": "FINISH_JOB",
        "calling_id": callingId,
        "end_time": DateTime.now().toIso8601String(),
        "spare_part_used": _sparePartCtrl.text.trim(),
        "estimate_cost": cost,
        "machine_condition": _machineCondCtrl.text.trim(),
        "result_action": _resultActionCtrl.text.trim(),
        "cause_detail": _causeDetailSelected,
        "can_use": _canUse,
      };

      widget.onSendCommand(finishPayload);

      // 2) UPLOAD_IMAGE (required)
      final imgBase64 = await _photoToBase64(_photo);
      if (imgBase64 == null || imgBase64.isEmpty) {
        throw Exception('แปลงรูปเป็น base64 ไม่สำเร็จ');
      }

      final uploadPayload = <String, dynamic>{
        "type": "UPLOAD_IMAGE",
        "calling_id": callingId,
        "image_base64": imgBase64,
        "file_name": _photo!.name,
        "content_type": "image/jpeg",
      };

      widget.onSendCommand(uploadPayload);

      // 3) CLOSE_JOB (ส่งแค่นี้เท่านั้น ตามที่คุณยืนยัน)
      final closePayload = <String, dynamic>{
        "type": "CLOSE_JOB",
        "calling_id": callingId,
      };

      widget.onSendCommand(closePayload);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'บันทึกผลซ่อม + อัปโหลดรูป + ปิดงานเรียบร้อย',
            style: GoogleFonts.kanit(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'เกิดข้อผิดพลาด: ${e.toString()}',
            style: GoogleFonts.kanit(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(color: Colors.grey.shade100),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.kanit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _textInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool requiredField = false,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.kanit(color: AppTheme.textDark),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.kanit(color: Colors.grey[500]),
        prefixIcon: Icon(
          icon,
          color: AppTheme.primaryRed.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ).borderRadius,
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryRed),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: requiredField
          ? (v) => v?.trim().isEmpty == true ? 'กรุณาระบุข้อมูล' : null
          : null,
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          _infoRow('WorkOrder', widget.job.workOrder),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _infoRow('Line', '${widget.job.lineNo}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _infoRow('Item', widget.job.itemName, highlight: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _infoRow('Cause', widget.job.cause, highlight: true),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(label, style: GoogleFonts.kanit(color: Colors.grey[600])),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: GoogleFonts.kanit(
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight ? AppTheme.primaryRed : AppTheme.textDark,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdownCause() {
    return DropdownButtonFormField<String>(
      value: _causeDetailSelected,
      items: _causeOptions
          .map((x) => DropdownMenuItem(value: x, child: Text(x)))
          .toList(),
      onChanged: (v) => setState(() => _causeDetailSelected = v),
      decoration: InputDecoration(
        labelText: 'Cause Detail *',
        labelStyle: GoogleFonts.kanit(color: Colors.grey[500]),
        prefixIcon: Icon(
          Icons.report_problem_outlined,
          color: AppTheme.primaryRed.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryRed),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'กรุณาเลือก Cause Detail' : null,
    );
  }

  Widget _dropdownCanUse() {
    return DropdownButtonFormField<bool>(
      value: _canUse,
      items: const [
        DropdownMenuItem(value: true, child: Text('ใช้งานได้')),
        DropdownMenuItem(value: false, child: Text('ยังใช้งานไม่ได้')),
      ],
      onChanged: (v) => setState(() => _canUse = v),
      decoration: InputDecoration(
        labelText: 'สถานะหลังซ่อม (Can Use) *',
        labelStyle: GoogleFonts.kanit(color: Colors.grey[500]),
        prefixIcon: Icon(
          Icons.verified_outlined,
          color: AppTheme.primaryRed.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryRed),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (v) => v == null ? 'กรุณาเลือกสถานะหลังซ่อม' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_isSubmitting && (_photo != null);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'บันทึกผลการซ่อม',
          style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeader('ข้อมูลใบงาน (Job Info)'),
              _infoCard(),
              const SizedBox(height: 24),

              _sectionHeader('สรุปผลการซ่อม (Result)'),
              Container(
                decoration: _cardDecoration(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _dropdownCause(),
                    const SizedBox(height: 16),

                    _dropdownCanUse(),
                    const SizedBox(height: 16),

                    _textInput(
                      controller: _sparePartCtrl,
                      label: 'Spare Part Used',
                      icon: Icons.settings_input_component,
                      maxLines: 2,
                      requiredField: true,
                      hint: 'เช่น Bearing, Sensor, Relay',
                    ),
                    const SizedBox(height: 16),

                    _textInput(
                      controller: _estimateCostCtrl,
                      label: 'Estimate Cost (THB)',
                      icon: Icons.currency_exchange,
                      requiredField: true,
                      keyboardType: TextInputType.number,
                      hint: 'เช่น 2500',
                    ),
                    const SizedBox(height: 16),

                    _textInput(
                      controller: _machineCondCtrl,
                      label: 'Machine Condition',
                      icon: Icons.monitor_heart_outlined,
                      requiredField: true,
                      hint: 'เช่น Normal / Need Monitor',
                    ),
                    const SizedBox(height: 16),

                    _textInput(
                      controller: _resultActionCtrl,
                      label: 'Result Action',
                      icon: Icons.task_alt_outlined,
                      requiredField: true,
                      maxLines: 2,
                      hint: 'สรุปการแก้ไข/ผลลัพธ์',
                    ),
                    const SizedBox(height: 16),

                    // Photo (Required)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _pickPhoto,
                        icon: Icon(
                          _photo != null
                              ? Icons.check_circle
                              : Icons.camera_alt,
                        ),
                        label: Text(
                          _photo != null
                              ? 'แนบรูปภาพเรียบร้อย'
                              : 'ถ่ายรูปหน้างาน (Required)',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: _photo != null
                              ? Colors.green
                              : AppTheme.primaryRed,
                          side: BorderSide(
                            color: _photo != null
                                ? Colors.green
                                : AppTheme.primaryRed,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: GoogleFonts.kanit(),
                        ),
                      ),
                    ),

                    if (_photo != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _photo!.name,
                        style: GoogleFonts.kanit(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 28),

              ElevatedButton.icon(
                onPressed: canSubmit ? _finishAndCloseJob : null,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSubmitting
                      ? 'กำลังส่งข้อมูล...'
                      : 'บันทึก + ปิดงาน (Finish & Close)',
                  style: GoogleFonts.kanit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),

              if (_photo == null) ...[
                const SizedBox(height: 10),
                Text(
                  '⚠️ ต้องถ่ายรูปก่อนจึงจะสามารถปิดงานได้',
                  style: GoogleFonts.kanit(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
