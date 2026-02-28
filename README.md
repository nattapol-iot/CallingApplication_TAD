# 📱 THAI ASAHI DENSO Calling Application

แอปพลิเคชันรับแจ้งเตือนงานซ่อมแบบเรียลไทม์สำหรับโรงงาน THAI ASAHI DENSO
Real-time maintenance calling notification application for THAI ASAHI DENSO factory

---

## 🎯 คุณสมบัติหลัก (Key Features)

### ✅ การทำงานในพื้นหลัง (Background Operation)
- **Foreground Service**: ทำงานต่อเนื่องแม้ปิดหน้าจอหรือออกจากแอป
- **WebSocket Connection**: เชื่อมต่อกับเซิร์ฟเวอร์แบบเรียลไทม์ตลอดเวลา
- **Auto-Reconnect**: เชื่อมต่อใหม่อัตโนมัติเมื่อขาดการเชื่อมต่อ
- **Battery Optimization**: ขอสิทธิ์ปิดการประหยัดแบตเตอรี่เพื่อการทำงานที่เสถียร

### 🔔 การแจ้งเตือนอัจฉริยะ (Smart Notifications)
- **Screen Wake-up**: ปลุกหน้าจอเมื่อมีงานเรียกเข้ามา
- **Vibration Alert**: สั่นเตือนทุก 10 วินาทีจนกว่าจะรับงาน
- **Sound Alert**: เสียงแจ้งเตือนพร้อมความสำคัญสูงสุด
- **Persistent Notification**: แจ้งเตือนค้างจนกว่าจะดำเนินการ

### 📋 การจัดการงาน (Task Management)
- **Real-time Job List**: รายการงานอัปเดตแบบเรียลไทม์
- **Status Filtering**: กรองงานตามสถานะ (CALLING, WORKING, COMPLETED, CLOSED)
- **Job Details**: ข้อมูลครบถ้วน (WorkOrder, Line, Machine, Cause)
- **Start Job**: เริ่มงานพร้อมกรอกข้อมูลเบื้องต้น
- **Finish & Close**: บันทึกผลการซ่อมพร้อมแนบรูปภาพ

### 📸 การจัดการรูปภาพ (Photo Management)
- **Required Photo**: บังคับถ่ายรูปก่อนปิดงาน
- **Camera Integration**: เปิดกล้องถ่ายรูปโดยตรง
- **Image Compression**: ลดขนาดรูปอัตโนมัติ (max 1280px, quality 60%)
- **Size Validation**: ตรวจสอบขนาดไฟล์ไม่เกิน 5MB
- **Base64 Upload**: แปลงและส่งรูปผ่าน WebSocket

### 🔐 ระบบความปลอดภัย (Security)
- **BCrypt Authentication**: รหัสผ่านเข้ารหัสด้วย BCrypt
- **PHP Hash Support**: รองรับ `$2y$` hash จาก PHP
- **User Management**: ดึงรายชื่อพนักงานจากเซิร์ฟเวอร์
- **Session Management**: จัดการ session ผู้ใช้งาน

---

## 🏗️ สถาปัตยกรรม (Architecture)

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Application                       │
├─────────────────────────────────────────────────────────────┤
│  UI Layer (Screens)                                          │
│  ├─ LoginScreen          : Authentication                    │
│  ├─ HomeScreen           : Job list & management             │
│  ├─ JobDetailScreen      : Finish job with photo             │
│  └─ ServerSettingsScreen : WebSocket URL configuration       │
├─────────────────────────────────────────────────────────────┤
│  Service Layer                                               │
│  ├─ WebSocketService          : Real-time communication      │
│  ├─ NotificationService       : Alerts & vibration           │
│  ├─ ForegroundCallingService  : Background task              │
│  ├─ CallingTaskHandler        : Background WebSocket         │
│  └─ WakeLockService           : Screen wake-up               │
├─────────────────────────────────────────────────────────────┤
│  Model Layer                                                 │
│  ├─ CallingJob    : Job data model                           │
│  └─ EmployeeProfile : User data model                        │
└─────────────────────────────────────────────────────────────┘
                            ↕ WebSocket
