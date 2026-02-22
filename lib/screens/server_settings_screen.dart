import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_theme.dart';
import '../services/websocket_service.dart';
import 'login_screen.dart';

class ServerSettingPage extends StatefulWidget {
  const ServerSettingPage({super.key});

  @override
  State<ServerSettingPage> createState() => _ServerSettingPageState();
}

class _ServerSettingPageState extends State<ServerSettingPage> {
  final _urlCtrl = TextEditingController();
  final WebSocketService _ws = WebSocketService();

  bool _isTesting = false;
  bool? _testPassed; // null=ยังไม่ทดสอบ, true/false=ผลทดสอบ
  String _testMessage = 'ยังไม่ได้ทดสอบ';
  Timer? _testTimeout;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  @override
  void dispose() {
    _testTimeout?.cancel();
    _ws.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _urlCtrl.text =
          prefs.getString('ws_url') ?? 'ws://127.0.0.1:5020/ws/calling';
      _testPassed = null;
      _testMessage = 'ยังไม่ได้ทดสอบ';
    });
  }

  String _normalizeWsUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return url;

    // ถ้าผู้ใช้พิมพ์ http/https ให้แปลงเป็น ws/wss
    if (url.startsWith('http://')) url = url.replaceFirst('http://', 'ws://');
    if (url.startsWith('https://'))
      url = url.replaceFirst('https://', 'wss://');

    // ถ้าไม่มี scheme ให้เติม ws://
    if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      url = 'ws://$url';
    }
    return url;
  }

  Future<void> _saveAndGoLogin() async {
    // ✅ บังคับให้ทดสอบผ่านก่อน (ลดปัญหา save แล้วกลับไปยังต่อไม่ได้)
    if (_testPassed != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาทดสอบเชื่อมต่อให้ผ่านก่อนบันทึก'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final url = _normalizeWsUrl(_urlCtrl.text);

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุ URL ก่อน'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await prefs.setString('ws_url', url);

    if (!mounted) return;

    // ✅ เด้งกลับไปหน้า Login และเคลียร์ stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _testConnection() async {
    final url = _normalizeWsUrl(_urlCtrl.text);

    if (url.isEmpty) {
      setState(() {
        _testPassed = false;
        _testMessage = 'กรุณาระบุ URL ก่อน';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testPassed = null;
      _testMessage = 'กำลังทดสอบการเชื่อมต่อ...';
    });

    _testTimeout?.cancel();
    _ws.dispose(); // เคลียร์ connection เดิม

    // สร้าง instance ใหม่กัน state ค้าง
    final ws = WebSocketService();

    bool done = false;
    bool gotAnyMessage = false;

    void finish(bool pass, String msg) {
      if (done) return;
      done = true;

      _testTimeout?.cancel();
      ws.dispose();

      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testPassed = pass;
        _testMessage = msg;
      });
    }

    ws.onError = (err) => finish(false, 'เชื่อมต่อไม่สำเร็จ: $err');

    ws.onMessage = (message) {
      if (gotAnyMessage) return;
      gotAnyMessage = true;

      // ถ้าเป็น JSON และมี type ให้โชว์ type เพื่อดีบัก
      try {
        final obj = jsonDecode(message.toString());
        final type = obj['type']?.toString() ?? '';
        if (type.isNotEmpty) {
          finish(true, 'เชื่อมต่อสำเร็จ ✅ (ได้รับ: $type)');
          return;
        }
      } catch (_) {
        // ไม่ใช่ JSON
      }

      finish(true, 'เชื่อมต่อสำเร็จ ✅ (ได้รับข้อความตอบกลับ)');
    };

    // timeout 6 วินาที
    _testTimeout = Timer(const Duration(seconds: 6), () {
      finish(false, 'หมดเวลา (timeout) ❌ กรุณาตรวจสอบ IP/Port/Network');
    });

    ws.connect(url);
    ws.sendJson({"type": "PING"});
  }

  Color _statusColor() {
    if (_isTesting) return Colors.orange;
    if (_testPassed == true) return Colors.green;
    if (_testPassed == false) return Colors.red;
    return Colors.grey;
  }

  IconData _statusIcon() {
    if (_isTesting) return Icons.hourglass_top;
    if (_testPassed == true) return Icons.check_circle;
    if (_testPassed == false) return Icons.cancel;
    return Icons.help_outline;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Scaffold(
      appBar: AppBar(title: const Text('การตั้งค่า')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'การเชื่อมต่อ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),

          // Card URL
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WebSocket Server URL'),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    hintText: 'ws://192.168.x.x:5020/ws/calling',
                    prefixIcon: Icon(Icons.cloud_sync_outlined),
                  ),
                  onChanged: (_) {
                    setState(() {
                      _testPassed = null;
                      _testMessage = 'ยังไม่ได้ทดสอบ';
                    });
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'ระบุ IP Address และ Port ของเครื่อง Server',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Result badge
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(_statusIcon(), color: statusColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _testMessage,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Test button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: const Icon(Icons.wifi_tethering),
                    label: Text(
                      _isTesting ? 'กำลังทดสอบ...' : 'ทดสอบเชื่อมต่อ Server',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryRed,
                      side: const BorderSide(color: AppTheme.primaryRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Save -> Go Login
          ElevatedButton.icon(
            onPressed: _saveAndGoLogin,
            icon: const Icon(Icons.save),
            label: const Text('บันทึกการตั้งค่า'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 32),
          const Center(
            child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
