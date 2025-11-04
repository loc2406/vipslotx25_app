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
  StreamSubscription? _subscription;

  Timer? _watchdogTimer;
  Timer? _timeUpdateTimer;
  int _lastHeartbeatTime = DateTime.now().millisecondsSinceEpoch;
  static const int _appDeadThresholdMillis = 3000;
  bool _isAppAlive = true;

  // Biến lưu thông tin game
  String _gameName = '';
  String _gameImage = '';
  String _gameTiLe = '0';
  String _gameCountdown = '';
  String _startTime = '';
  String _endTime = '';
  String _vong = '';

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

      // Xử lý game_info_update từ app
      if (data is Map && data['type'] == 'game_info_update') {
        final gameInfo = data['gameInfo'] as Map<String, dynamic>?;
        setState(() {
          if (gameInfo != null) {
            _gameName = gameInfo['gameName']?.toString() ?? '';
            _gameImage = gameInfo['gameImageUrl']?.toString() ?? '';
            // Lấy tỉ lệ từ winRate (có thể là "75%" hoặc "75")
            final winRateStr = gameInfo['winRate']?.toString() ?? '0%';
            _gameTiLe = winRateStr.replaceAll('%', '').trim();
            _gameCountdown = gameInfo['countdown']?.toString() ?? '';
            _startTime = gameInfo['startTime']?.toString() ?? '';
            _endTime = gameInfo['endTime']?.toString() ?? '';
            _vong = gameInfo['vong']?.toString() ?? '';
          } else {
            _gameName = '';
            _gameImage = '';
            _gameTiLe = '0';
            _gameCountdown = '';
            _startTime = '';
            _endTime = '';
            _vong = '';
          }
        });
        debugPrint(
          '🎮 Overlay nhận game_info_update: GameName=$_gameName, Tỉ lệ=$_gameTiLe%, StartTime=$_startTime, EndTime=$_endTime, Vòng=$_vong, ImageUrl=$_gameImage',
        );
        return;
      }

      setState(() {
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
      return Container(color: Colors.transparent, width: 0, height: 0);
    }

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
                              size: robotIconSize,
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
                                    horizontal: overlayWidth * 0.03,
                                    vertical: overlayHeight * 0.03,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade800,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$_gameTiLe%',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: mainFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            _gameImage.isNotEmpty
                                ? Container(
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
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.error_outline,
                                      color: Colors.green,
                                      size: gameImageSize,
                                    );
                                  },
                                ),
                              ),
                            )
                                : Container(
                              width: gameImageSize,
                              height: gameImageSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.error_outline,
                                color: Colors.green,
                                size: gameImageSize,
                              ),
                            ),
                            // Game name
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
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
                                    fontSize: mainFontSize,
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
                        _startTime.isNotEmpty ? _startTime : '--:--',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: mainFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _endTime.isNotEmpty ? _endTime : '--:--',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: mainFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    _vong.isNotEmpty ? 'Số vòng: $_vong' : 'Số vòng: --',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: mainFontSize,
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
}