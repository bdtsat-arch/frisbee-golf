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

  Widget _buildScoreLine(String label, List<String> values, String total) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 2),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...values.map(
                (value) => Container(
                  width: 28,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(value, style: const TextStyle(fontSize: 12)),
                ),
              ),
              Container(
                width: 34,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(total,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerBoxes(List<GameHistory> sortedGames) {
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

    allPlayers.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 700) {
                    return _buildPlayerScoreMobile(
                        playerName, playerGames, maxHoles);
                  }
                  return _buildPlayerScoreTable(
                      playerName, playerGames, maxHoles);
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlayerScoreMobile(
      String playerName, List<GameHistory> games, int maxHoles) {
    final parGame = games.firstWhere(
      (g) => g.parValues.length >= maxHoles,
      orElse: () => games.first,
    );

    final parValues = List<String>.generate(maxHoles, (hole) {
      if (hole < parGame.parValues.length) {
        return parGame.parValues[hole].toString();
      }
      return '';
    });
    final parTotal =
        parGame.parValues.take(maxHoles).fold<int>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Holes  ${List.generate(maxHoles, (i) => i + 1).join(' ')}  Total',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        _buildScoreLine('Par', parValues, parTotal.toString()),
        ...games.map((game) {
          int playerIndex = -1;
          for (int i = 0; i < game.playerNames.length; i++) {
            if (game.playerNames[i].trim().toLowerCase() ==
                playerName.trim().toLowerCase()) {
              playerIndex = i;
              break;
            }
          }

          final holeValues = List<String>.generate(maxHoles, (hole) {
            if (hole >= game.numHoles) return '';
            if (playerIndex < 0 ||
                playerIndex >= game.scores.length ||
                hole >= game.scores[playerIndex].length) {
              return '-';
            }
            final raw = game.scores[playerIndex][hole].trim();
            return raw.isEmpty ? '-' : raw;
          });
          final total = _calculatePlayerGameTotal(game, playerIndex);
          return _buildScoreLine(game.date, holeValues, total.toString());
        }),
        const SizedBox(height: 4),
        _buildSummaryLines(playerName, games, maxHoles),
      ],
    );
  }

  Widget _buildSummaryLines(
      String playerName, List<GameHistory> games, int maxHoles) {
    final holeScores = List<List<int>>.generate(maxHoles, (_) => []);
    final gameTotals = <int>[];
    for (final game in games) {
      int pi = -1;
      for (int i = 0; i < game.playerNames.length; i++) {
        if (game.playerNames[i].trim().toLowerCase() ==
            playerName.trim().toLowerCase()) {
          pi = i;
          break;
        }
      }
      if (pi < 0) continue;
      int gameTotal = 0;
      for (int hole = 0; hole < maxHoles; hole++) {
        if (hole < game.numHoles &&
            pi < game.scores.length &&
            hole < game.scores[pi].length) {
          final v = int.tryParse(game.scores[pi][hole].trim());
          if (v != null) {
            holeScores[hole].add(v);
            gameTotal += v;
          }
        }
      }
      gameTotals.add(gameTotal);
    }

    String perHoleValue(List<int> values, String kind) {
      if (values.isEmpty) return '';
      switch (kind) {
        case 'avg':
          return (values.fold(0, (a, b) => a + b) / values.length)
              .toStringAsFixed(1);
        case 'low':
          return values.reduce((a, b) => a < b ? a : b).toString();
        case 'high':
          return values.reduce((a, b) => a > b ? a : b).toString();
      }
      return '';
    }

    Widget buildSummaryRow(String label, String kind) {
      final values = List<String>.generate(
        maxHoles,
        (i) => perHoleValue(holeScores[i], kind),
      );
      final total = gameTotals.isEmpty
          ? ''
          : kind == 'avg'
              ? (gameTotals.fold(0, (a, b) => a + b) / gameTotals.length)
                  .toStringAsFixed(1)
              : kind == 'low'
                  ? gameTotals.reduce((a, b) => a < b ? a : b).toString()
                  : gameTotals.reduce((a, b) => a > b ? a : b).toString();
      return _buildScoreLine(label, values, total);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSummaryRow('Avg', 'avg'),
        buildSummaryRow('Low', 'low'),
        buildSummaryRow('High', 'high'),
      ],
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
      const DataColumn(
          label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
    ];

    // Build par row from the first game that has par values for this hole count
    final parGame = games.firstWhere(
      (g) => g.parValues.length >= maxHoles,
      orElse: () => games.first,
    );
    final parCells = <DataCell>[
      const DataCell(
          Text('Par', style: TextStyle(fontWeight: FontWeight.w600))),
    ];
    int parTotal = 0;
    for (int hole = 0; hole < maxHoles; hole++) {
      if (hole < parGame.parValues.length) {
        final p = parGame.parValues[hole];
        parCells.add(DataCell(Text(p.toString())));
        parTotal += p;
      } else {
        parCells.add(const DataCell(Text('')));
      }
    }
    parCells.add(DataCell(Text(parTotal.toString(),
        style: const TextStyle(fontWeight: FontWeight.w600))));
    final parRow = DataRow(cells: parCells);

    final gameRows = games.map((game) {
      int playerIndex = -1;
      for (int i = 0; i < game.playerNames.length; i++) {
        if (game.playerNames[i].trim().toLowerCase() ==
            playerName.trim().toLowerCase()) {
          playerIndex = i;
          break;
        }
      }

      final cells = <DataCell>[DataCell(Text(game.date))];
      int rowTotal = 0;

      for (int hole = 0; hole < maxHoles; hole++) {
        String score = '';
        if (hole < game.numHoles) {
          if (playerIndex >= 0 &&
              playerIndex < game.scores.length &&
              hole < game.scores[playerIndex].length) {
            final raw = game.scores[playerIndex][hole].trim();
            score = raw.isEmpty ? '-' : raw;
            rowTotal += int.tryParse(raw) ?? 0;
          } else {
            score = '-';
          }
        }
        cells.add(DataCell(Text(score)));
      }

      cells.add(DataCell(Text(playerIndex >= 0 ? rowTotal.toString() : '')));
      return DataRow(cells: cells);
    }).toList();

    // Collect per-hole scores for Avg / Low / High summary rows
    final holeScores = List<List<int>>.generate(maxHoles, (_) => []);
    final gameTotals = <int>[];
    for (final game in games) {
      int pi = -1;
      for (int i = 0; i < game.playerNames.length; i++) {
        if (game.playerNames[i].trim().toLowerCase() ==
            playerName.trim().toLowerCase()) {
          pi = i;
          break;
        }
      }
      if (pi < 0) continue;
      int gameTotal = 0;
      for (int hole = 0; hole < maxHoles; hole++) {
        if (hole < game.numHoles &&
            pi < game.scores.length &&
            hole < game.scores[pi].length) {
          final v = int.tryParse(game.scores[pi][hole].trim());
          if (v != null) {
            holeScores[hole].add(v);
            gameTotal += v;
          }
        }
      }
      gameTotals.add(gameTotal);
    }

    const summaryStyle = TextStyle(fontSize: 12, color: Colors.black54);

    List<DataCell> summaryRowCells(String label,
        String Function(List<int>) perHole, String Function(List<int>) total) {
      final cells = <DataCell>[DataCell(Text(label, style: summaryStyle))];
      for (int hole = 0; hole < maxHoles; hole++) {
        final val = holeScores[hole].isEmpty ? '' : perHole(holeScores[hole]);
        cells.add(DataCell(Text(val, style: summaryStyle)));
      }
      cells.add(DataCell(Text(gameTotals.isEmpty ? '' : total(gameTotals),
          style: summaryStyle)));
      return cells;
    }

    final avgRow = DataRow(
        cells: summaryRowCells(
      'Avg',
      (v) => (v.fold(0, (a, b) => a + b) / v.length).toStringAsFixed(1),
      (t) => (t.fold(0, (a, b) => a + b) / t.length).toStringAsFixed(1),
    ));
    final lowRow = DataRow(
        cells: summaryRowCells(
      'Low',
      (v) => v.reduce((a, b) => a < b ? a : b).toString(),
      (t) => t.reduce((a, b) => a < b ? a : b).toString(),
    ));
    final highRow = DataRow(
        cells: summaryRowCells(
      'High',
      (v) => v.reduce((a, b) => a > b ? a : b).toString(),
      (t) => t.reduce((a, b) => a > b ? a : b).toString(),
    ));

    return DataTable(
      columnSpacing: 18,
      horizontalMargin: 8,
      dataRowMinHeight: 28,
      dataRowMaxHeight: 36,
      headingRowHeight: 36,
      columns: columns,
      rows: [parRow, ...gameRows, avgRow, lowRow, highRow],
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
