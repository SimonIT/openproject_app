import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:openproject_app/model/project_tree.dart';
import 'package:openproject_app/model/widgets.dart';
import 'package:openproject_dart_sdk/api.dart';

final FlutterSecureStorage storage = FlutterSecureStorage();

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenProject App',
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  LoginPage();

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController _hostController = TextEditingController();
  TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    storage.read(key: "host").then((String host) async {
      if (host != null) {
        storage.read(key: "apikey").then((String apiKey) {
          _login(host, apiKey);
        });
      }
    });
  }

  Future<void> _login(String host, String apiKey) async {
    defaultApiClient.basePath = host;
    defaultApiClient.getAuthentication<HttpBasicAuth>('basicAuth').username = 'apikey';
    defaultApiClient.getAuthentication<HttpBasicAuth>('basicAuth').password = apiKey;

    try {
      User me = await UsersApi().apiV3UsersIdGet("me");
      Projects projects = await ProjectsApi().apiV3ProjectsGet();
      storage.write(key: "host", value: host);
      storage.write(key: "apikey", value: apiKey);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) => StartPage(me: me, projects: projects),
        ),
      );
    } catch (e) {
      print("Exception when calling ActivitiesApi->apiV3ActivitiesIdGet: $e\n");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Anmelden"),
      ),
      body: Center(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text("Host:"),
              TextFormField(
                controller: _hostController,
                validator: (value) {
                  if (!Uri.parse(value).isAbsolute) {
                    return "Bitte gebe einen validen Host ein";
                  }
                  return null;
                },
              ),
              Text("API Key:"),
              TextFormField(
                controller: _apiKeyController,
              ),
              MaterialButton(
                child: Text("Anmelden"),
                onPressed: () {
                  if (_formKey.currentState.validate()) {
                    _login(_hostController.text, _apiKeyController.text);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StartPage extends StatefulWidget {
  final User me;
  final Projects projects;

  StartPage({Key key, @required this.me, @required this.projects}) : super(key: key);

  @override
  _StartPageState createState() => _StartPageState(this.projects);
}

class _StartPageState extends State<StartPage> {
  ProjectTree _projectTree;

  _StartPageState(Projects projects) {
    _projectTree = ProjectTree(projects);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("OpenProject von ${widget.me.name}"),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: CachedNetworkImageProvider(
                    widget.me.avatar,
                  ),
                ),
              ),
              child: Text(widget.me.name),
            ),
            _buildPanel(widget.me, _projectTree.rootNode),
            ListTile(
              leading: Icon(Icons.add),
              title: Text("Add Project"),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(User me, ProjectNode node) {
    if (node.children.length == 0) return Text("Keine Subprojekte vorhanden");
    return ExpansionPanelList(
      expandedHeaderPadding: EdgeInsets.only(left: 9),
      expansionCallback: (int index, bool isExpanded) {
        setState(() {
          node.children[index].isExpanded = !isExpanded;
        });
      },
      children: node.children.map<ExpansionPanel>((ProjectNode item) {
        return ExpansionPanel(
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
              title: Text(item.project.name),
              subtitle: DescriptionWidget(
                description: item.project.description,
                maxLength: 25,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) => ProjectPage(
                      project: item.project,
                      me: me,
                    ),
                  ),
                );
              },
            );
          },
          body: _buildPanel(me, item),
          isExpanded: item.isExpanded,
        );
      }).toList(),
    );
  }
}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: <Widget>[],
        ),
      ),
    );
  }
}

class ProjectPage extends StatefulWidget {
  final User me;
  final Project project;

  const ProjectPage({Key key, @required this.project, @required this.me}) : super(key: key);

  @override
  _ProjectPageState createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  static const String filterAll = "[]";
  static const String filterMe = "[{\"assigneeOrGroup\": {\"operator\":\"=\",\"values\":[\"me\"]}}]";

