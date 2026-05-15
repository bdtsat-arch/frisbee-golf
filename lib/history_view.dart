import 'package:flutter/material.dart';

class GameHistory {
  final String? id;
  final String date;
  final int numPlayers;
  final int numHoles;
  final List<String> playerNames;
  final List<int> parValues;
  final List<List<String>> scores;
  final String courseName;

  GameHistory({
    this.id,
    required this.date,
    required this.numPlayers,
    required this.numHoles,
    required this.playerNames,
    required this.parValues,
    required this.scores,
    required this.courseName,
  });

  Map<String, dynamic> toJson() {
    // Firestore doesn't support nested arrays (List<List<String>>).
    // Convert scores to a Map where keys act as indices.
    Map<String, dynamic> scoresMap = {};
    for (int i = 0; i < scores.length; i++) {
      scoresMap[i.toString()] = scores[i];
    }

    return {
      'date': date,
      'numPlayers': numPlayers,
      'numHoles': numHoles,
      'playerNames': playerNames,
      'parValues': parValues,
      'scores': scoresMap, // Store as Map
      'courseName': courseName,
    };
  }

  factory GameHistory.fromJson(Map<String, dynamic> json, {String? id}) {
    List<List<String>> scoresList;
    if (json['scores'] is List) {
      scoresList = (json['scores'] as List)
          .map((row) => List<String>.from(row as List))
          .toList();
    } else {
      final scoresMap = Map<String, dynamic>.from(json['scores'] as Map);
      final int count = json['numPlayers'] as int;
      scoresList = List.generate(count, (index) {
        final row = scoresMap[index.toString()];
        return row != null ? List<String>.from(row as List) : [];
      });
    }

    return GameHistory(
      id: id,
      date: json['date'] as String,
      numPlayers: json['numPlayers'] as int,
      numHoles: json['numHoles'] as int,
      playerNames: List<String>.from(json['playerNames'] as List),
      parValues: List<int>.from(json['parValues'] as List),
      scores: scoresList,
      courseName: json['courseName'] as String? ?? '',
    );
  }
}

class HistoryView extends StatelessWidget {
  final List<GameHistory> history;
  final Function(int) onDelete;
  final Function(GameHistory) onContinueGame;

