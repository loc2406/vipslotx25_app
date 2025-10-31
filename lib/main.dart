import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'services/games_service.dart';

@pragma('vm:entry-point')
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("🔥 overlayMain() được gọi!");

  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: OverlayWidget()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloudNest.vn',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = true;

  Timer? _gameRotationTimer;
  double _screenHeight = 400;
  double _screenWidth = 800;
  double _pixelRatio = 1.0;

  bool _isOverlayProcessing = false;
  Timer? _aliveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _closeOverlayIfOpen();
    _checkAndRequestOverlayPermission();
    // _fetchGame();
    _setupWebView();
  }

  void _setupWebView() {
    const String yourWebsiteUrl = 'https://toolhack999.net';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          // (Bạn đã bỏ trống, giữ nguyên)
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) => setState(() => _isLoading = true),
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _injectJavaScript();
          },
          onWebResourceError: (WebResourceError error) {},
        ),
      )
      ..loadRequest(Uri.parse(yourWebsiteUrl));
  }

  // Kiểm tra và tự động xin quyền overlay
  Future<void> _checkAndRequestOverlayPermission() async {
    try {
      final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
      if (hasPermission != true) {
        debugPrint("⚠️ Chưa có quyền overlay, đang yêu cầu quyền...");
        await FlutterOverlayWindow.requestPermission();
      } else {
        debugPrint("✅ Đã có quyền overlay");
      }
    } catch (e) {
      debugPrint("❌ Lỗi khi kiểm tra quyền overlay: $e");
    }
  }

  Future<void> _closeOverlayIfOpen() async {
    if (_isOverlayProcessing) {
      debugPrint("Lỗi Race: Bỏ qua lệnh ĐÓNG vì đang xử lý...");
      return;
    }
    _isOverlayProcessing = true;
    debugPrint("Lấy khóa để ĐÓNG overlay");

    try {
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive == true) {
        debugPrint("🔴 Đóng overlay vì app đang mở");
        await FlutterOverlayWindow.closeOverlay();

        // === THÊM DELAY ĐỂ OS "THỞ" ===
        // Buộc "khóa" giữ lâu hơn 500ms để OS hủy service
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint("Lỗi khi đóng overlay: $e");
    } finally {
      _isOverlayProcessing = false;
      debugPrint("Trả khóa sau khi ĐÓNG (và delay)");
    }
  }

  Future<void> _injectJavaScript() async {
    try {
      await _controller.runJavaScript('''
        // Tạo helper function để website có thể gọi
        window.sendToFlutter = function(message) {
          if (window.FlutterChannel) {
            FlutterChannel.postMessage(message);
            console.log('✅ Sent to Flutter:', message);
          } else {
            console.error('❌ FlutterChannel not found!');
          }
        };
        
        // Thông báo rằng Flutter đã sẵn sàng
        console.log('🚀 Flutter Channel is ready!');
        console.log('📱 Use: sendToFlutter("your message") to send data to Flutter app');
       
      ''');

      debugPrint("✅ Đã inject JavaScript vào WebView");
    } catch (e) {
      debugPrint("❌ Lỗi khi inject JavaScript: $e");
    }
  }

  Future<void> _updateOverlayWithRandomGame() async {
    try {
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive != true) {
        _gameRotationTimer?.cancel();
        debugPrint("🔄 Overlay không hoạt động, dừng vòng lặp update.");
        return;
      }

      debugPrint("Đang fetch game MỚI cho vòng lặp 2 phút...");
      final Game? newGame = await GamesService.fetchRandomGame();

      if (newGame != null) {
        await FlutterOverlayWindow.shareData({
          'name': newGame.name,
          'image': newGame.fullGameImageUrl,
          'ti_le': newGame.tiLe.toString(),
        });
        debugPrint("✅ Đã gửi game MỚI: ${newGame.name}");
      } else {
        debugPrint("⚠️ Không fetch được game mới, sẽ thử lại sau 2 phút.");
      }
    } catch (e) {
      debugPrint("❌ Lỗi trong _updateOverlayWithRandomGame: $e");
    } finally {
      _gameRotationTimer?.cancel();
      _gameRotationTimer = Timer(
        const Duration(seconds: 120),
        _updateOverlayWithRandomGame,
      );
    }
  }

  void _startAliveTimer() {
    _aliveTimer?.cancel();
    _aliveTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        if (await FlutterOverlayWindow.isActive() == true) {
          // Gửi "nhịp tim" qua kênh giao tiếp duy nhất
          await FlutterOverlayWindow.shareData({'type': 'heartbeat'});
          debugPrint("💓 App sent heartbeat");
        } else {
          timer.cancel(); // Overlay đã bị đóng, dừng gửi
        }
      } catch (e) {
        // Lỗi (ví dụ: overlay đã bị crash), dừng gửi
        debugPrint("❌ Lỗi khi gửi heartbeat, có thể overlay đã chết: $e");
        timer.cancel();
      }
    });
    debugPrint("🟢 Started alive timer");
  }

  void _stopAliveTimer() {
    _aliveTimer?.cancel();
    _aliveTimer = null;
    debugPrint("🔴 Stopped alive timer");
  }

  @override
  Widget build(BuildContext context) {
    _screenHeight = MediaQuery.sizeOf(context).height;
    _screenWidth = MediaQuery.sizeOf(context).width;
    _pixelRatio = MediaQuery.of(context).devicePixelRatio;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gameRotationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _stopAliveTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    debugPrint("📱 App lifecycle: $state");

    if (state == AppLifecycleState.paused) {
      debugPrint("🟡 App paused - Hiển thị overlay");
      await _showOverlayAndSendData();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("🟢 App resumed - Đóng overlay");
      _stopAliveTimer();
      _gameRotationTimer?.cancel();
      await _closeOverlayIfOpen();
    } else if (state == AppLifecycleState.detached) {
      debugPrint("🔴 App detached - App đang bị kill");
      _stopAliveTimer();


      try {
        if (await FlutterOverlayWindow.isActive() == true) {
          await FlutterOverlayWindow.closeOverlay();
          debugPrint("🧹 Đã đóng overlay khi app detached");
        }
      } catch (e) {
        debugPrint("❌ Lỗi khi đóng overlay lúc detached: $e");
      }
    }
  }

  // Hiển thị overlay khi app vào nền
  Future<void> _showOverlayAndSendData() async {
    // 1. CHỜ KHÓA
    while (_isOverlayProcessing) {
      debugPrint("Lỗi Race: Đang chờ lệnh ĐÓNG hoàn thành...");
      await Future.delayed(const Duration(milliseconds: 100));
    }
    // 2. LẤY KHÓA
    _isOverlayProcessing = true;
    debugPrint("Lấy khóa để MỞ overlay");

    try {
      final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
      if (hasPermission != true) {
        debugPrint("⚠️ Chưa có quyền overlay. Hãy cấp quyền trước!");
        _isOverlayProcessing = false; // Trả khóa
        return;
      }
      debugPrint("✅ Đã có quyền overlay");

      final isActive = await FlutterOverlayWindow.isActive();

      if (isActive != true) {
        debugPrint("🚀 Đang mở overlay...");
        final double logicalHeight = _screenHeight * 0.18;
        final double logicalWidth = _screenWidth * 0.6;
        final int physicalHeight = (logicalHeight * _pixelRatio).toInt();
        final int physicalWidth = (logicalWidth * _pixelRatio).toInt();

        await FlutterOverlayWindow.showOverlay(
          height: physicalHeight,
          width: physicalWidth,
          alignment: OverlayAlignment.center,
          enableDrag: true,
          positionGravity: PositionGravity.auto,
          flag: OverlayFlag.defaultFlag,
        );
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        debugPrint("🔄 Overlay đã hiển thị. Bỏ qua bước tạo.");
      }

      debugPrint("Đang fetch game LẦN ĐẦU khi mở overlay...");
      final Game? firstGame = await GamesService.fetchRandomGame();

      if (firstGame != null) {
        await FlutterOverlayWindow.shareData({
          'name': firstGame.name,
          'image': firstGame.fullGameImageUrl,
          'ti_le': firstGame.tiLe.toString(),
        });
        debugPrint("✅ Gửi data game lên overlay: ${firstGame.name}");
      } else {
        await FlutterOverlayWindow.shareData({
          'name': 'Đang tìm...',
          'image': '',
          'ti_le': ' - ',
        });
      }

      _startAliveTimer();

      _gameRotationTimer?.cancel();
      _gameRotationTimer = Timer(
        const Duration(seconds: 120),
        _updateOverlayWithRandomGame,
      );
      debugPrint("▶️ Đã khởi động timer 2 phút");
    } catch (e) {
      debugPrint("❌ Lỗi khi hiển thị overlay: $e");
    } finally {
      // 3. TRẢ KHÓA
      _isOverlayProcessing = false;
      debugPrint("Trả khóa sau khi MỞ");
    }
  }
}

// ============================================
// OVERLAY WIDGET - Hiển thị khi app ở nền
// ============================================

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
                  flex: 8,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      //Robot
                      Expanded(
                        flex: 5,
                        child: SizedBox(
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
                      ),
                      // Main content
                      Expanded(
                        flex: 5,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Image anh
                            SizedBox(
                              width: gameImageSize,
                              height: gameImageSize,
                              child: ClipOval(
                                child: Image.network(
                                  _gameImage,
                                  width: gameImageSize,
                                  height: gameImageSize,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) {
                                        return Icon(
                                          Icons.error_outline,
                                          color: Colors.green,
                                          size: gameImageSize,
                                        );
                                      },
                                ),
                              ),
                            ),

                            Container(
                              width: gameImageSize,
                              height: gameImageSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                              ),
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
                                      _gameTiLe,
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
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _gameName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: mainFontSize, // Cố định
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}