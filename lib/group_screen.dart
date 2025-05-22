import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupScreen extends StatelessWidget {
  final String groupId;
  const GroupScreen({Key? key, required this.groupId}) : super(key: key);

  Future<void> _deleteGroup(BuildContext context) async {
    // Firebase DB에서 해당 그룹 삭제
    await FirebaseDatabase.instance.ref("groups/$groupId").remove();
    // 로컬 저장소에서 그룹 ID 제거
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('group_id');
    // 삭제 후 홈 화면으로 돌아감 (루트 화면까지 pop)
    Navigator.popUntil(context, ModalRoute.withName("/"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("그룹 화면 ($groupId)"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              bool? confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("그룹 삭제"),
                  content: const Text("정말 그룹을 삭제하시겠습니까?"),
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
                await _deleteGroup(context);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("현재 그룹: $groupId", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            // 여기에서 그룹 내 다른 기능(예: 채팅, 유튜브 검색 등)으로 이동하는 버튼들을 추가하면 됩니다.
            ElevatedButton(
              onPressed: () {
                // 예: 그룹 내 유튜브 공동 시청 화면으로 이동
              },
              child: const Text("유튜브 공동 시청"),
            ),
          ],
        ),
      ),
    );
  }
}
