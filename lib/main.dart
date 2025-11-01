import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'overlay_widget.dart';
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;
  Map<String, dynamic>? _userInfo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: ' Tool Quét lá bài BCR V92',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: WebViewScreen(initialUrl: 'https://toolmm88.top',  onLoginStatusChanged: (isLoggedIn) {
        setState(() {
          _isLoggedIn = isLoggedIn;
        });
        // Tùy chỉnh giao diện dựa trên trạng thái đăng nhập
        _customizeUI(isLoggedIn);
      },
        onLoginSuccess: (userInfo) {
          setState(() {
            _userInfo = userInfo;
          });
          // Thực hiện các hành động sau khi đăng nhập thành công
          _onLoginSuccess(userInfo);
        },),
    );
  }

  void _customizeUI(bool isLoggedIn) {
    if (isLoggedIn) {
      debugPrint('User đã đăng nhập - Tùy chỉnh UI');
    } else {
      debugPrint('User chưa đăng nhập');
    }
  }

  void _onLoginSuccess(Map<String, dynamic>? userInfo) {
    debugPrint('Đăng nhập thành công với thông tin: $userInfo');

    if (userInfo != null && userInfo['userToken'] != null) {
      debugPrint('User token: ${userInfo['userToken']}');
    }
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({
    super.key,
    required this.initialUrl,
    this.onLoginStatusChanged,
    this.onLoginSuccess,
  });

  final String initialUrl;
  final Function(bool isLoggedIn)? onLoginStatusChanged;
  final Function(Map<String, dynamic>? userInfo)? onLoginSuccess;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  late final String initialUrl;

  Timer? _gameRotationTimer;
  double _screenHeight = 400;
  double _screenWidth = 800;
  double _pixelRatio = 1.0;

  bool _isOverlayProcessing = false;
  Timer? _aliveTimer;

  @override
  void initState() {
    super.initState();
    initialUrl = widget.initialUrl;
    WidgetsBinding.instance.addObserver(this);
    _closeOverlayIfOpen();
    _checkAndRequestOverlayPermission();
    _setupWebView();
  }

  void _setupWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) => setState(() => _isLoading = true),
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            // _injectJavaScript();
          },
          onWebResourceError: (WebResourceError error) {},
        ),
      )
      ..loadRequest(Uri.parse(initialUrl));
  }

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

        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint("Lỗi khi đóng overlay: $e");
    } finally {
      _isOverlayProcessing = false;
      debugPrint("Trả khóa sau khi ĐÓNG (và delay)");
    }
  }

  // Future<void> _injectJavaScript() async {
  //   try {
  //     await _controller.runJavaScript('''
  //       (function() {
  //       // Kiểm tra nếu đã đăng nhập (có cookie hoặc session)
  //       function checkLoginStatus() {
  //         // Gửi trạng thái đăng nhập hiện tại
  //         if (document.cookie.indexOf('user_token') !== -1) {
  //           FlutterApp.postMessage(JSON.stringify({
  //             type: 'login_status',
  //             isLoggedIn: true
  //           }));
  //         }
  //       }
  //
  //       // Override hàm Login() để bắt sự kiện đăng nhập thành công
  //       if (typeof window.originalLogin === 'undefined') {
  //         window.originalLogin = window.Login;
  //         window.Login = function() {
  //           if (window.originalLogin) {
  //             window.originalLogin();
  //           }
  //           // Lắng nghe response từ AJAX
  //           const originalAjax = \$.ajax;
  //           \$.ajax = function(options) {
  //             if (options.url && options.url.includes('login.php')) {
  //               const originalSuccess = options.success;
  //               options.success = function(res) {
  //                 if (res.status == 'success') {
  //                   // Gửi thông báo đăng nhập thành công đến Flutter
  //                   FlutterApp.postMessage(JSON.stringify({
  //                     type: 'login_success',
  //                     message: res.message,
  //                     timestamp: new Date().toISOString()
  //                   }));
  //
  //                   // Gửi thông tin user nếu có
  //                   setTimeout(function() {
  //                     // Lấy thông tin user từ cookie hoặc localStorage nếu có
  //                     FlutterApp.postMessage(JSON.stringify({
  //                       type: 'user_info',
  //                       userToken: document.cookie.match(/user_token=([^;]+)/) ?
  //                                  document.cookie.match(/user_token=([^;]+)/)[1] : null
  //                     }));
  //                   }, 1000);
  //                 }
  //                 if (originalSuccess) {
  //                   originalSuccess.apply(this, arguments);
  //                 }
  //               };
  //             }
  //             return originalAjax.apply(this, arguments);
  //           };
  //         }
  //       }
  //
  //       // Lắng nghe thay đổi URL (khi redirect sau khi login)
  //       let lastUrl = window.location.href;
  //       setInterval(function() {
  //         if (window.location.href !== lastUrl) {
  //           lastUrl = window.location.href;
  //           // Kiểm tra nếu không còn ở trang login
  //           if (window.location.href.indexOf('login') === -1) {
  //             checkLoginStatus();
  //           }
  //         }
  //       }, 500);
  //
  //       // Kiểm tra trạng thái đăng nhập khi trang load
  //       setTimeout(checkLoginStatus, 1000);
  //
  //       // Lắng nghe khi có thay đổi cookie (thông qua polling)
  //       let lastCookie = document.cookie;
  //       setInterval(function() {
  //         if (document.cookie !== lastCookie) {
  //           lastCookie = document.cookie;
  //           checkLoginStatus();
  //         }
  //       }, 1000);
  //     })();
  //     ''');
  //
  //     debugPrint("✅ Đã inject JavaScript vào WebView");
  //   } catch (e) {
  //     debugPrint("❌ Lỗi khi inject JavaScript: $e");
  //   }
  // }

  void _handleMessage(String message) {
    try {
      final data = json.decode(message);
      final type = data['type'];

      if (type == 'login_success') {
        setState(() {
          _isLoggedIn = true;
        });
        widget.onLoginStatusChanged?.call(true);
        widget.onLoginSuccess?.call(data);
      } else if (type == 'login_status') {
        final isLoggedIn = data['isLoggedIn'] ?? false;
        if (_isLoggedIn != isLoggedIn) {
          setState(() {
            _isLoggedIn = isLoggedIn;
          });
          widget.onLoginStatusChanged?.call(isLoggedIn);
        }
      } else if (type == 'user_info') {
        widget.onLoginSuccess?.call(data);
      }
    } catch (e) {
      debugPrint('Error parsing message: $e');
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
          await FlutterOverlayWindow.shareData({'type': 'heartbeat'});
          debugPrint("💓 App sent heartbeat");
        } else {
          timer.cancel();
        }
      } catch (e) {
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

  Future<void> _showOverlayAndSendData() async {
    while (_isOverlayProcessing) {
      debugPrint("Lỗi Race: Đang chờ lệnh ĐÓNG hoàn thành...");
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _isOverlayProcessing = true;
    debugPrint("Lấy khóa để MỞ overlay");

    try {
      final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
      if (hasPermission != true) {
        debugPrint("⚠️ Chưa có quyền overlay. Hãy cấp quyền trước!");
        _isOverlayProcessing = false;
        return;
      }
      debugPrint("✅ Đã có quyền overlay");

      final isActive = await FlutterOverlayWindow.isActive();

      if (isActive != true) {
        debugPrint("🚀 Đang mở overlay...");
        final double logicalHeight = _screenHeight * 0.18;
        final double logicalWidth = _screenWidth * 0.60;
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

      await FlutterOverlayWindow.shareData({'type': 'trigger_update'});
      debugPrint("✅ Gửi 'trigger_update' KHỞI ĐỘNG lên overlay");

      _startAliveTimer();

      _gameRotationTimer?.cancel();
      _gameRotationTimer = Timer(
        const Duration(seconds: 120),
        _updateOverlayWithRandomGame,
      );
      debugPrint("▶️ Đã khởi động timer 2 phút");
      _startAliveTimer();
    } catch (e) {
      debugPrint("❌ Lỗi khi hiển thị overlay: $e");
    } finally {
      _isOverlayProcessing = false;
      debugPrint("Trả khóa sau khi MỞ");
    }
  }
}
