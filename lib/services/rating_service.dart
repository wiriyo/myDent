// ----------------------------------------------------------------
// 📁 lib/services/rating_service.dart (✨ ไฟล์ใหม่ล่าสุด!)
// ✨ ไลลาสร้างไฟล์นี้ขึ้นมาเพื่อจัดการ Logic การคำนวณคะแนนโดยเฉพาะเลยค่ะ
// ----------------------------------------------------------------

class RatingService {
  // เป็น static method เราเลยเรียกใช้ได้เลย ไม่ต้องสร้าง object ค่ะ
  static double calculateNewRating({
    required double currentRating,
    required String appointmentStatus,
  }) {
    double newRating = currentRating;

    switch (appointmentStatus) {
      case 'ยกเลิก':
      case 'ติดต่อไม่ได้':
      case 'ไม่มาตามนัด':
      case 'ปฏิเสธนัด':
        newRating -= 1.0;
        break;
      case 'เลื่อนนัด':
        newRating -= 0.5;
        break;
      case 'เสร็จสิ้น':
        newRating += 0.5;
        break;
      default:
        // สถานะอื่น ๆ ไม่มีการเปลี่ยนแปลงคะแนนค่ะ
        break;
    }

    // ✨ [IMPORTANT] เราจะจำกัดค่าคะแนนให้อยู่ระหว่าง 0.0 ถึง 5.0 เสมอค่ะ
    // ไม่ให้ต่ำกว่า 0 และไม่ให้เกิน 5 ตามที่พี่ทะเลบอกเลยค่ะ
    return newRating.clamp(0.0, 5.0);
  }
}
