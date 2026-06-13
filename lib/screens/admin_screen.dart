import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/stream_model.dart';
import '../services/firebase_service.dart';
import 'player_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<dynamic> _apiChannels = [];
  bool _isLoading = false;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notifTitleController = TextEditingController();
  final TextEditingController _notifBodyController = TextEditingController();
  final TextEditingController _versionController = TextEditingController();
  final TextEditingController _buildNumberController = TextEditingController();
  final TextEditingController _updateUrlController = TextEditingController();
  
  // Category controllers
  final TextEditingController _catNameController = TextEditingController();
  final TextEditingController _catIconController = TextEditingController();
  final TextEditingController _catPriorityController = TextEditingController();
  
  String _searchQuery = "";
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  // Helper to map string to IconData
  IconData _getIconData(String name) {
    switch (name) {
      case 'tv': return Icons.tv_rounded;
      case 'sports': return Icons.sports_soccer_rounded;
      case 'movie': return Icons.movie_rounded;
      case 'music': return Icons.music_note_rounded;
      case 'news': return Icons.newspaper_rounded;
      default: return Icons.category_rounded;
    }
  }

  Future<void> _loadCurrentVersion() async {
    final config = await _firebaseService.getAppVersionConfig();
    if (config != null) {
      _versionController.text = config['latest_version'] ?? '';
      _buildNumberController.text = config['latest_build_number']?.toString() ?? '';
      _updateUrlController.text = config['download_url'] ?? '';
    }
  }

  // Fetch from any M3U or JSON URL
  Future<void> _fetchFromUrl(String url) async {
    if (url.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        List<Map<String, dynamic>> parsedChannels = [];
        for (int i = 0; i < lines.length; i++) {
          String line = lines[i].trim();
          if (line.startsWith('#EXTINF')) {
            String name = line.split(',').last;
            if (i + 1 < lines.length) {
              String url = lines[i + 1].trim();
              if (url.isNotEmpty && !url.startsWith('#')) {
                parsedChannels.add({
                  'name': name,
                  'url': url,
                  'logo': '',
                  'categories': ['Asia'],
                });
              }
            }
          }
        }
        setState(() {
          _apiChannels = parsedChannels;
          _isLoading = false;
        });
        
        // Save URL to history
        _firebaseService.saveM3uUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loaded ${parsedChannels.length} channels.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  // Show Add/Edit Dialog
  Future<void> _showAddDialog({Map<String, dynamic>? channel, StreamModel? existingStream}) async {
    final titleController = TextEditingController(text: existingStream?.title ?? channel?['name'] ?? '');
    final urlController = TextEditingController(text: existingStream?.streamUrl ?? channel?['url'] ?? '');
    final team1NameController = TextEditingController(text: existingStream?.team1Name ?? channel?['name'] ?? '');
    final team1LogoController = TextEditingController(text: existingStream?.team1Logo ?? channel?['logo'] ?? '');
    final team2NameController = TextEditingController(text: existingStream?.team2Name ?? '');
    final team2LogoController = TextEditingController(text: existingStream?.team2Logo ?? '');
    final priorityController = TextEditingController(text: (existingStream?.priority ?? 0).toString());
    bool isHidden = existingStream?.isHidden ?? false;
    bool isScheduled = existingStream?.isScheduled ?? false;
    DateTime scheduledTime = existingStream?.startTime ?? DateTime.now();
    String subCategory = existingStream?.subCategory ?? 'live_match';
    String displayStyle = existingStream?.displayStyle ?? 'match';
    String streamType = existingStream?.streamType ?? 'm3u8';
    
    return showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<List<CategoryModel>>(
          stream: _firebaseService.getCategories(),
          builder: (context, snapshot) {
            final categories = snapshot.data ?? [];
            String localCategoryId = existingStream?.categoryId ?? (categories.isNotEmpty ? categories[0].id : 'live_tv');

            return StatefulBuilder(
              builder: (context, setDialogState) {
                final colorScheme = Theme.of(context).colorScheme;
                
                // Ensure localCategoryId exists in current categories to avoid Dropdown error
                bool categoryExists = categories.any((c) => c.id == localCategoryId);
                if (!categoryExists && categories.isNotEmpty) {
                  localCategoryId = categories[0].id;
                }

                final selectedCategory = categories.firstWhere(
                  (c) => c.id == localCategoryId, 
                  orElse: () => categories.isNotEmpty ? categories[0] : CategoryModel(id: 'live_tv', name: 'Live TV', icon: 'tv')
                );

                return AlertDialog(
                  title: Text(existingStream == null ? "Add Channel" : "Edit Channel"),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (categories.isEmpty)
                          const Text("Please add a category first!", style: TextStyle(color: Colors.red))
                        else
                          DropdownButton<String>(
                            value: localCategoryId,
                            isExpanded: true,
                            items: categories.map((CategoryModel cat) {
                              return DropdownMenuItem<String>(value: cat.id, child: Text(cat.name));
                            }).toList(),
                            onChanged: (newValue) => setDialogState(() => localCategoryId = newValue!),
                          ),
                        
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Link Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: DropdownButton<String>(
                            value: streamType,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 'm3u8', child: Text("Direct Link (m3u8/mp4)")),
                              DropdownMenuItem(value: 'webview', child: Text("WebView URL")),
                              DropdownMenuItem(value: 'iframe', child: Text("iFrame Tag")),
                            ],
                            onChanged: (v) => setDialogState(() => streamType = v!),
                          ),
                        ),

                        if (selectedCategory.icon == "sports") ...[
                          const SizedBox(height: 12),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Sports Display Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: const Text("Match", style: TextStyle(fontSize: 12)),
                                        value: 'live_match',
                                        contentPadding: EdgeInsets.zero,
                                        groupValue: subCategory,
                                        onChanged: (v) => setDialogState(() => subCategory = v!),
                                      ),
                                    ),
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: const Text("TV", style: TextStyle(fontSize: 12)),
                                        value: 'sports_tv',
                                        contentPadding: EdgeInsets.zero,
                                        groupValue: subCategory,
                                        onChanged: (v) => setDialogState(() => subCategory = v!),
                                      ),
                                    ),
                                  ],
                                ),
                                if (subCategory == 'live_match') ...[
                                  const Divider(height: 1),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: RadioListTile<String>(
                                          title: const Text("VS Mode", style: TextStyle(fontSize: 11)),
                                          value: 'match',
                                          contentPadding: EdgeInsets.zero,
                                          groupValue: displayStyle,
                                          onChanged: (v) => setDialogState(() => displayStyle = v!),
                                        ),
                                      ),
                                      Expanded(
                                        child: RadioListTile<String>(
                                          title: const Text("Banner Mode", style: TextStyle(fontSize: 11)),
                                          value: 'simple',
                                          contentPadding: EdgeInsets.zero,
                                          groupValue: displayStyle,
                                          onChanged: (v) => setDialogState(() => displayStyle = v!),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            title: const Text("Schedule Match", style: TextStyle(fontSize: 13)),
                            value: isScheduled,
                            onChanged: (v) => setDialogState(() => isScheduled = v),
                          ),
                          if (isScheduled) ...[
                            ListTile(
                              title: Text("Date: ${DateFormat('dd/MM/yyyy').format(scheduledTime)}", style: const TextStyle(fontSize: 12)),
                              trailing: const Icon(Icons.calendar_today, size: 18),
                              onTap: () async {
                                final now = DateTime.now();
                                final initialDate = scheduledTime.isBefore(now) ? now : scheduledTime;
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: initialDate,
                                  firstDate: initialDate.isBefore(now) ? initialDate : now,
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (date != null) {
                                  setDialogState(() {
                                    scheduledTime = DateTime(date.year, date.month, date.day, scheduledTime.hour, scheduledTime.minute);
                                  });
                                }
                              },
                            ),
                            ListTile(
                              title: Text("Time: ${DateFormat('hh:mm a').format(scheduledTime)}", style: const TextStyle(fontSize: 12)),
                              trailing: const Icon(Icons.access_time, size: 18),
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(scheduledTime),
                                );
                                if (time != null) {
                                  setDialogState(() {
                                    scheduledTime = DateTime(scheduledTime.year, scheduledTime.month, scheduledTime.day, time.hour, time.minute);
                                  });
                                }
                              },
                            ),
                          ],
                        ],
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(labelText: 'Display Title'),
                        ),
                        TextField(
                          controller: urlController,
                          decoration: InputDecoration(
                            labelText: streamType == 'iframe' ? 'iFrame Tag' : 'Stream URL',
                            hintText: streamType == 'iframe' ? '<iframe src="..."></iframe>' : 'https://...',
                          ),
                          maxLines: streamType == 'iframe' ? 3 : 1,
                        ),
                        TextField(
                          controller: team1LogoController,
                          decoration: const InputDecoration(labelText: 'Logo / Icon URL'),
                        ),
                        TextField(
                          controller: priorityController,
                          decoration: const InputDecoration(labelText: 'Priority / Serial (0, 1, 2...)'),
                          keyboardType: TextInputType.number,
                        ),
                        SwitchListTile(
                          title: const Text("Hide Channel"),
                          value: isHidden,
                          onChanged: (v) => setDialogState(() => isHidden = v),
                        ),
                        if (selectedCategory.icon == "sports" && subCategory == 'live_match' && displayStyle == 'match') ...[
                          const Divider(),
                          const Text("Match Details", style: TextStyle(fontWeight: FontWeight.bold)),
                          TextField(controller: team1NameController, decoration: const InputDecoration(labelText: 'Team 1 Name')),
                          TextField(controller: team1LogoController, decoration: const InputDecoration(labelText: 'Team 1 Logo URL')),
                          const SizedBox(height: 10),
                          Text("VS", style: TextStyle(color: colorScheme.primary)),
                          TextField(controller: team2NameController, decoration: const InputDecoration(labelText: 'Team 2 Name')),
                          TextField(controller: team2LogoController, decoration: const InputDecoration(labelText: 'Team 2 Logo URL')),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                    ElevatedButton(
                      onPressed: categories.isEmpty ? null : () {
                        final data = {
                          'title': titleController.text,
                          'streamUrl': urlController.text,
                          'subtitle': selectedCategory.name,
                          'categoryId': localCategoryId,
                          'subCategory': subCategory,
                          'displayStyle': displayStyle,
                          'streamType': streamType,
                          'team1Name': displayStyle == 'simple' ? 'Event' : team1NameController.text,
                          'team1Logo': team1LogoController.text,
                          'team2Name': (selectedCategory.icon == "sports" && subCategory == 'live_match' && displayStyle == 'match') ? team2NameController.text : "Live TV",
                          'team2Logo': team2LogoController.text,
                          'status': 'live',
                          'isHidden': isHidden,
                          'isScheduled': isScheduled,
                          'priority': int.tryParse(priorityController.text) ?? 0,
                          'startTime': isScheduled ? Timestamp.fromDate(scheduledTime) : Timestamp.now(),
                        };

                        if (existingStream != null) {
                          _firebaseService.updateStream(existingStream.id, data);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully!')));
                        } else {
                          FirebaseFirestore.instance.collection('streams').add(data);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added successfully!')));
                        }
                        Navigator.pop(context);
                      },
                      child: const Text("Save"),
                    ),
                  ],
                );
              }
            );
          }
        );
      },
    );
  }

  // Category Management Dialog
  Future<void> _showCategoryDialog({CategoryModel? category}) async {
    _catNameController.text = category?.name ?? '';
    String selectedIcon = category?.icon ?? 'tv';
    _catPriorityController.text = category?.priority.toString() ?? '0';
    bool isHidden = category?.isHidden ?? false;

    final List<Map<String, dynamic>> iconOptions = [
      {'name': 'tv', 'icon': Icons.tv_rounded},
      {'name': 'sports', 'icon': Icons.sports_soccer_rounded},
      {'name': 'movie', 'icon': Icons.movie_rounded},
      {'name': 'music', 'icon': Icons.music_note_rounded},
      {'name': 'news', 'icon': Icons.newspaper_rounded},
      {'name': 'category', 'icon': Icons.category_rounded},
    ];

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(category == null ? "Add Category" : "Edit Category"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: _catNameController, decoration: const InputDecoration(labelText: 'Category Name')),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedIcon,
                    decoration: const InputDecoration(labelText: 'Select Icon'),
                    items: iconOptions.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt['name'],
                        child: Row(
                          children: [
                            Icon(opt['icon'], size: 20),
                            const SizedBox(width: 12),
                            Text(opt['name'].toString().toUpperCase()),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedIcon = val!),
                  ),
                  TextField(controller: _catPriorityController, decoration: const InputDecoration(labelText: 'Priority (0, 1, 2...)'), keyboardType: TextInputType.number),
                  SwitchListTile(
                    title: const Text("Hide Category"),
                    value: isHidden,
                    onChanged: (v) => setDialogState(() => isHidden = v),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () {
                    final id = category?.id ?? _catNameController.text.toLowerCase().replaceAll(' ', '_');
                    final data = {
                      'name': _catNameController.text,
                      'icon': selectedIcon,
                      'priority': int.tryParse(_catPriorityController.text) ?? 0,
                      'isHidden': isHidden,
                    };
                    _firebaseService.saveCategory(id, data);
                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _duplicateStream(StreamModel stream) async {
    final data = {
      'title': "${stream.title} (Copy)",
      'streamUrl': stream.streamUrl,
      'subtitle': stream.subtitle,
      'categoryId': stream.categoryId,
      'subCategory': stream.subCategory,
      'displayStyle': stream.displayStyle,
      'team1Name': stream.team1Name,
      'team1Logo': stream.team1Logo,
      'team2Name': stream.team2Name,
      'team2Logo': stream.team2Logo,
      'status': stream.status,
      'isHidden': stream.isHidden,
      'isScheduled': stream.isScheduled,
      'priority': stream.priority,
      'startTime': Timestamp.fromDate(stream.startTime),
    };
    await FirebaseFirestore.instance.collection('streams').add(data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duplicate created!')));
    }
  }

  Future<void> _deleteChannel(String id) async {
    try {
      await _firebaseService.deleteStream(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  Future<void> _sendNotification() async {
    final title = _notifTitleController.text.trim();
    final body = _notifBodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title and message')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Send via FCM Topic
      await _firebaseService.sendBroadcastNotification(title, body);

      // 2. Log to Firestore for history
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'body': body,
        'createdAt': Timestamp.now(),
        'status': 'sent',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification sent successfully!')),
        );
        _notifTitleController.clear();
        _notifBodyController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Admin'),
        content: const Text('Are you sure you want to leave the Admin Dashboard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('YES'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: DefaultTabController(
        length: 6,
        child: Scaffold(
          appBar: AppBar(
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Search...', border: InputBorder.none),
                    style: TextStyle(color: colorScheme.onSurface),
                    onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                  )
                : const Text('Admin Dashboard'),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () => setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchQuery = "";
                    _searchController.clear();
                  }
                }),
              ),
              IconButton(
                onPressed: () => _showAddDialog(),
                icon: const Icon(Icons.add_box),
                tooltip: 'Add Individual Channel',
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              indicatorColor: colorScheme.primary,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.playlist_add), text: "Search"),
                Tab(icon: Icon(Icons.storage), text: "Channels"),
                Tab(icon: Icon(Icons.category), text: "Categories"),
                Tab(icon: Icon(Icons.send), text: "Push Now"),
                Tab(icon: Icon(Icons.schedule_send), text: "Schedule"),
                Tab(icon: Icon(Icons.settings), text: "Settings"),
              ],
            ),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth > 800 ? 1000 : constraints.maxWidth,
                  ),
                  child: TabBarView(
                    children: [
                      _buildScraperTab(colorScheme),
                      _buildDatabaseTab(colorScheme),
                      _buildCategoryTab(colorScheme),
                      _buildNotificationTab(colorScheme),
                      _buildScheduledNotificationTab(colorScheme),
                      _buildSettingsTab(colorScheme),
                    ],
                  ),
                ),
              );
            }
          ),
        ),
      ),
    );
  }

  Widget _buildScheduledNotificationTab(ColorScheme colorScheme) {
    DateTime scheduleDate = DateTime.now().add(const Duration(minutes: 10));
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showScheduleDialog(),
            icon: const Icon(Icons.add_alarm),
            label: const Text("Schedule New Match Alert"),
          ),
        ),
        const Divider(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firebaseService.getScheduledNotifications(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final time = (data['scheduledTime'] as Timestamp).toDate();
                  final status = data['status'] ?? 'pending';

                  return ListTile(
                    leading: Icon(
                      status == 'sent' ? Icons.check_circle : Icons.timer,
                      color: status == 'sent' ? Colors.green : Colors.orange,
                    ),
                    title: Text(data['title'] ?? ''),
                    subtitle: Text("${data['body']}\nTime: ${DateFormat('dd MMM, hh:mm a').format(time)}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _firebaseService.deleteScheduledNotification(docs[index].id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showScheduleDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    DateTime pickedTime = DateTime.now().add(const Duration(hours: 1));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Schedule Notification"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: bodyController, decoration: const InputDecoration(labelText: 'Body')),
                ListTile(
                  title: Text("Time: ${DateFormat('dd/MM/yyyy hh:mm a').format(pickedTime)}"),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: pickedTime,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(pickedTime),
                      );
                      if (time != null) {
                        setDialogState(() {
                          pickedTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                await _firebaseService.scheduleNotification(
                  titleController.text,
                  bodyController.text,
                  pickedTime,
                );
                Navigator.pop(context);
              },
              child: const Text("Schedule"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTab(ColorScheme colorScheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => _showCategoryDialog(),
            icon: const Icon(Icons.add),
            label: const Text("Add New Category"),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CategoryModel>>(
            stream: _firebaseService.getCategories(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final cats = snapshot.data!;
              return ListView.builder(
                itemCount: cats.length,
                itemBuilder: (context, index) {
                  final cat = cats[index];
                  return ListTile(
                    leading: Icon(_getIconData(cat.icon), color: cat.isHidden ? Colors.grey : colorScheme.primary),
                    title: Text(cat.name, style: TextStyle(decoration: cat.isHidden ? TextDecoration.lineThrough : null)),
                    subtitle: Text("ID: ${cat.id} | Priority: ${cat.priority}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(cat.isHidden ? Icons.visibility_off : Icons.visibility, color: cat.isHidden ? Colors.grey : Colors.blue),
                          onPressed: () => _firebaseService.saveCategory(cat.id, {'isHidden': !cat.isHidden}),
                        ),
                        IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _showCategoryDialog(category: cat)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _firebaseService.deleteCategory(cat.id)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Force Update Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            'Users with an older version will be forced to update to the version specified below.',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _versionController,
            decoration: InputDecoration(
              labelText: 'Latest App Version Name',
              hintText: 'e.g., 1.0.1',
              prefixIcon: const Icon(Icons.update_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _buildNumberController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Latest Version Code (Build Number)',
              hintText: 'e.g., 2',
              prefixIcon: const Icon(Icons.numbers_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _updateUrlController,
            decoration: InputDecoration(
              labelText: 'Download URL',
              hintText: 'e.g., https://yourwebsite.com/app.apk',
              prefixIcon: const Icon(Icons.link_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () async {
                setState(() => _isLoading = true);
                await _firebaseService.updateAppVersionConfig(
                  _versionController.text.trim(),
                  int.tryParse(_buildNumberController.text.trim()) ?? 1,
                  _updateUrlController.text.trim(),
                );
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Version settings updated!')),
                );
              },
              icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_rounded),
              label: Text(
                _isLoading ? 'Saving...' : 'Update App Version',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScraperTab(ColorScheme colorScheme) {
    final filteredChannels = _apiChannels.where((channel) {
      final name = (channel['name'] ?? '').toString().toLowerCase();
      final url = (channel['url'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || url.contains(_searchQuery);
    }).toList();

    return StreamBuilder<List<StreamModel>>(
      stream: _firebaseService.getStreams(),
      builder: (context, savedSnapshot) {
        final Map<String, StreamModel> savedStreams = {
          for (var s in (savedSnapshot.data ?? [])) s.streamUrl: s
        };

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: StreamBuilder<List<String>>(
                stream: _firebaseService.getM3uHistory(),
                builder: (context, snapshot) {
                  final history = snapshot.data ?? [];
                  return Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return history.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      _urlController.text = selection;
                      _fetchFromUrl(selection);
                    },
                    fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: textController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Enter M3U or JSON URL...',
                          prefixIcon: const Icon(Icons.link),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.download, color: colorScheme.primary),
                            onPressed: () {
                              _urlController.text = textController.text;
                              _fetchFromUrl(textController.text);
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onSubmitted: (value) {
                          _urlController.text = value;
                          _fetchFromUrl(value);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            if (_isLoading) LinearProgressIndicator(color: colorScheme.primary),
            Expanded(
              child: ListView.builder(
                itemCount: filteredChannels.length,
                itemBuilder: (context, index) {
                  final channel = filteredChannels[index];
                  final streamUrl = channel['url'] ?? '';
                  final savedStream = savedStreams[streamUrl];
                  final isSaved = savedStream != null;

                  return ListTile(
                    leading: channel['logo'] != null && channel['logo'] != ''
                        ? Image.network(channel['logo'], width: 40, errorBuilder: (c, e, s) => const Icon(Icons.tv))
                        : const Icon(Icons.tv),
                    title: Text(channel['name'] ?? 'Unknown', style: TextStyle(color: isSaved ? colorScheme.primary : colorScheme.onSurface)),
                    subtitle: Text(streamUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_arrow, color: Colors.green),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => PlayerScreen(
                              stream: StreamModel(
                                id: 'temp', title: channel['name'], subtitle: '', categoryId: 'all',
                                team1Name: '', team1Logo: '', team2Name: '', team2Logo: '',
                                streamUrl: streamUrl, startTime: DateTime.now(), status: 'live',
                              ),
                            )));
                          },
                        ),
                        if (isSaved)
                          IconButton(icon: Icon(Icons.delete, color: colorScheme.error), onPressed: () => _deleteChannel(savedStream.id))
                        else
                          IconButton(icon: Icon(Icons.add_circle, color: colorScheme.onSurfaceVariant), onPressed: () => _showAddDialog(channel: channel)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDatabaseTab(ColorScheme colorScheme) {
    return StreamBuilder<List<CategoryModel>>(
      stream: _firebaseService.getCategories(),
      builder: (context, catSnapshot) {
        if (!catSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final categories = catSnapshot.data!;
        if (categories.isEmpty) {
          return const Center(child: Text("No categories found. Please add one first."));
        }

        return DefaultTabController(
          length: categories.length,
          child: Column(
            children: [
              Container(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                child: TabBar(
                  isScrollable: true,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                  tabs: categories.map((cat) => Tab(text: cat.name)).toList(),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: categories.map((cat) {
                    if (cat.icon == 'sports') {
                      return DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            TabBar(
                              tabs: const [
                                Tab(text: "Live Matches"),
                                Tab(text: "Sports TV"),
                              ],
                              labelColor: colorScheme.primary,
                              unselectedLabelColor: colorScheme.onSurfaceVariant,
                              indicatorSize: TabBarIndicatorSize.label,
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildStreamList(cat.id, "Live Matches", colorScheme, subCategory: 'live_match'),
                                  _buildStreamList(cat.id, "Sports TV", colorScheme, subCategory: 'sports_tv'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return _buildStreamList(cat.id, cat.name, colorScheme);
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStreamList(String categoryId, String categoryName, ColorScheme colorScheme, {String? subCategory}) {
    return StreamBuilder<List<StreamModel>>(
      stream: _firebaseService.getStreams(categoryId: categoryId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: colorScheme.primary));
        
        var list = snapshot.data!.where((s) => s.title.toLowerCase().contains(_searchQuery)).toList();
        
        if (subCategory != null) {
          list = list.where((s) => s.subCategory == subCategory).toList();
        }
        
        if (list.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isEmpty ? "No channels in $categoryName" : "No results for '$_searchQuery'",
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          );
        }

        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final stream = list[index];
            return ListTile(
              leading: stream.team1Logo.isNotEmpty 
                  ? Image.network(stream.team1Logo, width: 40, errorBuilder: (c, e, s) => const Icon(Icons.tv))
                  : const Icon(Icons.tv),
              title: Row(
                children: [
                  Expanded(
                    child: Text(stream.title, style: TextStyle(color: stream.isHidden ? Colors.grey : colorScheme.onSurface, decoration: stream.isHidden ? TextDecoration.lineThrough : null)),
                  ),
                  if (stream.viewerCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye, size: 12, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            '${stream.viewerCount}',
                            style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              subtitle: Text("${stream.subtitle} | ${stream.streamUrl}", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colorScheme.onSurfaceVariant)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subCategory == 'live_match')
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.teal, size: 20),
                      tooltip: 'Duplicate Match',
                      onPressed: () => _duplicateStream(stream),
                    ),
                  IconButton(
                    icon: Icon(stream.isHidden ? Icons.visibility_off : Icons.visibility, color: stream.isHidden ? Colors.grey : Colors.blue),
                    onPressed: () => _firebaseService.updateStream(stream.id, {'isHidden': !stream.isHidden}),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PlayerScreen(stream: stream)));
                    },
                  ),
                  IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _showAddDialog(existingStream: stream)),
                  IconButton(icon: Icon(Icons.delete, color: colorScheme.error), onPressed: () => _deleteChannel(stream.id)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send Push Notification',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            'Broadcast a message to all app users immediately.',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _notifTitleController,
            decoration: InputDecoration(
              labelText: 'Notification Title',
              hintText: 'e.g., Live Match Starting!',
              prefixIcon: const Icon(Icons.title_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notifBodyController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Message Body',
              hintText: 'e.g., Bangladesh vs India is now live. Watch now on SponT TV!',
              prefixIcon: const Icon(Icons.message_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendNotification,
              icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
              label: Text(
                _isLoading ? 'Processing...' : 'Send Broadcast Notification',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Note: This will add a record to the "notifications" collection. Use a Firebase Cloud Function to listen to this collection and trigger actual FCM delivery.',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
