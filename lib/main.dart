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

  Timer? _gameRotationTimer;
  final Random _random = Random();
  double _screenHeight = 400;
  double _screenWidth = 800;
  double _pixelRatio = 1.0;

  // === SỬA LỖI: Thêm các biến quản lý trạng thái ===
  bool _isOverlayProcessing = false; // "Khóa" chống Race Condition
  Timer? _aliveTimer; // "Nhịp tim" (Heartbeat)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _closeOverlayIfOpen();
    _checkAndRequestOverlayPermission();
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


  // === THÊM: Bắt đầu rotation games mỗi 5 giây ===
  void _startGameRotation() {
    _gameRotationTimer?.cancel();

    // Bắt đầu kiểm tra và gửi game (không cần Timer.periodic nữa)
    _updateOverlayWithRandomGame();
  }

  // === THÊM: Random 1 game và gửi lên overlay ===
  Future<void> _updateOverlayWithRandomGame() async {
    try {
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive != true) {
        // Overlay đã bị đóng (ví dụ: user đóng thủ công), dừng vòng lặp
        _gameRotationTimer?.cancel();
        debugPrint("🔄 Overlay không hoạt động, dừng vòng lặp update.");
        return;
      }

      // Gửi một tin nhắn "trigger" đơn giản.
      // OverlayWidget sẽ dùng nó để gọi setState()
      await FlutterOverlayWindow.shareData({'type': 'trigger_update'});
      debugPrint("✅ Gửi 'trigger_update' lên overlay (lần cập nhật 2 phút)");

      // Hẹn giờ lần chạy KẾ TIẾP (sau 2 phút)
      _gameRotationTimer?.cancel();
      _gameRotationTimer = Timer(
        const Duration(seconds: 120),
        _updateOverlayWithRandomGame,
      );
    } catch (e) {
      debugPrint("❌ Lỗi khi gửi trigger_update: $e");
      // Nếu lỗi, vẫn thử lại sau 2 phút
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
      _stopAliveTimer();
      _gameRotationTimer?.cancel();
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

      // 4. LUÔN LUÔN GỬI DATA VÀ BẮT ĐẦU NHỊP TIM
      // (Dù overlay vừa được tạo hay đã có sẵn)

      await FlutterOverlayWindow.shareData({
        'type': 'trigger_update'
      });
      debugPrint("✅ Gửi 'trigger_update' KHỞI ĐỘNG lên overlay");

      // BẮT ĐẦU GỬI NHỊP TIM
      _startAliveTimer();

      // THÊM VÀO ĐÂY:
      // Bắt đầu vòng lặp 2 phút
      _gameRotationTimer?.cancel();
      _gameRotationTimer = Timer(
        const Duration(seconds: 120),
        _updateOverlayWithRandomGame, // Gọi hàm update mới
      );
      debugPrint("▶️ Đã khởi động timer 2 phút");
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
  StreamSubscription? _subscription;
  final Random _random = Random();
  List<String> tableNames = [
    "Bàn 1",
    "Bàn 2",
    "Bàn 3",
    "Bàn 4",
    "Bàn 5",
    "Bàn 6",
    "Bàn 7",
    "Bàn 8",
    "Bàn 9",
    "Bàn 10",
    "Bàn C01",
    "Bàn C02",
    "Bàn C03",
    "Bàn C08",
    "Bàn C09",
    "Bàn C10",
  ];
  List<String> predicts = ["B", "P"];

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
      debugPrint("🟢 Nhận data: $data");
      setState(() {
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

    final String randomTable = getRandomTable();
    final String randomPredict = getRandomPredict();
    final String randomPercent = getRandomPercent();

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double overlayWidth = constraints.maxWidth;
          final double overlayHeight = constraints.maxHeight;
          final double robotWidth = overlayWidth * 0.3;
          final double mainFontSize = (overlayHeight * 0.1).clamp(12.0, 16.0);
          final double gameImageSize = (overlayHeight * 0.25);
          final double robotIconSize = robotWidth * 0.8;

          return Container(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            decoration: BoxDecoration(
              color: Colors.transparent,
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
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/BG_lobby.jpg',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Row(
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
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Bang
                          Text(
                            randomTable,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: mainFontSize, // Cố định
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          // Image anh
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
                                    randomPredict == 'B'
                                        ? 'assets/symbol_b.png'
                                        : 'assets/symbol_p.png',
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) {
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

                          Text(
                            'Tỉ lệ thắng bàn',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: mainFontSize, // Cố định
                              fontWeight: FontWeight.w500,
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
                                    randomPercent,
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
              ],
            ),
          );
        },
      ),
    );
  }

  String getRandomTable() {
    final randomIndex = _random.nextInt(tableNames.length);
    return tableNames[randomIndex];
  }

  String getRandomPredict() {
    final randomIndex = _random.nextInt(predicts.length);
    return predicts[randomIndex];
  }

  String getRandomPercent() {
    final percent = _random.nextInt(99) + 1;
    return '$percent%';
  }
}
