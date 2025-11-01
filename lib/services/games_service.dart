import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class Game {
  final int id;
  final String name;
  final String image;
  final String cateImage;
  final int tiLe;

  Game({
    required this.id,
    required this.name,
    required this.image,
    required this.cateImage,
    required this.tiLe,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      cateImage: json['category_image'] ?? '',
      tiLe: int.tryParse(json['ti_le'].toString()) ?? 0,
    );
  }

  // Format image URL đầy đủ
  String get fullGameImageUrl {
    if (image.startsWith('http')) return image;
    return 'https://toolvip2025.top$image';
  }

  String get fullCateImageUrl {
    if (cateImage.startsWith('http')) return cateImage;
    return 'https://toolvip2025.top$cateImage';
  }
}

class GamesService {
  static const String apiUrl = 'https://toolvip2025.top/api/games_by_category.php';

  static Future<List<Game>> fetchHotGames() async {
    try {
      debugPrint("🎮 Đang fetch games từ API...");
      
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        
        if (jsonData['status'] == 'success') {
          final List<dynamic> gamesData = jsonData['data']['games'];
          
          // Lọc games có ti_le >= 70
          final List<Game> allGames = gamesData
              .map((json) => Game.fromJson(json))
              .toList();
          
          final List<Game> hotGames = allGames
              .where((game) => game.tiLe >= 70)
              .toList();
          
          debugPrint("✅ Tìm thấy ${hotGames.length} games HOT (ti_le >= 70%) từ ${allGames.length} games");
          
          return hotGames;
        }
      }
      
      debugPrint("❌ API trả về status: ${response.statusCode}");
      return [];
    } catch (e) {
      debugPrint("❌ Lỗi khi fetch games: $e");
      return [];
    }
  }
}

