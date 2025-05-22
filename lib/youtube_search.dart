import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'youtube_player_screen.dart';
import 'custom_recommendations.dart'; // 맞춤 추천 스크린 파일 import

class YouTubeSearchScreen extends StatefulWidget {
  final String groupId;
  const YouTubeSearchScreen({Key? key, required this.groupId})
      : super(key: key);

  @override
  State<YouTubeSearchScreen> createState() => _YouTubeSearchScreenState();
}

class _YouTubeSearchScreenState extends State<YouTubeSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List videos = [];
  String? nextPageToken;
  final String apiKey =
      "AIzaSyCld6cjNMQUg4UGljOiTSFM8242CUyz3vQ"; // 본인 API 키 입력
  bool isLoading = false;
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    fetchRecommendedVideos();
  }

  Future<void> searchVideos(String query, {bool loadMore = false}) async {
    if (isLoading) return;
    setState(() {
      isLoading = true;
      isSearching = true;
    });
    String url =
        "https://www.googleapis.com/youtube/v3/search?part=snippet&q=$query&type=video&maxResults=50&key=$apiKey";
    if (loadMore && nextPageToken != null) {
      url += "&pageToken=$nextPageToken";
    }
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        if (!loadMore) {
          videos = data['items'];
        } else {
          videos.addAll(data['items']);
        }
        nextPageToken = data['nextPageToken'];
      });
    } else {
      throw Exception('YouTube 검색 실패');
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchRecommendedVideos() async {
    setState(() {
      isLoading = true;
      isSearching = false;
    });
    final String url =
        "https://www.googleapis.com/youtube/v3/videos?part=snippet&chart=mostPopular&regionCode=KR&maxResults=50&key=$apiKey";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        videos = data['items'];
      });
    } else {
      throw Exception('추천 영상 가져오기 실패');
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("YouTube")),
      body: Column(
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: "유튜브 동영상 검색",
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => searchVideos(_controller.text),
              ),
            ),
          ),
          if (!isSearching)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: fetchRecommendedVideos,
                child: const Text("일반 추천 영상 보기"),
              ),
            ),
          Expanded(
            child: NotificationListener<ScrollEndNotification>(
              onNotification: (scrollNotification) {
                if (scrollNotification.metrics.pixels ==
                    scrollNotification.metrics.maxScrollExtent) {
                  if (isSearching) {
                    searchVideos(_controller.text, loadMore: true);
                  }
                }
                return true;
              },
              child: ListView.builder(
                itemCount: videos.length + (isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == videos.length) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListTile(
                    leading: Image.network(
                      videos[index]['snippet']['thumbnails']['default']['url'],
                    ),
                    title: Text(videos[index]['snippet']['title']),
                    onTap: () async {
                      final videoId = isSearching
                          ? videos[index]['id']['videoId']
                          : videos[index]['id'];
                      final groupRef = FirebaseDatabase.instance
                          .ref("groups/${widget.groupId}/youtubeInfo");
                      await groupRef.set({
                        "videoId": videoId,
                        "playback": 0,
                        "isPlaying": false,
                      });
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
            ),
          ),
        ],
      ),
    );
  }
}
