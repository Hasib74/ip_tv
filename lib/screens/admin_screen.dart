import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:m3u/m3u.dart';
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
  String _searchQuery = "";
  bool _isSearching = false;
  String _targetCategory = "Live TV";

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded ${parsedChannels.length} channels.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  // Parse M3U Text
  Future<void> _parseM3U(String content) async {
    try {
      final m3uList = await M3uParser.parse(content);
      setState(() {
        _apiChannels = m3uList.map((item) => {
          'name': item.title,
          'logo': item.attributes['tvg-logo'] ?? '',
          'url': item.link,
          'categories': [item.attributes['group-title'] ?? 'General'],
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('M3U Parse Error: $e')));
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
                      const Text("VS", style: TextStyle(color: Colors.cyanAccent)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Search...', border: InputBorder.none),
                  style: const TextStyle(color: Colors.white),
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
          bottom: const TabBar(
            tabs: [
              Tab(text: "Search & Add", icon: Icon(Icons.playlist_add)),
              Tab(text: "Manage Saved", icon: Icon(Icons.storage)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildScraperTab(),
            _buildDatabaseTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildScraperTab() {
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
                    icon: const Icon(Icons.download),
                    onPressed: () => _fetchFromUrl(_urlController.text),
                  ),
                ),
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(),
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
                    title: Text(channel['name'] ?? 'Unknown', style: TextStyle(color: isSaved ? Colors.cyanAccent : Colors.white)),
                    subtitle: Text(streamUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteChannel(savedStream.id))
                        else
                          IconButton(icon: const Icon(Icons.add_circle, color: Colors.white70), onPressed: () => _showAddDialog(channel: channel)),
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

  Widget _buildDatabaseTab() {
    return StreamBuilder<List<StreamModel>>(
      stream: _firebaseService.getStreams(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final list = snapshot.data!.where((s) => s.title.toLowerCase().contains(_searchQuery)).toList();
        
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final stream = list[index];
            return ListTile(
              leading: stream.team1Logo.isNotEmpty 
                  ? Image.network(stream.team1Logo, width: 40, errorBuilder: (c, e, s) => const Icon(Icons.tv))
                  : const Icon(Icons.tv),
              title: Text(stream.title),
              subtitle: Text("${stream.subtitle} | ${stream.streamUrl}", maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _showAddDialog(existingStream: stream)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteChannel(stream.id)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
