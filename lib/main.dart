import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat.dart'; // 그룹 기능 적용 채팅 화면
import 'calendar.dart'; // 그룹 캘린더 화면
import 'profile.dart'; // 그룹 관리 기능이 추가된 프로필 화면
import 'youtube_search.dart'; // 그룹 기능 적용 유튜브 검색 화면
import 'youtube_player_screen.dart'; // 그룹 기능 적용 유튜브 플레이어 화면
import 'group_screen.dart'; // 그룹 화면
import 'location_screen.dart'; // 내 위치 확인 페이지
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 한영 전환

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('ko', 'KR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ko', 'KR'),
      ],
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 1;
  String _dDayText = "D-0";
  String? _savedGroupId; // 로컬에 저장된 그룹 ID

  @override
  void initState() {
    super.initState();
    _loadDDay();
    _loadGroupId();
  }

  Future<void> _loadDDay() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('couple_date');
    if (savedDate != null) {
      DateTime startDate = DateTime.parse(savedDate);
      int dDayCount = DateTime.now().difference(startDate).inDays + 1;
      setState(() {
        _dDayText = dDayCount >= 1 ? "D+$dDayCount" : "D$dDayCount";
      });
    }
  }

  Future<void> _loadGroupId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedGroupId = prefs.getString('group_id') ?? "";
    });
  }

  // 그룹이 없으면 NoGroupScreen을, 있으면 각 화면에 자동으로 전달
  String get currentGroupId => _savedGroupId ?? "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Image.asset(
                'assets/top_logo.png',
                height: 30,
              ),
            ),
            const Spacer(),
            Text(
              _dDayText,
              style: const TextStyle(color: Color(0xFF8CA1FD), fontSize: 16),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red, size: 30),
              onPressed: () async {
                await _authService.signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Color(0xFF8CA1FD), size: 35),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
              _loadDDay();
              _loadGroupId();
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // 그룹에 가입하지 않은 경우 NoGroupScreen을 표시
          currentGroupId.isEmpty
              ? const NoGroupScreen()
              : ChatScreen(groupId: currentGroupId),
          currentGroupId.isEmpty
              ? const NoGroupScreen()
              : HomeContent(groupId: currentGroupId),
          currentGroupId.isEmpty
              ? const NoGroupScreen()
              : GroupCalendarScreen(groupId: currentGroupId),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() {
          _selectedIndex = index;
        }),
        items: const [
          BottomNavigationBarItem(
              icon: ImageIcon(AssetImage('assets/chat.png')), label: '채팅'),
          BottomNavigationBarItem(
              icon: SizedBox(
                width: 45,
                height: 45,
                child: Image(image: AssetImage('assets/logo.png')),
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: ImageIcon(AssetImage('assets/calendar.png')), label: '캘린더'),
        ],
      ),
    );
  }
}

class NoGroupScreen extends StatelessWidget {
  const NoGroupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "먼저 프로필에서 그룹에 가입해 주세요.",
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final String groupId;
  const HomeContent({Key? key, required this.groupId}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    // 기존 그리드에 "내 위치 확인" 버튼 추가 (groupId 전달)
    final List<Map<String, dynamic>> gridItems = [
      {'title': '채팅', 'page': ChatScreen(groupId: groupId)},
      {'title': '캘린더', 'page': GroupCalendarScreen(groupId: groupId)},
      {'title': '프로필', 'page': const ProfileScreen()},
      {
        'title': '유튜브 같이보기',
        'page': YouTubeSearchScreen(groupId: groupId),
      },
      {
        'title': '내 위치 확인',
        'page': LocationScreen(groupId: groupId),
      },
    ];
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.2,
        ),
        itemCount: gridItems.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => gridItems[index]['page'],
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF8CA1FD),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Text(
                  gridItems[index]['title'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
