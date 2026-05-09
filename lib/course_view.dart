import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';

class CourseView extends StatefulWidget {
  final List<SavedCourse> savedCourses;
  final Function(List<SavedCourse>) onCoursesUpdated;
  final Function(String oldName, String newName)? onCourseEdited;

  const CourseView({
    super.key,
    required this.savedCourses,
    required this.onCoursesUpdated,
    this.onCourseEdited,
  });

  @override
  State<CourseView> createState() => _CourseViewState();
}

class _CourseViewState extends State<CourseView> {
  final TextEditingController _courseNameController = TextEditingController();
  int numHoles = 9;
  final List<TextEditingController> _parControllers = [];
  final List<TextEditingController> _distanceControllers = [];
  int? _editingCourseIndex;

  @override
  void initState() {
    super.initState();
    _ensureControllers(numHoles);
  }

  void _ensureControllers(int count) {
    // Manage par controllers
    while (_parControllers.length < count) {
      _parControllers.add(TextEditingController(text: '3'));
    }
    while (_parControllers.length > count) {
      _parControllers.removeLast().dispose();
    }

    // Manage distance controllers
    while (_distanceControllers.length < count) {
      _distanceControllers.add(TextEditingController());
    }
    while (_distanceControllers.length > count) {
      _distanceControllers.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    for (var controller in _parControllers) {
      controller.dispose();
    }
    for (var controller in _distanceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onNumHolesChanged(int newValue) {
    setState(() {
      numHoles = newValue;
      _ensureControllers(numHoles);
    });
  }

  void _saveCourse() {
    if (_courseNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a course name')),
      );
      return;
    }

    // Validate that all fields are filled
    bool allFilled = true;
    for (int i = 0; i < numHoles; i++) {
      if (_parControllers[i].text.trim().isEmpty ||
          _distanceControllers[i].text.trim().isEmpty) {
        allFilled = false;
        break;
      }
    }

    if (!allFilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all par and distance values')),
      );
      return;
    }

    // Collect the par and distance values
    List<int> parValues = [];
    List<int> distanceValues = [];
    for (int i = 0; i < numHoles; i++) {
      parValues.add(int.tryParse(_parControllers[i].text) ?? 3);
      distanceValues.add(int.tryParse(_distanceControllers[i].text) ?? 0);
    }

    // Create the course
    String? existingId;
    if (_editingCourseIndex != null) {
      existingId = widget.savedCourses[_editingCourseIndex!].id;
    }

    final course = SavedCourse(
      id: existingId,
      name: _courseNameController.text.trim(),
      numHoles: numHoles,
      parValues: parValues,
      distanceValues: distanceValues,
    );

    final updatedCourses = List<SavedCourse>.from(widget.savedCourses);
    String? oldCourseName;
    
    if (_editingCourseIndex != null) {
      // Capture old course name before updating
      oldCourseName = widget.savedCourses[_editingCourseIndex!].name;
      // Update existing course
      updatedCourses[_editingCourseIndex!] = course;
      
      // Notify parent about the edit for history versioning
      // This versions all games with the old course name when ANY course property is edited
      if (widget.onCourseEdited != null) {
        widget.onCourseEdited!(oldCourseName, course.name);
      }
    } else {
      // Add new course
      updatedCourses.add(course);
    }
    
    widget.onCoursesUpdated(updatedCourses);
    
    setState(() {
      _editingCourseIndex = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Course "${_courseNameController.text}" saved!')),
    );

    // Clear the form
    _courseNameController.clear();
    for (var controller in _parControllers) {
      controller.text = '3';
    }
    for (var controller in _distanceControllers) {
      controller.clear();
    }
  }

  void _editCourse(int index) {
    final course = widget.savedCourses[index];
    
    setState(() {
      _editingCourseIndex = index;
      _courseNameController.text = course.name;
      numHoles = course.numHoles;
      _ensureControllers(numHoles);
      
      for (int i = 0; i < course.numHoles; i++) {
        _parControllers[i].text = course.parValues[i].toString();
        _distanceControllers[i].text = course.distanceValues[i].toString();
      }
    });

    // Scroll to top to see the form
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Editing "${course.name}"')),
    );
  }

  void _cancelEdit() {
    setState(() {
      _editingCourseIndex = null;
      _courseNameController.clear();
      for (var controller in _parControllers) {
        controller.text = '3';
      }
      for (var controller in _distanceControllers) {
        controller.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _editingCourseIndex != null ? 'Edit Course' : 'Add New Course',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (_editingCourseIndex != null)
                    TextButton.icon(
                      onPressed: _cancelEdit,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel Edit'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // Course Name
              SizedBox(
                width: 300,
                child: TextFormField(
                  controller: _courseNameController,
                  maxLength: 30,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: const InputDecoration(
                    labelText: 'Course Name',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Number of Holes Dropdown
              Row(
                children: [
                  const Text('Number of Holes: ', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: numHoles,
                    items: [9, 18].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      if (newValue == null) return;
                      _onNumHolesChanged(newValue);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Header Row
              const Row(
                children: [
                  SizedBox(width: 60, child: Text('Hole', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 100, child: Text('Par', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 100, child: Text('Distance (ft)', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 100, child: Text('Factor', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 10),
              // Hole entries
              ...List.generate(numHoles, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text('${index + 1}', style: const TextStyle(fontSize: 16)),
                      ),
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          controller: _parControllers[index],
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          controller: _distanceControllers[index],
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 90,
                        child: Builder(
                          builder: (context) {
                            final par = int.tryParse(_parControllers[index].text);
                            final distance = int.tryParse(_distanceControllers[index].text);
                            final factor = (par != null && par > 0 && distance != null) 
                                ? (distance / par).round().toString() 
                                : '-';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              alignment: Alignment.centerLeft,
                              child: Text(factor, style: const TextStyle(fontSize: 16)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 30),
              // Save Button
              ElevatedButton.icon(
                onPressed: _saveCourse,
                icon: const Icon(Icons.save),
                label: Text(_editingCourseIndex != null ? 'Update Course' : 'Save Course'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 40),
              // Saved Courses Section
              if (widget.savedCourses.isNotEmpty) ...[
                const Divider(thickness: 2),
                const SizedBox(height: 20),
                const Text(
                  'Saved Courses',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                // Display each saved course (sorted alphabetically)
                ...() {
                  final sortedCourses = List<SavedCourse>.from(widget.savedCourses)
                    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                  return List.generate(sortedCourses.length, (courseIndex) {
                    final course = sortedCourses[courseIndex];
                    final originalIndex = widget.savedCourses.indexOf(course);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 20),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Course Header with Edit button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      course.name,
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${course.numHoles} holes',
                                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.orange),
                                onPressed: () => _editCourse(originalIndex),
                                tooltip: 'Edit Course',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Course details table
                          Row(
                            children: [
                              const SizedBox(width: 60, child: Text('Hole', style: TextStyle(fontWeight: FontWeight.bold))),
                              const SizedBox(width: 60, child: Text('Par', style: TextStyle(fontWeight: FontWeight.bold))),
                              const SizedBox(width: 100, child: Text('Distance', style: TextStyle(fontWeight: FontWeight.bold))),
                              const SizedBox(width: 100, child: Text('Factor', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                          const Divider(),
                          // Display each hole
                          ...List.generate(course.numHoles, (holeIndex) {
                            final par = course.parValues[holeIndex];
                            final distance = course.distanceValues[holeIndex];
                            final factor = par > 0 ? (distance / par).round().toString() : '-';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  SizedBox(width: 60, child: Text('${holeIndex + 1}')),
                                  SizedBox(width: 60, child: Text('$par')),
                                  SizedBox(width: 100, child: Text('$distance ft')),
                                  SizedBox(width: 100, child: Text(factor)),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          // Total par and distance
                          Row(
                            children: [
                              const SizedBox(width: 60, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  '${course.parValues.reduce((a, b) => a + b)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  '${course.distanceValues.reduce((a, b) => a + b)} ft',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                });
                }(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
