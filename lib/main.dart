import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class AppConstants {
  static const String sportsJsonPath = 'assets/data/sports.json';
  static const String lastViewedKey = 'last_viewed_sport';
}

class AppRoutes {
  static const home = '/';
  static const details = '/details';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const SportListScreen());
      case details:
        final sport = settings.arguments as Sport;
        return MaterialPageRoute(
          builder: (_) => SportDetailScreen(sport: sport),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Página não encontrada: ${settings.name}')),
          ),
        );
    }
  }
}

class Sport {
  final int id;
  final String name;
  final String description;
  final String image;
  final double popularity;

  Sport({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.popularity,
  });

  factory Sport.fromJson(Map<String, dynamic> json) {
    return Sport(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      image: json['image'] as String,
      popularity: (json['popularity'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'image': image,
        'popularity': popularity,
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Esportes',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}

class SportListScreen extends StatefulWidget {
  const SportListScreen({super.key});

  @override
  State<SportListScreen> createState() => _SportListScreenState();
}

class _SportListScreenState extends State<SportListScreen> {
  List<Sport> sports = [];
  Sport? lastViewed;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadSports(), _loadLastViewed()]);
    setState(() => isLoading = false);
  }

  Future<void> _loadSports() async {
    try {
      final jsonStr = await rootBundle.loadString(AppConstants.sportsJsonPath);
      final list = jsonDecode(jsonStr) as List;
      setState(() {
        sports = list.map((e) => Sport.fromJson(Map<String, dynamic>.from(e))).toList();
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Erro ao carregar os dados: $e';
      });
    }
  }

  Future<void> _loadLastViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(AppConstants.lastViewedKey);
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        setState(() {
          lastViewed = Sport.fromJson(map);
        });
      } catch (_) {}
    }
  }

  Future<void> _saveLastViewed(Sport sport) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.lastViewedKey, jsonEncode(sport.toJson()));
    setState(() {
      lastViewed = sport;
    });
  }

  void _openDetails(Sport sport) async {
    await _saveLastViewed(sport);
    await Navigator.pushNamed(context, AppRoutes.details, arguments: sport);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Esportes Populares')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(child: Text(errorMessage!))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Último esporte visto', style: TextStyle(fontSize: 18)),
                      LastViewedCard(
                        sport: lastViewed,
                        onTap: lastViewed != null ? () => _openDetails(lastViewed!) : null,
                      ),
                      const SizedBox(height: 16),
                      const Text('Esportes em alta', style: TextStyle(fontSize: 18, color: Colors.red)),
                      Expanded(
                        child: sports.isEmpty
                            ? const Center(child: Text('Nenhum esporte disponível'))
                            : ListView.builder(
                                itemCount: sports.length,
                                itemBuilder: (context, index) {
                                  return SportCard(
                                    sport: sports[index],
                                    onTap: () => _openDetails(sports[index]),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class LastViewedCard extends StatelessWidget {
  final Sport? sport;
  final VoidCallback? onTap;

  const LastViewedCard({super.key, this.sport, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (sport == null) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('Nenhum esporte visto recentemente'),
      );
    }
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          label: 'Último esporte visto: ${sport!.name}',
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Image.asset(
                  sport!.image,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sport!.name,
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        sport!.description,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SportCard extends StatelessWidget {
  final Sport sport;
  final VoidCallback? onTap;

  const SportCard({super.key, required this.sport, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          label: 'Esporte: ${sport.name}',
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Image.asset(
                  sport.image,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sport.name,
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        sport.description,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SportDetailScreen extends StatelessWidget {
  final Sport sport;

  const SportDetailScreen({super.key, required this.sport});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(sport.name)),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                sport.image,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 100),
              ),
              const SizedBox(height: 16),
              Text(
                sport.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Popularidade: ${sport.popularity.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                sport.description,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
