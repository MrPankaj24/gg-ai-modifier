/// Documentation.
/// Documentation.

class BookmarkModel {
  /// Documentation.
  final String id;

  /// Documentation.
  final String name;

  /// memoryaddress
  final String address;

  /// Documentation.
  final int addressInt;

  /// data type
  final String dataType;

  /// Documentation.
  final dynamic currentValue;

  /// Documentation.
  final dynamic frozenValue;

  /// whether Freeze
  final bool isFrozen;

  /// Documentation.
  final String? packageName;

  /// Documentation.
  final int? pid;

  /// Documentation.
  final DateTime createdAt;

  /// Documentation.
  final DateTime updatedAt;

  /// Documentation.
  final String? note;

  const BookmarkModel({
    required this.id,
    required this.name,
    required this.address,
    required this.addressInt,
    required this.dataType,
    this.currentValue,
    this.frozenValue,
    this.isFrozen = false,
    this.packageName,
    this.pid,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  BookmarkModel copyWith({
    String? id,
    String? name,
    String? address,
    int? addressInt,
    String? dataType,
    dynamic currentValue,
    dynamic frozenValue,
    bool? isFrozen,
    String? packageName,
    int? pid,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? note,
  }) {
    return BookmarkModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      addressInt: addressInt ?? this.addressInt,
      dataType: dataType ?? this.dataType,
      currentValue: currentValue ?? this.currentValue,
      frozenValue: frozenValue ?? this.frozenValue,
      isFrozen: isFrozen ?? this.isFrozen,
      packageName: packageName ?? this.packageName,
      pid: pid ?? this.pid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'addressInt': addressInt,
      'dataType': dataType,
      'currentValue': currentValue,
      'frozenValue': frozenValue,
      'isFrozen': isFrozen,
      'packageName': packageName,
      'pid': pid,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'note': note,
    };
  }

  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    return BookmarkModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      addressInt: json['addressInt'] as int,
      dataType: json['dataType'] as String,
      currentValue: json['currentValue'],
      frozenValue: json['frozenValue'],
      isFrozen: json['isFrozen'] as bool? ?? false,
      packageName: json['packageName'] as String?,
      pid: json['pid'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      note: json['note'] as String?,
    );
  }

  @override
  String toString() {
    return 'BookmarkModel(name: $name, address: $address, type: $dataType)';
  }
}
