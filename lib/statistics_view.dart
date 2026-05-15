import 'package:flutter/material.dart';

import 'history_view.dart';

class StatisticsView extends StatelessWidget {
  final List<GameHistory> history;

  const StatisticsView({
    super.key,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(
        child: Text(
          'No statistics yet',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    final groupedByCourse = _groupHistoryByCourse(history);
    final sortedCourseNames = groupedByCourse.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedCourseNames.length,
      itemBuilder: (context, index) {
        final courseName = sortedCourseNames[index];
        final games = groupedByCourse[courseName] ?? <GameHistory>[];
        final sortedGames = List<GameHistory>.from(games)
          ..sort((a, b) =>
              _parseDateTime(b.date).compareTo(_parseDateTime(a.date)));

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildCoursePlayerStatsTable(sortedGames),
                const SizedBox(height: 8),
                _buildPlayerBoxes(sortedGames),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, List<GameHistory>> _groupHistoryByCourse(
      List<GameHistory> games) {
    final Map<String, List<GameHistory>> grouped = {};
    for (final game in games) {
      final course = game.courseName.trim().isEmpty
          ? 'Unnamed Course'
          : game.courseName.trim();
      grouped.putIfAbsent(course, () => <GameHistory>[]).add(game);
    }
    return grouped;
  }

  DateTime _parseDateTime(String dateStr) {
    try {
      final parts = dateStr.split(' ');
      if (parts.length != 2) return DateTime.fromMillisecondsSinceEpoch(0);

      final dateParts = parts[0].split('/');
      final timeParts = parts[1].split(':');
      if (dateParts.length != 3 || timeParts.length != 2) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }

      final month = int.parse(dateParts[0]);
      final day = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  int _calculatePlayerGameTotal(GameHistory game, int playerIndex) {
    if (playerIndex >= game.scores.length) return 0;
    int total = 0;
    for (final score in game.scores[playerIndex]) {
      final parsed = int.tryParse(score.trim());
      if (parsed != null) {
        total += parsed;
      }
    }
    return total;
  }

  Widget _buildPlayerBoxes(List<GameHistory> sortedGames) {
    // Collect unique player names in first-seen order across all games
    final List<String> allPlayers = [];
    for (final game in sortedGames) {
      for (int i = 0; i < game.numPlayers; i++) {
        final name = i < game.playerNames.length
            ? game.playerNames[i]
            : 'Player ${i + 1}';
        if (!allPlayers
            .any((p) => p.trim().toLowerCase() == name.trim().toLowerCase())) {
          allPlayers.add(name);
        }
      }
    }

    if (allPlayers.isEmpty) return const SizedBox.shrink();

    final maxHoles =
        sortedGames.fold<int>(0, (m, g) => g.numHoles > m ? g.numHoles : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: allPlayers.map((playerName) {
        final playerGames = sortedGames.where((game) {
          return game.playerNames.any(
              (n) => n.trim().toLowerCase() == playerName.trim().toLowerCase());
        }).toList();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playerName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child:
                    _buildPlayerScoreTable(playerName, playerGames, maxHoles),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlayerScoreTable(
      String playerName, List<GameHistory> games, int maxHoles) {
    final columns = <DataColumn>[
      const DataColumn(
          label: Text('Holes', style: TextStyle(fontWeight: FontWeight.bold))),
      ...List.generate(
          maxHoles,
          (i) => DataColumn(
              label: Text('${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600)))),
    ];

    final rows = games.map((game) {
      int playerIndex = -1;
      for (int i = 0; i < game.playerNames.length; i++) {
        if (game.playerNames[i].trim().toLowerCase() ==
            playerName.trim().toLowerCase()) {
          playerIndex = i;
          break;
        }
      }

      final cells = <DataCell>[DataCell(Text(game.date))];

      for (int hole = 0; hole < maxHoles; hole++) {
        String score = '';
        if (hole < game.numHoles) {
          if (playerIndex >= 0 &&
              playerIndex < game.scores.length &&
              hole < game.scores[playerIndex].length) {
            final raw = game.scores[playerIndex][hole].trim();
            score = raw.isEmpty ? '-' : raw;
          } else {
            score = '-';
          }
        }
        cells.add(DataCell(Text(score)));
      }

      return DataRow(cells: cells);
    }).toList();

    return DataTable(
      columnSpacing: 18,
      horizontalMargin: 8,
      dataRowMinHeight: 28,
      dataRowMaxHeight: 36,
      headingRowHeight: 36,
      columns: columns,
      rows: rows,
    );
  }

  Widget _buildCoursePlayerStatsTable(List<GameHistory> courseGames) {
    final Map<String, List<int>> playerTotals = {};

    for (final game in courseGames) {
      for (int i = 0; i < game.numPlayers; i++) {
        final name = i < game.playerNames.length
            ? game.playerNames[i]
            : 'Player ${i + 1}';
        final total = _calculatePlayerGameTotal(game, i);
        playerTotals.putIfAbsent(name, () => <int>[]).add(total);
      }
    }

    final players = playerTotals.keys.toList()..sort();
    if (players.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Player')),
          DataColumn(label: Text('Games')),
          DataColumn(label: Text('Avg')),
          DataColumn(label: Text('Low')),
          DataColumn(label: Text('High')),
        ],
        rows: players.map((player) {
          final totals = playerTotals[player] ?? <int>[];
          final games = totals.length;
          final sum = totals.fold<int>(0, (a, b) => a + b);
          final avg = games == 0 ? 0.0 : sum / games;
          final low =
              totals.isEmpty ? 0 : totals.reduce((a, b) => a < b ? a : b);
          final high =
              totals.isEmpty ? 0 : totals.reduce((a, b) => a > b ? a : b);

          return DataRow(
            cells: [
              DataCell(Text(player)),
              DataCell(Text(games.toString())),
              DataCell(Text(avg.toStringAsFixed(1))),
              DataCell(Text(low.toString())),
              DataCell(Text(high.toString())),
            ],
          );
        }).toList(),
      ),
    );
  }
}