  String filter = filterAll;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
      ),
      endDrawer: Drawer(
        child: ListView(
          children: <Widget>[
            ListTile(
              title: Text("Calendar"),
            ),
            ListTile(
              title: Text("Members"),
            )
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: <Widget>[
            DescriptionWidget(description: widget.project.description),
            DescriptionWidget(description: widget.project.statusExplanation),
            Row(
              children: <Widget>[
                Text(
                  "Arbeitspakete",
                  style: Theme.of(context).textTheme.headline5,
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(Icons.person),
                  onPressed: () {
                    setState(() {
                      if (filter == filterAll) {
                        filter = filterMe;
                      } else {
                        filter = filterAll;
                      }
                    });
                  },
                )
              ],
            ),
            FutureBuilder(
              future: WorkPackagesApi().apiV3ProjectsIdWorkPackagesGet(widget.project.id, filters: filter),
              builder: (BuildContext context, AsyncSnapshot<WorkPackages> snapshot) {
                if (!snapshot.hasData) {
                  return CircularProgressIndicator();
                } else {
                  WorkPackages workPackages = snapshot.data;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      showCheckboxColumn: false,
                      columnSpacing: 10,
                      columns: [
                        DataColumn(
                          label: Text("TYP"),
                        ),
                        DataColumn(
                          label: Text("ID"),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text("THEMA"),
                        ),
                        DataColumn(
                          label: Text("STATUS"),
                        ),
                        DataColumn(
                          label: Text("ZUGEWIESEN AN"),
                        ),
                        DataColumn(
                          label: Text("PRIORITÄT"),
                        ),
                      ],
                      rows: [
                        for (WorkPackage workPackage in workPackages.embedded.elements)
                          DataRow(
                            cells: [
                              DataCell(
                                Text(workPackage.links.type.title),
                              ),
                              DataCell(
                                Text(workPackage.id.toString()),
                              ),
                              DataCell(
                                Text(workPackage.subject),
                              ),
                              DataCell(
                                Text(workPackage.links.status.title),
                              ),
                              DataCell(
                                Text(workPackage.links.assignee.title != null ? workPackage.links.assignee.title : "-"),
                              ),
                              DataCell(
                                Text(workPackage.links.priority.title),
                              ),
                            ],
                            onSelectChanged: (bool selected) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (BuildContext context) => WorkPackagePage(
                                    workPackage: workPackage,
                                    me: widget.me,
                                  ),
                                ),
                              );
                            },
                          )
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class WorkPackagePage extends StatelessWidget {
  final User me;
  final WorkPackage workPackage;

  const WorkPackagePage({Key key, @required this.workPackage, @required this.me}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${workPackage.links.type.title} ${workPackage.subject}"),
      ),
      endDrawer: Drawer(
        child: ListView(
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.delete),
              title: Text("Löschen"),
              onTap: () {
                WorkPackagesApi().apiV3WorkPackagesIdDelete(workPackage.id).then((value) {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text("Mir zuweisen"),
              onTap: () {
                WorkPackagesApi()
                    .apiV3WorkPackagesIdPatch(
                  workPackage.id,
                  body: WorkPackage()
                    ..lockVersion = workPackage.lockVersion
                    ..links = WorkPackageLinks()
                    ..links.assignee = Link()
                    ..links.assignee.href = me.links.self.href,
                )
                    .then((WorkPackage workPackage) {
                  Navigator.of(context).pop();
                }).catchError((Object error) {
                  if (error is ApiException) {
                    print(error.message);
                  } else {
                    throw error;
                  }
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.archive),
              title: Text("Archivieren"),
            ),
            ListTile(
              leading: Icon(Icons.business_center),
              title: Text("Status setzen"),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: <Widget>[
            Text(
              "Beschreibung",
              style: Theme.of(context).textTheme.headline5,
            ),
            DescriptionWidget(description: workPackage.description),
          ],
        ),
      ),
    );
  }
}
