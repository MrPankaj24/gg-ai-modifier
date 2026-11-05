/// process information data model

/// process information
class ProcessInfo {
  /// process  ID
  final int pid;

  /// Documentation.
  final String packageName;

  /// process name
  final String processName;

  /// User ID
  final int uid;

  /// whether  to Systemprocess
  final bool isSystem;

  /// Documentation.
  final String? iconPath;

  const ProcessInfo({
    required this.pid,
    required this.packageName,
    required this.processName,
    this.uid = 0,
    this.isSystem = false,
    this.iconPath,
  });

  ProcessInfo copyWith({
    int? pid,
    String? packageName,
    String? processName,
    int? uid,
    bool? isSystem,
    String? iconPath,
  }) {
    return ProcessInfo(
      pid: pid ?? this.pid,
      packageName: packageName ?? this.packageName,
      processName: processName ?? this.processName,
      uid: uid ?? this.uid,
      isSystem: isSystem ?? this.isSystem,
      iconPath: iconPath ?? this.iconPath,
    );
  }

  /// Documentation.
  String get displayName => processName.isNotEmpty && processName != packageName
      ? processName
      : packageName;

  /// Documentation.
  String get shortName {
    final parts = packageName.split('.');
    return parts.isNotEmpty ? parts.last : packageName;
  }

  Map<String, dynamic> toJson() {
    return {
      'pid': pid,
      'packageName': packageName,
      'processName': processName,
      'uid': uid,
      'isSystem': isSystem,
      'iconPath': iconPath,
    };
  }

  factory ProcessInfo.fromJson(Map<String, dynamic> json) {
    return ProcessInfo(
      pid: json['pid'] as int,
      packageName: json['packageName'] as String? ?? '',
      processName: json['processName'] as String? ?? '',
      uid: json['uid'] as int? ?? 0,
      isSystem: json['isSystem'] as bool? ?? false,
      iconPath: json['iconPath'] as String?,
    );
  }

  @override
  String toString() {
    return 'ProcessInfo(pid: $pid, package: $packageName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProcessInfo && other.pid == pid;
  }

  @override
  int get hashCode => pid.hashCode;
}
