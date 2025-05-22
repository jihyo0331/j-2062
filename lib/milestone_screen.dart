import 'package:flutter/material.dart';

class MilestoneScreen extends StatelessWidget {
  final DateTime coupleDate;
  const MilestoneScreen({Key? key, required this.coupleDate}) : super(key: key);

  // 커플 시작일을 기준으로 기념일들을 계산하여 위젯 리스트로 반환
  List<Widget> _buildMilestones(BuildContext context) {
    List<Widget> milestones = [];

    // 1일 기념일: 커플 시작일 그대로
    milestones.add(_buildMilestoneTile("1일", coupleDate));

    // 50일 기념일: 시작일 기준 49일 후
    DateTime day50 = coupleDate.add(const Duration(days: 49));
    milestones.add(_buildMilestoneTile("50일", day50));

    // 100일 단위 기념일 (100일, 200일, ... 최대 900일)
    for (int i = 100; i <= 900; i += 100) {
      DateTime milestoneDate = coupleDate.add(Duration(days: i - 1));
      milestones.add(_buildMilestoneTile("${i}일", milestoneDate));
    }

    // 1년 단위 기념일 (1년, 2년, ... 5년)
    for (int year = 1; year <= 5; year++) {
      DateTime anniversary = DateTime(coupleDate.year + year, coupleDate.month,
          coupleDate.day, coupleDate.hour, coupleDate.minute);
      milestones.add(_buildMilestoneTile("${year}년", anniversary));
    }
    return milestones;
  }

  Widget _buildMilestoneTile(String label, DateTime date) {
    String formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} "
        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    return ListTile(
      title: Text("$label 기념일: $formattedDate"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("기념일 확인")),
      body: ListView(
        children: _buildMilestones(context),
      ),
    );
  }
}
