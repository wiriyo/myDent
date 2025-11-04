import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageSaverService {
  static const String _storageFileName = 'mydent_image_saver_path.txt';

  static Future<bool> saveImage(Uint8List imageBytes, String fileName) async {
    if (kIsWeb) {
      debugPrint('ImageSaverService is not available on web.');
      return false;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return _saveImageToDesktop(imageBytes);
    }

    final hasPermission = await _ensurePermission();
    if (!hasPermission) {
      debugPrint('Photos permission not granted.');
      return false;
    }

    try {
      await Gal.putImageBytes(imageBytes, name: fileName);
      debugPrint('Image saved to gallery using gal.');
      return true;
    } catch (e) {
      debugPrint('Error saving image with gal: $e');
      return false;
    }
  }

  static Future<bool> ensurePermission() => _ensurePermission();

  static Future<bool> _saveImageToDesktop(Uint8List bytes) async {
    try {
      final now = DateTime.now();
      final dayFolderName = DateFormat('dd_MM_yy').format(now);
      final baseFileName = DateFormat('ddMMyy_HHmm').format(now);

      final storedMyDent = await _loadStoredMyDentDirectory();
      final String? initialDirectory = await _resolveInitialDirectory(
        storedMyDent,
      );
      final String? pickedDirectory = await getDirectoryPath(
        initialDirectory: initialDirectory,
        confirmButtonText: 'Select Folder',
      );

      if (pickedDirectory == null) {
        return false;
      }

      final Directory? myDentDir = await _prepareMyDentDirectory(
        pickedDirectory,
      );
      if (myDentDir == null) {
        debugPrint('Unable to create myDent directory.');
        await _clearStoredMyDentDirectory();
        return false;
      }
      await _persistStoredMyDentDirectory(myDentDir.path);

      final Directory dayDirectory = Directory(
        p.join(myDentDir.path, dayFolderName),
      );
      if (!await dayDirectory.exists()) {
        await dayDirectory.create(recursive: true);
      }

      final String targetPath = await _resolveUniqueFilePath(
        directoryPath: dayDirectory.path,
        baseName: baseFileName,
        extension: '.png',
      );

      final File outFile = File(targetPath);
      await outFile.writeAsBytes(bytes);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to save image on desktop: $error');
      debugPrint('$stackTrace');
      return false;
    }
  }

  static Future<String?> _resolveInitialDirectory(String? storedMyDent) async {
    if (storedMyDent != null && await Directory(storedMyDent).exists()) {
      return storedMyDent;
    }

    if (storedMyDent != null) {
      await _clearStoredMyDentDirectory();
    }

    if (Platform.isWindows) {
      final String? userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final Directory picturesDir = Directory(
          p.join(userProfile, 'Pictures'),
        );
        if (await picturesDir.exists()) {
          return picturesDir.path;
        }
      }
    }

    if (Platform.isLinux || Platform.isMacOS) {
      final String? home = Platform.environment['HOME'];
      if (home != null) {
        final Directory picturesDir = Directory(p.join(home, 'Pictures'));
        if (await picturesDir.exists()) {
          return picturesDir.path;
        }
      }
    }

    final Directory fallback = await getApplicationDocumentsDirectory();
    return fallback.path;
  }

  static Future<Directory?> _prepareMyDentDirectory(String pickedPath) async {
    final Directory selectedDir = Directory(pickedPath);
    if (!await selectedDir.exists()) {
      return null;
    }

    final List<String> segments = p.split(selectedDir.path);
    final int myDentIndex = segments.lastIndexWhere(
      (segment) => segment.toLowerCase() == 'mydent',
    );
    if (myDentIndex != -1) {
      final String existingMyDentPath = p.joinAll(
        segments.sublist(0, myDentIndex + 1),
      );
      return Directory(existingMyDentPath);
    }

    if (p.basename(selectedDir.path).toLowerCase() == 'mydent') {
      return selectedDir;
    }

    final Directory myDentDir = Directory(p.join(selectedDir.path, 'myDent'));
    if (!await myDentDir.exists()) {
      await myDentDir.create(recursive: true);
    }
    return myDentDir;
  }

  static Future<String> _resolveUniqueFilePath({
    required String directoryPath,
    required String baseName,
    required String extension,
  }) async {
    String candidate = p.join(directoryPath, '$baseName$extension');
    int counter = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(directoryPath, '${baseName}_$counter$extension');
      counter += 1;
    }
    return candidate;
  }

  static Future<bool> _ensurePermission() async {
    if (kIsWeb) return false;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return true;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      PermissionStatus storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
      }
      if (storageStatus.isGranted) {
        return true;
      }

      PermissionStatus photosStatus = await Permission.photos.status;
      if (!photosStatus.isGranted && !photosStatus.isLimited) {
        photosStatus = await Permission.photos.request();
      }
      if (photosStatus.isGranted || photosStatus.isLimited) {
        return true;
      }

      return false;
    }

    PermissionStatus status = await Permission.photos.status;
    if (!status.isGranted && !status.isLimited) {
      status = await Permission.photos.request();
    }
    return status.isGranted || status.isLimited;
  }

  static Future<File> _resolveStorageFile() async {
    final Directory supportDir = await getApplicationSupportDirectory();
    return File(p.join(supportDir.path, _storageFileName));
  }

  static Future<String?> _loadStoredMyDentDirectory() async {
    try {
      final File storageFile = await _resolveStorageFile();
      if (!await storageFile.exists()) {
        return null;
      }
      final String contents = (await storageFile.readAsString()).trim();
      if (contents.isEmpty) {
        return null;
      }
      final Directory dir = Directory(contents);
      if (await dir.exists()) {
        return dir.path;
      }
      await _clearStoredMyDentDirectory();
    } catch (error) {
      debugPrint('Failed to load stored myDent directory: $error');
    }
    return null;
  }

  static Future<void> _persistStoredMyDentDirectory(String path) async {
    try {
      final File storageFile = await _resolveStorageFile();
      await storageFile.writeAsString(path, flush: true);
    } catch (error) {
      debugPrint('Failed to persist myDent directory path: $error');
    }
  }

  static Future<void> _clearStoredMyDentDirectory() async {
    try {
      final File storageFile = await _resolveStorageFile();
      if (await storageFile.exists()) {
        await storageFile.delete();
      }
    } catch (error) {
      debugPrint('Failed to clear stored myDent directory path: $error');
    }
  }
}
