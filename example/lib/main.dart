import 'package:flutter/material.dart';
import 'package:hotspot/hotspot.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hotspot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.purple,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.purple,
      ),
      home: HotspotProvider(
        hotspotShapeBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
          side: const BorderSide(color: Colors.blue, width: 2),
        ),
        autoScroll: true, // Enable auto scrolling
        scrollAlignment: 0.5, // Center the target in scroll view
        skipInvisibleTargets: true, // Skip targets that can't be shown
        child: const MyHomePage(title: 'Hotspot Demo Home Page'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HotspotProvider.of(context).startFlow();
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('hotspot').withHotspot(
          order: 1,
          title: "Let's get started!",
          text: "We're going to give you an example tour with hotspot",
          hotspotShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(1),
            side: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              HotspotProvider.of(context).startFlow();
            },
          ).withHotspot(
            order: 4,
            icon: const Icon(Icons.play_arrow),
            title: 'Tour It!',
            text: 'Want to see the tour again? Tap this button',
          ),
        ],
      ),
      body: ListView(
        children: <Widget>[
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 20),
                const Text(
                  'You have smashed the button this many times:',
                ),
                Text(
                  '$_counter',
                  style: Theme.of(context).textTheme.headlineMedium,
                ).withHotspot(
                  order: 2,
                  title: 'Count It!',
                  text:
                      'This is the number of times you\'ve smashed the like button',
                ),
                const SizedBox(height: 30),

                // Add a button to navigate to the list example
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ListExamplePage(),
                      ),
                    );
                  },
                  child: const Text('Go to List Example'),
                ).withHotspot(
                  order: 3,
                  title: 'List Example',
                  text:
                      'Click here to see how hotspot works with scrollable lists',
                ),

                const SizedBox(height: 30),
                FloatingActionButton(
                  onPressed: _incrementCounter,
                  tooltip: 'Like',
                  child: const Icon(Icons.thumb_up),
                ).withHotspot(
                  order: 5, // Changed from 3 to 5 to accommodate the new button
                  title: 'Smash It!',
                  text: 'Smash this button after the tour.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ListExamplePage extends StatelessWidget {
  const ListExamplePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HotspotProvider(
      hotspotShapeBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.orange, width: 2),
      ),
      autoScroll: true,
      scrollAlignment: 0.5, // Center the target in scroll view
      skipInvisibleTargets: true, // Skip targets that can't be shown
      scrollDuration: const Duration(
          milliseconds: 800), // Longer duration for more visible scrolling
      scrollTimeout: const Duration(seconds: 3), // Longer timeout
      child: const ListExamplePageView(),
    );
  }
}

class ListExamplePageView extends StatefulWidget {
  const ListExamplePageView({Key? key}) : super(key: key);

  @override
  State<ListExamplePageView> createState() => _ListExamplePageViewState();
}

class _ListExamplePageViewState extends State<ListExamplePageView> {
  // Generate a list of 50 items for better demonstration of scrolling
  final List<String> items = List.generate(50, (index) => 'Item ${index + 1}');
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Start the list tour after everything is fully rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure we're at the top of the list when starting
      _scrollController.jumpTo(0);

      // Small delay to ensure the list is fully rendered
      Future.delayed(const Duration(milliseconds: 500), () {
        HotspotProvider.of(context).startFlow('list');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scrolling Example').withHotspot(
          flow: 'list',
          order: 1,
          title: 'Scrollable List',
          text:
              'This example shows how hotspot automatically scrolls to show items',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              // Ensure we're at the top of the list when restarting
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );

              Future.delayed(const Duration(milliseconds: 350), () {
                HotspotProvider.of(context).startFlow('list');
              });
            },
          ).withHotspot(
            flow: 'list',
            order: 2,
            title: 'Restart Tour',
            text: 'Click here to restart the scrolling demonstration',
          ),
        ],
      ),
      body: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          // Add hotspots to specific items with more spacing between them
          if (index == 0) {
            return Card(
              elevation: 2,
              child: ListTile(
                title: Text(items[index],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                leading: const Icon(Icons.star, color: Colors.amber),
                subtitle:
                    const Text('This is the first item in our scrollable list'),
              ),
            ).withHotspot(
              flow: 'list',
              order: 3,
              title: 'First Item',
              text: 'This is the first item in our list',
            );
          } else if (index == 10) {
            return Card(
              elevation: 2,
              color: Colors.lightBlue.withOpacity(0.1),
              child: ListTile(
                title: Text(items[index],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                leading: const Icon(Icons.favorite, color: Colors.red),
                subtitle: const Text(
                    'This item should scroll into view automatically'),
              ),
            ).withHotspot(
              flow: 'list',
              order: 4,
              title: 'Item #10',
              text: 'The list should have scrolled down to show this item',
            );
          } else if (index == 15) {
            return Card(
              elevation: 2,
              color: Colors.amber.withOpacity(0.1),
              child: ListTile(
                title: Text(items[index],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                leading: const Icon(Icons.lightbulb, color: Colors.amber),
                subtitle: const Text('This is much farther down the list'),
              ),
            ).withHotspot(
              flow: 'list',
              order: 5,
              title: 'Item #16',
              text: 'Notice how the page automatically scrolls to show items',
            );
          } else if (index == 40) {
            return Card(
              elevation: 2,
              color: Colors.green.withOpacity(0.1),
              child: ListTile(
                title: Text(items[index],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                leading: const Icon(Icons.check_circle, color: Colors.green),
                subtitle: const Text('This is near the end of our list!'),
              ),
            ).withHotspot(
              flow: 'list',
              order: 6,
              title: 'Item #40',
              text: 'We\'re nearing the end of the list tour!',
            );
          } else {
            return ListTile(
              title: Text(items[index]),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // First ensure we're at the top of the list
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );

          // Then start the tour after scrolling completes
          Future.delayed(const Duration(milliseconds: 350), () {
            HotspotProvider.of(context).startFlow('list');
          });
        },
        tooltip: 'Start Tour',
        child: const Icon(Icons.play_arrow),
      ).withHotspot(
        flow: 'list',
        order: 7,
        title: 'Start Tour',
        text: 'Click this button to restart the list tour',
      ),
    );
  }
}
