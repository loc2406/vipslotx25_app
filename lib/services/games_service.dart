import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class Game {
  final int id;
  final String name;
  final String image;
  final String slotImage;
  final int tiLe;

  Game({
    required this.id,
    required this.name,
    required this.image,
    required this.slotImage,
    required this.tiLe,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      slotImage: json['slot_image'] ?? '',
      tiLe: int.tryParse(json['ti_le'].toString()) ?? 0,
    );
  }

  // Format image URL đầy đủ
  String get fullGameImageUrl {
    if (image.startsWith('http')) return image;
    return 'https://toolhack999.net$image';
  }

  String get fullSlotImageUrl {
    if (slotImage.startsWith('http')) return slotImage;
    return 'https://toolhack999.net$slotImage';
  }
}

class GamesService {
  static const String apiUrl = 'https://toolhack999.net/api/games.php';

  // Lấy danh sách games có ti_le >= 70
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

