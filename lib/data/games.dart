import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:isolated_worker/isolated_worker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xml/xml_events.dart';
import 'package:collection/collection.dart';

import 'package:titanius/data/repo.dart';
import 'package:titanius/data/models.dart';
import 'package:titanius/data/systems.dart';

part 'games.g.dart';

class GameList {
  final System system;
  final String currentFolder;
  final List<Game> games;
  final int Function(Game, Game)? compare;

  const GameList(this.system, this.currentFolder, this.games, this.compare);
}

@Riverpod(keepAlive: true)
Future<List<Game>> allGames(AllGamesRef ref) async {
  final detectedSystems = await ref.watch(detectedSystemsProvider.future);
  final romFolders = await ref.watch(romFoldersProvider.future);

  final allGames = <Game>[];

  if (detectedSystems.isEmpty) {
    return [];
  }

  final stopwatch = Stopwatch()..start();

  try {
    List<Future<List<Game>>> tasks = [];
    for (var system in detectedSystems) {
      for (var romsFolder in romFolders) {
        for (var folder in system.folders) {
          final task = IsolatedWorker().run(_processFolder, GamelistTaskParams(romsFolder, folder, system));
          tasks.add(task);
        }
      }
    }

    final results = await Future.wait(tasks);
    for (var r in results) {
      allGames.addAll(r);
    }
  } finally {
    stopwatch.stop();
    debugPrint("Gamelist parsing took ${stopwatch.elapsedMilliseconds}ms");
  }

  return allGames;
}

class GamelistTaskParams {
  final String romsFolder;
  final String folder;
  final System system;

  GamelistTaskParams(this.romsFolder, this.folder, this.system);
}

Future<List<Game>> _processFolder(GamelistTaskParams params) async {
  try {
    final romsPath = "${params.romsFolder}/${params.folder}";
    final pathExists = await Directory(romsPath).exists();
    if (!pathExists) {
      return [];
    }
    final gamelistPath = "$romsPath/gamelist.xml";
    final file = File(gamelistPath);
    final exists = await file.exists();
    var gamesFromGamelistXml = [];
    if (exists) {
      gamesFromGamelistXml = await file
          .openRead()
          .transform(utf8.decoder)
          .toXmlEvents()
          .normalizeEvents()
          .selectSubtreeEvents((event) => event.name == 'game' || event.name == 'folder')
          .toXmlNodes()
          .expand((nodes) => nodes)
          .map((node) => Game.fromXmlNode(node, params.system, params.romsFolder, params.folder))
          .toList();
    }
    final dir = Directory(romsPath);
    final allFiles = dir.listSync(recursive: true, followLinks: false);
    final gamesFromGamelistXmlMap = {for (var e in gamesFromGamelistXml) e.absoluteRomPath: e};
    // remove games that are already in the gamelist
    allFiles.removeWhere((element) => gamesFromGamelistXmlMap.containsKey(element.absolute.path));
    // remove non-roms
    allFiles.removeWhere((element) => _nonRom(element));
    final gamesFromFiles =
        allFiles.map((file) => Game.fromFile(file, params.system, params.romsFolder, params.folder)).toList();
    return [...gamesFromGamelistXml, ...gamesFromFiles];
  } catch (e) {
    debugPrint("Error processing folder ${params.folder}: $e");
    return [];
  }
}

bool _nonRom(FileSystemEntity element) {
  if (element is Directory) {
    return true;
  }
  final fileName = element.uri.pathSegments.last;
  if (fileName.contains("gamelist")) {
    return true;
  }
  if (fileName.startsWith(".") || fileName.startsWith("ZZZ")) {
    return true;
  }
  return fileName.endsWith(".mp4") ||
      fileName.endsWith(".png") ||
      fileName.endsWith(".jpg") ||
      fileName.endsWith(".jpeg") ||
      fileName.endsWith(".gif") ||
      fileName.endsWith(".txt") ||
      fileName.endsWith(".cfg");
}

@Riverpod(keepAlive: true)
Future<GameList> games(GamesRef ref, String systemId) async {
  final allGamelistGames = await ref.watch(allGamesProvider.future);
  final systems = await ref.watch(allSupportedSystemsProvider.future);
  final settings = await ref.watch(settingsProvider.future);
  final recentGames = await ref.watch(recentGamesProvider.future);

  final system = systems.firstWhere((system) => system.id == systemId);

  final allGames = [...allGamelistGames];
  if (!settings.showHiddenGames) {
    allGames.removeWhere((game) => game.hidden);
  }

  if (settings.checkMissingGames) {
    Stopwatch stopwatch = Stopwatch()..start();
    allGames.retainWhere((game) =>
        game.isFolder ? Directory(game.absoluteRomPath).existsSync() : File(game.absoluteRomPath).existsSync());
    stopwatch.stop();
    debugPrint("checkMissingGames took ${stopwatch.elapsedMilliseconds}ms");
  }

  switch (system.id) {
    case "favourites":
      compare(Game a, Game b) => a.name.compareTo(b.name);
      final games = allGames.where((game) => game.favorite).sorted(compare);
      final gamesInCollection = settings.uniqueGamesInCollections ? _uniqueGames(games) : games;
      return GameList(system, ".", gamesInCollection, (a, b) => a.name.compareTo(b.name));
    case "recent":
      Map<String, int> recentGamesMap = {
        for (var item in recentGames) item.romPath: item.timestamp,
      };
      compare(Game a, Game b) => recentGamesMap[b.romPath]!.compareTo(recentGamesMap[a.romPath]!);
      final games = allGames.where((game) => recentGamesMap.containsKey(game.romPath)).sorted(compare);
      final gamesInCollection = settings.uniqueGamesInCollections ? _uniqueGames(games) : games;
      return GameList(
        system,
        ".",
        gamesInCollection,
        compare,
      );
    case "all":
      final sorter = GameSorter(settings);
      final gamesButNotFolders = allGames.where((game) => !game.isFolder).toList();
      final games = settings.uniqueGamesInCollections ? _uniqueGames(gamesButNotFolders) : gamesButNotFolders;
      final gamesInCollection = _sortGames(settings, games);
      return GameList(system, ".", gamesInCollection, sorter.compare);
    default:
      final sorter = GameSorter(settings);
      final games = _sortGames(settings, allGames.where((game) => game.system.id == system.id).toList());
      return GameList(system, ".", games, sorter.compare);
  }
}

List<Game> _uniqueGames(List<Game> allGames) {
  final roms = <String>{};
  final uniqueGames = [...allGames];
  uniqueGames.retainWhere((game) => roms.add(game.uniqueKey));
  return uniqueGames;
}

List<Game> _sortGames(Settings settings, List<Game> allGames) {
  final sorter = GameSorter(settings);
  return allGames.sorted(sorter.compare);
}

class GameSorter {
  final Settings settings;

  GameSorter(this.settings);

  int compare(Game a, Game b) {
    // folders on top
    if (a.isFolder && b.isFolder) {
      return a.name.compareTo(b.name);
    }
    if (a.isFolder) {
      return -1;
    }
    if (b.isFolder) {
      return 1;
    }
    if (settings.favouritesOnTop) {
      if (a.favorite && b.favorite) {
        final c = a.name.compareTo(b.name);
        if (c == 0) {
          return a.rom.compareTo(b.rom);
        } else {
          return c;
        }
      }
      if (a.favorite) {
        return -1;
      }
      if (b.favorite) {
        return 1;
      }
    }
    final c = a.name.compareTo(b.name);
    if (c == 0) {
      return a.rom.compareTo(b.rom);
    } else {
      return c;
    }
  }
}
