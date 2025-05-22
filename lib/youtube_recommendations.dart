import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'youtube_player_screen.dart';

class YouTubeRecommendations extends StatelessWidget {
  final String groupId;

  // 예시 더미 데이터: 실제 앱에서는 YouTube API를 이용해 데이터를 받아올 수 있습니다.
  final List<Map<String, String>> videos = [
    {"title": "영상 1", "videoId": "dQw4w9WgXcQ"},
    {"title": "영상 2", "videoId": "J---aiyznGQ"},
  ];

  YouTubeRecommendations({Key? key, required this.groupId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("추천 영상")),
      body: ListView.builder(
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final videoId = videos[index]["videoId"]!;
          return ListTile(
            title: Text(videos[index]["title"]!),
            onTap: () async {
              // 선택한 영상 정보를 그룹의 youtubeInfo 경로에 저장
              final groupRef =
                  FirebaseDatabase.instance.ref("groups/$groupId/youtubeInfo");
              await groupRef.set({
                "videoId": videoId,
                "playback": 0,
                "isPlaying": false,
              });
              // 저장 후 YouTubePlayerScreen으로 이동하여 영상 재생
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => YouTubePlayerScreen(groupId: groupId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
