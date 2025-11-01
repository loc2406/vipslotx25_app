import 'dart:async';
import 'dart:math';
import 'dart:convert'; // <-- Thêm thư viện này
import 'package:flutter/services.dart'; // <-- Thêm thư viện này

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'services/games_service.dart';

@pragma('vm:entry-point')
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// Overlay entry point - Theo documentation chính thức
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
      title: 'toolslotvip',
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

  List<Game> _hotGames = [];
  Timer? _gameRotationTimer;
  final Random _random = Random();
  double _screenHeight = 400;
  double _screenWidth = 800;
  double _pixelRatio = 1.0;
  static const int _maxRetries = 10;

  // === SỬA LỖI: Thêm các biến quản lý trạng thái ===
  bool _isOverlayProcessing = false; // "Khóa" chống Race Condition
  Timer? _aliveTimer; // "Nhịp tim" (Heartbeat)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _closeOverlayIfOpen();
    _checkAndRequestOverlayPermission();
    _fetchHotGames();
    _setupWebView();
  }

  void _setupWebView() {
    const String yourWebsiteUrl = 'https://toolvip2025.top';
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

  // === SỬA LỖI: Thêm "Khóa" (Lock) ===
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

  // Inject JavaScript vào website để có thể gửi data lên Flutter
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
        
        // VÍ DỤ: Tự động gửi data sau 3 giây (để test)
        setTimeout(function() {
          sendToFlutter('🎰 Slot game đang hot! Chơi ngay!');
        }, 3000);
      ''');

      debugPrint("✅ Đã inject JavaScript vào WebView");
    } catch (e) {
      debugPrint("❌ Lỗi khi inject JavaScript: $e");
    }
  }

  Future<void> _fetchHotGames() async {
    try {
      final games = await GamesService.fetchHotGames();

      setState(() {
        _hotGames = games;
      });

      if (_hotGames.isNotEmpty) {
        debugPrint("✅ Đã load ${_hotGames.length} games HOT (ti_le >= 70%)");
        // Bắt đầu rotation games
        _startGameRotation();
      } else {
        debugPrint("⚠️ Không có game nào có ti_le >= 70%");
      }
    } catch (e) {
      debugPrint("❌ Lỗi khi fetch hot games: $e");
    }
  }

  // === THÊM: Bắt đầu rotation games mỗi 5 giây ===
  void _startGameRotation() {
    _gameRotationTimer?.cancel();

    // Bắt đầu kiểm tra và gửi game (không cần Timer.periodic nữa)
    _updateOverlayWithRandomGame();
  }

  // === THÊM: Random 1 game và gửi lên overlay ===
  Future<void> _updateOverlayWithRandomGame({int retryCount = 0}) async {
    // 1. Kiểm tra các điều kiện dừng
    if (_hotGames.isEmpty) return; // Không có game
    if (retryCount >= _maxRetries) {
      debugPrint(
        "❌ Đã re-roll $_maxRetries lần, tất cả game đều không hợp lệ. Tạm dừng 2 phút.",
      );
      // Dừng lại và thử lại sau 2 phút
      _gameRotationTimer?.cancel();
      _gameRotationTimer = Timer(
        const Duration(seconds: 120),
        _updateOverlayWithRandomGame,
      );
      return;
    }

    try {
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive != true) {
        // Nếu overlay không bật, không làm gì cả
        return;
      }

      // 2. Lấy game ngẫu nhiên
      final randomGame = _hotGames[_random.nextInt(_hotGames.length)];

      // 3. KIỂM TRA TÍNH HỢP LỆ CỦA DATA
      //    (Giả định: "hợp lệ" là khi có cả 2 ảnh)
      final bool isDataValid =
          (randomGame.fullGameImageUrl.isNotEmpty) &&
          (randomGame.fullCateImageUrl.isNotEmpty);

      if (isDataValid) {
        debugPrint(
          "✅ Dữ liệu hợp lệ (thử lần ${retryCount + 1}). Gửi game: ${randomGame.name}",
        );
        await FlutterOverlayWindow.shareData({
          'name': randomGame.name,
          'image': randomGame.fullGameImageUrl,
          'cate_image': randomGame.fullCateImageUrl,
          'ti_le': randomGame.tiLe.toString(),
        });

        // Hẹn giờ lần chạy KẾ TIẾP (sau 2 phút)
        _gameRotationTimer?.cancel();
        _gameRotationTimer = Timer(
          const Duration(seconds: 120),
          _updateOverlayWithRandomGame,
        );
      } else {
        // 5. KHÔNG HỢP LỆ: Re-roll NGAY LẬP TỨC
        debugPrint(
          "⚠️ Dữ liệu KHÔNG hợp lệ (thử lần ${retryCount + 1}) cho game: ${randomGame.name}. Đang re-roll...",
        );

        // Chờ 50ms để tránh vòng lặp vô hạn quá nhanh
        await Future.delayed(const Duration(milliseconds: 50));
        // Gọi lại chính hàm này, tăng số lần thử
        _updateOverlayWithRandomGame(retryCount: retryCount + 1);
      }
    } catch (e) {
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
    _gameRotationTimer?.cancel(); // === THÊM: Hủy timer ===
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
      // Sẽ chờ nếu _closeOverlayIfOpen đang chạy
      await _showOverlayAndSendData();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("🟢 App resumed - Đóng overlay");
      _stopAliveTimer(); // Dừng nhịp tim
      // Sẽ bị hủy nếu _showOverlayAndSendData đang chạy
      await _closeOverlayIfOpen();
    } else if (state == AppLifecycleState.detached) {
      debugPrint("🔴 App detached - App đang bị kill");
      _stopAliveTimer(); // Dừng nhịp tim
      // Đảm bảo đóng overlay khi app bị kill/clear recent
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
        final double logicalHeight = _screenHeight * 0.35;
        final double logicalWidth = _screenWidth * 0.8;
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
        // SỬA LỖI DATA: Không gửi 'message' nữa
        debugPrint("🔄 Overlay đã hiển thị. Bỏ qua bước tạo.");
      }
      if (_hotGames.isNotEmpty) {
        final randomGame = _hotGames[_random.nextInt(_hotGames.length)];
        await FlutterOverlayWindow.shareData({
          'name': randomGame.name,
          'image': randomGame.fullGameImageUrl,
          'cate_image': randomGame.fullCateImageUrl,
          'ti_le': randomGame.tiLe.toString(),
        });
        debugPrint("✅ Gửi data game lên overlay: ${randomGame.name}");
      } else {
        await FlutterOverlayWindow.shareData({
          'name': 'VipSlotX25',
          'image': '',
          'cate_image': '',
          'ti_le': '100',
        });
      }
      // BẮT ĐẦU GỬI NHỊP TIM
      _startAliveTimer();
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
  String _gameName = "Đang tải...";
  String _gameImage = "";
  String _gameTiLe = "0";
  String _cateImage = "";
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

    // === SỬA LỖI: Cập nhật listener để xử lý "Nhịp tim" ===
    _subscription = FlutterOverlayWindow.overlayListener.listen((data) async {
      if (!mounted) return;

      // === SỬA LỖI LOGIC "NHỊP TIM" ===

      // 1. Dù là data gì, cứ nhận được là "reset" thời gian
      _lastHeartbeatTime = DateTime.now().millisecondsSinceEpoch;

      // 2. Kích hoạt Watchdog (nếu nó chưa chạy)
      if (_watchdogTimer == null || !_watchdogTimer!.isActive) {
        _startWatchdogTimer();
        debugPrint("🔥 Watchdog đã được kích hoạt.");
      }

      // 3. Xử lý data
      if (data is Map && data['type'] == 'heartbeat') {
        debugPrint("💓 Overlay received heartbeat");
        // Nếu app đang "chết" (vô hình), cho nó "sống" lại
        if (!_isAppAlive) {
          setState(() {
            _isAppAlive = true;
          });
        }
        // Khôi phục khả năng tương tác khi app "sống" lại
        try {
          await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
          debugPrint("✅ Đã cập nhật cờ (flag) thành 'defaultFlag'");
        } catch (e) {
          debugPrint("❌ Lỗi khi cập nhật cờ (flag) về 'defaultFlag': $e");
        }
        return;
      }

      // 4. Nếu là data game, cập nhật UI VÀ cho "sống" lại
      debugPrint("🟢 Nhận game data: $data");
      setState(() {
        _gameName = data['name'] ?? 'Unknown Game';
        _gameImage = data['image'] ?? '';
        _cateImage = data['cate_image'] ?? '';
        _gameTiLe = data['ti_le'] ?? '0';
        _isAppAlive = true; // <-- ĐẶT LẠI THÀNH TRUE
      });
    });
  }

  // BÊN TRONG _OverlayWidgetState

  void _startWatchdogTimer() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final timeDiff = now - _lastHeartbeatTime;

      debugPrint("🔍 Watchdog check: Time since last heartbeat: ${timeDiff}ms");

      if (timeDiff > _appDeadThresholdMillis) {
        // App đã chết
        if (_isAppAlive) {
          // Chỉ cập nhật nếu trạng thái đang là "sống"
          debugPrint("💀 App đã chết (không nhận được heartbeat) - ẨN overlay");
          try {
            // Cập nhật cờ để click-through
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
          // Chủ động đóng overlay sau khi coi app là "chết" để đồng nhất hành vi.
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

  // main.dart - BÊN TRONG CLASS _OverlayWidgetState

  @override
  Widget build(BuildContext context) {
    if (!_isAppAlive) {
      // Khi app chết, trả về widget rỗng và trong suốt
      return Container(color: Colors.transparent, width: 0, height: 0);
    }

    final now = DateTime.now();

    // Yêu cầu 1: Định dạng thời gian hiện tại (hh:mm)
    final String currentTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // Yêu cầu 2: Tính thời gian tương lai (random 5-10 phút)
    final int randomMinutes =
        _random.nextInt(6) + 5; // (0 đến 5) + 5 = 5 đến 10
    final futureTime = now.add(Duration(minutes: randomMinutes));
    final String formattedFutureTime =
        "${futureTime.hour.toString().padLeft(2, '0')}:${futureTime.minute.toString().padLeft(2, '0')}";

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // === CÁC GIÁ TRỊ CỐ ĐỊNH ===
          final double overlayWidth = constraints.maxWidth;
          final double overlayHeight = constraints.maxHeight;
          // Giả sử Robot chiếm 30% chiều rộng
          final double robotWidth = overlayWidth * 0.3;

          // Kích thước font chữ (kẹp giữa 12 và 16)
          final double mainFontSize = (overlayHeight * 0.1).clamp(12.0, 16.0);

          // Kích thước ảnh game (khoảng 60% chiều cao, kẹp giữa 50 và 80)
          final double gameImageSize = (overlayHeight * 0.25);
          final double slotImageSize = (overlayHeight * 0.15);

          // Kích thước icon (nếu lỗi ảnh)
          final double robotIconSize = robotWidth * 0.8;
          final double gameIconSize = gameImageSize * 0.7;

          return Container(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            // Chiều rộng cố định
            padding: EdgeInsets.all(10),
            // Padding cố định
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.cyan.shade700, width: 2),
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

                            // Image anh
                            Container(
                              width: gameImageSize, // Cố định
                              height: gameImageSize, // Cố định
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.cyan,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyan.withOpacity(0.5),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _gameImage.isNotEmpty
                                    ? Image.network(
                                        _gameImage,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey.shade900,
                                                child: Icon(
                                                  Icons.casino,
                                                  color: Colors.cyan,
                                                  size: gameIconSize, // Cố định
                                                ),
                                              );
                                            },
                                      )
                                    : Container(
                                        color: Colors.grey.shade900,
                                        child: Icon(
                                          Icons.casino,
                                          color: Colors.cyan,
                                          size: gameIconSize, // Cố định
                                        ),
                                      ),
                              ),
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
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 20),
                          child: _cateImage.isNotEmpty
                              ? Image.network(
                                  _cateImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade900,
                                      child: Icon(
                                        Icons.casino,
                                        color: Colors.cyan,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey.shade900,
                                  child: Icon(Icons.casino, color: Colors.cyan),
                                ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
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
                        flex: 2,
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
