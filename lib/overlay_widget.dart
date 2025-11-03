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
  int _lastHeartbeatTime = DateTime.now().millisecondsSinceEpoch;
  static const int _appDeadThresholdMillis = 3000;
  bool _isAppAlive = true;
  String? _roomTableName;
  String? _roomPredict;
  String? _roomWinrate;
  bool _hasRoomInfo = false;
  bool _isOnRoomPage = false;

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

      if (data is Map && data['type'] == 'room_info_update') {
        final roomInfo = data['roomInfo'] as Map<String, dynamic>?;
        final isOnRoomPage = data['isOnRoomPage'] as bool? ?? false;
        setState(() {
          _isOnRoomPage = isOnRoomPage;
          if (roomInfo != null) {
            _roomTableName = roomInfo['tableName']?.toString();
            _roomPredict = roomInfo['predict']?.toString();
            _roomWinrate = roomInfo['winrate']?.toString();
            _hasRoomInfo = true;
          }
        });
        debugPrint(
          '📊 Overlay nhận room_info_update: isOnRoomPage=$isOnRoomPage, Bàn=$_roomTableName, Dự đoán=$_roomPredict, Tỉ lệ=$_roomWinrate',
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

  String getTableName() {
    if (_hasRoomInfo && _roomTableName != null && _roomTableName!.isNotEmpty) {
      return 'Bàn: $_roomTableName';
    }
    return 'Không lấy được tên bàn!';
  }

  String getPredict() {
    if (_hasRoomInfo && _roomPredict != null && _roomPredict!.isNotEmpty) {
      return _roomPredict!;
    }
    return 'Không lấy được dự đoán!';
  }

  String getWinrate() {
    if (_hasRoomInfo && _roomWinrate != null && _roomWinrate!.isNotEmpty) {
      return _roomWinrate!;
    }
    return 'Không lấy được tỉ lệ!';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAppAlive) {
      return Container(color: Colors.transparent, width: 0, height: 0);
    }

    if (!_isOnRoomPage && !_hasRoomInfo) {
      return Material(
        color: Colors.transparent,

        child: LayoutBuilder(
          builder: (context, constraints) {
            final double overlayWidth = constraints.maxWidth;
            final double overlayHeight = constraints.maxHeight;
            final double mainFontSize = (overlayHeight * 0.12).clamp(
              14.0,
              18.0,
            );
            return Container(
              height: overlayHeight,
              width: overlayWidth,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade700, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Bạn chưa chọn bàn!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: mainFontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    final String tableName = getTableName();
    final String predict = getPredict();
    final String winrate = getWinrate();

    debugPrint('===Table name: $tableName, predict: $predict, wỉnate: $winrate');

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
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade700, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Bang
                      Text(
                        tableName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: mainFontSize, // Cố định
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                              color: Colors.cyan,
                              size: robotIconSize, // Cố định
                            );
                          },
                        ),
                      ),
                      // Main content
                      SizedBox(
                        width: gameImageSize,
                        height: gameImageSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              'assets/forecast.png',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                            ClipOval(
                              child: Image.asset(
                                width: gameImageSize - 10,
                                height: gameImageSize - 10,
                                predict == 'B'
                                    ? 'assets/symbol_b.png'
                                    : 'assets/symbol_p.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    'assets/symbol_b.png',
                                    fit: BoxFit.cover,
                                    width: gameImageSize - 10,
                                    height: gameImageSize - 10,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        width: gameImageSize,
                        height: gameImageSize,
                        decoration: BoxDecoration(shape: BoxShape.circle),
                        child: Stack(
                          children: [
                            Image.asset(
                              'assets/forecast_percent.png',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                            Center(
                              child: Text(
                                winrate,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: mainFontSize, // Cố định
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
