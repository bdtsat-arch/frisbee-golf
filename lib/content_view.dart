import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'scoring_view.dart';

class ContentView extends StatefulWidget {
  const ContentView({super.key});

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  int numPlayers = 2;
  int numHoles = 9;
  bool gameStarted = false;
  List<List<String>> scores = [];
  final List<TextEditingController> _nameControllers = [];
  List<String> playerNames = [];
  final List<TextEditingController> _parControllers = [];
  List<int> parValues = [];
  int parDefault = 3;
  String courseName = '';
  final TextEditingController _courseNameController = TextEditingController();
  static const String _kSavedNamesKey = 'saved_player_names_v1';

  void startGame() {
    setState(() {
      scores = List.generate(numPlayers, (_) => List.filled(numHoles, ""));
      playerNames = List.generate(numPlayers, (i) {
        final txt = _nameControllers.length > i ? _nameControllers[i].text.trim() : '';
        return txt.isNotEmpty ? txt : 'Player ${i + 1}';
      });
      // Capture par values (default to 3 when not provided)
      parValues = List.generate(numHoles, (i) => i < _parControllers.length ? int.tryParse(_parControllers[i].text) ?? 3 : 3);
      courseName = _courseNameController.text.trim();
      gameStarted = true;
    });
    // Persist the chosen/entered player names so they are available after restart
    _saveNames();
  }

  @override
  void initState() {
    super.initState();
    _ensureControllers(numPlayers);
    _loadSavedNames();
    _ensureParControllers(numHoles);
  }

  void _ensureControllers(int count) {
    while (_nameControllers.length < count) {
      final c = TextEditingController();
      // Save names whenever they change so we can restore on restart
      c.addListener(() {
        _saveNames();
      });
      _nameControllers.add(c);
    }
    while (_nameControllers.length > count) {
      _nameControllers.removeLast().dispose();
    }
  }

  Future<void> _loadSavedNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_kSavedNamesKey);
      if (saved == null || saved.isEmpty) return;

      // Ensure we have controllers for the current player count
      _ensureControllers(numPlayers);

      for (int i = 0; i < _nameControllers.length; i++) {
        if (i < saved.length && saved[i].isNotEmpty) {
          _nameControllers[i].text = saved[i];
        }
      }
      setState(() {});
    } catch (e) {
      // ignore errors loading preferences
    }
  }

  Future<void> _saveNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final names = List<String>.generate(numPlayers, (i) {
        final txt = i < _nameControllers.length ? _nameControllers[i].text.trim() : '';
        return txt;
      });
      await prefs.setStringList(_kSavedNamesKey, names);
    } catch (e) {
      // ignore save errors
    }
  }

  void _ensureParControllers(int count) {
    while (_parControllers.length < count) {
      final c = TextEditingController(text: parDefault.toString());
      _parControllers.add(c);
    }
    while (_parControllers.length > count) {
      _parControllers.removeLast().dispose();
    }
  }

  void _onNumPlayersChanged(int newValue) {
    setState(() {
      numPlayers = newValue;
      _ensureControllers(numPlayers);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (gameStarted) {
      return ScoringView(
        numPlayers: numPlayers,
        numHoles: numHoles,
        scores: scores,
        playerNames: playerNames,
        parValues: parValues,
        distanceValues: List.filled(numHoles, 0),
        courseName: courseName,
        gameHistory: const [],
        onScoresChanged: (newScores) {
          setState(() {
            scores = newScores;
          });
        },
        onRestart: () {
          setState(() {
            // Return to setup so user can re-select players/holes
            gameStarted = false;
            scores = [];
          });
        },
        onSave: () {
          // Empty save callback for content_view (not used since main.dart handles navigation)
        }, initialHole: 0,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Frisbee Scoring App')),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
            const Text('Select Game Options', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: 240,
                child: TextFormField(
                  controller: _courseNameController,
                  maxLength: 30,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: InputDecoration(
                    labelText: 'Course Name',
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Players: '),
                DropdownButton<int>(
                  value: numPlayers,
                  items: [1, 2, 3, 4, 5, 6].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(value.toString()),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    if (newValue == null) return;
                    _onNumPlayersChanged(newValue);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Player name input fields (one per player) — centered and limited to 15 chars
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List<Widget>.generate(
                    numPlayers,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: SizedBox(
                        width: 240,
                        child: TextFormField(
                          controller: _nameControllers[index],
                          maxLength: 15,
                          inputFormatters: [LengthLimitingTextInputFormatter(15)],
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Player ${index + 1} Name',
                            border: const OutlineInputBorder(),
                            counterText: '',
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Holes: '),
                DropdownButton<int>(
                  value: numHoles,
                  items: [9, 18].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(value.toString()),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    setState(() {
                      numHoles = newValue!;
                      _ensureParControllers(numHoles);
                    });
                  },
                ),
                const SizedBox(width: 16),
                const Text('Par Default: '),
                DropdownButton<int>(
                  value: parDefault,
                  items: [3, 4, 5].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(value.toString()),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    if (newValue == null) return;
                    setState(() {
                      parDefault = newValue;
                      // Fill all par boxes with the chosen default
                      for (int i = 0; i < _parControllers.length; i++) {
                        _parControllers[i].text = parDefault.toString();
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Par input boxes generated based on selected holes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: List<Widget>.generate(numHoles, (index) {
                  return SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('H${index + 1}', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 6),
                                SizedBox(
                                  width: 64,
                                  height: 36,
                                  child: TextFormField(
                                    controller: _parControllers.length > index ? _parControllers[index] : null,
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
                                    onChanged: (value) {
                                      if (_parControllers.length <= index) return;
                                      final c = _parControllers[index];
                                      final v = int.tryParse(value);
                                      if (v == null) return; // allow temporary empty input
                                      final clamped = v.clamp(2, 6);
                                      if (clamped != v) {
                                        c.text = clamped.toString();
                                        c.selection = TextSelection.collapsed(offset: c.text.length);
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                                    ),
                                  ),
                                ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: startGame,
              child: const Text('Start Game'),
            ),
          ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    for (final c in _parControllers) {
      c.dispose();
    }
    _courseNameController.dispose();
    super.dispose();
  }
}
