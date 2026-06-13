class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  int get totalPages => total == 0 ? 1 : (total / pageSize).ceil();
  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final rawItems = (json['items'] as List<dynamic>? ?? const <dynamic>[]);
    return PaginatedResponse<T>(
      items: rawItems
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      total: json['total'] as int? ?? rawItems.length,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? rawItems.length,
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T item) toJson) => {
    'items': items.map(toJson).toList(),
    'total': total,
    'page': page,
    'page_size': pageSize,
  };
}
