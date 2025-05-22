import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:firebase_database/firebase_database.dart';

class GroupCalendarScreen extends StatefulWidget {
  final String groupId;
  const GroupCalendarScreen({Key? key, required this.groupId})
      : super(key: key);

  @override
  _GroupCalendarScreenState createState() => _GroupCalendarScreenState();
}

class _GroupCalendarScreenState extends State<GroupCalendarScreen> {
  late DatabaseReference _calendarRef;
  List<Appointment> _appointments = <Appointment>[];

  @override
  void initState() {
    super.initState();
    _calendarRef =
        FirebaseDatabase.instance.ref("groups/${widget.groupId}/calendar");
    _loadAppointments();
  }

  // Firebase에서 그룹의 일정 데이터를 불러와 Appointment로 변환
  Future<void> _loadAppointments() async {
    final snapshot = await _calendarRef.get();
    List<Appointment> appointments = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      data.forEach((key, value) {
        final event = value as Map;
        final String title = event["title"] ?? "일정 없음";
        // "date" 필드는 ISO 형식의 날짜 문자열로 저장되어 있다고 가정합니다.
        final DateTime start = DateTime.parse(event["date"]);
        // 기본 1시간 일정으로 설정 (필요에 따라 변경)
        final DateTime end = start.add(const Duration(hours: 1));
        // Appointment.notes 필드에 Firebase의 key를 저장해서 삭제 시 활용
        appointments.add(Appointment(
          startTime: start,
          endTime: end,
          subject: title,
          color: Colors.blue,
          notes: key, // Firebase key 저장
        ));
      });
    }
    setState(() {
      _appointments = appointments;
    });
  }

  // 캘린더 데이터 소스 클래스
  MeetingDataSource _getCalendarDataSource() {
    return MeetingDataSource(_appointments);
  }

  // 일정 삭제 함수: Firebase에서 해당 이벤트 삭제 후 재로딩
  Future<void> _deleteEvent(String eventKey) async {
    await _calendarRef.child(eventKey).remove();
    _loadAppointments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("캘린더")),
      body: SfCalendar(
        view: CalendarView.month,
        dataSource: _getCalendarDataSource(),
        monthViewSettings: const MonthViewSettings(
          appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
          showAgenda: true,
          agendaStyle: AgendaStyle(
            appointmentTextStyle: TextStyle(fontSize: 12),
          ),
        ),
        onLongPress: (CalendarLongPressDetails details) async {
          if (details.appointments != null &&
              details.appointments!.isNotEmpty) {
            // 여러 이벤트가 있는 경우 첫번째 이벤트로 가정 (필요 시 목록 선택 가능)
            Appointment appointment = details.appointments!.first;
            String? eventKey = appointment.notes as String?;
            if (eventKey != null) {
              bool? confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("일정 삭제"),
                  content:
                      Text("선택한 일정 '${appointment.subject}' 을(를) 삭제하시겠습니까?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("취소"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("삭제"),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _deleteEvent(eventKey);
              }
            }
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  // 일정 추가 다이얼로그 (날짜와 시간 선택)
  Future<void> _showAddEventDialog() async {
    final TextEditingController _titleController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("새 일정 추가"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "일정 제목"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    selectedDate = pickedDate;
                  });
                }
              },
              child: Text(
                "날짜 선택 (${selectedDate.toLocal().toString().split(' ')[0]})",
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: selectedTime,
                );
                if (pickedTime != null) {
                  setState(() {
                    selectedTime = pickedTime;
                  });
                }
              },
              child: Text("시간 선택 (${selectedTime.format(context)})"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () async {
              String title = _titleController.text.trim();
              if (title.isNotEmpty) {
                // 선택한 날짜와 시간을 합쳐 하나의 DateTime 객체 생성
                DateTime combined = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                Map<String, dynamic> newEvent = {
                  "title": title,
                  "date": combined.toIso8601String(),
                  "timestamp": ServerValue.timestamp,
                };
                await _calendarRef.push().set(newEvent);
                Navigator.pop(context);
                _loadAppointments();
              }
            },
            child: const Text("추가"),
          ),
        ],
      ),
    );
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Appointment> source) {
    appointments = source;
  }
}
