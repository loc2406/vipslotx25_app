# vipslotx25_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

lib/
├── main.dart                 # Điểm khởi đầu, chứa ProviderScope

├── **core**/                   # Mã nguồn dùng chung cho toàn bộ ứng dụng
│   ├── api/                  # Cài đặt client API (ví dụ: Dio instance provider)
│   ├── constants/            # Các hằng số (VD: API keys, route names)
│   ├── errors/               # Xử lý lỗi (failures, exceptions)
│   ├── navigation/           # Cài đặt router (VD: GoRouter)
│   ├── theme/                # Chủ đề (theme) của ứng dụng
│   ├── utils/                # Các hàm tiện ích (VD: validators, formatters)
│   └── widgets/              # Các widget dùng chung (VD: CustomButton, LoadingSpinner)

└── **features**/              # Thư mục chứa tất cả các tính năng
│
├── **auth**/               # Ví dụ: Tính năng Xác thực (Authentication)
│   │
│   ├── **presentation/** # Lớp UI (Flutter Widgets)
│   │   ├── screens/        # Các màn hình (VD: login_screen.dart)
│   │   ├── widgets/        # Các widget con chỉ dùng cho tính năng này (VD: login_form.dart)
│   │   └── providers/      # (Tùy chọn) Provider chỉ cho trạng thái UI (VD: form validation)
│   │
│   ├── **application/** # Lớp Business Logic (Riverpod Providers)
│   │   └── providers/      # Nơi chứa logic chính, VD: auth_controller_provider.dart
│   │
│   ├── **domain/** # Lớp dữ liệu thuần túy (Pure Dart)
│   │   ├── models/       # Các data models (VD: user.dart)
│   │   └── repositories/ # Các Interface (abstract class) cho repository
│   │
│   └── **infrastructure/** # Lớp Data (Implementation)
│       ├── repositories/ # Triển khai (implement) của repository interface
│       └── data_sources/ # Nơi gọi API hoặc database (VD: auth_api_data_source.dart)
│
└── **products**/            # Ví dụ: Tính năng Sản phẩm
│
├── presentation/
├── application/
├── domain/
└── infrastructure/