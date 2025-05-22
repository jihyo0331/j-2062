import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'youtube_player_screen.dart';

class CustomRecommendationsScreen extends StatefulWidget {
  final String groupId;
  const CustomRecommendationsScreen({Key? key, required this.groupId})
      : super(key: key);

  @override
  State<CustomRecommendationsScreen> createState() =>
      _CustomRecommendationsScreenState();
}

class _CustomRecommendationsScreenState
    extends State<CustomRecommendationsScreen> {
  final String apiKey = "YOUR_YOUTUBE_API_KEY"; // 본인의 API 키 입력
  List videos = [];
  bool isLoading = false;
  String? lastWatchedVideoId;

  @override
  void initState() {
    super.initState();
    _loadLastWatchedVideo();
  }

  // 그룹의 watchHistory 경로에서 마지막 시청 영상(videoId)을 불러옵니다.
  Future<void> _loadLastWatchedVideo() async {
    DatabaseReference historyRef =
        FirebaseDatabase.instance.ref("groups/${widget.groupId}/watchHistory");
    // 마지막 시청 기록 1개만 불러오기 (timestamp 정렬 필요 시 추가)
    final snapshot = await historyRef.limitToLast(1).get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      // 데이터 값 중 마지막 엔트리를 가져옵니다.
      final lastEntry = data.values.last;
      setState(() {
        lastWatchedVideoId = lastEntry["videoId"] ?? "";
      });
      if (lastWatchedVideoId != null && lastWatchedVideoId!.isNotEmpty) {
        _fetchRecommendations(lastWatchedVideoId!);
      }
    } else {
      setState(() {
        lastWatchedVideoId = "";
      });
    }
  }

  // 마지막 시청 영상(videoId)을 바탕으로 관련 추천 영상들을 불러옵니다.
  Future<void> _fetchRecommendations(String videoId) async {
    setState(() {
      isLoading = true;
    });
    // YouTube API의 relatedToVideoId 파라미터 사용
    final String url =
        "https://www.googleapis.com/youtube/v3/search?part=snippet&relatedToVideoId=$videoId&type=video&maxResults=25&key=$apiKey";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        videos = data["items"];
      });
    } else {
      throw Exception("추천 영상 가져오기 실패");
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("맞춤 추천 영상")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : videos.isEmpty
              ? const Center(child: Text("추천 영상을 불러올 수 없습니다."))
              : ListView.builder(
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    final videoId = video["id"]["videoId"];
                    return ListTile(
                      leading: Image.network(
                        video["snippet"]["thumbnails"]["default"]["url"],
                      ),
                      title: Text(video["snippet"]["title"]),
                      onTap: () async {
                        // 선택한 영상의 videoId를 그룹의 youtubeInfo에 저장
                        final groupRef = FirebaseDatabase.instance
                            .ref("groups/${widget.groupId}/youtubeInfo");
                        await groupRef.set({
                          "videoId": videoId,
                          "playback": 0,
                          "isPlaying": true,
                        });
                        // 추천 영상 선택 후 YouTubePlayerScreen으로 이동하여 재생
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                YouTubePlayerScreen(groupId: widget.groupId),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
