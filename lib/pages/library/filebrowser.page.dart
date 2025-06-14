import 'package:flutter/material.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;


// ignore: camel_case_types
class FileBrowserPage extends StatefulWidget {
  const FileBrowserPage({super.key});

  @override
  FileBrowserPageState createState() => FileBrowserPageState();
}

// ignore: camel_case_types
class FileBrowserPageState extends State<FileBrowserPage> {
  // webdav
  late webdav.Client client;

  // https://stackoverflow.com/questions/65630743/how-to-solve-flutter-web-api-cors-error-only-with-dart-code
  final url = 'http://100.113.37.85:8888/remote.php/dav/files/admin/';
  final user = 'admin';
  final pwd = 'Expo@2020#';
  final dirPath = '/';

  @override
  void initState() {
    super.initState();

    // init client
    // client = webdav.newClient(
    //   url,
    //   user: user,
    //   password: pwd,
    //   debug: true,
    // );
    client = webdav.newClient(
      url,
      user: 'admin',
      password: 'Expo@2020#',
      debug: true,
    );

    client.ping().then((_) {
    print("✅ Connection successful");
    }).catchError((e) {
      print("❌ Ping failed: $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || user.isEmpty || pwd.isEmpty) {
      return const Center(child: Text("you need add url || user || pwd"));
    }
    return Scaffold(
      body: FutureBuilder(
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
                return _buildListView(context, snapshot.data ?? []);
            }
          },
        ),
    );
  }

  Future<List<webdav.File>> _getData() async {
  try {
    return await client.readDir(dirPath);
  } catch (e) {
    print('WebDAV Error: $e');
    rethrow;
  }
}

  Widget _buildListView(BuildContext context, List<webdav.File> list) {
    return ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, index) {
          final file = list[index];
          return ListTile(
            leading: Icon(
                file.isDir == true ? Icons.folder : Icons.file_present_rounded),
            title: Text(file.name ?? ''),
            subtitle: Text(file.mTime.toString()),
          );
        });
  }
}