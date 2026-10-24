// Confinement tests for FilePersistenceService.readTrack / deleteTrack.
//
// A note's `gpx_file` value is untrusted input, so a track name must never
// reach a file outside the vault's Tracks/ folder, whether by traversal,
// absolute or nested paths, other separators, or a symbolic link.
//
// Everything runs in a temporary directory. "Outside" files are created next
// to (and above) the vault and are checked for unchanged content after every
// rejected attempt.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/services/FilePersistenceService.dart';
import 'package:path/path.dart' as p;

const String _trackXml = '<gpx version="1.1"><trk/></gpx>';
const String _outsideContent = 'OUTSIDE: must never be read or changed';

/// True when this platform/account can create symbolic links. Probed
/// synchronously so it can feed `skip:` at declaration time.
final bool _symlinksSupported = _probeSymlinks();

bool _probeSymlinks() {
  final dir = Directory.systemTemp.createTempSync('obsidianfit_link_probe_');
  try {
    final target = File(p.join(dir.path, 'target.txt'))..writeAsStringSync('x');
    Link(p.join(dir.path, 'link.txt')).createSync(target.path);
    return true;
  } on FileSystemException {
    return false;
  } on UnsupportedError {
    return false;
  } finally {
    dir.deleteSync(recursive: true);
  }
}

const String _noSymlinks = 'symbolic links are not supported here';

