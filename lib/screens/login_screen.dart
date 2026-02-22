import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';

import '../constants/app_theme.dart';
import '../models/employee_model.dart';
import '../services/websocket_service.dart';
import 'home_screen.dart';
import 'server_settings_screen.dart';
import '../services/foreground_calling_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final WebSocketService _wsService = WebSocketService();

  bool _isManualMode = false;
  bool _isLoading = false;
  bool _isServerConfigured = false;
  String _statusText = "";
  List<Map<String, dynamic>> _availableAccounts = [];

  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  String? _serverUrl;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _checkServerConfig();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _wsService.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ---------------------------
  // Server config + fetch users
  // ---------------------------
  Future<void> _checkServerConfig() async {
    setState(() {
      _isLoading = true;
      _statusText = "กำลังตรวจสอบการตั้งค่า...";
    });

    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('ws_url');

    if (url == null || url.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _isServerConfigured = false;
        _isLoading = false;
      });
      return;
    }

    _serverUrl = url.trim();
    _connectAndFetchUsers();
  }

  void _connectAndFetchUsers() {
    if (_serverUrl == null) return;

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _isManualMode = true;
          _isServerConfigured = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('โหลดรายชื่อไม่ทัน กรุณากรอกข้อมูลเอง'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });

    setState(() => _statusText = "กำลังเชื่อมต่อ Server...");

    _wsService.onMessage = _handleWSMessage;
    _wsService.onStatusChange = (isConnected) {
      if (!isConnected) return;
      if (mounted)
        setState(() => _statusText = "เชื่อมต่อสำเร็จ! กำลังขอรายชื่อ...");
      _wsService.sendJson({"type": "GET_USERS", "status": "A"});
    };
    _wsService.onError = (err) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isServerConfigured = false;
      });
    };

    _wsService.connect(_serverUrl!);
  }

  // ---------------------------
  // WS message handler
  // ---------------------------
  void _handleWSMessage(dynamic message) {
    try {
      final obj = jsonDecode(message.toString());
      final type = obj['type'];

      if (type == 'USER_LIST') {
        _timeoutTimer?.cancel();
        final List<dynamic> usersJson = obj['users'] ?? [];

        String getString(dynamic val) {
          if (val == null) return '';
          if (val is String) return val;
          // server บาง field ส่ง {} มา ให้ถือว่า empty
          if (val is Map || val is List) return '';
          return val.toString();
        }

        final List<Map<String, dynamic>> loadedUsers = usersJson.map((u) {
          final userId = getString(u['user_id']);
          final username = getString(u['username']);

          final firstName = getString(u['first_name']);
          final lastName = getString(u['last_name']);
          final nickName = getString(u['nick_name']);

          final positionName = getString(u['position_name']);
          final positionCode = getString(u['position_code']);
          final displayPosition = positionName.isNotEmpty
              ? positionName
              : positionCode;

          final passwordHash = getString(u['password']);

          String displayName = username;
          final full = ([
            firstName,
            lastName,
          ].where((x) => x.isNotEmpty).join(' ')).trim();

          if (nickName.isNotEmpty) {
            displayName = nickName;
          } else if (full.isNotEmpty) {
            displayName = full;
          }

          return {
            "id": userId, // GUID
            "username": username,
            "name": displayName.trim(),
            "position": displayPosition,
            "position_code": positionCode,
            "position_name": positionName,
            "password_hash": passwordHash,
            "color": _generateColor(displayName),
          };
        }).toList();

        if (!mounted) return;
        setState(() {
          _availableAccounts = loadedUsers;
          _isLoading = false;
          _isServerConfigured = true;
          _isManualMode = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Parse Error: $e");
    }
  }

  String _generateColor(String name) {
    final colors = [
      "0xFFE30613",
      "0xFF10B981",
      "0xFFF59E0B",
      "0xFF3B82F6",
      "0xFF8B5CF6",
      "0xFFEC4899",
    ];
    if (name.isEmpty) return colors[0];
    final index = name.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  // ---------------------------
  // Navigation
  // ---------------------------
  Future<void> _loginWithProfile(EmployeeProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final wsUrl =
        prefs.getString('ws_url') ?? 'ws://192.168.1.132:5020/ws/calling';

    await ForegroundCallingService.start(
      wsUrl: wsUrl,
    ); // ✅ start หลัง login สำเร็จ

    _wsService.dispose();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => CallingHomePage(employee: profile)),
    );
  }

  // ---------------------------
  // UI: select user
  // ---------------------------
  Future<void> _onSelectUser(Map<String, dynamic> account) async {
    _passCtrl.clear();
    final color = Color(int.parse(account['color']));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Text(
                account['name'].toString().substring(0, 1).toUpperCase(),
                style: GoogleFonts.kanit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              account['name'].toString(),
              style: GoogleFonts.kanit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              account['position'].toString(),
              style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'กรุณาระบุรหัสผ่าน:',
              style: GoogleFonts.kanit(color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                hintText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) {
                Navigator.pop(ctx);
                _verifyAndLogin(account);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ยกเลิก', style: GoogleFonts.kanit(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _verifyAndLogin(account);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'เข้าสู่ระบบ',
              style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // ✅ Login verify (bcrypt) with $2y$ support
  // ---------------------------
  void _verifyAndLogin(Map<String, dynamic> account) {
    final inputPass = _passCtrl.text.trim();
    var storedHash = (account['password_hash'] ?? '').toString().trim();

    if (inputPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกรหัสผ่าน'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (storedHash.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบข้อมูลรหัสผ่านในระบบ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ Fix: PHP bcrypt $2y$ -> $2a$
    if (storedHash.startsWith(r'$2y$')) {
      storedHash = storedHash.replaceFirst(r'$2y$', r'$2a$');
    }

    try {
      final ok = BCrypt.checkpw(inputPass, storedHash);

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('รหัสผ่านไม่ถูกต้อง!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final profile = EmployeeProfile(
        userId: (account['id'] ?? '').toString(), // GUID from server
        username: (account['username'] ?? '').toString(),
        displayName: (account['name'] ?? '').toString(),
        positionCode: (account['position_code'] ?? '').toString(),
        positionName: (account['position_name'] ?? '').toString(),
      );

      _loginWithProfile(profile);
    } catch (e) {
      debugPrint("BCrypt Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hash ไม่รองรับ/ตรวจสอบไม่ได้'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------------------
  // Manual login (offline)
  // ---------------------------
  void _onManualLogin() {
    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอก Username และ Password')),
      );
      return;
    }

    final profile = EmployeeProfile(
      userId: _userCtrl.text.trim(),
      username: _userCtrl.text.trim(),
      displayName: _userCtrl.text.trim(),
      positionCode: "User",
    );
    _loginWithProfile(profile);
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'ตั้งค่า Server',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServerSettingPage()),
              );
              _checkServerConfig();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/asahi_denso_logo.png',
                      height: 50,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.build_circle,
                        size: 50,
                        color: AppTheme.primaryRed,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'THAI ASAHI DENSO',
                    style: GoogleFonts.kanit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: AppTheme.textDark,
                    ),
                  ),
                  Text(
                    _isManualMode
                        ? 'เข้าสู่ระบบ (Manual Login)'
                        : 'เลือกบัญชีเพื่อเข้าสู่ระบบ',
                    style: GoogleFonts.kanit(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(child: _buildBody()),
                  const SizedBox(height: 20),
                  Text(
                    'Version 1.0.6',
                    style: GoogleFonts.kanit(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryRed),
            const SizedBox(height: 24),
            Text(_statusText, style: GoogleFonts.kanit(color: Colors.grey)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() {
                _isLoading = false;
                _isManualMode = true;
                _isServerConfigured = true;
              }),
              child: const Text(
                'รอนาน? กดเพื่อกรอกเอง',
                style: TextStyle(color: AppTheme.primaryRed),
              ),
            ),
          ],
        ),
      );
    }

    if (!_isServerConfigured) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'ยังไม่ได้ตั้งค่า Server',
            style: GoogleFonts.kanit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'กรุณากดปุ่มตั้งค่าด้านบนเพื่อเริ่มต้น',
            style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServerSettingPage()),
              );
              _checkServerConfig();
            },
            icon: const Icon(Icons.settings),
            label: Text('ตั้งค่า Server', style: GoogleFonts.kanit()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      );
    }

    if (_isManualMode) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _userCtrl,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onManualLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'เข้าสู่ระบบ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _checkServerConfig,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(
                    'ลองโหลดรายชื่อใหม่',
                    style: GoogleFonts.kanit(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ServerSettingPage(),
                      ),
                    );
                    _checkServerConfig();
                  },
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: Text(
                    'ตั้งค่า Server',
                    style: GoogleFonts.kanit(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_availableAccounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              'ไม่พบรายชื่อพนักงาน',
              style: GoogleFonts.kanit(color: Colors.grey),
            ),
            TextButton(
              onPressed: _connectAndFetchUsers,
              child: const Text('ลองโหลดใหม่'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _availableAccounts.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final acc = _availableAccounts[i];
        final color = Color(int.parse(acc['color']));
        return Card(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _onSelectUser(acc),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: color.withOpacity(0.1),
                    child: Text(
                      acc['name'].toString().substring(0, 1).toUpperCase(),
                      style: GoogleFonts.kanit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          acc['name'].toString(),
                          style: GoogleFonts.kanit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          '${acc['position']} (${acc['username']})',
                          style: GoogleFonts.kanit(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.lock_outline, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
