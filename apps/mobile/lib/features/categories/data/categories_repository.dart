import '../../../core/network/api_client.dart';

/// A marketplace service category, served from GET /categories. `key` maps to
/// a ride `vertical` used as the search filter.
class Category {
  const Category({
    required this.key,
    required this.label,
    required this.tagline,
    required this.icon,
    required this.active,
    required this.comingSoon,
    required this.sort,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        key: j['key'] as String? ?? '',
        label: j['label'] as String? ?? '',
        tagline: j['tagline'] as String? ?? '',
        icon: j['icon'] as String? ?? '',
        active: j['active'] as bool? ?? false,
        comingSoon: j['comingSoon'] as bool? ?? false,
        sort: (j['sort'] as num?)?.toInt() ?? 0,
      );

  final String key;
  final String label;
  final String tagline;
  final String icon;
  final bool active;
  final bool comingSoon;
  final int sort;
}

class CategoriesRepository {
  CategoriesRepository(this._api);
  final ApiClient _api;

  Future<List<Category>> list() async {
    final res = await _api.getList('/categories');
    return res
        .cast<Map<String, dynamic>>()
        .map(Category.fromJson)
        .toList();
  }
}
