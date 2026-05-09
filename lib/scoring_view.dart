import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'history_view.dart';

class ScoringView extends StatefulWidget {
  final int numPlayers;
  final int numHoles;
  final int initialHole;
  final List<List<String>> scores;
  final List<String> playerNames;
  final List<int> parValues;
  final List<int> distanceValues;
  final String courseName;
  final List<GameHistory> gameHistory;
  final Function(List<List<String>>) onScoresChanged;
  final VoidCallback onRestart;
  final VoidCallback onSave;

  const ScoringView({
    super.key,
    required this.numPlayers,
    required this.numHoles,
    required this.initialHole,
    required this.scores,
    required this.playerNames,
    required this.parValues,
    required this.distanceValues,
    required this.courseName,
    required this.gameHistory,
    required this.onScoresChanged,
    required this.onRestart,
    required this.onSave,
  });

  @override
  State<ScoringView> createState() => _ScoringViewState();
}

class _ScoringViewState extends State<ScoringView> {
  int currentHole = 0;
  List<List<String>> errorMessages = [];
  late List<int> playerOrder;
  late List<TextEditingController> controllers;
  late ScrollController _scrollController;
  late ScrollController _gridScrollController;
  int lastCompletedHole = -1;

  @override
  void initState() {
    super.initState();
    final maxStartHole = widget.numHoles > 0 ? widget.numHoles - 1 : 0;
    currentHole = widget.initialHole.clamp(0, maxStartHole);
    errorMessages = List.generate(
        widget.numPlayers, (_) => List.filled(widget.numHoles, ""));
    playerOrder = List.generate(widget.numPlayers, (i) => i);
    controllers = List.generate(
      widget.numPlayers,
      (i) => TextEditingController(text: widget.scores[i][currentHole]),
    );
    _scrollController = ScrollController();
    _gridScrollController = ScrollController();
    if (kDebugMode) {
      debugPrint('ScoringView.initState currentHole=$currentHole numPlayers=${widget.numPlayers} controllers=${controllers.length}');
    }
    // If some holes were pre-filled before startup, update order incrementally
    for (int h = 0; h < widget.numHoles; h++) {
      if (_holeIsComplete(h)) {
        _maybeUpdateOrderForHole(h);
      } else {
        break;
      }
    }
  }