  const HistoryView({
    super.key,
    required this.history,
    required this.onDelete,
    required this.onContinueGame,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(
        child: Text(
          'No saved games yet',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    // Create sorted copy of history (newest first)
    final sortedHistory = List<GameHistory>.from(history);
    sortedHistory.sort((a, b) {
      try {
        final dateTimeA = _parseDateTime(a.date);
        final dateTimeB = _parseDateTime(b.date);
        return dateTimeB.compareTo(dateTimeA); // Descending order (newest first)
      } catch (e) {
        return 0; // If parsing fails, keep original order
      }
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedHistory.length,
      itemBuilder: (context, index) {
        final game = sortedHistory[index];
        final originalIndex = history.indexOf(game);
        final canContinue = _hasIncompleteScores(game);
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: ExpansionTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${game.courseName.isNotEmpty ? game.courseName + ' - ' : ''}Game ${sortedHistory.length - index} - ${game.date}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (canContinue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'In Progress',
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text('${game.numPlayers} players, ${game.numHoles} holes'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Final Scores:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...List.generate(game.numPlayers, (i) {
                      int total = 0;
                      for (var score in game.scores[i]) {
                        if (score.isNotEmpty && int.tryParse(score) != null) {
                          total += int.parse(score);
                        }
                      }
                      final name = i < game.playerNames.length ? game.playerNames[i] : 'Player ${i + 1}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text('$name: $total'),
                      );
                    }),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildScoreTable(game),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canContinue) ...[
                            ElevatedButton.icon(
                              onPressed: () {
                                onContinueGame(game);
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Continue Game'),
                            ),
                            const SizedBox(width: 12),
                          ],
                          ElevatedButton.icon(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Game'),
                                  content: const Text('Delete this saved game?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                onDelete(originalIndex);
                              }
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text('Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _hasIncompleteScores(GameHistory game) {
    for (int p = 0; p < game.numPlayers; p++) {
      final row = p < game.scores.length ? game.scores[p] : <String>[];
      for (int h = 0; h < game.numHoles; h++) {
        if (h >= row.length) {
          return true;
        }
        final score = row[h].trim();
        if (score.isEmpty || int.tryParse(score) == null) {
          return true;
        }
      }
    }
    return false;
  }

  DateTime _parseDateTime(String dateStr) {
    // Parse date string in format 'M/D/YYYY H:MM'
    try {
      final parts = dateStr.split(' ');
      if (parts.length != 2) return DateTime.now();
      
      final dateParts = parts[0].split('/');
      final timeParts = parts[1].split(':');
      
      if (dateParts.length != 3 || timeParts.length != 2) return DateTime.now();
      
      final month = int.parse(dateParts[0]);
      final day = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      return DateTime.now();
    }
  }

  String _calculateHistoricalPlayerHoleLow(String courseName, String playerName, int holeIndex) {
    if (courseName.isEmpty || playerName.isEmpty) return '';
    
    // Filter games with the same course name
    final matchingGames = history.where((game) {
      // Check if game is for the same course
      if (game.courseName != courseName) return false;
      
      // Check if game has enough holes for this holeIndex
      if (game.numHoles <= holeIndex) return false;
      
      return true;
    }).toList();
    
    if (matchingGames.isEmpty) return '';
    
    // Find lowest score for this player on this hole
    int? lowestScore;
    
    for (final game in matchingGames) {
      // Find this player in the historical game (with trimmed comparison)
      for (int p = 0; p < game.numPlayers; p++) {
        if (p < game.playerNames.length && 
            game.playerNames[p].trim().toLowerCase() == playerName.trim().toLowerCase()) {
          if (holeIndex < game.scores[p].length) {
            final scoreStr = game.scores[p][holeIndex].trim();
            final score = int.tryParse(scoreStr);
            if (score != null) {
              if (lowestScore == null || score < lowestScore) {
                lowestScore = score;
              }
            }
          }
          break; // Found the player, move to next game
        }
      }
    }
    
    if (lowestScore == null) return '';
    return lowestScore.toString();
  }

  String _calculateHistoricalPlayerHoleAverage(String courseName, String playerName, int holeIndex) {
    if (courseName.isEmpty || playerName.isEmpty) return '';

    // Filter games with the same course name
    final matchingGames = history.where((game) {
      // Check if game is for the same course
      if (game.courseName != courseName) return false;

      // Check if game has enough holes for this holeIndex
      if (game.numHoles <= holeIndex) return false;

      return true;
    }).toList();

    if (matchingGames.isEmpty) return '';

    // Calculate average score for this player on this hole
    int totalScores = 0;
    int scoreCount = 0;

    for (final game in matchingGames) {
      // Find this player in the historical game (with trimmed comparison)
      for (int p = 0; p < game.numPlayers; p++) {
        if (p < game.playerNames.length &&
            game.playerNames[p].trim().toLowerCase() == playerName.trim().toLowerCase()) {
          if (holeIndex < game.scores[p].length) {
            final scoreStr = game.scores[p][holeIndex].trim();
            final score = int.tryParse(scoreStr);
            if (score != null) {
              totalScores += score;
              scoreCount++;
            }
          }
          break; // Found the player, move to next game
        }
      }
    }

    if (scoreCount == 0) return '';
    final average = totalScores / scoreCount;
    return average.toStringAsFixed(1);
  }

  String _calculateHistoricalPlayerHoleHigh(String courseName, String playerName, int holeIndex) {
    if (courseName.isEmpty || playerName.isEmpty) return '';
    
    // Filter games with the same course name
    final matchingGames = history.where((game) {
      // Check if game is for the same course
      if (game.courseName != courseName) return false;
      
      // Check if game has enough holes for this holeIndex
      if (game.numHoles <= holeIndex) return false;
      
      return true;
    }).toList();
    
    if (matchingGames.isEmpty) return '';
    
    // Find highest score for this player on this hole
    int? highestScore;
    
    for (final game in matchingGames) {
      // Find this player in the historical game (with trimmed comparison)
      for (int p = 0; p < game.numPlayers; p++) {
        if (p < game.playerNames.length && 
            game.playerNames[p].trim().toLowerCase() == playerName.trim().toLowerCase()) {
          if (holeIndex < game.scores[p].length) {
            final scoreStr = game.scores[p][holeIndex].trim();
            final score = int.tryParse(scoreStr);
            if (score != null) {
              if (highestScore == null || score > highestScore) {
                highestScore = score;
              }
            }
          }
          break; // Found the player, move to next game
        }
      }
    }
    
    if (highestScore == null) return '';
    return highestScore.toString();
  }

  Widget _buildScoreTable(GameHistory game) {
    List<DataColumn> columns = [const DataColumn(label: Text('Player'))];
    for (int i = 0; i < game.numHoles; i++) {
      columns.add(DataColumn(label: Text('H${i + 1}')));
    }
    columns.add(const DataColumn(label: Text('Total')));

    List<DataRow> rows = [];
    
    // Par row
    if (game.parValues.isNotEmpty) {
      List<DataCell> parCells = [const DataCell(Text('Par'))];
      int parTotal = 0;
      for (int j = 0; j < game.numHoles; j++) {
        final p = j < game.parValues.length ? game.parValues[j] : 3;
        parCells.add(DataCell(Text(p.toString())));
        parTotal += p;
      }
      parCells.add(DataCell(Text(parTotal.toString())));
      rows.add(DataRow(cells: parCells));
    }

    // Player rows
    for (int i = 0; i < game.numPlayers; i++) {
      final name = i < game.playerNames.length ? game.playerNames[i] : 'P${i + 1}';
      List<DataCell> cells = [DataCell(Text(name))];
      int total = 0;
      for (int j = 0; j < game.numHoles; j++) {
        String score = j < game.scores[i].length ? game.scores[i][j] : '';
        cells.add(DataCell(Text(score.isEmpty ? '-' : score)));
        if (score.isNotEmpty && int.tryParse(score) != null) {
          total += int.parse(score);
        }
      }
      cells.add(DataCell(Text(total.toString())));
      rows.add(DataRow(cells: cells));

      // Add AVG row under this player if we have historical data
      List<DataCell> avgCells = [const DataCell(Text('  AVG', style: TextStyle(fontSize: 12, color: Colors.grey)))];
      bool hasAnyAvg = false;
      double avgTotal = 0.0;
      for (int j = 0; j < game.numHoles; j++) {
        final avg = _calculateHistoricalPlayerHoleAverage(game.courseName, name, j);
        if (avg.isNotEmpty) {
          hasAnyAvg = true;
          avgTotal += double.tryParse(avg) ?? 0.0;
        }
        avgCells.add(DataCell(Text(avg.isNotEmpty ? avg : '-', style: const TextStyle(fontSize: 12, color: Colors.grey))));
      }
      avgCells.add(DataCell(Text(hasAnyAvg ? avgTotal.toStringAsFixed(1) : '-', style: const TextStyle(fontSize: 12, color: Colors.grey))));
      if (hasAnyAvg) {
        rows.add(DataRow(cells: avgCells));
      }
      
      // Add LOW row under this player if we have historical data
      List<DataCell> lowCells = [const DataCell(Text('  LOW', style: TextStyle(fontSize: 12, color: Colors.grey)))];
      bool hasAnyLow = false;
      int lowTotal = 0;
      for (int j = 0; j < game.numHoles; j++) {
        final low = _calculateHistoricalPlayerHoleLow(game.courseName, name, j);
        if (low.isNotEmpty) {
          hasAnyLow = true;
          lowTotal += int.tryParse(low) ?? 0;
        }
        lowCells.add(DataCell(Text(low.isNotEmpty ? low : '-', style: const TextStyle(fontSize: 12, color: Colors.grey))));
      }
      lowCells.add(DataCell(Text(hasAnyLow ? lowTotal.toString() : '-', style: const TextStyle(fontSize: 12, color: Colors.grey))));
      if (hasAnyLow) {
        rows.add(DataRow(cells: lowCells));
      }
      
      // Add HIGH row under this player if we have historical data
      List<DataCell> highCells = [const DataCell(Text('  HIGH', style: TextStyle(fontSize: 12, color: Colors.grey)))];
      bool hasAnyHigh = false;
      int highTotal = 0;
      for (int j = 0; j < game.numHoles; j++) {
        final high = _calculateHistoricalPlayerHoleHigh(game.courseName, name, j);
        if (high.isNotEmpty) {
          hasAnyHigh = true;
          highTotal += int.tryParse(high) ?? 0;
        }
        highCells.add(DataCell(Text(high.isNotEmpty ? high : '-', style: const TextStyle(fontSize: 12, color: Colors.grey))));
      }
      highCells.add(DataCell(Text(hasAnyHigh ? highTotal.toString() : '-', style: const TextStyle(fontSize: 12, color: Colors.grey))));
      if (hasAnyHigh) {
        rows.add(DataRow(cells: highCells));
      }
    }

    return DataTable(
      columns: columns,
      rows: rows,
      columnSpacing: 8,
      horizontalMargin: 8,
      dataRowMinHeight: 30,
      dataRowMaxHeight: 40,
      headingRowHeight: 40,
    );
  }
}
