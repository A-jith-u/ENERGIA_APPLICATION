import 'dart:io' show File, Platform, Directory;
import 'package:path_provider/path_provider.dart';

/// Export user data as CSV with separate sections for Coordinators, Class Representatives, and Sergeants.
/// Returns the file path on desktop platforms, null on mobile/web (fallback to share).
Future<String?> exportUsersCSV({
  required List<Map<String, String>> coordinators,
  required List<Map<String, String>> classReps,
  List<Map<String, String>>? sergeants,
}) async {
  Future<Directory?> resolveDownloadsDir() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (dirs != null && dirs.isNotEmpty) return dirs.first;
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return getDownloadsDirectory();
    }
    return null;
  }

  final buffer = StringBuffer();
  
  // Header
  buffer.writeln('ENERGIA USER DETAILS ');
  buffer.writeln('GENERATED: ${DateTime.now()}');
  buffer.writeln('');
  
  // Coordinators Section
  buffer.writeln('========== COORDINATORS ==========');
  buffer.writeln('NAME,KTU-ID,DEPARTMENT');
  for (var coord in coordinators) {
    buffer.writeln('${coord['name']},${coord['ktuid']},${coord['department']}');
  }
  buffer.writeln('');
  buffer.writeln('TOTAL COORDINATORS: ${coordinators.length}');
  buffer.writeln('');
  buffer.writeln('');
  
  // Class Representatives Section
  buffer.writeln('========== CLASS REPRESENTATIVES ==========');
  buffer.writeln('NAME,KTU-ID,DEPARTMENT,ROOM NO,YEAR,GENDER');
  for (var rep in classReps) {
    buffer.writeln('${rep['name']},${rep['ktuid']},${rep['department']},${rep['room']},${rep['year']},${rep['gender']}');
  }
  buffer.writeln('');
  buffer.writeln('TOTAL CLASS REPRESENTATIVES: ${classReps.length}');
  buffer.writeln('');
  buffer.writeln('');
  
  // Sergeants Section (if provided)
  if (sergeants != null && sergeants.isNotEmpty) {
    buffer.writeln('========== SERGEANTS ==========');
    buffer.writeln('NAME,EMAIL,DEPARTMENT');
    for (var sgt in sergeants) {
      buffer.writeln('${sgt['name']},${sgt['email']},${sgt['department']}');
    }
    buffer.writeln('');
    buffer.writeln('TOTAL SERGEANTS: ${sergeants.length}');
    buffer.writeln('');
    buffer.writeln('');
  }
  
  // Summary Footer
  buffer.writeln('========= SUMMARY =========');
  final totalUsers = coordinators.length + classReps.length + (sergeants?.length ?? 0);
  buffer.writeln('TOTAL USERS: $totalUsers');
  buffer.writeln('COORDINATORS: ${coordinators.length}');
  buffer.writeln('CLASS REPRESENTATIVES: ${classReps.length}');
  if (sergeants != null && sergeants.isNotEmpty) {
    buffer.writeln('SERGEANTS: ${sergeants.length}');
  }
  
  final csvContent = buffer.toString();
  final fileName = 'Energia_users_${DateTime.now().millisecondsSinceEpoch}.csv';

  final downloadsDir = await resolveDownloadsDir();
  if (downloadsDir != null) {
    final filePath = '${downloadsDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsString(csvContent);
    return filePath;
  }

  // Mobile/Web fallback (not implemented here, could use share package)
  return null;
}
