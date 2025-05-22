import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;
  const ChatScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  late DatabaseReference _chatRef;
  final List<Map<String, dynamic>> _messages = [];

  // 스크롤 컨트롤러 추가
  final ScrollController _scrollController = ScrollController();

  // flutter_local_notifications 플러그인 인스턴스 생성
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String _groupName = ""; // 그룹 이름

  @override
  void initState() {
    super.initState();
    _chatRef =
        FirebaseDatabase.instance.ref("groups/${widget.groupId}/chat/messages");

    _initializeNotifications();
    _loadGroupName();

    // 새로운 메시지 수신
    _chatRef.onChildAdded.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final message = Map<String, dynamic>.from(data);
        message['key'] = event.snapshot.key;
        setState(() {
          _messages.add(message);
        });
        _showNotification(message);
        _scrollToBottom();
      }
    });
  }

  Future<void> _loadGroupName() async {
    final DatabaseReference groupNameRef =
        FirebaseDatabase.instance.ref("groups/${widget.groupId}/groupName");
    final snapshot = await groupNameRef.get();
    if (snapshot.exists && snapshot.value is String) {
      setState(() {
        _groupName = snapshot.value as String;
      });
    } else {
      setState(() {
        _groupName = widget.groupId; // 그룹 이름이 없으면 groupId로 표시
      });
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(Map<String, dynamic> message) async {
    String sender = message["sender"] ?? "누군가";
    String text = message["text"] ?? "";

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'chat_channel',
      '채팅 알림',
      channelDescription: '채팅 메시지 수신 시 알림',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      "$sender 님의 메시지",
      text,
      platformChannelSpecifics,
      payload: 'chat_payload',
    );
  }

  void _sendMsg() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "unknown";
    _chatRef.push().set({
      "sender": uid,
      "text": text,
      "timestamp": ServerValue.timestamp,
    });
  }

  // 스크롤 컨트롤러를 사용해 목록의 마지막으로 스크롤
  void _scrollToBottom() {
    // 약간의 지연 후에 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "unknown";
    return Scaffold(
      appBar: AppBar(title: Text(_groupName)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMine = msg["sender"] == uid;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  alignment:
                      isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMine ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      msg["text"] ?? "",
                      style: TextStyle(
                        color: isMine ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration.collapsed(
                      hintText: "메시지를 입력하세요...",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMsg,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
