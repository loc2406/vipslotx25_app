import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GamesService {
  static const String apiGetAllGamesUrl = 'https://hack88.top/api_get_all_games.php';
  static const String apiGetGameUrl = 'https://hack88.top/api_get_game.php';



  static Future<Game?> fetchRandomGame({
    int maxRetries = 10,
  }) async {
    try {
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

      int totalGames = 0;

      if (totalGames == 0) {
        totalGames = allGamesJson['count'] ?? 0;
      }

      if (totalGames <= 0) {
        debugPrint("❌ Không có game nào");
        return null;
      }

      debugPrint("✅ Tổng số games: $totalGames");

      final random = Random();
      int attempts = 0;

      while (attempts < maxRetries) {
        final randomId = random.nextInt(totalGames) + 1;

        debugPrint("🎲 Bước 2: Random ID: $randomId (Lần thử: ${attempts + 1}/$maxRetries)");

        final gameResponse = await http.get(
            Uri.parse('$apiGetGameUrl?id=$randomId')
        );

        if (gameResponse.statusCode == 200) {
          final gameJson = json.decode(gameResponse.body);

          if (gameJson['status'] == 'success' && gameJson['data'] != null) {
            debugPrint("✅ Tìm thấy game ID: $randomId");

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
}

class Game {
  final int id;
  final String name;
  final String image;
  final int tiLe;

  Game({
    required this.id,
    required this.name,
    required this.image,
    required this.tiLe,
  });

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
    return 'https://toolhack999.net$image';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'ti_le': tiLe,
    };
  }

  @override
  String toString() {
    return 'Game(id: $id, name: $name, image: $image, tiLe: $tiLe)';
  }
}
