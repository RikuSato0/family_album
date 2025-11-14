import 'package:flutter/material.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:immich_mobile/widgets/common/immich_app_bar.dart';
import 'package:immich_mobile/widgets/common/search_field.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:immich_mobile/entities/store.entity.dart' as immichStore;
import 'package:immich_mobile/domain/models/store.model.dart';

class FileBrowserPage extends StatefulWidget {
  const FileBrowserPage({super.key});

  @override
  FileBrowserPageState createState() => FileBrowserPageState();
}

class FileBrowserPageState extends State<FileBrowserPage> {
  late webdav.Client client;
  late String url;
  late String user;
  late String pwd;
  String dirPath = '/';

  // Search functionality
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  List<webdav.File> allFiles = [];
  List<webdav.File> filteredFiles = [];
  String searchQuery = '';

  List<String> pathStack = ['/'];

  // Selection mode
  bool isSelectionMode = false;
  Set<String> selectedFiles = <String>{};

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    url = immichStore.Store.tryGet(StoreKey.localEndpoint) ?? '';
    user = immichStore.Store.tryGet(StoreKey.nextcloudUser) ?? '';
    pwd = immichStore.Store.tryGet(StoreKey.nextcloudPassword) ?? '';
    if (url.isNotEmpty && user.isNotEmpty && pwd.isNotEmpty) {
      client = webdav.newClient(
        url,
        user: user,
        password: pwd,
        debug: true,
      );
      client.ping().then((_) {
        print("✅ Connection successful");
      }).catchError((e) {
        print("❌ Ping failed: $e");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || user.isEmpty || pwd.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("You need to configure Nextcloud URL, username, and password in settings.")),
      );
    }

    return Scaffold(
      appBar: ImmichAppBar(
        title: isSelectionMode ? "${selectedFiles.length} ${'selected'.tr()}" : "library".tr(),
        showUploadButton: false,
        showRefreshButton: false,
        showProfileButton: false,
        actions: _buildAppBarActions(),
      ),
      body: Column(
        children: [
          // Breadcrumbs navigation
          if (pathStack.length > 1 && !isSelectionMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _buildBreadcrumbs(),
                ),
              ),
            ),

          // Search bar
          if (!isSelectionMode)
            Container(
              padding: const EdgeInsets.all(16),
              child: SearchField(
                autofocus: false,
                contentPadding: const EdgeInsets.all(16),
                hintText: 'Search'.tr(),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: clearSearch,
                      )
                    : null,
                controller: searchController,
                onChanged: (_) => onSearch(searchController.text),
                focusNode: searchFocusNode,
                onTapOutside: (_) => searchFocusNode.unfocus(),
              ),
            ),