void main() {
  late Directory root;
  late Directory vaultDir;
  late Directory tracksDir;
  late FilePersistenceService vault;

  /// `<vault>/outside.gpx`: what `../outside.gpx` from Tracks/ points at.
  late File siblingOutside;

  /// `<root>/elsewhere/secret.gpx`: completely outside the vault.
  late File farOutside;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('obsidianfit_track_path_');
    vaultDir = Directory(p.join(root.path, 'vault'));
    vault = FilePersistenceService(vaultDir);
    await vault.ensureStructure();
    tracksDir =
        Directory(p.join(vaultDir.path, FilePersistenceService.tracksFolder));

    siblingOutside = File(p.join(vaultDir.path, 'outside.gpx'));
    await siblingOutside.writeAsString(_outsideContent);
    final elsewhere = Directory(p.join(root.path, 'elsewhere'));
    await elsewhere.create();
    farOutside = File(p.join(elsewhere.path, 'secret.gpx'));
    await farOutside.writeAsString(_outsideContent);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> putTrack(String name, [String content = _trackXml]) async {
    final file = File(p.join(tracksDir.path, name));
    await file.writeAsString(content);
    return file;
  }

  Future<void> expectOutsideUntouched() async {
    for (final f in [siblingOutside, farOutside]) {
      expect(await f.exists(), isTrue, reason: '${f.path} was deleted');
      expect(await f.readAsString(), _outsideContent,
          reason: '${f.path} was modified');
    }
  }

  Matcher rejects() => throwsA(isA<FileSystemException>());

  group('normal behaviour is unchanged', () {
    test('reads a bare .gpx track', () async {
      await putTrack('2026-10-22_1730_Route.gpx');

      expect(await vault.readTrack('2026-10-22_1730_Route.gpx'), _trackXml);
    });

    test('reads what saveGpx wrote, by basename', () async {
      final saved =
          await vault.saveGpx(DateTime(2026, 10, 22, 17, 30), _trackXml);

      expect(await vault.readTrack(p.basename(saved.path)), _trackXml);
    });

    test('accepts spaces and an upper-case extension', () async {
      await putTrack('Morning Run.GPX');

      expect(await vault.readTrack('Morning Run.GPX'), _trackXml);
    });

    test('a missing track throws FileSystemException on read', () async {
      await expectLater(vault.readTrack('nope.gpx'), rejects());
    });

    test('a missing Tracks folder throws on read, is ignored on delete',
        () async {
      final bare = FilePersistenceService(Directory(p.join(root.path, 'bare')));

      await expectLater(bare.readTrack('a.gpx'), rejects());
      await bare.deleteTrack('a.gpx');
    });

    test('deleting a missing track is ignored', () async {
      await vault.deleteTrack('nope.gpx');
    });

    test('deleting removes only the named track', () async {
      final target = await putTrack('a.gpx');
      final other = await putTrack('b.gpx');

      await vault.deleteTrack('a.gpx');

      expect(await target.exists(), isFalse);
      expect(await other.exists(), isTrue);
      await expectOutsideUntouched();
    });
  });

  group('rejected names (read and delete)', () {
    // The first group of names would reach an outside file if joined naively.
    final hostile = <String, String Function()>{
      'parent traversal': () => '../outside.gpx',
      'deep traversal': () => '../../elsewhere/secret.gpx',
      'traversal inside a subfolder': () => 'sub/../../outside.gpx',
      'absolute path': () => farOutside.path,
      'absolute POSIX path': () => '/etc/passwd.gpx',
      'backslash traversal': () => r'..\outside.gpx',
      'backslash nested': () => r'sub\route.gpx',
      'Windows absolute path': () => r'C:\Users\me\route.gpx',
      'Windows drive-relative': () => 'C:route.gpx',
      'nested path': () => 'sub/route.gpx',
      'dot-slash prefix': () => './route.gpx',
    };
    final malformed = <String, String>{
      'empty': '',
      'blank': '   ',
      'single dot': '.',
      'double dot': '..',
      'extension only': '.gpx',
      'wrong extension': 'route.txt',
      'no extension': 'route',
      'markdown note': 'note.md',
      'extension then suffix': 'route.gpx.txt',
      'trailing space after extension': 'route.gpx ',
      'NUL byte': 'a\u0000.gpx',
    };

    for (final entry in hostile.entries) {
      test('rejects ${entry.key}', () async {
        final name = entry.value();
        await putTrack('route.gpx');

        await expectLater(vault.readTrack(name), rejects());
        await expectLater(vault.deleteTrack(name), rejects());

        await expectOutsideUntouched();
        expect(
            await File(p.join(tracksDir.path, 'route.gpx')).exists(), isTrue);
      });
    }

    for (final entry in malformed.entries) {
      test('rejects ${entry.key}', () async {
        await expectLater(vault.readTrack(entry.value), rejects());
        await expectLater(vault.deleteTrack(entry.value), rejects());

        await expectOutsideUntouched();
      });
    }

    test('a file in a Tracks subfolder is not reachable by name', () async {
      final nested = Directory(p.join(tracksDir.path, 'sub'));
      await nested.create();
      final inner = File(p.join(nested.path, 'inner.gpx'))
        ..writeAsStringSync(_trackXml);

      await expectLater(vault.readTrack('sub/inner.gpx'), rejects());
      await expectLater(vault.deleteTrack('sub/inner.gpx'), rejects());

      expect(await inner.readAsString(), _trackXml);
      await expectOutsideUntouched();
    });

    test('a non-.gpx file inside Tracks is neither read nor deleted', () async {
      final txt = await putTrack('secret.txt', 'not a track');

      await expectLater(vault.readTrack('secret.txt'), rejects());
      await expectLater(vault.deleteTrack('secret.txt'), rejects());

      expect(await txt.readAsString(), 'not a track');
    });

    test('a directory named like a track is not deleted', () async {
      final dir = Directory(p.join(tracksDir.path, 'folder.gpx'));
      await dir.create();

      await vault.deleteTrack('folder.gpx');

      expect(await dir.exists(), isTrue);
    });
  });

  group('symbolic links', () {
    test('a link to a file outside Tracks cannot be read', () async {
      final link = Link(p.join(tracksDir.path, 'escape.gpx'));
      await link.create(farOutside.path);

      await expectLater(vault.readTrack('escape.gpx'), rejects());

      await expectOutsideUntouched();
    }, skip: _symlinksSupported ? false : _noSymlinks);

    test('a link to a file outside Tracks cannot be used to delete it',
        () async {
      final link = Link(p.join(tracksDir.path, 'escape.gpx'));
      await link.create(farOutside.path);
      final link2 = Link(p.join(tracksDir.path, 'escape2.gpx'));
      await link2.create(siblingOutside.path);

      await expectLater(vault.deleteTrack('escape.gpx'), rejects());
      await expectLater(vault.deleteTrack('escape2.gpx'), rejects());

      await expectOutsideUntouched();
      expect(await link.exists(), isTrue, reason: 'rejected: link untouched');
    }, skip: _symlinksSupported ? false : _noSymlinks);

    test('a relative link out of Tracks is rejected too', () async {
      final link = Link(p.join(tracksDir.path, 'rel.gpx'));
      await link.create(p.join('..', 'outside.gpx'));

      await expectLater(vault.readTrack('rel.gpx'), rejects());
      await expectLater(vault.deleteTrack('rel.gpx'), rejects());

      await expectOutsideUntouched();
    }, skip: _symlinksSupported ? false : _noSymlinks);

    test('a dangling link counts as a missing track', () async {
      final link = Link(p.join(tracksDir.path, 'dangling.gpx'));
      await link.create(p.join(root.path, 'does_not_exist.gpx'));

      await expectLater(vault.readTrack('dangling.gpx'), rejects());
      await vault.deleteTrack('dangling.gpx');

      await expectOutsideUntouched();
    }, skip: _symlinksSupported ? false : _noSymlinks);

    test('a link to another file inside Tracks still works', () async {
      await putTrack('real.gpx');
      await Link(p.join(tracksDir.path, 'alias.gpx'))
          .create(p.join(tracksDir.path, 'real.gpx'));

      expect(await vault.readTrack('alias.gpx'), _trackXml);

      // Deleting the alias removes the link only, not its target.
      await vault.deleteTrack('alias.gpx');
      expect(await FileSystemEntity.type(p.join(tracksDir.path, 'alias.gpx')),
          FileSystemEntityType.notFound);
      expect(await File(p.join(tracksDir.path, 'real.gpx')).exists(), isTrue);
    }, skip: _symlinksSupported ? false : _noSymlinks);

    test('a Tracks folder that is itself a link keeps working', () async {
      final linkedVault = Directory(p.join(root.path, 'linked_vault'));
      final storage = Directory(p.join(root.path, 'storage'));
      await storage.create();
      await File(p.join(storage.path, 'a.gpx')).writeAsString(_trackXml);
      await Directory(p.join(linkedVault.path)).create();
      await Link(p.join(linkedVault.path, 'Tracks')).create(storage.path);
      final svc = FilePersistenceService(linkedVault);

      expect(await svc.readTrack('a.gpx'), _trackXml);
      await svc.deleteTrack('a.gpx');
      expect(await File(p.join(storage.path, 'a.gpx')).exists(), isFalse);
    }, skip: _symlinksSupported ? false : _noSymlinks);
  });
}
