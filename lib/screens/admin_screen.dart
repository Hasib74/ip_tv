import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  String _searchQuery = "";
  bool _isSearching = false;
  final String _targetCategory = "Live TV";

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
    String localTargetCategory = existingStream?.subtitle ?? _targetCategory;

    return showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingStream == null ? "Add Channel" : "Edit Channel"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      value: localTargetCategory,
                      isExpanded: true,
                      items: ["Live TV", "Live Sports"].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (newValue) => setDialogState(() => localTargetCategory = newValue!),
                    ),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Display Title'),
                    ),
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(labelText: 'Stream URL'),
                    ),
                    TextField(
                      controller: team1LogoController,
                      decoration: const InputDecoration(labelText: 'Logo / Icon URL'),
                    ),
                    if (localTargetCategory == "Live Sports") ...[
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
                  onPressed: () {
                    final data = {
                      'title': titleController.text,
                      'streamUrl': urlController.text,
                      'subtitle': localTargetCategory,
                      'categoryId': localTargetCategory.toLowerCase().replaceAll(' ', '_'),
                      'team1Name': team1NameController.text,
                      'team1Logo': team1LogoController.text,
                      'team2Name': localTargetCategory == "Live Sports" ? team2NameController.text : "Live TV",
                      'team2Logo': team2LogoController.text,
                      'status': 'live',
                      'startTime': existingStream?.startTime ?? Timestamp.now(),
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
      },
    );
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
      // In a real-world scenario with FCM, you would call a Cloud Function here.
      // For now, we will store the notification in a Firestore collection 
      // which a background task or your backend can process.
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'body': body,
        'createdAt': Timestamp.now(),
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification queued for sending!')),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
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
            indicatorColor: colorScheme.primary,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            tabs: const [
              Tab(text: "Search & Add", icon: Icon(Icons.playlist_add)),
              Tab(text: "Manage Saved", icon: Icon(Icons.storage)),
              Tab(text: "Notifications", icon: Icon(Icons.notifications_active)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildScraperTab(colorScheme),
            _buildDatabaseTab(colorScheme),
            _buildNotificationTab(colorScheme),
          ],
        ),
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
              child: TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'Enter M3U or JSON URL...',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.download, color: colorScheme.primary),
                    onPressed: () => _fetchFromUrl(_urlController.text),
                  ),
                ),
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
    return StreamBuilder<List<StreamModel>>(
      stream: _firebaseService.getStreams(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: colorScheme.primary));
        
        final list = snapshot.data!.where((s) => s.title.toLowerCase().contains(_searchQuery)).toList();
        
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final stream = list[index];
            return ListTile(
              leading: stream.team1Logo.isNotEmpty 
                  ? Image.network(stream.team1Logo, width: 40, errorBuilder: (c, e, s) => const Icon(Icons.tv))
                  : const Icon(Icons.tv),
              title: Text(stream.title, style: TextStyle(color: colorScheme.onSurface)),
              subtitle: Text("${stream.subtitle} | ${stream.streamUrl}", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colorScheme.onSurfaceVariant)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
