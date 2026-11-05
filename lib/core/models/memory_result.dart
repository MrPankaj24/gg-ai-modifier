/// Memory searchresults data model

/// support  of data type
enum DataType {
  byte(1, 'Byte'),
  word(2, 'Word'),
  dword(4, 'DWord'),
  qword(8, 'QWord'),
  float(4, 'Float'),
  double(8, 'Double'),
  string(0, 'String');

  final int size;
  final String displayName;

  const DataType(this.size, this.displayName);

  /// Documentation.
  static DataType fromString(String value) {
    return DataType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => DataType.dword,
    );
  }
}

/// Memory searchresults
class MemoryResult {
  /// Documentation.
  final String address;

  /// Documentation.
  final int addressInt;

  /// current value
  final dynamic value;

  /// data type
  final DataType type;

  /// Documentation.
  final bool isFavorite;

  /// whether Freeze
  final bool isFrozen;

  /// Freeze of value  (if Freeze)
  final dynamic frozenValue;

  /// Documentation.
  final String? regionName;

  const MemoryResult({
    required this.address,
    required this.addressInt,
    required this.value,
    required this.type,
    this.isFavorite = false,
    this.isFrozen = false,
    this.frozenValue,
    this.regionName,
  });

  MemoryResult copyWith({
    String? address,
    int? addressInt,
    dynamic value,
    DataType? type,
    bool? isFavorite,
    bool? isFrozen,
    dynamic frozenValue,
    String? regionName,
  }) {
    return MemoryResult(
      address: address ?? this.address,
      addressInt: addressInt ?? this.addressInt,
      value: value ?? this.value,
      type: type ?? this.type,
      isFavorite: isFavorite ?? this.isFavorite,
      isFrozen: isFrozen ?? this.isFrozen,
      frozenValue: frozenValue ?? this.frozenValue,
      regionName: regionName ?? this.regionName,
    );
  }

  /// Documentation.
  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'addressInt': addressInt,
      'value': value,
      'type': type.name,
      'isFavorite': isFavorite,
      'isFrozen': isFrozen,
      'frozenValue': frozenValue,
      'regionName': regionName,
    };
  }

  /// Documentation.
  factory MemoryResult.fromJson(Map<String, dynamic> json) {
    return MemoryResult(
      address: json['address'] as String,
      addressInt: json['addressInt'] as int,
      value: json['value'],
      type: DataType.fromString(json['type'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
      isFrozen: json['isFrozen'] as bool? ?? false,
      frozenValue: json['frozenValue'],
      regionName: json['regionName'] as String?,
    );
  }

  @override
  String toString() {
    return 'MemoryResult(address: $address, value: $value, type: ${type.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MemoryResult && other.addressInt == addressInt;
  }

  @override
  int get hashCode => addressInt.hashCode;
}

/// Documentation.
class MemoryRegion {
  /// Documentation.
  final int startAddress;

  /// Documentation.
  final int endAddress;

  /// Documentation.
  final int size;

  /// permission (rwxp)
  final String permissions;

  /// Documentation.
  final bool isReadable;

  /// Documentation.
  final bool isWritable;

  /// Documentation.
  final bool isExecutable;

  /// Documentation.
  final bool isAnonymous;

  /// Documentation.
  final String? name;

  const MemoryRegion({
    required this.startAddress,
    required this.endAddress,
    required this.size,
    required this.permissions,
    this.isReadable = false,
    this.isWritable = false,
    this.isExecutable = false,
    this.isAnonymous = false,
    this.name,
  });

  /// Documentation.
  String get startHex => '0x${startAddress.toRadixString(16).toUpperCase()}';

  /// Documentation.
  String get endHex => '0x${endAddress.toRadixString(16).toUpperCase()}';

  /// Documentation.
  bool get isSearchable => isReadable && isAnonymous;

  Map<String, dynamic> toJson() {
    return {
      'startAddress': startAddress,
      'endAddress': endAddress,
      'size': size,
      'permissions': permissions,
      'isReadable': isReadable,
      'isWritable': isWritable,
      'isExecutable': isExecutable,
      'isAnonymous': isAnonymous,
      'name': name,
    };
  }

  factory MemoryRegion.fromJson(Map<String, dynamic> json) {
    return MemoryRegion(
      startAddress: json['startAddress'] as int,
      endAddress: json['endAddress'] as int,
      size: json['size'] as int,
      permissions: json['permissions'] as String,
      isReadable: json['isReadable'] as bool? ?? false,
      isWritable: json['isWritable'] as bool? ?? false,
      isExecutable: json['isExecutable'] as bool? ?? false,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      name: json['name'] as String?,
    );
  }
}

/// Documentation.
class WriteRequest {
  /// Documentation.
  final int address;

  /// write  of value
  final dynamic value;

  /// data type
  final DataType type;

  const WriteRequest({
    required this.address,
    required this.value,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {'address': address, 'value': value, 'type': type.name};
  }
}
