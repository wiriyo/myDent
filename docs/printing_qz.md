# Printing ด้วย QZ Tray (Flutter Web)

## 1. ติดตั้งและเตรียม QZ Tray
- ดาวน์โหลด QZ Tray รุ่นล่าสุดจาก [https://qz.io/download](https://qz.io/download) (รองรับ Windows / macOS)
- ติดตั้งและเปิดโปรแกรม QZ Tray ให้ทำงานอยู่ใน System Tray ก่อนสั่งพิมพ์ทุกครั้ง
- หากระบบถามเรื่องการยืนยัน certificate ในโหมด dev สามารถกดยอมรับได้

## 2. โหมดทดสอบ (Dev)
- เว็บแอปรวมสคริปต์ `qz-tray.js@2.2.5` และตั้งค่า demo certificate/signature ให้พร้อมใช้งาน
- แค่เปิด QZ Tray แล้วเข้า MyDent Web ก็สามารถกด `พิมพ์ (QZ Tray)` ได้ทันที
- มีข้อความเตือนใน console และ UI หาก QZ Tray ไม่ทำงาน, certificate ผิด หรือหาเครื่องพิมพ์ไม่เจอ

## 3. โหมด Production (TODO)
- ต้องเปลี่ยนไปใช้ certificate และ signature จริงที่ลงทะเบียนกับ QZ Tray
- ใน `web/index.html` มี TODO ชัดเจน: 
  - `QZ_CERT_MISSING` → ดึง certificate จากแหล่งที่ปลอดภัย (เช่น เซิร์ฟเวอร์)
  - `QZ_SIGNATURE_MISSING` → เรียก signing service ฝั่ง backend เพื่อเซ็นข้อความ
- ห้าม hardcode private key ลงใน client (security risk)

## 4. การใช้งานใน MyDent Web
- ปุ่มพิมพ์จะแสดงก็ต่อเมื่อรันบนเว็บ (`kIsWeb`) และ QZ Tray feature flag เปิดอยู่
- ปุ่มหลัก:
  - `พิมพ์ (QZ Tray)` → ส่ง PNG (576px) ผ่าน QZ, ตัดกระดาษอัตโนมัติ (GS V 0)
  - `พิมพ์` → เปิดการพิมพ์แบบเบราว์เซอร์ (window.print) เป็น fallback
- หาก QZ Tray ไม่พร้อม หรือเกิด error จะขึ้น SnackBar และเสนอ fallback อัตโนมัติ

## 5. การเลือกและบันทึกเครื่องพิมพ์
- กดเมนู `...` (ไอคอนเครื่องพิมพ์บน AppBar) → `เลือกเครื่องพิมพ์ QZ Tray`
- เลือกจากรายชื่อเครื่องที่ QZ Tray รายงาน หรือเลือก `ให้ QZ Tray ถามเครื่องพิมพ์ทุกครั้ง`
- ระบบจำชื่อเครื่องพิมพ์ไว้ใน `SharedPreferences` (Web ใช้ LocalStorage) สำหรับครั้งถัดไป
- เลือก `ล้างเครื่องพิมพ์ที่บันทึก` เพื่อให้ถามใหม่
- หากเครื่องพิมพ์ที่จำไว้หายไป ระบบจะล้างค่าและขอเลือกใหม่โดยอัตโนมัติ

## 6. วิธีแก้ปัญหา
- **ไม่พบ QZ Tray / websocket ต่อไม่ได้**  
  → เปิดโปรแกรม QZ Tray และ refresh หน้า, ตรวจสอบว่าไม่ได้ block websocket
- **Security / Certificate error**  
  → ตรวจสอบว่า certificate และ signature ถูกต้อง (ดู TODO ใน index.html)
- **ไม่เจอเครื่องพิมพ์ที่ตั้งไว้**  
  → เปิดเมนูเลือกเครื่องพิมพ์อีกครั้ง หรือเลือกให้ QZ Tray ถามทุกครั้ง
- **พิมพ์ไม่ออก / ไม่ตัดกระดาษ**  
  → ตรวจสอบว่าเครื่องพิมพ์เป็น ESC/POS, driver พร้อมใช้งาน และเช็ค command cut (GS V 0)
- **Safari/macOS**  
  → ต้องเปิด QZ Tray เวอร์ชัน macOS และอนุญาตการทำงานของ certificate หากมี popup

## 7. หมายเหตุเพิ่มเติม
- PNG ที่ renderer สร้างมีความกว้าง 576px (มาตรฐาน 80mm @ 203dpi) เพื่อให้ rasterize ชัด
- ใน index.html เปิด `rasterize: true` เพื่อให้ QZ Tray แปลงภาพเป็น ESC/POS อัตโนมัติ
- โค้ดตัดกระดาษใช้คำสั่งเต็มใบ (GS V 0) พร้อม TODO สำหรับ half cut ในอนาคต
- Feature flag `MYDENT_ENABLE_QZ` สามารถปิดได้ (ผ่าน `--dart-define`)
