import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      title: 'TOOLVIP25',
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

  // Biến lưu data từ WebView để hiển thị trên overlay
  String _overlayMessage = 'Pinup Girls đang chuẩn bị nổ...';

  // === THÊM: Biến lưu hot games (ti_le >= 70) ===
  List<Game> _hotGames = [];
  Timer? _gameRotationTimer;
  final Random _random = Random();
  double _screenHeight = 400;
  double _screenWidth = 800;
  double _pixelRatio = 1.0;
  static const int _maxRetries = 10;
  bool _isOverlayProcessing = false;

  // Timer để update timestamp báo hiệu app còn sống
  Timer? _aliveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Đảm bảo overlay đóng khi app khởi động
    _closeOverlayIfOpen();

    // Tự động kiểm tra và xin quyền overlay khi app khởi động
    _checkAndRequestOverlayPermission();

    // === THÊM: Fetch hot games từ API ===
    _fetchHotGames();

    // Bắt đầu update timestamp để báo app còn sống
    _startAliveTimer();

    const String yourWebsiteUrl = 'https://toolvip2025.top/';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      // Thêm JavaScript Channel để nhận data từ WebView
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint("📩 Nhận message từ WebView: ${message.message}");

          // Cập nhật message để hiển thị trên overlay
          setState(() {
            _overlayMessage = message.message;
          });
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });

            // Inject JavaScript để website có thể gửi data lên Flutter
            _injectJavaScript();
          },
          onWebResourceError: (WebResourceError error) {},
        ),
      )
      ..loadRequest(Uri.parse(yourWebsiteUrl));
  }

  // Kiểm tra và tự động xin quyền overlay khi app khởi động
  Future<void> _checkAndRequestOverlayPermission() async {
    try {
      final hasPermission = await FlutterOverlayWindow.isPermissionGranted();

      if (hasPermission != true) {
        debugPrint("⚠️ Chưa có quyền overlay, đang yêu cầu quyền...");
        // requestPermission() sẽ tự động mở Settings để người dùng cấp quyền
        await FlutterOverlayWindow.requestPermission();
        debugPrint("✅ Đã yêu cầu quyền overlay");
      } else {
        debugPrint("✅ Đã có quyền overlay");
      }
    } catch (e) {
      debugPrint("❌ Lỗi khi kiểm tra quyền overlay: $e");
    }
  }

  // Đóng overlay nếu đang mở (khi app khởi động hoặc resume)
  Future<void> _closeOverlayIfOpen() async {
    // Nếu đang có lệnh khác (show/close) chạy, thì HỦY
    if (_isOverlayProcessing) {
      debugPrint("Lỗi Race: Bỏ qua lệnh ĐÓNG vì đang xử lý...");
      return;
    }
    // 1. LẤY KHÓA
    _isOverlayProcessing = true;
    debugPrint("Lấy khóa để ĐÓNG overlay");

    try {
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive == true) {
        debugPrint("🔴 Đóng overlay vì app đang mở");
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (e) {
      debugPrint("Lỗi khi đóng overlay: $e");
    } finally {
      // 2. TRẢ KHÓA (bất kể thành công hay thất bại)
      _isOverlayProcessing = false;
      debugPrint("Trả khóa sau khi ĐÓNG");
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

  // === THÊM: Fetch hot games (ti_le >= 70) ===
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

  // === BƯỚC 2: THAY THẾ 2 HÀM CŨ BẰNG 2 HÀM MỚI NÀY ===

  // Hàm này giờ chỉ có nhiệm vụ BẮT ĐẦU vòng lặp
  void _startGameRotation() {
    _gameRotationTimer?.cancel();

    // Bắt đầu kiểm tra và gửi game (không cần Timer.periodic nữa)
    _updateOverlayWithRandomGame();
  }

  // Hàm này sẽ kiểm tra, gửi data, và TỰ HẸN GIỜ cho lần kế tiếp
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
          (randomGame.fullGameImageUrl != null &&
              randomGame.fullGameImageUrl!.isNotEmpty) &&
          (randomGame.fullSlotImageUrl != null &&
              randomGame.fullSlotImageUrl!.isNotEmpty);

      if (isDataValid) {
        // 4. HỢP LỆ: Gửi data và hẹn giờ 2 PHÚT
        debugPrint(
          "✅ Dữ liệu hợp lệ (thử lần ${retryCount + 1}). Gửi game: ${randomGame.name}",
        );
        await FlutterOverlayWindow.shareData({
          'name': randomGame.name,
          'image': randomGame.fullGameImageUrl,
          'slot_image': randomGame.fullSlotImageUrl,
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
      debugPrint("❌ Lỗi khi gửi game data: $e");
      // Nếu có lỗi, thử lại sau 2 phút
      _gameRotationTimer?.cancel();
      _gameRotationTimer = Timer(
        const Duration(seconds: 120),
        _updateOverlayWithRandomGame,
      );
    }
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

  // Bắt đầu update timestamp mỗi giây để báo hiệu app còn sống
  void _startAliveTimer() {
    _aliveTimer?.cancel();
    _aliveTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // KIỂM TRA NẾU OVERLAY CÒN HOẠT ĐỘNG KHÔNG
      if (await FlutterOverlayWindow.isActive() == true) {
        // GỬI NHỊP TIM QUA shareData
        await FlutterOverlayWindow.shareData({'type': 'heartbeat'});
        debugPrint("💓 App sent heartbeat");
      } else {
        // Overlay đã bị đóng (có thể do người dùng tự đóng), dừng timer
        timer.cancel();
      }
    });
    debugPrint("🟢 Started alive timer");
  }

  // Dừng update timestamp
  void _stopAliveTimer() {
    _aliveTimer?.cancel();
    _aliveTimer = null;
    debugPrint("🔴 Stopped alive timer");
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _gameRotationTimer?.cancel();
    _aliveTimer?.cancel();

    // Đảm bảo đóng overlay khi app bị dispose
    await _closeOverlayIfOpen();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    debugPrint("📱 App lifecycle: $state");

    if (state == AppLifecycleState.paused) {
      debugPrint("🟡 App paused - Hiển thị overlay");
      await _showOverlayAndSendData(); // Hàm này sẽ gọi _startAliveTimer
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("🟢 App resumed - Đóng overlay");
      _stopAliveTimer(); // Dừng gửi nhịp tim
      await _closeOverlayIfOpen();
    } else if (state == AppLifecycleState.detached) {
      debugPrint("🔴 App detached - App đang bị kill");
      _stopAliveTimer(); // Dừng gửi nhịp tim
    }
  }

  // Hiển thị overlay khi app vào nền
  // BÊN TRONG _WebViewScreenState

  Future<void> _showOverlayAndSendData() async {
    // 1. CHỜ KHÓA ĐƯỢC TRẢ LẠI
    // (Nếu _closeOverlayIfOpen đang chạy, nó sẽ chờ ở đây)
    while (_isOverlayProcessing) {
      debugPrint("Lỗi Race: Đang chờ lệnh ĐÓNG hoàn thành...");
      await Future.delayed(const Duration(milliseconds: 100));
    }
    // 2. LẤY KHÓA
    _isOverlayProcessing = true;
    debugPrint("Lấy khóa để MỞ overlay");

    try {
      // 1. Kiểm tra quyền (vẫn giữ)
      final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
      if (hasPermission != true) {
        debugPrint("⚠️ Chưa có quyền overlay. Hãy cấp quyền trước!");
        _isOverlayProcessing = false; // Trả khóa trước khi return
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
          flag: OverlayFlag.clickThrough,
          positionGravity: PositionGravity.auto,
          overlayTitle: '',
        );
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        debugPrint("🔄 Overlay đã hiển thị. Bỏ qua bước tạo.");
      }

      // Luôn gửi data và bắt đầu nhịp tim
      if (_hotGames.isNotEmpty) {
        final randomGame = _hotGames[_random.nextInt(_hotGames.length)];
        await FlutterOverlayWindow.shareData({
          'name': randomGame.name,
          'image': randomGame.fullGameImageUrl,
          'slot_image': randomGame.fullSlotImageUrl,
          'ti_le': randomGame.tiLe.toString(),
        });
        debugPrint(
          "✅ Gửi data game lên overlay: ${randomGame.name}",
        );
      } else {
        await FlutterOverlayWindow.shareData({
          'name': 'VipSlotX25', 'image': '', 'slot_image': '', 'ti_le': '100',
        });
      }
      _startAliveTimer(); // Luôn bắt đầu nhịp tim

    } catch (e) {
      debugPrint("❌ Lỗi khi hiển thị overlay: $e");
    } finally {
      // 3. TRẢ KHÓA
      _isOverlayProcessing = false;
      debugPrint("Trả khóa sau khi MỞ");
    }
  }

  static const platform = MethodChannel('com.example/service');

// 2. Gửi lệnh "startService"
  Future<void> _startNativeService() async {
    try {
      await platform.invokeMethod('startService');
      debugPrint("Đã gửi lệnh 'startService' đến Kotlin");
    } on PlatformException catch (e) {
      debugPrint("Lỗi khi gọi native: '${e.message}'.");
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
  String _slotImage = "";
  StreamSubscription? _subscription;
  final Random _random = Random();

  Timer? _watchdogTimer; // Timer "chó canh gác"
  int _lastHeartbeatTime =
      DateTime.now().millisecondsSinceEpoch; // Lưu lần cuối nhận nhịp tim
  static const int _appDeadThresholdMillis = 2000;
  bool _isAppAlive = true;
  bool _hasReceivedFirstHeartbeat = false;

  int getRandomRound() {
    return _random.nextInt(120 - 50 + 1) + 50;
  }

  int getRandomMoney() {
    return _random.nextInt(5) + 1;
  }

  @override
  void initState() {
    super.initState();

    debugPrint("🟢 OverlayWidget initState được gọi");

    // Lắng nghe dữ liệu từ main app
    _subscription = FlutterOverlayWindow.overlayListener.listen((data) {
      if (!mounted) return;

      // 1. KIỂM TRA XEM CÓ PHẢI LÀ NHỊP TIM KHÔNG
      if (data is Map && data['type'] == 'heartbeat') {
        debugPrint("💓 Overlay received heartbeat");
        _lastHeartbeatTime = DateTime.now().millisecondsSinceEpoch;

        // === THÊM LOGIC NÀY ===
        // Nếu đây là nhịp tim đầu tiên, hãy khởi động Watchdog
        if (!_hasReceivedFirstHeartbeat) {
          _startWatchdogTimer();
          _hasReceivedFirstHeartbeat = true;
          debugPrint("🔥 Watchdog đã được kích hoạt sau nhịp tim đầu tiên.");
        }
        // === KẾT THÚC THÊM ===
        return;
      }

      // 2. NẾU KHÔNG PHẢI, THÌ ĐÓ LÀ DATA GAME
      debugPrint("🟢 Nhận game data: $data");
      setState(() {
        _gameName = data['name'] ?? 'Unknown Game';
        _gameImage = data['image'] ?? '';
        _slotImage = data['slot_image'] ?? '';
        _gameTiLe = data['ti_le'] ?? '0';
      });
    });
  }

  // Check định kỳ xem app còn sống không
  void _startWatchdogTimer() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final timeDiff = now - _lastHeartbeatTime;

      debugPrint("🔍 Watchdog check: Time since last heartbeat: ${timeDiff}ms");

      if (timeDiff > _appDeadThresholdMillis) {
         FlutterOverlayWindow.closeOverlay();
        debugPrint("💀 App đã chết (không nhận được heartbeat) - ẨN overlay");

        // === THAY VÌ GỌI _closeOverlay() ===
        if (mounted) {
          setState(() {
            _isAppAlive = false;
          });
        }
        // === KẾT THÚC THAY ĐỔI ===

        timer.cancel(); // Dừng watchdog
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
      return Container(color: Colors.red);
    }

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
          final double slotIconSize = slotImageSize * 0.7;

          debugPrint("OVERLAY_HEIGHT ============== $overlayHeight");
          debugPrint("OVERLAY_WIDTH ============== $overlayWidth");

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
                  flex: 6,
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
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 20),
                          child: _slotImage.isNotEmpty
                              ? Image.network(
                                  _slotImage,
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
                              'Vòng cược: ${getRandomRound()}',
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
                              'Mức cược: ${getRandomMoney()}k',
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
