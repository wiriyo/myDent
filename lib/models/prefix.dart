class Prefix {
  final String id;
  final String name;

  Prefix({required this.id, required this.name});

  factory Prefix.fromMap(Map<String, dynamic> data, String docId) {
    return Prefix(
      id: docId,
      name: data['name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
    };
  }
}