          // Selection mode toolbar
          if (isSelectionMode)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _selectAll,
                    icon: const Icon(Icons.select_all),
                    label: Text('select_all'.tr()),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed:
                        selectedFiles.isNotEmpty ? _downloadSelected : null,
                    icon: const Icon(Icons.download),
                    tooltip: 'Download',
                  ),
                  IconButton(
                    onPressed:
                        selectedFiles.isNotEmpty ? _deleteSelected : null,
                    icon: const Icon(Icons.delete),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ),

          // File list
          Expanded(
            child: FutureBuilder<List<webdav.File>>(
              future: _getData(),
              builder: (BuildContext context,
                  AsyncSnapshot<List<webdav.File>> snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.none:
                  case ConnectionState.active:
                  case ConnectionState.waiting:
                    return const Center(child: CircularProgressIndicator());
                  case ConnectionState.done:
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    allFiles = snapshot.data ?? [];
                    final displayFiles =
                        searchQuery.isEmpty ? allFiles : filteredFiles;
                    return _buildFileList(context, displayFiles);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    if (isSelectionMode) {
      return [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectionMode,
        ),
      ];
    }

    List<Widget> actions = [];

    // Select button
    actions.add(
      IconButton(
        icon: const Icon(Icons.checklist),
        onPressed: _enterSelectionMode,
        tooltip: 'Select files',
      ),
    );

    // Back button for navigation
    if (pathStack.length > 1) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBack,
        ),
      );
    }

    return actions;
  }

  void _enterSelectionMode() {
    setState(() {
      isSelectionMode = true;
      selectedFiles.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      isSelectionMode = false;
      selectedFiles.clear();
    });
  }

  void _selectAll() {
    setState(() {
      final displayFiles = searchQuery.isEmpty ? allFiles : filteredFiles;
      selectedFiles.clear();
      for (var file in displayFiles) {
        if (file.name != null) {
          selectedFiles.add(file.name!);
        }
      }
    });
  }

  void _downloadSelected() {
    // Implement download logic for selected files
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${selectedFiles.length} files...'),
      ),
    );
    print('Download selected files: $selectedFiles');
  }

  void _deleteSelected() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Files'),
        content: Text(
            'Are you sure you want to delete ${selectedFiles.length} selected files?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeleteSelected();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _performDeleteSelected() async {
    try {
      for (String fileName in selectedFiles) {
        String filePath = dirPath;
        if (!filePath.endsWith('/')) filePath += '/';
        filePath += fileName;

        await client.remove(filePath);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${selectedFiles.length} files'),
          backgroundColor: Colors.green,
        ),
      );

      _exitSelectionMode();
      setState(() {}); // Refresh the file list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<webdav.File>> _getData() async {
    try {
      return await client.readDir(dirPath);
    } catch (e) {
      print('WebDAV Error: $e');
      rethrow;
    }
  }

  void onSearch(String query) {
    setState(() {
      searchQuery = query.toLowerCase();
      if (searchQuery.isEmpty) {
        filteredFiles = [];
      } else {
        filteredFiles = allFiles.where((file) {
          return file.name?.toLowerCase().contains(searchQuery) ?? false;
        }).toList();
      }
    });
  }

  void clearSearch() {
    setState(() {
      searchController.clear();
      searchQuery = '';
      filteredFiles = [];
    });
  }

  Widget _buildFileList(BuildContext context, List<webdav.File> files) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: files.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final file = files[index];
        return _buildFileItem(file);
      },
    );
  }

  Widget _buildFileItem(webdav.File file) {
    final isSelected = selectedFiles.contains(file.name);

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: Colors.blue.shade300, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true && file.name != null) {
                      selectedFiles.add(file.name!);
                    } else if (file.name != null) {
                      selectedFiles.remove(file.name!);
                    }
                  });
                },
              ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getFileColor(file),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getFileIcon(file),
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
        title: Text(
          file.name ?? 'Unknown',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          _formatDate(file.mTime),
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        trailing: file.isDir == true
            ? const Icon(Icons.chevron_right, color: Colors.grey)
            : Text(
                _formatFileSize(file.size ?? 0),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
        onTap: () {
          if (isSelectionMode) {
            setState(() {
              if (isSelected && file.name != null) {
                selectedFiles.remove(file.name!);
              } else if (file.name != null) {
                selectedFiles.add(file.name!);
              }
            });
          } else {
            if (file.isDir == true) {
              _navigateToFolder(file);
            } else {
              _handleFileTap(file);
            }
          }
        },
        onLongPress: isSelectionMode ? null : () => _showFileActionModal(file),
      ),
    );
  }

  void _showFileActionModal(webdav.File file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file.name ?? 'Unknown',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (file.isDir == true)
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Browse'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToFolder(file);
                },
              ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              onTap: () {
                Navigator.pop(context);
                _downloadFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(file);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _downloadFile(webdav.File file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${file.name}...'),
      ),
    );
    print('Download file: ${file.name}');
    // Implement actual download logic here
  }

  void _showRenameDialog(webdav.File file) {
    final TextEditingController renameController =
        TextEditingController(text: file.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: renameController,
          decoration: const InputDecoration(
            labelText: 'New name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _renameFile(file, renameController.text);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _renameFile(webdav.File file, String newName) async {
    if (newName.isEmpty || newName == file.name) return;

    try {
      String oldPath = dirPath;
      if (!oldPath.endsWith('/')) oldPath += '/';
      oldPath += file.name ?? '';

      String newPath = dirPath;
      if (!newPath.endsWith('/')) newPath += '/';
      newPath += newName;

      await client.rename(oldPath, newPath, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Renamed to $newName'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {}); // Refresh the file list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error renaming file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteDialog(webdav.File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFile(file);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteFile(webdav.File file) async {
    try {
      String filePath = dirPath;
      if (!filePath.endsWith('/')) filePath += '/';
      filePath += file.name ?? '';

      await client.remove(filePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${file.name}'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {}); // Refresh the file list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  IconData _getFileIcon(webdav.File file) {
    if (file.isDir == true) {
      return Icons.folder;
    }

    final fileName = file.name?.toLowerCase() ?? '';
    if (fileName.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    } else if (fileName.endsWith('.jpg') ||
        fileName.endsWith('.jpeg') ||
        fileName.endsWith('.png')) {
      return Icons.image;
    } else if (fileName.endsWith('.xlsx') || fileName.endsWith('.xls')) {
      return Icons.table_chart;
    } else if (fileName.endsWith('.doc') || fileName.endsWith('.docx')) {
      return Icons.description;
    } else if (fileName.endsWith('.mp4') || fileName.endsWith('.mov')) {
      return Icons.play_circle;
    } else if (fileName.endsWith('.mp3') || fileName.endsWith('.wav')) {
      return Icons.music_note;
    }
    return Icons.insert_drive_file;
  }

  Color _getFileColor(webdav.File file) {
    if (file.isDir == true) {
      final folderName = file.name?.toLowerCase() ?? '';
      if (folderName.contains('download')) {
        return Colors.orange;
      } else if (folderName.contains('document')) {
        return Colors.blue;
      } else if (folderName.contains('work')) {
        return Colors.green;
      } else if (folderName.contains('archive')) {
        return Colors.grey;
      }
      return Colors.amber;
    }

    final fileName = file.name?.toLowerCase() ?? '';
    if (fileName.endsWith('.pdf')) {
      return Colors.red;
    } else if (fileName.endsWith('.jpg') ||
        fileName.endsWith('.jpeg') ||
        fileName.endsWith('.png')) {
      return Colors.lightBlue;
    } else if (fileName.endsWith('.xlsx') || fileName.endsWith('.xls')) {
      return Colors.green;
    } else if (fileName.endsWith('.doc') || fileName.endsWith('.docx')) {
      return Colors.blue;
    }
    return Colors.grey;
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown date';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  void _navigateToFolder(webdav.File folder) {
    print('Navigate to folder: ${folder.name}');
    setState(() {
      // Build new path
      String newPath = dirPath;
      if (!newPath.endsWith('/')) {
        newPath += '/';
      }
      newPath += folder.name ?? '';
      if (!newPath.endsWith('/')) {
        newPath += '/';
      }

      dirPath = newPath;
      pathStack.add(newPath);

      // Clear search when navigating
      searchController.clear();
      searchQuery = '';
      filteredFiles = [];

      // Exit selection mode when navigating
      if (isSelectionMode) {
        _exitSelectionMode();
      }
    });
  }

  void _handleFileTap(webdav.File file) {
    print('Open file: ${file.name}');
    // You can implement file opening logic here
  }

  void _navigateBack() {
    if (pathStack.length > 1) {
      setState(() {
        pathStack.removeLast();
        dirPath = pathStack.last;

        // Clear search when navigating
        searchController.clear();
        searchQuery = '';
        filteredFiles = [];

        // Exit selection mode when navigating
        if (isSelectionMode) {
          _exitSelectionMode();
        }
      });
    }
  }

  List<Widget> _buildBreadcrumbs() {
    List<Widget> breadcrumbs = [];

    for (int i = 0; i < pathStack.length; i++) {
      String pathName = i == 0
          ? 'Home'
          : pathStack[i].split('/').where((s) => s.isNotEmpty).last;

      breadcrumbs.add(
        GestureDetector(
          onTap: () => _navigateToPath(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: i == pathStack.length - 1
                  ? Colors.blue.shade100
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              pathName,
              style: TextStyle(
                color: i == pathStack.length - 1
                    ? Colors.blue.shade700
                    : Colors.grey.shade700,
                fontWeight: i == pathStack.length - 1
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ),
      );

      if (i < pathStack.length - 1) {
        breadcrumbs.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.chevron_right,
                size: 16, color: Colors.grey.shade600),
          ),
        );
      }
    }

    return breadcrumbs;
  }

  void _navigateToPath(int index) {
    if (index < pathStack.length - 1) {
      setState(() {
        pathStack = pathStack.sublist(0, index + 1);
        dirPath = pathStack.last;

        // Clear search when navigating
        searchController.clear();
        searchQuery = '';
        filteredFiles = [];

        // Exit selection mode when navigating
        if (isSelectionMode) {
          _exitSelectionMode();
        }
      });
    }
  }
}
