// ----------------------------------------------------------------
// 📁 lib/screens/weekly_calendar_screen.dart (v4.3 - 💖 Laila's Navigation Fix!)
// ----------------------------------------------------------------
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

// 🌸 Imports from our project
import '../models/appointment_model.dart';
import '../models/patient.dart';
import '../models/working_hours_model.dart';
import '../services/appointment_service.dart';
import '../services/patient_service.dart';
import '../services/working_hours_service.dart';
import '../services/daily_override_service.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../styles/app_theme.dart';
import '../widgets/appointment_detail_dialog.dart';
import '../widgets/appointment_card.dart';
import '../widgets/gap_card.dart';
import '../widgets/view_mode_selector.dart';
import 'daily_calendar_screen.dart';

// 💖✨ Imports for Magic Spell
import '../features/printing/domain/receipt_model.dart' as receipt;
import '../features/printing/render/combined_slip_preview_page.dart';
import '../features/printing/render/receipt_mapper.dart'
    show mapCalendarResultToApptInfo;
import '../services/appointment_flow_service.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';


class _WeeklyAppointmentLayoutInfo {
  final AppointmentModel appointment;
  final Patient patient;
  final DateTime startTime;
  final DateTime endTime;
  int maxOverlaps = 1;
  int columnIndex = 0;

  _WeeklyAppointmentLayoutInfo({
    required this.appointment,
    required this.patient,
    required this.startTime,
    required this.endTime,
  });

  bool overlaps(_WeeklyAppointmentLayoutInfo other) {
    return startTime.isBefore(other.endTime) &&
        endTime.isAfter(other.startTime);
  }
}

class _FloatingHorizontalScrollbar extends StatefulWidget {
  final ScrollController controller;
  final double thickness;
  final double minThumbLength;
  final EdgeInsets margin;

