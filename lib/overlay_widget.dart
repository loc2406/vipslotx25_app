import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  String _gameName = "Đang tìm...";
  String _gameImage = "";
  String _gameTiLe = "0";

  StreamSubscription? _subscription;
  final Random _random = Random();

  Timer? _watchdogTimer; // "Chó canh gác"
  int _lastHeartbeatTime = DateTime.now().millisecondsSinceEpoch;
  static const int _appDeadThresholdMillis = 3000; // Chờ 3 giây
  bool _isAppAlive = true; // Trạng thái để ẨN/HIỆN

  @override
  void initState() {
    super.initState();
    debugPrint("🟢 OverlayWidget initState được gọi");

    _subscription = FlutterOverlayWindow.overlayListener.listen((data) async {
      if (!mounted) return;

      _lastHeartbeatTime = DateTime.now().millisecondsSinceEpoch;

      if (_watchdogTimer == null || !_watchdogTimer!.isActive) {
        _startWatchdogTimer();
        debugPrint("🔥 Watchdog đã được kích hoạt.");
      }

      // 3. Xử lý data
      if (data is Map && data['type'] == 'heartbeat') {
        debugPrint("💓 Overlay received heartbeat");

        if (!_isAppAlive) {
          setState(() {
            _isAppAlive = true;
          });
        }

        try {
          await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
          debugPrint("✅ Đã cập nhật cờ (flag) thành 'defaultFlag'");
        } catch (e) {
          debugPrint("❌ Lỗi khi cập nhật cờ (flag) về 'defaultFlag': $e");
        }
        return;
      }

      debugPrint("🟢 Nhận data: $data");
      setState(() {
        _gameName = data['name'] ?? 'Đang tìm...';
        _gameImage = data['image'] ?? '';
        _gameTiLe = data['ti_le'] ?? '0';
        _isAppAlive = true;
      });
    });
  }

  void _startWatchdogTimer() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final timeDiff = now - _lastHeartbeatTime;

      debugPrint("🔍 Watchdog check: Time since last heartbeat: ${timeDiff}ms");

      if (timeDiff > _appDeadThresholdMillis) {
        // App đã chết
        if (_isAppAlive) {
          debugPrint("💀 App đã chết (không nhận được heartbeat) - ẨN overlay");
          try {
            await FlutterOverlayWindow.updateFlag(OverlayFlag.clickThrough);
            debugPrint("✅ Đã cập nhật cờ (flag) thành 'clickThrough'");
          } catch (e) {
            debugPrint("❌ Lỗi khi cập nhật cờ (flag): $e");
          }
          if (mounted) {
            setState(() {
              _isAppAlive = false;
            });
          }
          try {
            await FlutterOverlayWindow.closeOverlay();
            debugPrint("🧹 Đã đóng overlay do app không còn heartbeat");
          } catch (e) {
            debugPrint("❌ Lỗi khi đóng overlay trong watchdog: $e");
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _watchdogTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAppAlive) {
      // Khi app chết, trả về widget rỗng và trong suốt
      return Container(color: Colors.transparent, width: 0, height: 0);
    }

    final now = DateTime.now();

    final String currentTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    final int randomMinutes = _random.nextInt(6) + 5; // (0 đến 5) + 5 = 5 đến 10
    final futureTime = now.add(Duration(minutes: randomMinutes));
    final String formattedFutureTime =
        "${futureTime.hour.toString().padLeft(2, '0')}:${futureTime.minute.toString().padLeft(2, '0')}";

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double overlayWidth = constraints.maxWidth;
          final double overlayHeight = constraints.maxHeight;
          final double robotWidth = overlayWidth * 0.3;
          final double mainFontSize = (overlayHeight * 0.1).clamp(10.0, 12.0);
          final double gameImageSize = (overlayHeight * 0.3);
          final double robotIconSize = robotWidth * 0.8;

          return Container(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            padding: EdgeInsets.all(10),
            // Padding cố định
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade700, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  flex: 8,
                  child: Row(
                    children: [
                      //Robot
                      SizedBox(
                        width: robotWidth,
                        child: Image.asset(
                          'assets/overlay_robot.gif',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.android,
                              color: Colors.green,
                              size: robotIconSize, // Cố định
                            );
                          },
                        ),
                      ),
                      // Main content
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Ti le
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: overlayWidth * 0.03, // Tỉ lệ
                                    vertical: overlayHeight * 0.03, // Tỉ lệ
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade800,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$_gameTiLe%',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: mainFontSize, // Cố định
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            _gameImage.isNotEmpty ?  Container(
                              width: gameImageSize,
                              height: gameImageSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.green,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.5),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: ClipOval(
                                  child: Image.network(
                                    _gameImage,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) {
                                      return Icon(
                                        Icons.error_outline,
                                        color: Colors.green,
                                        size: gameImageSize, // Cố định
                                      );
                                    },
                                  )
                              ),
                            ) : Container(
                                width: gameImageSize,
                                height: gameImageSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.error_outline,
                                  color: Colors.green,
                                  size: gameImageSize, // Cố định
                                )
                            ),

                            // Game name
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8, // Cố định
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _gameName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: mainFontSize, // Cố định
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        currentTime,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: mainFontSize, // Cố định
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        formattedFutureTime,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: mainFontSize, // Cố định
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Số vòng: ${getRandomRound()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: mainFontSize, // Cố định
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int getRandomRound() {
    return _random.nextInt(120 - 50 + 1) + 50;
  }
}