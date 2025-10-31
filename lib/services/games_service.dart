import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GamesService {
  static const String apiGetAllGamesUrl = 'https://toolmm88.top/api_get_all_games.php';
  static const String apiGetGameUrl = 'https://toolmm88.top/api_get_game.php';



  static Future<Game?> fetchRandomGame({
    int maxRetries = 10,
  }) async {
    try {
      // Bước 1: Lấy tổng số games từ api_get_all_games.php
      debugPrint("🎮 Bước 1: Đang lấy tổng số games...");

      final allGamesResponse = await http.get(Uri.parse(apiGetAllGamesUrl));

      if (allGamesResponse.statusCode != 200) {
        debugPrint("❌ Lỗi khi lấy tổng số games: ${allGamesResponse.statusCode}");
        return null;
      }

      final allGamesJson = json.decode(allGamesResponse.body);

      if (allGamesJson['status'] != 'success') {
        debugPrint("❌ API trả về status không thành công");
        return null;
      }

      // Lấy tổng số games từ statistics hoặc count
      int totalGames = 0;

      if (totalGames == 0) {
        totalGames = allGamesJson['count'] ?? 0;
      }

      if (totalGames <= 0) {
        debugPrint("❌ Không có game nào");
        return null;
      }

      debugPrint("✅ Tổng số games: $totalGames");

      // Bước 2: Random ID và thử lấy game
      final random = Random();
      int attempts = 0;

      while (attempts < maxRetries) {
        // Random ID từ 1 đến totalGames
        final randomId = random.nextInt(totalGames) + 1;

        debugPrint("🎲 Bước 2: Random ID: $randomId (Lần thử: ${attempts + 1}/$maxRetries)");

        // Bước 3: Gọi API lấy game theo ID (api_get_game.php)
        final gameResponse = await http.get(
            Uri.parse('$apiGetGameUrl?id=$randomId')
        );

        if (gameResponse.statusCode == 200) {
          final gameJson = json.decode(gameResponse.body);

          if (gameJson['status'] == 'success' && gameJson['data'] != null) {
            debugPrint("✅ Tìm thấy game ID: $randomId");

            // Parse thành Game object với các field: id, name, image, ti_le
            return Game.fromJson(gameJson['data']);
          } else {
            debugPrint("⚠️ Game ID $randomId không tồn tại, thử ID khác...");
          }
        } else if (gameResponse.statusCode == 404) {
          debugPrint("⚠️ Game ID $randomId không tìm thấy (404), thử ID khác...");
        } else {
          debugPrint("❌ Lỗi khi lấy game ID $randomId: ${gameResponse.statusCode}");
        }

        attempts++;
      }

      debugPrint("❌ Không thể tìm game sau $maxRetries lần thử");
      return null;

    } catch (e) {
      debugPrint("❌ Lỗi khi fetch random game: $e");
      return null;
    }
  }

  /// Legacy: Lấy tất cả games từ api_get_all_games.php
  // static Future<List<Game>> fetchGames() async {
  //   try {
  //     debugPrint("🎮 Đang fetch games từ API...");
  //
  //     final response = await http.get(Uri.parse(apiGetAllGamesUrl));
  //
  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> jsonData = json.decode(response.body);
  //
  //       if (jsonData['status'] == 'success') {
  //         final List<dynamic> gamesData = jsonData['data'];
  //         final int gameCount = jsonData['count'] ?? gamesData.length;
  //
  //         // Parse mỗi game object thành Game model
  //         final List<Game> allGames = gamesData
  //             .map((json) => Game.fromJson(json))
  //             .toList();
  //
  //         debugPrint("✅ Tìm thấy ${allGames.length} games");
  //
  //         return allGames;
  //       }
  //     }
  //
  //     debugPrint("❌ API trả về status: ${response.statusCode}");
  //     return [];
  //   } catch (e) {
  //     debugPrint("❌ Lỗi khi fetch games: $e");
  //     return [];
  //   }
  // }
}

/// Game model class - Parse từ JSON response của api_get_all_games.php
/// Chỉ lấy các field: id, name, image, ti_le
class Game {
  final int id;
  final String name;
  final String image;
  final int tiLe; // ti_le từ JSON

  Game({
    required this.id,
    required this.name,
    required this.image,
    required this.tiLe,
  });

  /// Parse từ JSON object (từ data array trong api_get_all_games.php hoặc data trong api_get_game.php)
  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as int,
      name: json['name'] as String,
      image: json['image'] as String,
      tiLe: json['ti_le'] as int,
    );
  }

  String get fullGameImageUrl {
    if (image.startsWith('http')) return image;
    return 'https://toolmm88.top$image';
  }

  /// Convert Game object thành Map (nếu cần)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'ti_le': tiLe,
    };
  }

  /// Debug info
  @override
  String toString() {
    return 'Game(id: $id, name: $name, image: $image, tiLe: $tiLe)';
  }
}
