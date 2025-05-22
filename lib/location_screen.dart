import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationScreen extends StatefulWidget {
  final String groupId;
  const LocationScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  Position? _currentPosition;
  Position? _partnerPosition;
  String? _error;
  bool _isLoading = false;
  double? _distanceKm;

  // 현재 위치 업데이트를 위한 스트림 (group별로 저장)
  Stream<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _fetchPartnerLocation();
  }

  // 현재 사용자 위치를 "groups/{groupId}/members/{uid}/location"에 업데이트
  void _startLocationUpdates() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
    _positionStream!.listen((Position position) async {
      final String currentUid =
          FirebaseAuth.instance.currentUser?.uid ?? "defaultUser";
      DatabaseReference locationRef = FirebaseDatabase.instance
          .ref("groups/${widget.groupId}/members/$currentUid/location");
      await locationRef.set({
        "lat": position.latitude,
        "lng": position.longitude,
        "timestamp": ServerValue.timestamp,
      });
      setState(() {
        _currentPosition = position;
      });
      // 위치 업데이트 후 파트너 위치도 재확인
      _fetchPartnerLocation();
    });
  }

  // 그룹 멤버 중 현재 사용자와 다른(파트너) 사용자의 위치를 가져오기
  Future<void> _fetchPartnerLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final String currentUid =
          FirebaseAuth.instance.currentUser?.uid ?? "defaultUser";
      // 그룹의 멤버 목록 가져오기 ("groups/{groupId}/members")
      DatabaseReference membersRef =
          FirebaseDatabase.instance.ref("groups/${widget.groupId}/members");
      DataSnapshot membersSnapshot = await membersRef.get();
      if (!membersSnapshot.exists || membersSnapshot.value == null) {
        throw Exception("그룹 멤버 정보를 불러올 수 없습니다.");
      }
      Map members = membersSnapshot.value as Map;
      String? partnerUid;
      // 멤버 중 현재 uid와 다른 사용자 uid를 선택
      members.forEach((key, value) {
        if (value.toString() != currentUid) {
          partnerUid = value.toString();
        }
      });
      if (partnerUid == null) {
        throw Exception("파트너의 위치 정보를 가져올 수 없습니다.");
      }
      // 파트너 위치는 "groups/{groupId}/members/{partnerUid}/location"에서 읽음
      DatabaseReference partnerLocationRef = FirebaseDatabase.instance
          .ref("groups/${widget.groupId}/members/$partnerUid/location");
      DataSnapshot partnerLocationSnapshot = await partnerLocationRef.get();
      if (!partnerLocationSnapshot.exists ||
          partnerLocationSnapshot.value == null) {
        throw Exception("파트너 위치 정보가 없습니다.");
      }
      Map partnerData = partnerLocationSnapshot.value as Map;
      double partnerLat = double.parse(partnerData["lat"].toString());
      double partnerLng = double.parse(partnerData["lng"].toString());
      Position partner = Position(
        latitude: partnerLat,
        longitude: partnerLng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      // _currentPosition이 업데이트되었을 때만 거리 계산
      if (_currentPosition != null) {
        double distance = _calculateHaversine(_currentPosition!.latitude,
            _currentPosition!.longitude, partner.latitude, partner.longitude);
        setState(() {
          _partnerPosition = partner;
          _distanceKm = distance;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Haversine 공식으로 두 좌표 간 거리를 km 단위로 계산
  double _calculateHaversine(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // 지구 반지름 (km)
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("내 위치 및 그룹 거리 확인")),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _error != null
                ? Text("오류: $_error")
                : _currentPosition != null && _partnerPosition != null
                    ? DistanceDisplayWidget(
                        currentProfileLabel: "나",
                        partnerProfileLabel: "상대",
                        distanceKm: _distanceKm ?? 0,
                      )
                    : const Text("위치 정보를 가져올 수 없습니다."),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchPartnerLocation,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

/// 두 사용자 프로필 정보를 기본 텍스트로 표시하고, 그 사이에 포물선을 그리는 위젯
class DistanceDisplayWidget extends StatelessWidget {
  final String currentProfileLabel;
  final String partnerProfileLabel;
  final double distanceKm;
  const DistanceDisplayWidget({
    super.key,
    required this.currentProfileLabel,
    required this.partnerProfileLabel,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 포물선 그리기
              Positioned.fill(
                child: CustomPaint(
                  painter: DistancePainter(),
                ),
              ),
              // 왼쪽 사용자 표시 (기본 텍스트)
              Align(
                alignment: Alignment.centerLeft,
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue,
                  child: Text(
                    currentProfileLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              // 오른쪽 사용자 표시 (기본 텍스트)
              Align(
                alignment: Alignment.centerRight,
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.red,
                  child: Text(
                    partnerProfileLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "두 사용자는 약 ${distanceKm.toStringAsFixed(2)} km 떨어져 있습니다.",
          style: const TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// CustomPainter를 사용하여 포물선(Quadratic Bezier curve) 그리기
class DistancePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path();
    // 왼쪽 이미지 중심: (30, size.height/2), 오른쪽 이미지 중심: (size.width - 30, size.height/2)
    path.moveTo(30, size.height / 2);
    // 제어점: 화면 중앙 상단 (size.width/2, 0)
    path.quadraticBezierTo(size.width / 2, 0, size.width - 30, size.height / 2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
