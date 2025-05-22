import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

class YouTubePlayerScreen extends StatefulWidget {
  final String groupId;
  const YouTubePlayerScreen({Key? key, required this.groupId})
      : super(key: key);

  @override
  State<YouTubePlayerScreen> createState() => _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState extends State<YouTubePlayerScreen> {
  late YoutubePlayerController _controller;
  late DatabaseReference _youtubeRef;

  String _videoId = "";
  bool _isPlaying = false;
  int _playback = 0;
  bool _isControllerReady = true;

  // 각 클라이언트의 고유 ID (예시: 현재 시간 기반)
  final String _clientId = DateTime.now().millisecondsSinceEpoch.toString();
  // Firebase에 저장된 마스터 클라이언트 ID (즉, playback 업데이트 담당)
  String _masterId = "";

  @override
  void initState() {
    super.initState();
    _youtubeRef =
        FirebaseDatabase.instance.ref("groups/${widget.groupId}/youtubeInfo");
    _initYouTube();
    // master 필드 리스너 추가: 언제든지 마스터 클라이언트 ID를 업데이트
    _youtubeRef.child("master").onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _masterId = event.snapshot.value as String;
        });
      }
    });
  }

  Future<void> _initYouTube() async {
    final snapshot = await _youtubeRef.get();
    debugPrint("Firebase snapshot: ${snapshot.value}");
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      _videoId = data["videoId"] ?? "";
      _playback = data["playback"] ?? 0;
      _isPlaying = data["isPlaying"] ?? false;
      debugPrint(
          "불러온 videoId: $_videoId, playback: $_playback, isPlaying: $_isPlaying");
      // 만약 master 필드가 없다면 현재 클라이언트가 마스터로 지정
      if (data["master"] == null || (data["master"] as String).isEmpty) {
        await _youtubeRef.child("master").set(_clientId);
        _masterId = _clientId;
        debugPrint("master가 설정되지 않아, 현재 클라이언트($_clientId)가 master로 지정됨");
      }
    } else {
      debugPrint("Firebase snapshot이 존재하지 않습니다.");
    }

    // 컨트롤러 초기화: videoId가 비어있어도 생성(나중에 업데이트됨)
    _controller = YoutubePlayerController(
      initialVideoId: _videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        enableCaption: false,
        forceHD: false,
      ),
    )..addListener(() {
        if (_controller.value.isReady && !_isControllerReady) {
          _isControllerReady = true;
          if (_playback > 0) {
            _controller.seekTo(Duration(seconds: _playback));
          }
          if (_isPlaying) {
            _controller.play();
          }
        }
        // 사용자가 직접 재생/일시정지한 경우 Firebase 업데이트
        if (_isControllerReady) {
          if (_controller.value.isPlaying) {
            _youtubeRef.child("isPlaying").set(true);
          } else {
            _youtubeRef.child("isPlaying").set(false);
          }
          // 오직 마스터 클라이언트에서만 playback 업데이트
          if (_masterId == _clientId) {
            _youtubeRef
                .child("playback")
                .set(_controller.value.position.inSeconds);
          }
        }
        if (_controller.value.isFullScreen) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
        setState(() {});
      });

    setState(() {});

    _youtubeRef.child("videoId").onValue.listen((event) {
      try {
        debugPrint("videoId 리스너: ${event.snapshot.value}");
        if (event.snapshot.value != null && _isControllerReady) {
          final newId = event.snapshot.value as String;
          if (newId != _videoId) {
            _videoId = newId;
            debugPrint("새로운 videoId: $_videoId");
            _controller.load(newId);
          }
        }
      } catch (e) {
        debugPrint("videoId 리스너 에러: $e");
      }
    });

    _youtubeRef.child("playback").onValue.listen((event) {
      try {
        if (event.snapshot.value != null && _isControllerReady) {
          final newPlayback = event.snapshot.value as int;
          final currentPos = _controller.value.position.inSeconds;
          if ((newPlayback - currentPos).abs() > 2) {
            _controller.seekTo(Duration(seconds: newPlayback));
          }
        }
      } catch (e) {
        debugPrint("playback 리스너 에러: $e");
      }
    });

    _youtubeRef.child("isPlaying").onValue.listen((event) {
      try {
        if (event.snapshot.value != null && _isControllerReady) {
          final playing = event.snapshot.value as bool;
          if (!playing && _controller.value.isPlaying) {
            debugPrint("리스너: 다른 클라이언트에서 일시정지 명령 감지");
            _controller.pause();
          } else if (playing && !_controller.value.isPlaying) {
            debugPrint("리스너: 다른 클라이언트에서 재생 명령 감지");
            _controller.play();
          }
        }
      } catch (e) {
        debugPrint("isPlaying 리스너 에러: $e");
      }
    });
  }

  @override
  void dispose() {
    _youtubeRef.remove();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 컨트롤러 준비가 안됐으면 로딩 표시
    if (!_isControllerReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_videoId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("영상이 선택되지 않았습니다.")),
      );
    }
    final bool isFullScreen = _controller.value.isFullScreen;
    return Scaffold(
      appBar: isFullScreen ? null : AppBar(title: const Text("공동 시청")),
      body: Column(
        children: [
          Expanded(
            child: YoutubePlayer(controller: _controller),
          ),
          if (!isFullScreen)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    // 일단 isPlaying 값을 false로 업데이트
                    await _youtubeRef.child("isPlaying").set(false);
                    // 1초 동안 대기 (1초 동안 재생 상태가 false임을 유지)
                    await Future.delayed(const Duration(seconds: 1));
                    // (여기서 추가 동작이 필요하지 않으면 그대로 유지)
                  },
                  child: const Text("일시정지"),
                ),
                ElevatedButton(
                  onPressed: () => _youtubeRef.child("isPlaying").set(true),
                  child: const Text("재생"),
                ),
                ElevatedButton(
                  onPressed: () => _controller.toggleFullScreenMode(),
                  child: const Text("전체화면"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _youtubeRef.remove();
                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text("영상 종료"),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
