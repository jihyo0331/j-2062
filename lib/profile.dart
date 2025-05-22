import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'group_screen.dart'; // 그룹 스크린 파일 (별도 파일로 만들어 둬야 함)
import 'main.dart'; // 필요에 따라 추가
import 'milestone_screen.dart'; // 기념일 확인 페이지 (별도 파일로 작성)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 커플 디데이 관련 변수
  DateTime? _selectedDate;
  // 그룹 관리 관련 변수
  final TextEditingController _groupIdController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  String? _savedGroupId;
  bool _isProcessing = false;

  // 프로필 정보 관련 변수 (Realtime Database에 base64 문자열로 이미지 저장)
  final TextEditingController _nicknameController = TextEditingController();
  File? _profileImage;
  String? _profileImageBase64;
  final ImagePicker _picker = ImagePicker();
  late DatabaseReference _userRef;
  final String _userId =
      FirebaseAuth.instance.currentUser?.uid ?? "defaultUser";

  @override
  void initState() {
    super.initState();
    _loadGroupId();
    _loadCoupleDate();
    _userRef = FirebaseDatabase.instance.ref("users/$_userId");
    _loadProfileData();
  }

  // SharedPreferences에서 저장된 그룹 ID 불러오기
  Future<void> _loadGroupId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedGroupId = prefs.getString('group_id') ?? "";
    });
  }

  // SharedPreferences에서 저장된 커플 시작일 불러오기 (시간은 00:00으로 고정)
  Future<void> _loadCoupleDate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? dateString = prefs.getString('couple_date');
    if (dateString != null && dateString.isNotEmpty) {
      DateTime parsed = DateTime.parse(dateString);
      DateTime dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
      setState(() {
        _selectedDate = dateOnly;
      });
    }
  }

  // 사용자 프로필 데이터 불러오기
  Future<void> _loadProfileData() async {
    final snapshot = await _userRef.get();
    if (snapshot.exists && snapshot.value is Map) {
      final data = snapshot.value as Map;
      setState(() {
        _nicknameController.text = data["nickname"] ?? "";
        _profileImageBase64 = data["profileImageBase64"] as String?;
      });
    }
  }

  // 갤러리에서 프로필 사진 선택 후, 파일을 base64 문자열로 변환하여 Realtime Database에 저장
  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
      try {
        final bytes = await _profileImage!.readAsBytes();
        final base64Str = base64Encode(bytes);
        setState(() {
          _profileImageBase64 = base64Str;
        });
        await _userRef.update({"profileImageBase64": base64Str});
      } catch (e) {
        debugPrint("이미지 업로드 오류: $e");
      }
    }
  }

  // 닉네임 저장 및 Realtime Database 업데이트
  Future<void> _saveProfile() async {
    String nickname = _nicknameController.text.trim();
    if (nickname.isNotEmpty) {
      await _userRef.update({"nickname": nickname});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 업데이트 완료')),
      );
    }
  }

  // 그룹 가입: 입력한 그룹 ID로 그룹에 가입 후 GroupScreen으로 이동
  Future<void> _joinGroup() async {
    final String groupId = _groupIdController.text.trim();
    if (groupId.isEmpty) return;
    setState(() {
      _isProcessing = true;
    });
    try {
      final DatabaseReference groupRef =
          FirebaseDatabase.instance.ref("groups/$groupId");
      final snapshot = await groupRef.get();
      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("존재하지 않는 그룹 ID입니다.")),
        );
        return;
      }
      final String uid = "joined_${groupId.substring(0, 5)}";
      await groupRef.child("members/user2").set(uid);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('group_id', groupId);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GroupScreen(groupId: groupId)),
      );
    } catch (e) {
      debugPrint("그룹 가입 오류: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // 그룹 생성: 새 그룹 생성 후 GroupScreen으로 이동
  Future<void> _createGroup() async {
    setState(() {
      _isProcessing = true;
    });
    try {
      final DatabaseReference groupRef =
          FirebaseDatabase.instance.ref("groups").push();
      final String groupId = groupRef.key!;
      final String groupName = _groupNameController.text.trim().isEmpty
          ? "My Group"
          : _groupNameController.text.trim();
      final String uid = "user_${groupId.substring(0, 5)}";
      await groupRef.set({
        "groupName": groupName,
        "members": {"user1": uid},
        "youtubeInfo": {
          "videoId": "",
          "playback": 0,
          "isPlaying": false,
        },
        "chat": {
          "messages": {},
        },
      });
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('group_id', groupId);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GroupScreen(groupId: groupId)),
      );
    } catch (e) {
      debugPrint("그룹 생성 오류: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // 커플 시작일을 기준으로 기념일 목록 계산 (시간은 00:00 고정)
  List<Widget> _buildMilestones(DateTime coupleDate) {
    List<Widget> milestones = [];
    milestones.add(_buildMilestoneTile("1일", coupleDate));
    DateTime day50 = coupleDate.add(const Duration(days: 49));
    milestones.add(_buildMilestoneTile("50일", day50));
    for (int i = 100; i <= 900; i += 100) {
      DateTime milestoneDate = coupleDate.add(Duration(days: i - 1));
      milestones.add(_buildMilestoneTile("${i}일", milestoneDate));
    }
    for (int year = 1; year <= 5; year++) {
      DateTime anniversary =
          DateTime(coupleDate.year + year, coupleDate.month, coupleDate.day);
      milestones.add(_buildMilestoneTile("${year}년", anniversary));
    }
    return milestones;
  }

  // 단일 기념일 타일 위젯 생성 (형식: "1일: YYYY-MM-DD")
  Widget _buildMilestoneTile(String label, DateTime date) {
    String formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return ListTile(
      title: Text("$label: $formattedDate"),
    );
  }

  // 날짜만 선택하도록 수정된 _pickDateTime 함수 (시간은 00:00 고정)
  Future<void> _pickDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      DateTime combined =
          DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
      setState(() {
        _selectedDate = combined;
      });
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('couple_date', combined.toIso8601String());
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? profileImageProvider;
    if (_profileImage != null) {
      profileImageProvider = FileImage(_profileImage!);
    } else if (_profileImageBase64 != null) {
      profileImageProvider = MemoryImage(base64Decode(_profileImageBase64!));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('프로필')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 프로필 정보 영역
            const Text(
              '프로필 정보',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickAndUploadImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: profileImageProvider,
                child: profileImageProvider == null
                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: '닉네임',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('프로필 업데이트'),
            ),
            const Divider(height: 40),
            // 커플 디데이 및 기념일 영역
            const Text(
              '커플 디데이 설정',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _selectedDate != null
                ? Column(
                    children: [
                      Text(
                        "선택한 날짜: ${_selectedDate!.toLocal().toString().split(' ')[0]}",
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _pickDateTime,
                        child: const Text("날짜 수정"),
                      ),
                    ],
                  )
                : ElevatedButton(
                    onPressed: _pickDateTime,
                    child: const Text('날짜 선택'),
                  ),
            const SizedBox(height: 30),
            _selectedDate != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "기념일 목록",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      ..._buildMilestones(_selectedDate!),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MilestoneScreen(coupleDate: _selectedDate!),
                            ),
                          );
                        },
                        child: const Text("기념일 확인 페이지로 이동"),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),
            // 그룹 관리 영역
            const Text(
              '그룹 관리',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _savedGroupId != null && _savedGroupId!.isNotEmpty
                ? ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupScreen(groupId: _savedGroupId!),
                        ),
                      );
                    },
                    child: const Text("그룹 스크린으로 이동"),
                  )
                : Column(
                    children: [
                      _isProcessing
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _createGroup,
                              child: const Text("새 그룹 만들기"),
                            ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _groupNameController,
                        decoration: const InputDecoration(
                          labelText: "그룹 이름 (선택)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _groupIdController,
                        decoration: const InputDecoration(
                          labelText: "그룹 ID 입력 (가입)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _isProcessing
                          ? const SizedBox.shrink()
                          : ElevatedButton(
                              onPressed: _joinGroup,
                              child: const Text("그룹 참여"),
                            ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