  @override
  void didUpdateWidget(covariant ScoringView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.numPlayers != oldWidget.numPlayers || widget.numHoles != oldWidget.numHoles) {
      // Recreate error messages and controllers to match new sizes.
      for (final c in controllers) {
        c.dispose();
      }
      controllers = List.generate(
        widget.numPlayers,
        (i) => TextEditingController(text: i < widget.scores.length && currentHole < widget.scores[i].length ? widget.scores[i][currentHole] : ''),
      );
      errorMessages = List.generate(widget.numPlayers, (_) => List.filled(widget.numHoles, ""));
      playerOrder = List.generate(widget.numPlayers, (i) => i);
      // Ensure lastCompletedHole is valid for new hole count
      if (lastCompletedHole >= widget.numHoles) lastCompletedHole = widget.numHoles - 1;
    }
  }

  void updateScore(int player, String score) {
    setState(() {
      widget.scores[player][currentHole] = score;
      if (score.isNotEmpty && int.tryParse(score) == null) {
        errorMessages[player][currentHole] = "Invalid number";
      } else {
        errorMessages[player][currentHole] = "";
      }
      widget.onScoresChanged(widget.scores);
      _maybeUpdateOrderForHole(currentHole);
    });
  }

  bool _holeIsComplete(int holeIndex) {
    for (int p = 0; p < widget.numPlayers; p++) {
      String s = widget.scores[p][holeIndex];
      if (s.isEmpty || int.tryParse(s) == null) return false;
    }
    return true;
  }

  String _calculatePlayerHoleAverage(String playerName, int holeIndex) {
    if (widget.courseName.isEmpty || playerName.isEmpty) return '';
    
    // Filter games with the same course name and that are complete
    final matchingGames = widget.gameHistory.where((game) {
      // Check if game is for the same course
      if (game.courseName != widget.courseName) return false;
      
      // Check if game has enough holes for this holeIndex
      if (game.numHoles <= holeIndex) return false;
      
      // Check if game is complete (all holes must have valid scores for all players)
      for (int p = 0; p < game.numPlayers; p++) {
        if (p >= game.scores.length) return false;
        for (int h = 0; h < game.numHoles; h++) {
          if (h >= game.scores[p].length) return false;
          final scoreStr = game.scores[p][h].trim();
          if (scoreStr.isEmpty || int.tryParse(scoreStr) == null) return false;
        }
      }
      
      return true;
    }).toList();
    
    if (matchingGames.isEmpty) return '';
    
    // Calculate average for this player on this hole
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

  void _maybeUpdateOrderForHole(int holeIndex) {
    if (!_holeIsComplete(holeIndex)) return;
    if (holeIndex <= lastCompletedHole) return;

    // Compute partial totals up to and including holeIndex
    final Map<int, int> partialTotals = {};
    for (int p = 0; p < widget.numPlayers; p++) {
      int total = 0;
      for (int h = 0; h <= holeIndex; h++) {
        String s = widget.scores[p][h];
        if (s.isNotEmpty && int.tryParse(s) != null) {
          total += int.parse(s);
        }
      }
      partialTotals[p] = total;
    }

    // Keep previous order to break ties (stable sort)
    final Map<int, int> prevPos = {};
    for (int i = 0; i < playerOrder.length; i++) {
      prevPos[playerOrder[i]] = i;
    }

    List<int> newOrder = List.from(playerOrder);
    newOrder.sort((a, b) {
      int ta = partialTotals[a]!;
      int tb = partialTotals[b]!;
      if (ta != tb) return ta.compareTo(tb); // lowest score first
      return (prevPos[a] ?? a).compareTo(prevPos[b] ?? b);
    });

    playerOrder = newOrder;
    lastCompletedHole = holeIndex;
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('ScoringView.build currentHole=$currentHole numPlayers=${widget.numPlayers} controllers=${controllers.length}');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courseName.isNotEmpty ? widget.courseName + ' - ' : ''}Hole ${currentHole + 1} of ${widget.numHoles}'),
        actions: [
          IconButton(
            tooltip: 'Restart game',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Restart Game'),
                  content: const Text('Return to setup and restart the game?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Restart'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                widget.onRestart();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ...List.generate(widget.numPlayers, (index) {
              if (kDebugMode) {
                debugPrint('ScoringView building player index=$index');
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.playerNames[index], style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 88,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (value) {
                              updateScore(index, value);
                            },
                            controller: controllers[index],
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (errorMessages[index][currentHole].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          errorMessages[index][currentHole],
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10, // 10px between buttons when space allows
                  runSpacing: 8,
                  children: [
                    if (currentHole > 0)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            currentHole--;
                            for (int i = 0; i < controllers.length; i++) {
                              controllers[i].text = widget.scores[i][currentHole];
                            }
                          });
                        },
                        child: const Text('Previous'),
                      ),

                    // Center control: Next or Finish
                    Builder(builder: (context) {
                      if (currentHole < widget.numHoles - 1) {
                        return ElevatedButton(
                          onPressed: () {
                            setState(() {
                              currentHole++;
                              for (int i = 0; i < controllers.length; i++) {
                                controllers[i].text = widget.scores[i][currentHole];
                              }
                            });
                          },
                          child: const Text('Next'),
                        );
                      }

                      return ElevatedButton(
                        onPressed: () {
                          // Finish game, perhaps show final scores
                          
                          // Create (playerIndex, score) pairs
                          List<MapEntry<int, int>> playerScores = [];
                          for (int index = 0; index < widget.numPlayers; index++) {
                            int total = widget.scores[index]
                                .where((s) => s.isNotEmpty)
                                .map((s) => int.tryParse(s) ?? 0)
                                .fold(0, (a, b) => a + b);
                            playerScores.add(MapEntry(index, total));
                          }
                          
                          // Sort by score (ascending - lowest first), stable sort maintains original order for ties
                          playerScores.sort((a, b) => a.value.compareTo(b.value));
                          
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Final Scores'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: playerScores.map((entry) {
                                  int index = entry.key;
                                  int total = entry.value;
                                  final name = index < widget.playerNames.length && widget.playerNames[index].isNotEmpty
                                      ? widget.playerNames[index]
                                      : 'Player ${index + 1}';
                                  return Text('$name: $total');
                                }).toList(),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text('Finish'),
                      );
                    }),

                    ElevatedButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Restart Game'),
                            content: const Text('Return to setup and restart the game?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Restart'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          widget.onRestart();
                        }
                      },
                      child: const Text('Restart'),
                    ),
                    ElevatedButton(
                      onPressed: widget.onSave,
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const Text('Totals:', style: TextStyle(fontSize: 18)),
            ...List.generate(widget.numPlayers, (index) {
              int total = widget.scores[index]
                  .where((s) => s.isNotEmpty && int.tryParse(s) != null)
                  .map((s) => int.tryParse(s)!)
                  .fold(0, (a, b) => a + b);
              final name = index < widget.playerNames.length && widget.playerNames[index].isNotEmpty
                  ? widget.playerNames[index]
                  : 'Player ${index + 1}';
              return Text('$name: $total');
            }),
            const SizedBox(height: 20),
            const Text('Game Progress Dashboard',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                        'Hole Progress: ${currentHole + 1} / ${widget.numHoles}'),
                    LinearProgressIndicator(
                      value: (currentHole + 1) / widget.numHoles,
                    ),
                    const SizedBox(height: 20),
                    const Text('Leaderboard',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    ..._getLeaderboard(),
                    const SizedBox(height: 20),
                    const Text('Score Grid',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    _buildScoreGrid(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 100), // Bottom padding for better scrolling
          ],
        ),
      ),
    );
  }

  Widget _buildScoreGrid() {
    List<DataColumn> columns = [const DataColumn(label: Text('Player'))];
    for (int i = 0; i < widget.numHoles; i++) {
      columns.add(DataColumn(label: Text('H${i + 1}')));
    }
    columns.add(const DataColumn(label: Text('Total')));

    List<DataRow> rows = [];
    // Add a Par row at the top if parValues are provided
    if (widget.parValues.isNotEmpty) {
      List<DataCell> parCells = [const DataCell(Text('Par'))];
      int parTotal = 0;
      for (int j = 0; j < widget.numHoles; j++) {
        final p = j < widget.parValues.length ? widget.parValues[j] : 3;
        parCells.add(DataCell(Text(p.toString())));
        parTotal += p;
      }
      parCells.add(DataCell(Text(parTotal.toString())));
      rows.add(DataRow(cells: parCells));
    }

    // Add a Distance row if distanceValues are provided
    if (widget.distanceValues.isNotEmpty) {
      List<DataCell> distanceCells = [const DataCell(Text('Dist'))];
      int distanceTotal = 0;
      for (int j = 0; j < widget.numHoles; j++) {
        final d = j < widget.distanceValues.length ? widget.distanceValues[j] : 0;
        distanceCells.add(DataCell(Text(d.toString())));
        distanceTotal += d;
      }
      distanceCells.add(DataCell(Text(distanceTotal.toString())));
      rows.add(DataRow(cells: distanceCells));
    }

    // Add a Factor row if both parValues and distanceValues are provided
    if (widget.parValues.isNotEmpty && widget.distanceValues.isNotEmpty) {
      List<DataCell> factorCells = [const DataCell(Text('Factor'))];
      int totalDistance = 0;
      int totalPar = 0;
      for (int j = 0; j < widget.numHoles; j++) {
        final p = j < widget.parValues.length ? widget.parValues[j] : 3;
        final d = j < widget.distanceValues.length ? widget.distanceValues[j] : 0;
        final factor = p > 0 ? d / p : 0.0;
        factorCells.add(DataCell(Text(factor.round().toString())));
        totalDistance += d;
        totalPar += p;
      }
      final factorTotal = totalPar > 0 ? totalDistance / totalPar : 0.0;
      factorCells.add(DataCell(Text(factorTotal.round().toString())));
      rows.add(DataRow(cells: factorCells));
    }

    for (int i = 0; i < widget.numPlayers; i++) {
      final name = i < widget.playerNames.length && widget.playerNames[i].isNotEmpty ? widget.playerNames[i] : 'P${i + 1}';
      List<DataCell> cells = [DataCell(Text(name))];
      int total = 0;
      for (int j = 0; j < widget.numHoles; j++) {
        String score = widget.scores[i][j];
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
      for (int j = 0; j < widget.numHoles; j++) {
        final avg = _calculatePlayerHoleAverage(name, j);
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
    }

    return Scrollbar(
      controller: _gridScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _gridScrollController,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 300,
          ),
          child: DataTable(
            columns: columns,
            rows: rows,
            columnSpacing: 8,
            horizontalMargin: 8,
            dataRowMinHeight: 30,
            dataRowMaxHeight: 40,
            headingRowHeight: 40,
          ),
        ),
      ),
    );
  }

  List<Widget> _getLeaderboard() {
    List<Widget> items = [];

    // Create a list of (playerIndex, score) pairs
    List<MapEntry<int, int>> playerScores = [];
    
    for (int idx = 0; idx < widget.numPlayers; idx++) {
      int total = 0;
      if (lastCompletedHole >= 0) {
        for (int h = 0; h <= lastCompletedHole; h++) {
          String s = widget.scores[idx][h];
          if (s.isNotEmpty && int.tryParse(s) != null) {
            total += int.parse(s);
          }
        }
      } else {
        // If no hole fully completed yet, show sum of entered numeric scores
        for (int h = 0; h < widget.numHoles; h++) {
          String s = widget.scores[idx][h];
          if (s.isNotEmpty && int.tryParse(s) != null) {
            total += int.parse(s);
          }
        }
      }
      playerScores.add(MapEntry(idx, total));
    }
    
    // Sort by score (ascending - lowest first), stable sort maintains original order for ties
    playerScores.sort((a, b) => a.value.compareTo(b.value));
    
    for (final entry in playerScores) {
      int idx = entry.key;
      int total = entry.value;
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(idx < widget.playerNames.length && widget.playerNames[idx].isNotEmpty ? widget.playerNames[idx] : 'Player ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Text('$total points'),
            ],
          ),
        ),
      );
    }

    return items;
  }

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    _scrollController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }
}
