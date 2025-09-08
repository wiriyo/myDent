// 📁 lib/models/staff_model.dart
// v1.0.0 - Laila's Staff Model
// โมเดลสำหรับเก็บข้อมูลของพนักงานแต่ละคนค่ะ 🧑‍⚕️👩‍💼

class Staff {
  final String id;
  final String name;
  final String username;
  final String role;
  // เราอาจจะเพิ่มฟิลด์อื่นๆ ในอนาคตได้นะคะ เช่น เบอร์โทร, รูปโปรไฟล์

  Staff({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
  });

  // Factory constructor สำหรับสร้าง Staff object จาก Firestore document
  factory Staff.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Staff(
      id: documentId,
      name: data['name'] ?? '',
      username: data['username'] ?? '',
      role: data['role'] ?? 'guest', // ถ้าไม่มี role ให้เป็น guest ไปก่อน
    );
  }
}
