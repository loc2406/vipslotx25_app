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
      home: WebViewScreen(
        initialUrl: 'https://toolhack999.net',
        onLoginStatusChanged: (isLoggedIn) {
          setState(() {
            _isLoggedIn = isLoggedIn;
          });
        },
        onLoginSuccess: (userInfo) {
          setState(() {
            _userInfo = userInfo;
          });
          // Thực hiện các hành động sau khi đăng nhập thành công
          _onLoginSuccess(userInfo);
        },
      ),
    );
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

  int _userCash = 0;
  String _userRole = '';

  double _screenHeight = 400;
  double _screenWidth = 800;
  double _pixelRatio = 1.0;

  bool _isOverlayProcessing = false;
  Timer? _aliveTimer;

  Map<String, dynamic>? _roomInfo;
  bool _isOnRoomPage = false;

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

  void _handleMessage(String message) {
    try {
      final data = json.decode(message);

      final type = data['type'];

      debugPrint('📨 Nhận message: type=$type, data=$data');

      if (type == 'login_success') {
        // Xử lý khi có user info cho tất cả roles

        if (data['user'] != null) {
          final role = data['role'] ?? '';

          final userCash =
              int.tryParse(data['user']['cash']?.toString() ?? '0') ?? 0;

          if (role == 'admin') {
            // Admin: luôn coi là đăng nhập thành công và hiển thị overlay

            setState(() {
              _isLoggedIn = true;

              _userCash = userCash;

              _userRole = role;
            });

            widget.onLoginStatusChanged?.call(true);

            widget.onLoginSuccess?.call(data);

            debugPrint(
              '✅ [ADMIN] Đăng nhập thành công. Role: $role, Cash: $userCash (không kiểm tra cash cho admin)',
            );
          } else if (role == 'users') {
            // Users: chỉ coi là đăng nhập thành công khi cash > 0

            if (userCash > 0) {
              setState(() {
                _isLoggedIn = true;

                _userCash = userCash;

                _userRole = role;
              });

              widget.onLoginStatusChanged?.call(true);

              widget.onLoginSuccess?.call(data);

              debugPrint(
                '✅ [USERS] Đăng nhập thành công. Role: $role, Cash: $userCash (> 0)',
              );
            } else {
              // Users với cash <= 0: không coi là đăng nhập thành công

              setState(() {
                _isLoggedIn = false;

                _userCash = 0;

                _userRole = '';
              });

              widget.onLoginStatusChanged?.call(false);

              debugPrint(
                '⚠️ [USERS] Cash = 0 hoặc âm, không coi là đăng nhập thành công. Cash: $userCash',
              );
            }
          } else if (role == 'ctv') {
            // CTV: luôn coi là đăng nhập thành công và hiển thị overlay (giống admin)

            setState(() {
              _isLoggedIn = true;

              _userCash = userCash;

              _userRole = role;
            });

            widget.onLoginStatusChanged?.call(true);

            widget.onLoginSuccess?.call(data);

            debugPrint(
              '✅ [CTV] Đăng nhập thành công. Role: $role, Cash: $userCash (không kiểm tra cash cho ctv)',
            );
          } else {
            // Role không hợp lệ

            setState(() {
              _isLoggedIn = false;

              _userCash = 0;

              _userRole = '';
            });

            widget.onLoginStatusChanged?.call(false);

            debugPrint('⚠️ Role không hợp lệ: $role');
          }
        } else {
          // Không có user info, không coi là đăng nhập thành công

          setState(() {
            _isLoggedIn = false;
          });

          widget.onLoginStatusChanged?.call(false);

          debugPrint('⚠️ Không có user info trong login_success message');
        }
      } else if (type == 'login_failed') {
        // Xử lý trường hợp đăng nhập thất bại

        setState(() {
          _isLoggedIn = false;

          _userCash = 0;

          _userRole = '';
        });

        widget.onLoginStatusChanged?.call(false);

        final reason = data['reason'] ?? 'unknown';

        final message = data['message'] ?? 'Đăng nhập thất bại';

        debugPrint('❌ Đăng nhập thất bại: $message (Lý do: $reason)');

        if (reason == 'zero_cash') {
          debugPrint('⚠️ Tài khoản không có xu, không cho phép đăng nhập');
        }
      } else if (type == 'login_status') {
        final isLoggedIn = data['isLoggedIn'] ?? false;

        if (_isLoggedIn != isLoggedIn) {
          setState(() {
            _isLoggedIn = isLoggedIn;
          });

          widget.onLoginStatusChanged?.call(isLoggedIn);
        }
      } else if (type == 'user_info') {
        // Chỉ xử lý khi có user info hợp lệ

        if (data['user'] != null) {
          final role = data['role'] ?? '';

          final userCash =
              int.tryParse(data['user']['cash']?.toString() ?? '0') ?? 0;

          // Cập nhật logic tương tự như login_success

          if (role == 'admin' || role == 'ctv') {
            setState(() {
              _userCash = userCash;

              _isLoggedIn = true;

              _userRole = role;
            });

            widget.onLoginSuccess?.call(data);

            debugPrint(
              '💰 Cập nhật user info: Role=$role, Cash=$userCash (không kiểm tra cash)',
            );
          } else if (role == 'users' && userCash > 0) {
            setState(() {
              _userCash = userCash;

              _isLoggedIn = true;

              _userRole = role;
            });

            widget.onLoginSuccess?.call(data);

            debugPrint('💰 Cập nhật user cash: $_userCash');
          } else {
            setState(() {
              _isLoggedIn = false;

              _userCash = 0;

              _userRole = '';
            });

            widget.onLoginStatusChanged?.call(false);

            debugPrint(
              '⚠️ Cash = 0 hoặc role không hợp lệ, không cập nhật trạng thái đăng nhập',
            );
          }
        }
      } else if (type == 'room_info') {
        // Xử lý thông tin room từ web

        setState(() {
          _roomInfo = {
            'tableName': data['tableName'] ?? '',

            'predict': data['predict'] ?? '',

            'winrate': data['winrate'] ?? '0%',

            'timestamp': data['timestamp'] ?? '',
          };
        });

        debugPrint(
          '📊 Nhận thông tin room: Bàn=${data['tableName']}, Dự đoán=${data['predict']}, Tỉ lệ=${data['winrate']}',
        );

        // Gửi thông tin room đến overlay nếu overlay đang hoạt động

        _sendRoomInfoToOverlay();
      } else if (type == 'page_status') {
        final isOnRoomPage = data['isOnRoomPage'] ?? false;
        setState(() {
          _isOnRoomPage = isOnRoomPage;
        });
        debugPrint(
          '📄 Trạng thái trang: ${isOnRoomPage ? "Đang ở trang room" : "Không ở trang room"}',
        );
        _sendPageStatusToOverlay();
      }
    } catch (e) {
      debugPrint('❌ Error parsing message: $e');
    }
  }

  Future<void> _sendRoomInfoToOverlay() async {
    try {
      if (_roomInfo != null) {
        final isActive = await FlutterOverlayWindow.isActive();
        if (isActive == true) {
          await FlutterOverlayWindow.shareData({
            'type': 'room_info_update',
            'roomInfo': _roomInfo,
            'isOnRoomPage': _isOnRoomPage,
          });
          debugPrint('✅ Đã gửi room_info_update đến overlay');
        }
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gửi room_info đến overlay: $e');
    }
  }

  Future<void> _sendPageStatusToOverlay() async {
    try {
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive == true) {
        await FlutterOverlayWindow.shareData({
          'type': 'page_status_update',
          'isOnRoomPage': _isOnRoomPage,
          'roomInfo': _roomInfo,
        });
        debugPrint(
          '✅ Đã gửi page_status_update đến overlay: isOnRoomPage=$_isOnRoomPage',
        );
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi gửi page_status đến overlay: $e');
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
    if (!_isLoggedIn) {
      debugPrint(
        "⚠️ Không hiển thị overlay: Chưa đăng nhập (isLoggedIn=false)",
      );
      return;
    }
    // Kiểm tra logic theo role
    debugPrint(
      "🔍 Kiểm tra điều kiện hiển thị overlay: Role=$_userRole, Cash=$_userCash",
    );
    if (_userRole == 'admin' || _userRole == 'ctv') {
      debugPrint(
        "✅ [$_userRole] Không phép hiển thị overlay (không kiểm tra cash)",
      );
      return;
    } else if (_userRole == 'users') {
      if (_userCash <= 0) {
        debugPrint(
          "⚠️ [USERS] Không hiển thị overlay: Cash = 0 hoặc âm (Cash=$_userCash)",
        );
        return;
      } else {
        debugPrint("✅ [USERS] Cho phép hiển thị overlay (Cash=$_userCash > 0)");
      }
    } else {
      // Role không hợp lệ
      debugPrint(
        "❌ Không hiển thị overlay: Role không hợp lệ (Role=$_userRole)",
      );
      return;
    }
    // Nếu đến đây, có nghĩa là cho phép hiển thị overlay
    debugPrint("🚀 Chuẩn bị mở overlay...");
    while (_isOverlayProcessing) {
      debugPrint("⏸️ Race: Đang chờ lệnh ĐÓNG hoàn thành...");
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _isOverlayProcessing = true;
    debugPrint("🔒 Lấy khóa để MỞ overlay");

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

      await _sendRoomInfoToOverlay();
      await _sendPageStatusToOverlay();

      await FlutterOverlayWindow.shareData({'type': 'trigger_update'});
      debugPrint("✅ Gửi 'trigger_update' KHỞI ĐỘNG lên overlay");
      _startAliveTimer();
      debugPrint("✅ Đã gửi thông tin room và trạng thái trang đến overlay");
      _startAliveTimer();
    } catch (e) {
      debugPrint("❌ Lỗi khi hiển thị overlay: $e");
    } finally {
      _isOverlayProcessing = false;
      debugPrint("🔓 Trả khóa sau khi MỞ");
    }
  }
}