┌─────────────────────────────────────────────────────────────┐
│                    Backend Server                            │
│  (C# - WebSocket Server)                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 การติดตั้ง (Installation)

### ข้อกำหนดระบบ (Requirements)
- Flutter SDK: `^3.10.7`
- Dart SDK: `^3.10.7`
- Android: API Level 21+ (Android 5.0+)
- iOS: iOS 12.0+ (ถ้าต้องการรองรับ)

### ติดตั้ง Dependencies

```bash
# 1. Clone repository
git clone <repository-url>
cd calling_application

# 2. ติดตั้ง dependencies
flutter pub get

# 3. สร้างไอคอนแอป (ถ้ามีไฟล์ assets/icon/icon.png)
flutter pub run flutter_launcher_icons

# 4. Build APK
flutter build apk --release

# หรือ Build App Bundle
flutter build appbundle --release
```

### การตั้งค่าเซิร์ฟเวอร์ (Server Configuration)

1. เปิดแอปครั้งแรก → กดปุ่ม **"ไปที่หน้าตั้งค่า"**
2. กรอก WebSocket URL เช่น: `ws://XXX.XXX.XXX.XXX:5020/ws/calling`
3. กด **"บันทึก"**
4. กลับไปหน้า Login → แอปจะโหลดรายชื่อพนักงานอัตโนมัติ

---

## 🚀 การใช้งาน (Usage)

### 1️⃣ เข้าสู่ระบบ (Login)

**แบบอัตโนมัติ (Auto Mode)**
- แอปจะดึงรายชื่อพนักงานจากเซิร์ฟเวอร์
- เลือกชื่อของคุณ → กรอกรหัสผ่าน → เข้าสู่ระบบ

**แบบกรอกเอง (Manual Mode)**
- กด "รอนาน? กดเพื่อกรอกเอง"
- กรอก Username และ Password
- เข้าสู่ระบบ

### 2️⃣ รับงาน (Accept Job)

1. เมื่อมีงานเรียกเข้ามา → **หน้าจอจะปลุกขึ้นมา + สั่น + เสียงดัง**
2. เปิดแอป → เห็นรายการงาน **สถานะ CALLING (สีแดง)**
3. **แตะที่งาน** → กรอกข้อมูล:
   - Machine Code
   - Machine Name
   - Work Type (PD / Engineer)
   - Repair Type (Repair / PM)
   - Can Self Repair (ซ่อมเองได้/ไม่ได้)
   - Need Support (ต้องการ Support หรือไม่)
   - Detail Action
   - Cause Detail
4. กด **"ยืนยันเริ่มงาน"**
5. **เสียงและการสั่นจะหยุดทันที**

### 3️⃣ ปิดงาน (Finish Job)

1. แตะที่งาน **สถานะ WORKING (สีส้ม)**
2. กรอกข้อมูลผลการซ่อม:
   - Cause Detail (เลือกจาก dropdown)
   - Can Use (ใช้งานได้/ไม่ได้)
   - Spare Part Used
   - Estimate Cost (THB)
   - Machine Condition
   - Result Action
3. **กด "ถ่ายรูปหน้างาน" (บังคับ)**
4. กด **"บันทึก + ปิดงาน"**
5. แอปจะส่ง:
   - ข้อมูลการซ่อม (FINISH_JOB)
   - รูปภาพ (UPLOAD_IMAGE)
   - ปิดงาน (CLOSE_JOB)

---

## 🔧 WebSocket API

### ข้อความที่แอปส่ง (Client → Server)

```json
// 1. ขอรายชื่อพนักงาน
{
  "type": "GET_USERS",
  "status": "A"
}

// 2. ขอประวัติงาน
{
  "type": "GET_HISTORY"
}

// 3. Ping (ทุก 20 วินาที)
{
  "type": "PING"
}

// 4. เริ่มงาน
{
  "type": "START_JOB",
  "calling_id": 12345,
  "emp_id": 556001,
  "work_type": "ENGINEER",
  "can_self_repair": true,
  "need_support": false,
  "repair_type": "REPAIR",
  "detail_action": "ตรวจเช็คเบื้องต้น",
  "cause_detail": "Sensor ชำรุด",
  "start_time": "2024-01-15T10:30:00.000Z",
  "machine_name": "Press-01",
  "machine_code": "MC-PRS-001"
}

// 5. ปิดงาน
{
  "type": "FINISH_JOB",
  "calling_id": 12345,
  "end_time": "2024-01-15T11:00:00.000Z",
  "spare_part_used": "Sensor XYZ",
  "estimate_cost": 2500.0,
  "machine_condition": "Normal",
  "result_action": "เปลี่ยน Sensor สำเร็จ",
  "cause_detail": "ซ่อมเรียบร้อย",
  "can_use": true
}

// 6. อัปโหลดรูป
{
  "type": "UPLOAD_IMAGE",
  "calling_id": 12345,
  "image_base64": "iVBORw0KGgoAAAANS...",
  "file_name": "image_picker_xxx.jpg",
  "content_type": "image/jpeg"
}

// 7. ปิดงาน (สุดท้าย)
{
  "type": "CLOSE_JOB",
  "calling_id": 12345
}
```

### ข้อความที่แอปรับ (Server → Client)

```json
// 1. รายชื่อพนักงาน
{
  "type": "USER_LIST",
  "users": [
    {
      "user_id": "guid-xxx",
      "username": "john.doe",
      "first_name": "John",
      "last_name": "Doe",
      "nick_name": "John",
      "position_name": "Technician",
      "position_code": "TECH",
      "password": "$2y$10$..."
    }
  ]
}

// 2. อัปเดตงาน / ประวัติ
{
  "type": "CALLING_UPDATE",  // or "CALLING_HISTORY"
  "jobs": [
    {
      "calling_id": 12345,
      "doc_no": "DOC-001",
      "job_id": "JOB-001",
      "line_no": 5,
      "work_order": "WO-2024-001",
      "item_name": "Press Machine",
      "status": 1,  // 1=CALLING, 3=WORKING, 4=COMPLETED, 9=CLOSED
      "status_name": "CALLING",
      "start_time": "2024-01-15T10:00:00.000Z",
      "cause": "Machine stopped"
    }
  ]
}

// 3. ACK (ตอบรับคำสั่ง)
{
  "type": "ACK",
  "success": true,
  "message": "Job started.",
  "cmd": "START_JOB"
}

// 4. PONG (ตอบ PING)
{
  "type": "ACK",
  "message": "PONG"
}
```

---

## 📱 Permissions

แอปต้องการสิทธิ์ดังนี้:

| Permission | เหตุผล |
|------------|--------|
| `INTERNET` | เชื่อมต่อ WebSocket |
| `POST_NOTIFICATIONS` | แจ้งเตือน (Android 13+) |
| `WAKE_LOCK` | เปิดหน้าจอเมื่อมีงาน |
| `FOREGROUND_SERVICE` | ทำงานในพื้นหลัง |
| `FOREGROUND_SERVICE_DATA_SYNC` | Sync ข้อมูล (Android 14+) |
| `CAMERA` | ถ่ายรูปหน้างาน |
| `VIBRATE` | สั่นเตือน |
| `SCHEDULE_EXACT_ALARM` | ตั้งเวลาแจ้งเตือนแม่นยำ |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | ปิดการประหยัดแบต |

---

## 🛠️ การแก้ปัญหา (Troubleshooting)

### ❌ แอปไม่แจ้งเตือนเมื่อปิดหน้าจอ

**วิธีแก้:**
1. ไปที่ **Settings → Apps → Calling Application**
2. เปิด **"Allow background activity"**
3. ปิด **"Battery optimization"**
4. เปิด **"Autostart"** (ถ้ามี)

### ❌ ไม่ได้รับ Notification

**วิธีแก้:**
1. ตรวจสอบ Permission → Notifications = **Allowed**
2. ตรวจสอบ Notification Channels → **Calling Alert** = เปิดอยู่
3. Restart แอป

### ❌ WebSocket ขาดการเชื่อมต่อบ่อย

**วิธีแก้:**
1. ตรวจสอบ URL ให้ถูกต้อง (`ws://` ไม่ใช่ `wss://` ถ้าไม่มี SSL)
2. ตรวจสอบ Network → WiFi มีสัญญาณดี
3. ตรวจสอบ Server ว่าทำงานอยู่
4. ดู Log: `adb logcat | grep "WS"`

### ❌ รูปภาพอัปโหลดไม่ได้

**วิธีแก้:**
1. ตรวจสอบขนาดรูป < 5MB
2. ตรวจสอบ Camera Permission
3. ลองถ่ายใหม่

---

## 📂 โครงสร้างโปรเจค (Project Structure)

```
calling_application/
├── android/
│   └── app/
│       └── src/main/
│           ├── AndroidManifest.xml          # Permissions & Service
│           └── kotlin/.../MainActivity.kt   # WakeLock native code
├── lib/
│   ├── constants/
│   │   └── app_theme.dart                   # Theme & colors
│   ├── models/
│   │   ├── calling_job_model.dart           # Job data model
│   │   └── employee_model.dart              # User model
│   ├── screens/
│   │   ├── login_screen.dart                # Login UI
│   │   ├── home_screen.dart                 # Job list UI
│   │   ├── job_detail_screen.dart           # Finish job UI
│   │   └── server_settings_screen.dart      # Settings UI
│   ├── services/
│   │   ├── websocket_service.dart           # WebSocket client
│   │   ├── notification_service.dart        # Notifications
│   │   ├── foreground_calling_service.dart  # Foreground service
│   │   ├── calling_task_handler.dart        # Background handler
│   │   └── wakelock_service.dart            # Screen wake-up
│   ├── widgets/
│   │   ├── summary_card.dart                # Summary widget
│   │   └── status_filter.dart               # Filter chips
│   └── main.dart                            # Entry point
├── assets/
│   └── icon/
│       └── icon.png                         # App icon
├── pubspec.yaml                             # Dependencies
└── README.md                                # This file
```

---

## 📚 Dependencies

```yaml
dependencies:
  flutter_foreground_task: ^6.1.3    # Background service
  flutter_local_notifications: ^20.0.0  # Notifications
  web_socket_channel: ^3.0.3         # WebSocket
  vibration: ^3.1.5                  # Vibration
  shared_preferences: ^2.5.4         # Local storage
  bcrypt: ^1.1.3                     # Password hashing
  google_fonts: ^6.1.0               # Kanit font
  image_picker: ^1.0.7               # Camera
```

---

## 🔄 การอัปเดต (Updates)

### Version 1.0.6 (Current)
- ✅ แก้ไข: เพิ่ม Foreground Service declaration
- ✅ แก้ไข: เพิ่ม Camera, Vibrate permissions
- ✅ แก้ไข: ลบ duplicate import
- ✅ แก้ไข: เพิ่ม Notification Channel creation
- ✅ แก้ไข: ปรับปรุง WebSocket reconnection logic
- ✅ แก้ไข: เพิ่ม Image size validation
- ✅ ใหม่: WakeLock Service สำหรับปลุกหน้าจอ
- ✅ ใหม่: Battery optimization request
- ✅ ปรับปรุง: Error handling ทั่วทั้งแอป

---

## 👨‍💻 ผู้พัฒนา (Developer)

** TOMAS TECH CO.,LTD. IoT Team **

---

## 📄 License

Copyright © 2026 TOMAS TECH CO.,LTD. All rights reserved.

---

## 📞 ติดต่อ (Contact)

หากพบปัญหาหรือต้องการความช่วยเหลือ กรุณาติดต่อ NATTAPOL POEAM [085-995-0178] Developer

---
