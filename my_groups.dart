import 'package:flutter/material.dart';
import 'dart:async';
import 'my_groups1.dart';
import 'package:responsive_builder/responsive_builder.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduConnect',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF007BFF),
        hintColor: const Color(0xFF28A745),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
          titleLarge: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          iconTheme: IconThemeData(color: Colors.black87),
          elevation: 1,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF007BFF),
          unselectedItemColor: Colors.grey,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007BFF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF28A745),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        dialogTheme: DialogTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFF28A745), // Accent color
        ),
      ),
      home: const ResponsiveGroupListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ResponsiveGroupListScreen extends StatelessWidget {
  const ResponsiveGroupListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        return GroupListScreen(
          deviceScreenType: sizingInformation.deviceScreenType,
        );
      },
    );
  }
}

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key, required this.deviceScreenType});

  final DeviceScreenType deviceScreenType;

  @override
  _GroupListScreenState createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen>
    with TickerProviderStateMixin {
  List<Group> groups = [];
  List<Group> archivedGroups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final List<String> _searchHistory = [];
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Color _backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Change background color based on device type
    if (widget.deviceScreenType == DeviceScreenType.mobile) {
      _backgroundColor = Colors.grey[100]!;
    } else {
      _backgroundColor = Colors.white;
    }

    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        groups = [
          Group(
            name: 'Flutter Development Group',
            description: 'A group for discussing Flutter development topics.',
            profileImage: 'https://source.unsplash.com/random/150x150?flutter',
            lastMessage: 'John: Let\'s discuss the new UI components.',
            time: '3:47 AM',
            messages: [
              Message(
                text: 'Hello!',
                sender: 'John',
                time: DateTime.now(),
                type: MessageType.text,
              ),
            ],
            media: [],
            members: [
              Member(
                name: 'George Smith',
                isAdmin: true,
                imageUrl: 'https://example.com/george.jpg', // Placeholder URL
                id: 'george-123', // Placeholder ID
                description: 'Software Engineer', // Placeholder description
                company: 'TechCorp', // Placeholder company
                location: 'New York, NY',
              ), // Placeholder location
            ],
            isJoinRequested: false,
            isMember: true,
          ),
          Group(
            name: 'AI and Machine Learning',
            description: 'Discussing the latest advancements in AI and ML.',
            profileImage: 'https://source.unsplash.com/random/150x150?ai',
            lastMessage: 'Emily: Check out this research paper!',
            time: '10:41 AM',
            messages: [
              Message(
                text: 'Important update!',
                sender: 'Alice',
                time: DateTime.now(),
                type: MessageType.text,
              ),
            ],
            media: [],
            members: [
              Member(
                name: 'George Smith',
                isAdmin: true,
                imageUrl: 'https://example.com/george.jpg', // Placeholder URL
                id: 'george-123', // Placeholder ID
                description: 'Software Engineer', // Placeholder description
                company: 'TechCorp', // Placeholder company
                location: 'New York, NY',
              ), // Placeholder location
              Member(
                name: 'Sophia Clark',
                imageUrl: 'https://example.com/sophia.jpg', // Placeholder URL
                id: 'sophia-456', // Placeholder ID
                description: 'Product Manager', // Placeholder description
                company: 'Innovate Inc.', // Placeholder company
                location: 'San Francisco, CA',
              ), // Placeholder location
              Member(
                name: 'Henry Taylor',
                imageUrl: 'https://example.com/henry.jpg', // Placeholder URL
                id: 'henry-789', // Placeholder ID
                description: 'Data Scientist', // Placeholder description
                company: 'Analytics Co.', // Placeholder company
                location: 'London, UK',
              ), // Placeholder location
            ],
            isJoinRequested: false,
            isMember: true,
          ),
          Group(
            name: 'Mobile App Design',
            description: 'Sharing design ideas and feedback for mobile apps.',
            profileImage: 'https://source.unsplash.com/random/150x150?mobile',
            lastMessage: 'Sophia: Updated design mockups are ready.',
            time: '3:57 AM',
            messages: [
              Message(
                text: 'New photo!',
                sender: 'Sree',
                time: DateTime.now(),
                type: MessageType.image,
                fileUrl: 'https://source.unsplash.com/random/150x150?design',
              ),
            ],
            media: [],
            members: [
              Member(
                name: 'George Smith',
                isAdmin: true,
                imageUrl: 'https://example.com/george.jpg', // Placeholder URL
                id: 'george-123', // Placeholder ID
                description: 'Software Engineer', // Placeholder description
                company: 'TechCorp', // Placeholder company
                location: 'New York, NY',
              ), // Placeholder location
              Member(
                name: 'Sophia Clark',
                imageUrl: 'https://example.com/sophia.jpg', // Placeholder URL
                id: 'sophia-456', // Placeholder ID
                description: 'Product Manager', // Placeholder description
                company: 'Innovate Inc.', // Placeholder company
                location: 'San Francisco, CA',
              ), // Placeholder location
              Member(
                name: 'Henry Taylor',
                imageUrl: 'https://example.com/henry.jpg', // Placeholder URL
                id: 'henry-789', // Placeholder ID
                description: 'Data Scientist', // Placeholder description
                company: 'Analytics Co.', // Placeholder company
                location: 'London, UK',
              ), // Placeholder location
            ],
            isJoinRequested: true,
            isMember: false,
          ),
        ];

        archivedGroups = [
          Group(
            name: 'Old Project Discussions',
            description: 'Group archived discussions of old projects',
            profileImage: 'https://source.unsplash.com/random/150x150?archive',
            lastMessage: 'This group is archived',
            time: 'Yesterday',
            messages: [],
            media: [],
            members: [
              Member(
                name: 'Archived User1',
                isAdmin: true,
                imageUrl: 'https://example.com/george.jpg', // Placeholder URL
                id: 'george-123', // Placeholder ID
                description: 'Software Engineer', // Placeholder description
                company: 'TechCorp', // Placeholder company
                location: 'New York, NY',
              ), // Placeholder location
              Member(
                name: 'Archived User2',
                imageUrl: 'https://example.com/sophia.jpg', // Placeholder URL
                id: 'sophia-456', // Placeholder ID
                description: 'Product Manager', // Placeholder description
                company: 'Innovate Inc.', // Placeholder company
                location: 'San Francisco, CA',
              ), // Placeholder location               // Placeholder location
            ],
            isJoinRequested: false,
            isMember: false,
          ),
        ];
        _isLoading = false;
        _animationController.forward();
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<Group> get _filteredGroups {
    if (_searchQuery.isEmpty) {
      return groups;
    } else {
      return groups
          .where(
            (group) =>
                group.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _addToSearchHistory(String query) {
    if (!_searchHistory.contains(query)) {
      setState(() {
        _searchHistory.insert(0, query);
        if (_searchHistory.length > 5) {
          _searchHistory.removeLast();
        }
      });
    }
  }

  void _clearSearchHistory() {
    setState(() {
      _searchHistory.clear();
    });
  }

  void _onCreateGroup() async {
    final newGroup = await Navigator.push<Group>(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
    );

    if (newGroup != null) {
      setState(() {
        groups.add(newGroup);
      });
    }
  }

  void _showGroupOptions(Group group) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Group Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.push_pin),
                title: const Text('Pin Group'),
                onTap: () {
                  Navigator.pop(context);
                  //Implement Pin Group Logic
                  _pinGroup(group);
                },
              ),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Leave Group'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement Leave Group Logic
                  _leaveGroup(group);
                },
              ),
              ListTile(
                leading: const Icon(Icons.report),
                title: const Text('Report Group'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement Report Group Logic
                  _reportGroup(group);
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _pinGroup(Group group) {
    // Implement Pin Group Logic
    print('Pinning group: ${group.name}');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Pinning group: ${group.name}')));
  }

  void _leaveGroup(Group group) {
    // Implement Leave Group Logic
    print('Leaving group: ${group.name}');
    setState(() {
      groups.remove(group);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('You left group: ${group.name}')));
  }

  void _reportGroup(Group group) {
    // Implement Report Group Logic
    print('Reporting group: ${group.name}');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Reporting group: ${group.name}')));
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title:
            _searchQuery.isEmpty ? const Text('Groups') : _buildSearchField(),
        actions: [
          if (_searchQuery.isEmpty)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                });
              },
            ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: EdgeInsets.all(
                    screenWidth * 0.02,
                  ), // Responsive padding
                  child: Column(
                    children: [
                      Expanded(
                        child:
                            _searchQuery.isNotEmpty && _searchHistory.isNotEmpty
                                ? _buildSearchHistoryListView()
                                : ListView(
                                  children: [
                                    Card(
                                      elevation: 2,
                                      margin: EdgeInsets.symmetric(
                                        horizontal: screenWidth * 0.02,
                                        vertical: 8,
                                      ),
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.archive,
                                          color: Colors.black54,
                                        ),
                                        title: const Text(
                                          'Archived',
                                          style: TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                        trailing: Text(
                                          '${archivedGroups.length}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      ArchivedGroupsScreen(
                                                        archivedGroups:
                                                            archivedGroups,
                                                      ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const Divider(),
                                    ..._filteredGroups
                                        .where(
                                          (group) =>
                                              group.name.toLowerCase().contains(
                                                _searchQuery.toLowerCase(),
                                              ),
                                        )
                                        .map(
                                          (group) => GestureDetector(
                                            onLongPress: () {
                                              _showGroupOptions(group);
                                            },
                                            child: GroupListItem(
                                              group: group,
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (context) => ChatScreen(
                                                          group: group,
                                                        ),
                                                  ),
                                                );
                                              },
                                              onJoinTap: () {
                                                _requestToJoinGroup(group);
                                              },
                                            ),
                                          ),
                                        ),
                                  ],
                                ),
                      ),
                    ],
                  ),
                ),
              ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.update), label: 'Updates'),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Communities',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        onPressed: _onCreateGroup,
        child: const Icon(Icons.group_add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchField() {
    double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth * 0.7, // Responsive width
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search groups...',
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
            },
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.02,
            vertical: 12,
          ), // Responsive padding
        ),
        style: const TextStyle(color: Colors.black87, fontSize: 16),
        onChanged: _onSearchChanged,
        onSubmitted: (String query) {
          _addToSearchHistory(query);
        },
      ),
    );
  }

  Widget _buildSearchHistoryListView() {
    double screenWidth = MediaQuery.of(context).size.width;

    return ListView.builder(
      itemCount: _searchHistory.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.all(screenWidth * 0.02), // Responsive padding
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _clearSearchHistory,
                child: const Text(
                  "Clear History",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ),
          );
        } else {
          final searchItem = _searchHistory[index - 1];
          return Card(
            elevation: 2,
            margin: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.02,
              vertical: 4,
            ),
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text(
                searchItem,
                style: const TextStyle(color: Colors.black87),
              ),
              onTap: () {
                _searchController.text = searchItem;
                _onSearchChanged(searchItem);
                _addToSearchHistory(searchItem);
              },
            ),
          );
        }
      },
    );
  }

  void _requestToJoinGroup(Group group) {
    setState(() {
      group.isJoinRequested = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        group.isMember = true;
      });

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You joined group: ${group.name}')),
      );
    });
  }
}
