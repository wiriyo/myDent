import 'package:flutter/material.dart';
import '../services/working_hours_service.dart';
import '../models/working_hours_model.dart';
import '../main.dart'; // Import the global key


class WorkingHoursScreen extends StatefulWidget {
  const WorkingHoursScreen({super.key});

  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  // Use a Future to hold the asynchronous data load.
  late Future<List<DayWorkingHours>> _workingHoursFuture;
  // Keep a state variable to hold the mutable list of working hours after loading.
  List<DayWorkingHours>? _workingHours;
  final WorkingHoursService _workingHoursService = WorkingHoursService();

  int _selectedIndex = 4; // ✨ เพิ่มตัวแปรสำหรับเก็บ index ที่เลือก

  // ✨ เพิ่มฟังก์ชันสำหรับจัดการการกดปุ่มใน Bottom Navigation Bar
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/calendar');
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/patients');
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/reports');
    } else if (index == 4) {
      // ถ้ากดปุ่มตั้งค่า (index 4) ให้ย้อนกลับไปหน้าตั้งค่าหลัก
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _workingHoursFuture = _loadWorkingHours();
  }

  // Save working hours to SharedPreferences
  Future<void> _saveWorkingHours() async {
    // Ensure we have data to save.
    // Create a local variable to help with null promotion.
    final workingHoursToSave = _workingHours;
    if (workingHoursToSave == null) {
      // Optionally show a message that there's nothing to save.
      return;
    }

    try {
      await _workingHoursService.saveWorkingHours(workingHoursToSave);

      if (mounted) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('บันทึกเวลาทำการเรียบร้อยแล้ว')),
        );
      }
    } catch (e) {
      print('Error saving working hours to Firestore: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')),
        );
      }
    }
  }
  
  Future<List<DayWorkingHours>> _loadWorkingHours() {
    // Delegate the call to the service
    return _workingHoursService.loadWorkingHours();
  }

  // Helper to convert TimeOfDay to minutes for easier comparison
  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  // Check for overlapping time slots within a day
  bool _hasOverlap(List<TimeSlot> slots, TimeSlot newSlot, [int? excludeIndex]) {
    final newOpenMinutes = _timeToMinutes(newSlot.openTime);
    final newCloseMinutes = _timeToMinutes(newSlot.closeTime);

    for (int i = 0; i < slots.length; i++) {
      if (excludeIndex != null && i == excludeIndex) {
        continue; // Skip the slot being modified
      }
      final existingSlot = slots[i];
      final existingOpenMinutes = _timeToMinutes(existingSlot.openTime);
      final existingCloseMinutes = _timeToMinutes(existingSlot.closeTime);

      // Check for overlap: (newOpen < existingClose) and (newClose > existingOpen)
      if (newOpenMinutes < existingCloseMinutes && newCloseMinutes > existingOpenMinutes) {
        return true; // Overlap found
      }
    }
    return false; // No overlap
  }

  // Show time picker dialog
  Future<void> _pickTime(BuildContext context, DayWorkingHours day, TimeSlot slot, bool isOpeningTime, int slotIndex) async {
    final initialTime = isOpeningTime ? slot.openTime : slot.closeTime;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false), // Use 12-hour format for better UX
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      // Create a temporary slot to validate before updating the actual slot
      TimeSlot tempSlot = TimeSlot(
        openTime: isOpeningTime ? picked : slot.openTime,
        closeTime: isOpeningTime ? slot.closeTime : picked,
      );

      // Basic validation: open time must be before close time for the current slot
      if (_timeToMinutes(tempSlot.openTime) >= _timeToMinutes(tempSlot.closeTime)) {
          scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('เวลาเปิดต้องก่อนเวลาปิดในช่องเดียวกัน')),
        );
        return;
      }

      // Advanced validation: check for overlaps with other slots in the same day
      if (_hasOverlap(day.timeSlots, tempSlot, slotIndex)) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('ช่วงเวลาทำการทับซ้อนกับช่วงเวลาอื่นในวันเดียวกัน')),
        );
        return;
      }

      setState(() {
        if (isOpeningTime) { slot.openTime = picked; } else { slot.closeTime = picked; }
        // Sort time slots by open time to maintain order
        day.timeSlots.sort((a, b) => _timeToMinutes(a.openTime) - _timeToMinutes(b.openTime));
      });
    }
  }

  // New helper function for time picker buttons
  Widget _buildTimePickerButton(BuildContext context, String label, TimeOfDay time, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white, // White background for input feel
        foregroundColor: Colors.black87, // Darker text
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300, width: 1), // Subtle border
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        elevation: 0, // Flat appearance
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(time.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Icon(Icons.access_time, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5FC),
      appBar: AppBar(
        title: const Text("ตั้งค่าเวลาทำการ"),
        backgroundColor: const Color(0xFFE0BBFF),
        elevation: 0,
      ),
      body: FutureBuilder<List<DayWorkingHours>>(
        future: _workingHoursFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('ไม่พบข้อมูลเวลาทำการ'));
          }

          // Once data is loaded, assign it to the state variable to allow mutation.
          // This check prevents it from being reassigned on every rebuild.
          _workingHours ??= snapshot.data;

          // Use a local variable for null-safety promotion.
          final currentWorkingHours = _workingHours;
          if (currentWorkingHours == null) {
             return const Center(child: Text('เกิดข้อผิดพลาดในการแสดงผล'));
          }

          return ListView.builder(
              // Main content list
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0), // Added bottom padding for FAB
              itemCount: currentWorkingHours.length,
              itemBuilder: (context, index) {
                final day = currentWorkingHours[index];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.white,
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              day.dayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // Replaced the old Row with Text and Switch
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  day.isClosed = !day.isClosed; // Toggle the state
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: day.isClosed
                                    ? Colors.red.shade300 // Pastel red for "หยุด"
                                    : const Color(0xFFE0BBFF), // Theme purple for "เปิด"
                                foregroundColor: day.isClosed
                                    ? Colors.white // White text on red
                                    : Colors.purple.shade900, // Dark purple text on light purple
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: day.isClosed
                                        ? Colors.red.shade500 // Darker red border
                                        : Colors.purple.shade700, // Darker purple border
                                    width: 1.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                elevation: 2, // Add a slight elevation for button feel
                              ),
                              child: Text(
                                day.isClosed ? 'หยุด' : 'เปิด', // Text changes based on state
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (!day.isClosed) ...[
                          // Display existing time slots
                          ...day.timeSlots.asMap().entries.map((entry) {
                            final int slotIndex = entry.key;
                            final TimeSlot slot = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0), // Slightly less padding
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildTimePickerButton(
                                      context, 'เปิด', slot.openTime,
                                      () => _pickTime(context, day, slot, true, slotIndex),
                                    ),
                                  ),
                                  const SizedBox(width: 8), // Smaller gap
                                  Expanded(
                                    child: _buildTimePickerButton(
                                      context, 'ปิด', slot.closeTime,
                                      () => _pickTime(context, day, slot, false, slotIndex),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red), // Use outline icon
                                    onPressed: () {
                                      setState(() {
                                        day.timeSlots.removeAt(slotIndex);
                                      });
                                    },
                                    tooltip: 'ลบช่วงเวลา',
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                          // Add new slot button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end, // Align to end
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  final newSlot = TimeSlot(
                                    openTime: const TimeOfDay(hour: 9, minute: 0),
                                    closeTime: const TimeOfDay(hour: 17, minute: 0),
                                  );
                                  // Check for overlap with default new slot
                                  if (_hasOverlap(day.timeSlots, newSlot)) {
                                    scaffoldMessengerKey.currentState?.showSnackBar(
                                      const SnackBar(content: Text('ไม่สามารถเพิ่มช่วงเวลาได้ เนื่องจากมีช่วงเวลาทับซ้อนกัน')),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    day.timeSlots.add(newSlot);
                                    // Sort after adding to maintain order
                                    day.timeSlots.sort((a, b) => _timeToMinutes(a.openTime) - _timeToMinutes(b.openTime));
                                  });
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('เพิ่มช่วงเวลา'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade100,
                                  foregroundColor: Colors.green.shade800,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Consistent border radius
                                ),
                              ), // End of ElevatedButton.icon
                            ],
                          ), // End of Row
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveWorkingHours,
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.save),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked, // ✨ ปรับตำแหน่งปุ่ม
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: const Color(0xFFFBEAFF),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.calendar_today, size: 30),
                color: _selectedIndex == 0 ? Colors.purple : Colors.purple.shade200,
                onPressed: () => _onItemTapped(0),
                tooltip: 'ปฏิทิน',
              ),
              IconButton(
                icon: const Icon(Icons.people_alt, size: 30),
                color: _selectedIndex == 1 ? Colors.purple : Colors.purple.shade200,
                onPressed: () => _onItemTapped(1),
                tooltip: 'คนไข้',
              ),
              const SizedBox(width: 40), // ที่ว่างสำหรับ FloatingActionButton
              IconButton(
                icon: const Icon(Icons.bar_chart, size: 30),
                color: _selectedIndex == 3 ? Colors.purple : Colors.purple.shade200,
                onPressed: () => _onItemTapped(3),
                tooltip: 'รายงาน',
              ),
              IconButton(
                icon: const Icon(Icons.settings, size: 30),
                color: _selectedIndex == 4 ? Colors.purple : Colors.purple.shade200,
                onPressed: () => _onItemTapped(4),
                tooltip: 'ตั้งค่า',
              ),
            ],
          ),
        ),
      ),
    );
  }
}