  const _FloatingHorizontalScrollbar({
    required this.controller,
    this.thickness = 6.0,
    this.minThumbLength = 48.0,
    this.margin = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  State<_FloatingHorizontalScrollbar> createState() =>
      _FloatingHorizontalScrollbarState();
}

class _FloatingHorizontalScrollbarState
    extends State<_FloatingHorizontalScrollbar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScroll);
    _ensureClientSync();
  }

  @override
  void didUpdateWidget(covariant _FloatingHorizontalScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleScroll);
      widget.controller.addListener(_handleScroll);
      _ensureClientSync();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScroll);
    super.dispose();
  }

  void _ensureClientSync() {
    if (!mounted) return;
    if (widget.controller.hasClients) {
      setState(() {});
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureClientSync();
      });
    }
  }

  void _handleScroll() {
    if (mounted) {
      setState(() {});
    }
  }

  void _jumpToPosition({
    required double localDx,
    required double thumbWidth,
    required double trackWidth,
    required double maxExtent,
  }) {
    if (!widget.controller.hasClients ||
        maxExtent <= 0 ||
        trackWidth <= thumbWidth) {
      return;
    }
    final available = trackWidth - thumbWidth;
    final thumbLeft = (localDx - thumbWidth / 2).clamp(0.0, available);
    final scrollFraction = available == 0 ? 0 : thumbLeft / available;
    widget.controller.jumpTo(scrollFraction * maxExtent);
  }

  @override
  Widget build(BuildContext context) {
    final scrollbarTheme = ScrollbarTheme.of(context);
    const states = <WidgetState>{};
    final resolvedThumbColor = scrollbarTheme.thumbColor?.resolve(states);
    final resolvedTrackColor = scrollbarTheme.trackColor?.resolve(states);
    final resolvedThickness =
        scrollbarTheme.thickness?.resolve(states) ?? widget.thickness;
    final resolvedRadius =
        scrollbarTheme.radius ?? Radius.circular(resolvedThickness / 2);
    final thumbColor = resolvedThumbColor ??
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.45);
    final trackColor = resolvedTrackColor ??
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.12);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!widget.controller.hasClients) {
          return const SizedBox.shrink();
        }

        final position = widget.controller.position;
        final maxExtent = position.maxScrollExtent;
        final viewport = position.viewportDimension;
        final trackWidth =
            max(0.0, constraints.maxWidth - widget.margin.horizontal);

        if (maxExtent <= 0 || trackWidth <= 0) {
          return const SizedBox.shrink();
        }

        final totalExtent = maxExtent + viewport;
        final thumbFraction = viewport / totalExtent;
        final thumbWidth = max(widget.minThumbLength, trackWidth * thumbFraction);
        final maxThumbTravel = max(0.0, trackWidth - thumbWidth);
        final scrollFraction =
            maxExtent == 0 ? 0 : (position.pixels / maxExtent).clamp(0.0, 1.0);
        final thumbOffset = maxThumbTravel * scrollFraction;

        return Padding(
          padding: widget.margin,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) => _jumpToPosition(
              localDx: details.localPosition.dx,
              thumbWidth: thumbWidth,
              trackWidth: trackWidth,
              maxExtent: maxExtent,
            ),
            onHorizontalDragUpdate: (details) => _jumpToPosition(
              localDx: details.localPosition.dx,
              thumbWidth: thumbWidth,
              trackWidth: trackWidth,
              maxExtent: maxExtent,
            ),
            child: SizedBox(
              height: resolvedThickness + 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.all(resolvedRadius),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Transform.translate(
                      offset: Offset(thumbOffset, 0),
                      child: Container(
                        width: thumbWidth,
                        height: resolvedThickness,
                        decoration: BoxDecoration(
                          color: thumbColor,
                          borderRadius: BorderRadius.all(resolvedRadius),
                          boxShadow: [
                            BoxShadow(
                              color: thumbColor.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class WeeklyViewScreen extends StatefulWidget {
  final DateTime focusedDate;
  final Patient? initialPatient;
  final receipt.ReceiptModel? receiptDraft;

  const WeeklyViewScreen({
    super.key, 
    required this.focusedDate,
    this.initialPatient,
    this.receiptDraft,
  });

  @override
  State<WeeklyViewScreen> createState() => _WeeklyViewScreenState();
}

class _WeeklyViewScreenState extends State<WeeklyViewScreen> {
  AppointmentService? _appointmentService;
  final PatientService _patientService = PatientService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  final DailyOverrideService _dailyOverrideService = DailyOverrideService();
  final Map<String, Patient> _patientCache = {};
  List<DayWorkingHours>? _workingHoursCache;
  final Map<DateTime, DayWorkingHours> _dailyOverrides = {};
  bool _overridesLoaded = false;
  String? _clinicId;
  bool _isClinicClosed = false;
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  bool _isLoading = true;

  Patient? _chainedPatient;
  receipt.ReceiptModel? _receiptDraft;
  bool _isInitialLoad = true;

  Map<
    DateTime,
    ({
      List<AppointmentModel> appointments,
      List<Patient> patients,
      DayWorkingHours? workingHours,
    })
  >
  _weeklyData = {};

  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _bodyScrollController = ScrollController();
  final ScrollController _timeAxisScrollController = ScrollController();
  final ScrollController _contentVerticalScrollController = ScrollController();

  final double _hourHeight = 120.0;
  final double _dayColumnWidth = 200.0;
  final double _timeAxisWidth = 60.0;

  int _dynamicStartHour = 9;
  int _dynamicEndHour = 17;
  DateTime? _pendingScrollDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.focusedDate;
    _selectedDay = widget.focusedDate;
    _pendingScrollDay = _selectedDay;

    _headerScrollController.addListener(() {
      if (_headerScrollController.hasClients &&
          _bodyScrollController.hasClients &&
          _headerScrollController.offset != _bodyScrollController.offset) {
        _bodyScrollController.jumpTo(_headerScrollController.offset);
      }
    });
    _bodyScrollController.addListener(() {
      if (_headerScrollController.hasClients &&
          _bodyScrollController.hasClients &&
          _headerScrollController.offset != _bodyScrollController.offset) {
        _headerScrollController.jumpTo(_bodyScrollController.offset);
      }
    });
    _contentVerticalScrollController.addListener(() {
      if (_contentVerticalScrollController.hasClients &&
          _timeAxisScrollController.hasClients &&
          _contentVerticalScrollController.offset !=
              _timeAxisScrollController.offset) {
        _timeAxisScrollController.jumpTo(
          _contentVerticalScrollController.offset,
        );
      }
    });

    // ✅ เตรียม AppointmentService ด้วย clinicId จาก Provider
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final clinicId = authProvider.verifiedClinicId;
    if (clinicId != null && clinicId.isNotEmpty) {
      _clinicId = clinicId;
      _appointmentService = AppointmentService(clinicId: clinicId);
      _fetchDataForWeek(_focusedDay);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบรหัสคลินิก กรุณาเข้าสู่ระบบใหม่')),
          );
          setState(() { _isLoading = false; });
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialLoad) {
      final arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments is Map) {
        _chainedPatient = arguments['initialPatient'] as Patient?;
        _receiptDraft = arguments['receiptDraft'] as receipt.ReceiptModel?;
      } else {
        _chainedPatient = widget.initialPatient;
        _receiptDraft = widget.receiptDraft;
      }
      _isInitialLoad = false;
    }
  }

  @override
  void didUpdateWidget(WeeklyViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isSameDay(widget.focusedDate, oldWidget.focusedDate)) {
      _focusedDay = widget.focusedDate;
      _selectedDay = widget.focusedDate;
      _queueScrollToDay(widget.focusedDate);
      _fetchDataForWeek(_focusedDay);
    }
  }

  @override
  void dispose() {
    _headerScrollController.dispose();
    _bodyScrollController.dispose();
    _timeAxisScrollController.dispose();
    _contentVerticalScrollController.dispose();
    super.dispose();
  }

  void _handleDataChange() {
    debugPrint(
      "📱 [WeeklyViewScreen] Data change detected! Refetching data...",
    );
    _patientCache.clear();
    _workingHoursCache = null;
    _overridesLoaded = false;
    _fetchDataForWeek(_focusedDay);
  }

  Future<void> _ensureOverridesLoaded() async {
    if (_overridesLoaded) return;
    final overrides =
        await _dailyOverrideService.loadOverrides(clinicId: _clinicId);
    if (!mounted) return;
    setState(() {
      _dailyOverrides
        ..clear()
        ..addAll(overrides);
      _overridesLoaded = true;
    });
  }

  Future<void> _persistDailyOverride(
    DateTime day,
    DayWorkingHours override,
  ) {
    return _dailyOverrideService.saveOverride(
      day,
      override,
      clinicId: _clinicId,
    );
  }

  Future<void> _clearDailyOverride(DateTime day) {
    return _dailyOverrideService.removeOverride(day, clinicId: _clinicId);
  }


  void _onAppointmentFlowComplete({bool clearPatient = false}) {
    if (clearPatient && mounted) {
      setState(() {
        _chainedPatient = null;
        _receiptDraft = null;
      });
    }
    _fetchDataForWeek(_focusedDay);
  }

  void _handleAddAppointment({required DateTime day, DateTime? initialStartTime}) {
    final flowService = AppointmentFlowService(
      context: context,
      onFlowComplete: _onAppointmentFlowComplete,
    );

    flowService.startAddAppointmentFlow(
      day: day,
      initialStartTime: initialStartTime,
      chainedPatient: _chainedPatient,
      receiptDraft: _receiptDraft,
    );
  }

  Future<void> _handleExistingAppointmentSelection(
    AppointmentModel appointment,
    Patient patient,
  ) async {
    if (_receiptDraft == null) {
      return;
    }

    if (_chainedPatient == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบข้อมูลคนไข้จากการรักษาค่ะ')),
        );
      }
      return;
    }

    if (_chainedPatient!.patientId != patient.patientId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('นัดหมายนี้เป็นของคนไข้คนละคนกับการรักษาค่ะ')),
        );
      }
      return;
    }

    final apptInfo = mapCalendarResultToApptInfo(appointment);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CombinedSlipPreviewPage(
          receipt: _receiptDraft!,
          nextAppointment: apptInfo,
        ),
      ),
    );

    if (!mounted) return;

    _onAppointmentFlowComplete(clearPatient: true);
  }

  void _calculateAndSetWeekHourRange() {
    if (_weeklyData.isEmpty) {
      setState(() {
        _dynamicStartHour = 9;
        _dynamicEndHour = 17;
      });
      return;
    }

    int minHour = 24;
    int maxHour = 0;
    bool hasData = false;

    for (var dayData in _weeklyData.values) {
      if (dayData.workingHours != null &&
          !dayData.workingHours!.isClosed &&
          dayData.workingHours!.timeSlots.isNotEmpty) {
        hasData = true;
        for (var slot in dayData.workingHours!.timeSlots) {
          minHour = min(minHour, slot.openTime.hour);
          maxHour = max(
            maxHour,
            slot.closeTime.hour + (slot.closeTime.minute > 0 ? 1 : 0),
          );
        }
      }
      if (dayData.appointments.isNotEmpty) {
        hasData = true;
        for (var appt in dayData.appointments) {
          minHour = min(minHour, appt.startTime.hour);
          maxHour = max(
            maxHour,
            appt.endTime.hour + (appt.endTime.minute > 0 ? 1 : 0),
          );
        }
      }
    }

    if (!hasData) {
      minHour = 9;
      maxHour = 17;
    } else {
      minHour = max(0, minHour);
      maxHour = min(24, maxHour);
      if (maxHour <= minHour) {
        maxHour = min(24, minHour + 1);
      }
    }

    if (_dynamicStartHour != minHour || _dynamicEndHour != maxHour) {
      setState(() {
        _dynamicStartHour = minHour;
        _dynamicEndHour = maxHour;
      });
    }
  }

  void _scrollToSelectedDay(DateTime selectedDay) {
    if (!_bodyScrollController.hasClients) {
      return;
    }
    final firstDayOfWeek = _focusedDay.subtract(
      Duration(days: _focusedDay.weekday % 7),
    );
    final index = selectedDay.difference(firstDayOfWeek).inDays.clamp(0, 6);
    final targetOffset = index * _dayColumnWidth;
    _bodyScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _queueScrollToDay(DateTime day) {
    _pendingScrollDay = day;
  }

  Future<void> _fetchDataForWeek(DateTime focusedDay) async {
    if (_appointmentService == null) {
      setState(() { _isLoading = false; });
      return;
    }
    setState(() {
      _isLoading = true;
    });


    await _ensureOverridesLoaded();
    final firstDayOfWeek = focusedDay.subtract(
      Duration(days: focusedDay.weekday % 7),
    );
    final endOfWeek = firstDayOfWeek.add(const Duration(days: 7));

    try {
      final appointments =
          await _appointmentService!.getAppointmentsInRange(firstDayOfWeek, endOfWeek);

      final Map<DateTime, List<AppointmentModel>> groupedAppointments = {};
      final Set<String> patientIds = {};

      int removedMissingIds = 0;
      for (final appointment in appointments) {
        if (appointment.patientId.isEmpty) {
          removedMissingIds++;
          continue;
        }
        final dayKey = DateTime(
          appointment.startTime.year,
          appointment.startTime.month,
          appointment.startTime.day,
        );
        (groupedAppointments[dayKey] ??= []).add(appointment);
        patientIds.add(appointment.patientId);
      }
      if (removedMissingIds > 0) {
        debugPrint(
            'Removed $removedMissingIds appointments without patient references.');
      }

      final missingIds = patientIds.where((id) => !_patientCache.containsKey(id)).toList();
      if (missingIds.isNotEmpty) {
        final fetchedPatients =
            await _patientService.fetchPatientsByIds(missingIds);
        for (final patient in fetchedPatients) {
          _patientCache[patient.patientId] = patient;
        }
      }

      final orphanedIds =
          patientIds.where((id) => !_patientCache.containsKey(id)).toSet();
      if (orphanedIds.isNotEmpty) {
        int removedCount = 0;
        for (final entry in groupedAppointments.entries) {
          final originalLength = entry.value.length;
          entry.value.removeWhere((appt) => orphanedIds.contains(appt.patientId));
          removedCount += originalLength - entry.value.length;
        }
        if (removedCount > 0) {
          debugPrint('Skipped $removedCount orphaned appointments during weekly load.');
        }
      }

      List<DayWorkingHours>? allWorkingHours = _workingHoursCache;
      if (allWorkingHours == null) {
        try {
          allWorkingHours = await _workingHoursService.loadWorkingHours();
          _workingHoursCache = allWorkingHours;
        } catch (e) {
          allWorkingHours = null;
        }
      }

      final Map<
        DateTime,
        ({
          List<AppointmentModel> appointments,
          List<Patient> patients,
          DayWorkingHours? workingHours,
        })
      > weeklyData = {};

      for (int i = 0; i < 7; i++) {
        final currentDay = firstDayOfWeek.add(Duration(days: i));
        final dayKey = DateTime(currentDay.year, currentDay.month, currentDay.day);
        final dailyAppointments =
            List<AppointmentModel>.from(groupedAppointments[dayKey] ?? [])
              ..sort((a, b) => a.startTime.compareTo(b.startTime));

        DayWorkingHours? dayWorkingHours;
        if (allWorkingHours != null) {
          try {
            dayWorkingHours = allWorkingHours.firstWhere(
              (day) => day.dayName == _getThaiDayName(currentDay.weekday),
            );
          } catch (e) {
            dayWorkingHours = null;
          }
        }
        final baseWorkingHours = dayWorkingHours;
        final override = _dailyOverrides[dayKey];
        if (override != null) {
          dayWorkingHours = override;
        }
        final updatedAppointments = _applyClosedOverlay(
          dailyAppointments,
          currentDay,
          baseWorkingHours,
          override,
        );
        final patients = updatedAppointments
            .map((appt) => _patientCache[appt.patientId])
            .whereType<Patient>()
            .toList();

        weeklyData[dayKey] = (
          appointments: updatedAppointments,
          patients: patients,
          workingHours: dayWorkingHours,
        );
      }

      if (!mounted) return;
      setState(() {
        _weeklyData = weeklyData;
        _isLoading = false;
      });
      if (_pendingScrollDay != null) {
        final day = _pendingScrollDay!;
        _pendingScrollDay = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToSelectedDay(day);
        });
      }
      _updateSelectedDayClosedState();

      _calculateAndSetWeekHourRange();
    } catch (e) {
      debugPrint('Error loading weekly appointments: $e');
      if (!mounted) return;
      setState(() {
        _weeklyData = {};
        _isLoading = false;
      });
    }
  }

  String _getThaiDayName(int weekday) {
    const days = [
      'จันทร์',
      'อังคาร',
      'พุธ',
      'พฤหัสบดี',
      'ศุกร์',
      'เสาร์',
      'อาทิตย์',
    ];
    return days[weekday - 1];
  }


  DateTime _dayKey(DateTime day) => DateTime(day.year, day.month, day.day);

  DayWorkingHours _cloneDayWorkingHours(DayWorkingHours? source, String dayName) {
    if (source == null) {
      return DayWorkingHours(dayName: dayName, isClosed: true, timeSlots: []);
    }
    return DayWorkingHours(
      dayName: dayName,
      isClosed: source.isClosed,
      timeSlots: source.timeSlots
          .map((slot) => TimeSlot(openTime: slot.openTime, closeTime: slot.closeTime))
          .toList(),
    );
  }

  List<AppointmentModel> _applyClosedOverlay(
    List<AppointmentModel> appointments,
    DateTime day,
    DayWorkingHours? baseWorkingHours,
    DayWorkingHours? override,
  ) {
    if (override == null || !override.isClosed) {
      return appointments;
    }
    if (baseWorkingHours == null || baseWorkingHours.timeSlots.isEmpty) {
      return appointments;
    }
    final closedAppointments = <AppointmentModel>[];
    for (int i = 0; i < baseWorkingHours.timeSlots.length; i++) {
      final slot = baseWorkingHours.timeSlots[i];
      final start = DateTime(day.year, day.month, day.day, slot.openTime.hour, slot.openTime.minute);
      final end = DateTime(day.year, day.month, day.day, slot.closeTime.hour, slot.closeTime.minute);
      if (!end.isAfter(start)) {
        continue;
      }
      final id = '__clinic_closed_${_dayKey(day).toIso8601String()}_$i';
      closedAppointments.add(
        AppointmentModel(
          appointmentId: id,
          userId: '',
          patientId: id,
          patientName: 'ปิดทำการ',
          treatment: 'ปิด',
          duration: end.difference(start).inMinutes,
          status: 'ปิดทำการ',
          startTime: start,
          endTime: end,
        ),
      );
      _patientCache[id] = Patient(
        patientId: id,
        name: 'ปิดทำการ',
        prefix: '',
        rating: 0.0,
        gender: '',
      );
    }
    final combined = [...appointments, ...closedAppointments];
    combined.sort((a, b) => a.startTime.compareTo(b.startTime));
    return combined;
  }

  void _updateSelectedDayClosedState() {
    final selectedDay = _selectedDay ?? _focusedDay;
    final dayKey = _dayKey(selectedDay);
    final workingHours = _weeklyData[dayKey]?.workingHours;
    final hasOverride = _dailyOverrides.containsKey(dayKey);
    setState(() {
      _isClinicClosed =
          workingHours == null ||
          workingHours.isClosed ||
          (!hasOverride && workingHours.timeSlots.isEmpty);
    });
  }

  void _toggleClinicOpenClosed() {
    final selectedDay = _selectedDay ?? _focusedDay;
    final key = _dayKey(selectedDay);
    final dayName = _getThaiDayName(selectedDay.weekday);
    if (_isClinicClosed) {
      DayWorkingHours? baseWorkingHours;
      if (_workingHoursCache != null) {
        try {
          baseWorkingHours =
              _workingHoursCache!.firstWhere((d) => d.dayName == dayName);
        } catch (_) {
          baseWorkingHours = null;
        }
      }
      final bool baseClosed =
          baseWorkingHours == null ||
          baseWorkingHours.isClosed ||
          baseWorkingHours.timeSlots.isEmpty;
      if (baseClosed) {
        final override = _cloneDayWorkingHours(baseWorkingHours, dayName);
        override.isClosed = false;
        _dailyOverrides[key] = override;
        _persistDailyOverride(selectedDay, override);
        setState(() {
          _isClinicClosed = false;
        });
        _fetchDataForWeek(_focusedDay);
        _showDailyWorkingHoursDialog(override);
      } else {
        _dailyOverrides.remove(key);
        _clearDailyOverride(selectedDay);
        setState(() {
          _isClinicClosed = false;
        });
        _fetchDataForWeek(_focusedDay);
        _showDailyWorkingHoursDialog(
          _cloneDayWorkingHours(baseWorkingHours, dayName),
        );
      }
    } else {
      final override = _dailyOverrides[key] ??
          DayWorkingHours(dayName: dayName, isClosed: true, timeSlots: []);
      override.isClosed = true;
      _dailyOverrides[key] = override;
      _persistDailyOverride(selectedDay, override);
      setState(() {
        _isClinicClosed = true;
      });
      _fetchDataForWeek(_focusedDay);
    }
  }

  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  bool _hasOverlap(List<TimeSlot> slots, TimeSlot newSlot, [int? excludeIndex]) {
    final newOpenMinutes = _timeToMinutes(newSlot.openTime);
    final newCloseMinutes = _timeToMinutes(newSlot.closeTime);
    for (int i = 0; i < slots.length; i++) {
      if (excludeIndex != null && i == excludeIndex) {
        continue;
      }
      final existingSlot = slots[i];
      final existingOpenMinutes = _timeToMinutes(existingSlot.openTime);
      final existingCloseMinutes = _timeToMinutes(existingSlot.closeTime);
      if (newOpenMinutes < existingCloseMinutes && newCloseMinutes > existingOpenMinutes) {
        return true;
      }
    }
    return false;
  }

  Future<void> _pickTime(
    BuildContext context,
    DayWorkingHours day,
    TimeSlot slot,
    bool isOpeningTime,
    int slotIndex, {
    VoidCallback? onChanged,
  }) async {
    final initialTime = isOpeningTime ? slot.openTime : slot.closeTime;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (!context.mounted) return;
    if (picked != null && mounted) {
      final tempSlot = TimeSlot(
        openTime: isOpeningTime ? picked : slot.openTime,
        closeTime: isOpeningTime ? slot.closeTime : picked,
      );
      if (_timeToMinutes(tempSlot.openTime) >= _timeToMinutes(tempSlot.closeTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ช่วงเวลาไม่ถูกต้อง'),
          ),
        );
        return;
      }
      if (_hasOverlap(day.timeSlots, tempSlot, slotIndex)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ช่วงเวลาทำการทับซ้อนกัน'),
          ),
        );
        return;
      }
      setState(() {
        if (isOpeningTime) {
          slot.openTime = picked;
        } else {
          slot.closeTime = picked;
        }
        day.timeSlots.sort((a, b) => _timeToMinutes(a.openTime) - _timeToMinutes(b.openTime));
        _dailyOverrides[_dayKey(_selectedDay ?? _focusedDay)] = day;
      });
      _persistDailyOverride(_selectedDay ?? _focusedDay, day);
      onChanged?.call();
    }
  }

  Widget _buildTimePickerButton(
    BuildContext context,
    String label,
    TimeOfDay time,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        elevation: 0,
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

  Future<void> _showDailyWorkingHoursDialog(DayWorkingHours day) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            void refreshDialog() {
              dialogSetState(() {});
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SingleChildScrollView(
                child: _buildDailyWorkingHoursCard(
                  day,
                  onChanged: refreshDialog,
                  onConfirm: () {
                    Navigator.of(context).pop();
                    _fetchDataForWeek(_focusedDay);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDailyWorkingHoursCard(
    DayWorkingHours day, {
    VoidCallback? onConfirm,
    VoidCallback? onChanged,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 3,
      margin: EdgeInsets.zero,
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      day.isClosed = !day.isClosed;
                      _isClinicClosed = day.isClosed;
                      _dailyOverrides[_dayKey(_selectedDay ?? _focusedDay)] = day;
                    });
                    _persistDailyOverride(_selectedDay ?? _focusedDay, day);
                    onChanged?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        day.isClosed ? Colors.red.shade300 : const Color(0xFFE0BBFF),
                    foregroundColor:
                        day.isClosed ? Colors.white : Colors.purple.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: day.isClosed ? Colors.red.shade500 : Colors.purple.shade700,
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                  ),
                  child: Text(
                    day.isClosed ? 'หยุด' : 'เปิด',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (!day.isClosed) ...[
              ...day.timeSlots.asMap().entries.map((entry) {
                final int slotIndex = entry.key;
                final TimeSlot slot = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTimePickerButton(
                          context,
                          'เปิด',
                          slot.openTime,
                          () => _pickTime(
                            context,
                            day,
                            slot,
                            true,
                            slotIndex,
                            onChanged: onChanged,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTimePickerButton(
                          context,
                          'ปิด',
                          slot.closeTime,
                          () => _pickTime(
                            context,
                            day,
                            slot,
                            false,
                            slotIndex,
                            onChanged: onChanged,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            day.timeSlots.removeAt(slotIndex);
                            _dailyOverrides[_dayKey(_selectedDay ?? _focusedDay)] = day;
                          });
                          _persistDailyOverride(_selectedDay ?? _focusedDay, day);
                          onChanged?.call();
                        },
                        tooltip: 'ลบช่วงเวลา',
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      final newSlot = TimeSlot(
                        openTime: const TimeOfDay(hour: 9, minute: 0),
                        closeTime: const TimeOfDay(hour: 17, minute: 0),
                      );
                      if (_hasOverlap(day.timeSlots, newSlot)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ช่วงเวลาทำการทับซ้อนกัน'),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        day.timeSlots.add(newSlot);
                        day.timeSlots.sort((a, b) => _timeToMinutes(a.openTime) - _timeToMinutes(b.openTime));
                        _dailyOverrides[_dayKey(_selectedDay ?? _focusedDay)] = day;
                      });
                      _persistDailyOverride(_selectedDay ?? _focusedDay, day);
                      onChanged?.call();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มช่วงเวลาทำการ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade800,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              if (onConfirm != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'ยืนยัน',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<_WeeklyAppointmentLayoutInfo> _calculateAppointmentLayouts(
    List<AppointmentModel> appointments,
    List<Patient> patients,
  ) {
    if (appointments.isEmpty) return [];
    final patientMap = {for (var p in patients) p.patientId: p};

    var events =
        appointments.map((appt) {
          final patient =
              patientMap[appt.patientId] ??
              Patient(patientId: 'unknown', name: 'Unknown', prefix: '');
          return _WeeklyAppointmentLayoutInfo(
            appointment: appt,
            patient: patient,
            startTime: appt.startTime,
            endTime: appt.endTime,
          );
        }).toList();

    events.sort((a, b) => a.startTime.compareTo(b.startTime));
    for (var event in events) {
      event.columnIndex = 0;
      event.maxOverlaps = 1;
    }
    for (int i = 0; i < events.length; i++) {
      var currentEvent = events[i];
      List<_WeeklyAppointmentLayoutInfo> overlappingPeers = [];
      for (int j = 0; j < i; j++) {
        if (currentEvent.overlaps(events[j])) {
          overlappingPeers.add(events[j]);
        }
      }
      var occupiedColumns = overlappingPeers.map((e) => e.columnIndex).toSet();
      int col = 0;
      while (occupiedColumns.contains(col)) {
        col++;
      }
      currentEvent.columnIndex = col;
    }
    for (var event in events) {
      var allOverlapping =
          events.where((peer) => peer.overlaps(event)).toList();
      int maxCol = 0;
      for (var item in allOverlapping) {
        if (item.columnIndex > maxCol) {
          maxCol = item.columnIndex;
        }
      }
      for (var item in allOverlapping) {
        item.maxOverlaps = max(item.maxOverlaps, maxCol + 1);
      }
    }
    return events;
  }

  List<Map<String, dynamic>> _getCombinedListForDay(
    List<AppointmentModel> appointments,
    DayWorkingHours workingHours,
    DateTime selectedDate,
  ) {
    appointments.sort((a, b) => a.startTime.compareTo(b.startTime));

    List<Map<String, dynamic>> finalCombinedList = [];
    final includedAppointments = <String>{};

    for (final slot in workingHours.timeSlots) {
      final slotOpenTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        slot.openTime.hour,
        slot.openTime.minute,
      );
      final slotCloseTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        slot.closeTime.hour,
        slot.closeTime.minute,
      );

      DateTime lastEventEnd = slotOpenTime;

      final appointmentsInSlot =
          appointments.where((appt) {
            return appt.endTime.isAfter(slotOpenTime) &&
                appt.startTime.isBefore(slotCloseTime);
          }).toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

      for (var appt in appointmentsInSlot) {
        if (appt.startTime.isAfter(lastEventEnd)) {
          finalCombinedList.add({
            'isGap': true,
            'start': lastEventEnd,
            'end': appt.startTime,
          });
        }
        finalCombinedList.add({'isGap': false, 'appointment': appt});
        final appointmentKey = appt.appointmentId.isNotEmpty
            ? appt.appointmentId
            : appt.startTime.toIso8601String();
        includedAppointments.add(appointmentKey);
        if (appt.endTime.isAfter(lastEventEnd)) {
          lastEventEnd = appt.endTime;
        }
      }

      if (slotCloseTime.isAfter(lastEventEnd)) {
        finalCombinedList.add({
          'isGap': true,
          'start': lastEventEnd,
          'end': slotCloseTime,
        });
      }
    }
    for (final appt in appointments) {
      final appointmentKey = appt.appointmentId.isNotEmpty
          ? appt.appointmentId
          : appt.startTime.toIso8601String();
      if (!includedAppointments.contains(appointmentKey)) {
        finalCombinedList.add({'isGap': false, 'appointment': appt});
      }
    }

    finalCombinedList.sort((a, b) {
      final aIsGap = a['isGap'] == true;
      final bIsGap = b['isGap'] == true;
      final aStart = aIsGap
          ? a['start'] as DateTime
          : (a['appointment'] as AppointmentModel).startTime;
      final bStart = bIsGap
          ? b['start'] as DateTime
          : (b['appointment'] as AppointmentModel).startTime;
      final compare = aStart.compareTo(bStart);
      if (compare != 0) {
        return compare;
      }
      if (aIsGap == bIsGap) {
        return 0;
      }
      return aIsGap ? -1 : 1;
    });
    return finalCombinedList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primaryLight,
        elevation: 0,
        title: const Text('ภาพรวมสัปดาห์'),
      ),
      body: _isLoading
          ? const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          )
          : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ViewModeSelector(
                        calendarFormat: CalendarFormat.week,
                        onFormatChanged: (format) {
                          if (format == CalendarFormat.month) {
                            Navigator.pop(context, {
                              'selectedDate': _selectedDay ?? _focusedDay,
                              'format': CalendarFormat.month,
                            });
                          }
                        },
                        onDailyViewTapped: () async {
                          final navigator = Navigator.of(context);
                          final result = await navigator.push(
                            MaterialPageRoute(
                              builder:
                                  (context) => DailyCalendarScreen(
                                    selectedDate: _selectedDay ?? DateTime.now(),
                                    returnFormatOnPop: CalendarFormat.week,
                                    initialPatient: _chainedPatient,
                                    receiptDraft: _receiptDraft,
                                  ),
                            ),
                          );

                          if (!mounted) return;

                          DateTime? selectedDate;
                          CalendarFormat? format;
                          if (result is Map) {
                            final rawFormat = result['format'];
                            final rawDate = result['selectedDate'];
                            if (rawFormat is CalendarFormat) {
                              format = rawFormat;
                            }
                            if (rawDate is DateTime) {
                              selectedDate = rawDate;
                            }
                          } else if (result is CalendarFormat) {
                            format = result;
                          }

                          if (selectedDate != null) {
                            final resolvedDate = selectedDate;
                            setState(() {
                              _selectedDay = resolvedDate;
                              _focusedDay = resolvedDate;
                            });
                            _updateSelectedDayClosedState();
                            _queueScrollToDay(resolvedDate);
                          }

                          if (format == CalendarFormat.month) {
                            navigator.pop({
                              'selectedDate': selectedDate ?? _selectedDay,
                              'format': CalendarFormat.month,
                            });
                            return;
                          }

                          _overridesLoaded = false;
                          _fetchDataForWeek(selectedDate ?? _focusedDay);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: _toggleClinicOpenClosed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isClinicClosed
                            ? Colors.red.shade300
                            : const Color(0xFFE0BBFF),
                        foregroundColor: _isClinicClosed
                            ? Colors.white
                            : Colors.purple.shade900,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: _isClinicClosed
                                ? Colors.red.shade500
                                : Colors.purple.shade700,
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(0, 36),
                        visualDensity: VisualDensity.compact,
                        elevation: 2,
                      ),
                      child: Text(
                        _isClinicClosed
                            ? '\u0e2b\u0e22\u0e38\u0e14'
                            : '\u0e40\u0e1b\u0e34\u0e14',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildCalendar(),
              const SizedBox(height: 12),
              _buildWeekDayHeader(),
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _contentVerticalScrollController,
                      child: SizedBox(
                        height:
                            _hourHeight * (_dynamicEndHour - _dynamicStartHour),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTimeAxis(),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _bodyScrollController,
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: List.generate(7, (index) {
                                    final firstDayOfWeek = _focusedDay.subtract(
                                      Duration(days: _focusedDay.weekday % 7),
                                    );
                                    final day = firstDayOfWeek.add(
                                      Duration(days: index),
                                    );
                                    final dayKey = DateTime(
                                      day.year,
                                      day.month,
                                      day.day,
                                    );
                                    final dayData = _weeklyData[dayKey];
                                    return _buildDayColumn(day, dayData);
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16 + _timeAxisWidth,
                      right: 16,
                      bottom: _scrollbarBottomOffset(context),
                      child: _FloatingHorizontalScrollbar(
                        controller: _bodyScrollController,
                        margin: EdgeInsets.zero,
                        thickness: 6,
                        minThumbLength: _resolveMinThumbLength(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleAddAppointment(day: _selectedDay ?? DateTime.now()),
        backgroundColor: AppTheme.primary,
        tooltip: 'เพิ่มนัดหมายใหม่',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 0),
    );
  }

  Widget _buildCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TableCalendar(
          locale: 'th_TH',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: CalendarFormat.week,
          availableCalendarFormats: const {CalendarFormat.week: 'Week'},
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          daysOfWeekHeight: 22.0,
          headerStyle: const HeaderStyle(
            titleCentered: true,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: AppTheme.fontFamily,
              
            ),
            formatButtonVisible: false,
            
          ),
          calendarBuilders: CalendarBuilders(
            headerTitleBuilder: (context, date) {
              final year = date.year + 543;
              final month = DateFormat.MMMM('th_TH').format(date);
              return Center(
                child: Text(
                  '$month $year',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.textPrimary,
                  ),
                ),
              );
            },
            dowBuilder: (context, day) {
              final text = DateFormat.E('th_TH').format(day);
              return Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
              );
            },
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            defaultTextStyle: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
            weekendTextStyle: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _updateSelectedDayClosedState();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToSelectedDay(selectedDay);
              });
            }
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
              _selectedDay = focusedDay;
            });
            _fetchDataForWeek(focusedDay);
            _updateSelectedDayClosedState();
            _queueScrollToDay(focusedDay);
          },
        ),
      ),
    );
  }

  Widget _buildWeekDayHeader() {
    final firstDayOfWeek = _focusedDay.subtract(
      Duration(days: _focusedDay.weekday % 7),
    );
    final dayFormatter = DateFormat('E', 'th_TH');
    final dateFormatter = DateFormat('d', 'th_TH');

    return SingleChildScrollView(
      controller: _headerScrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          SizedBox(width: _timeAxisWidth),
          ...List.generate(7, (index) {
            final day = firstDayOfWeek.add(Duration(days: index));
            final dayKey = DateTime(day.year, day.month, day.day);
            final eventCount = _weeklyData[dayKey]?.appointments.length ?? 0;
            final isToday = isSameDay(day, DateTime.now());

            return Container(
              width: _dayColumnWidth,
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
              decoration: BoxDecoration(
                color:
                    isToday
                        ? AppTheme.primaryLight.withValues(alpha: 0.3)
                        : Colors.transparent,
                border: Border(
                  right: BorderSide(color: Colors.grey.shade200),
                  bottom: BorderSide(color: Colors.grey.shade300, width: 2),
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayFormatter.format(day),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              isToday ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        dateFormatter.format(day),
                        style: TextStyle(
                          color:
                              isToday
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (eventCount > 0)
                    Positioned(
                      top: -6,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF06292),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            '$eventCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeAxis() {
    return SizedBox(
      width: _timeAxisWidth,
      child: ListView.builder(
        controller: _timeAxisScrollController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _dynamicEndHour - _dynamicStartHour,
        itemBuilder: (context, index) {
          final hour = _dynamicStartHour + index;
          return Container(
            height: _hourHeight,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayColumn(
    DateTime day,
    ({
      List<AppointmentModel> appointments,
      List<Patient> patients,
      DayWorkingHours? workingHours,
    })?
    dayData,
  ) {
    final pixelsPerMinute = _hourHeight / 60.0;
    final dayStartTime = DateTime(
      day.year,
      day.month,
      day.day,
      _dynamicStartHour,
    );

    final appointments = dayData?.appointments ?? [];
    final patients = dayData?.patients ?? [];
    final workingHours = dayData?.workingHours;

    // Build combinedList: if closed or no working hours, show appointments only (no gaps)
    final List<Map<String, dynamic>> combinedList = (workingHours == null || workingHours.isClosed)
        ? appointments.map((appt) => {'isGap': false, 'appointment': appt}).toList()
        : _getCombinedListForDay(appointments, workingHours, day);
    final appointmentLayouts = _calculateAppointmentLayouts(
      appointments,
      patients,
    );
    final patientMap = {for (var p in patients) p.patientId: p};

    return Container(
      width: _dayColumnWidth,
      height: _hourHeight * (_dynamicEndHour - _dynamicStartHour),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Stack(
        children: [
          if (workingHours == null || workingHours.isClosed)
            Positioned.fill(
              child: Container(color: Colors.grey.shade50),
            ),
          ...List.generate(
            _dynamicEndHour - _dynamicStartHour,
            (i) => Positioned(
              top: i * _hourHeight,
              left: 0,
              right: 0,
              child: Container(height: 1, color: Colors.grey.shade200),
            ),
          ),
          ...combinedList.map((item) {
            final bool isGap = item['isGap'] == true;
            final DateTime itemStart =
                isGap
                    ? item['start']
                    : (item['appointment'] as AppointmentModel).startTime;
            final DateTime itemEnd =
                isGap
                    ? item['end']
                    : (item['appointment'] as AppointmentModel).endTime;

            final top = max(
              0.0,
              itemStart.difference(dayStartTime).inMinutes * pixelsPerMinute,
            );
            final height = max(
              0.0,
              itemEnd.difference(itemStart).inMinutes * pixelsPerMinute,
            );

            if (height <= 0.1) return const SizedBox.shrink();

            if (isGap) {
              return Positioned(
                top: top,
                left: 0,
                right: 0,
                height: height,
                child: GapCard(
                  gapStart: itemStart,
                  gapEnd: itemEnd,
                  onTap: () => _handleAddAppointment(day: day, initialStartTime: itemStart),
                ),
              );
            } else {
              final appointmentModel = item['appointment'] as AppointmentModel;
              final patientModel = patientMap[appointmentModel.patientId];
              if (patientModel == null) return const SizedBox.shrink();

              final layoutInfo = appointmentLayouts.firstWhere(
                (l) =>
                    l.appointment.appointmentId ==
                    appointmentModel.appointmentId,
              );
              final cardWidth = (_dayColumnWidth / layoutInfo.maxOverlaps) - 4;
              final left = layoutInfo.columnIndex * (cardWidth + 4);

              return Positioned(
                top: top,
                left: left,
                width: cardWidth,
                height: height,
                child: AppointmentCard(
                  appointment: appointmentModel,
                  patient: patientModel,
                  isCompact: layoutInfo.maxOverlaps > 1,
                  isShort: height < 60,
                  onTap: () async {
                    final allowSelection =
                        _receiptDraft != null && _chainedPatient != null;
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder:
                          (_) => AppointmentDetailDialog(
                            appointment: appointmentModel,
                            patient: patientModel,
                            onDataChanged: _handleDataChange,
                            enableChainedSelection: allowSelection,
                            chainedPatient: _chainedPatient,
                          ),
                    );

                    if (allowSelection &&
                        result is Map<String, dynamic> &&
                        result['useChainedFlow'] == true) {
                      final selectedAppointment =
                          result['appointment'] as AppointmentModel? ??
                              appointmentModel;
                      final selectedPatient =
                          result['patient'] as Patient? ?? patientModel;
                      await _handleExistingAppointmentSelection(
                        selectedAppointment,
                        selectedPatient,
                      );
                    }
                  },
                ),
              );
            }
          }),
          if ((workingHours == null || workingHours.isClosed) && appointments.isEmpty)
            Center(
              child: Text(
                'ปิดทำการ',
                style: TextStyle(color: AppTheme.textDisabled),
              ),
            ),
        ],
      ),
    );
  }

  double _scrollbarBottomOffset(BuildContext context) {
    final viewPadding = MediaQuery.of(context).viewPadding.bottom;
    // Keep the scrollbar above the bottom navigation bar and safe area.
    return viewPadding + kBottomNavigationBarHeight - 50;
  }

  double _resolveMinThumbLength(BuildContext context) {
    final minLength = ScrollbarTheme.of(context).minThumbLength;
    if (minLength != null) {
      return minLength;
    }
    return 48;
  }
}
