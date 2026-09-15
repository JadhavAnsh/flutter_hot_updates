import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hot_updates/flutter_hot_updates.dart';

import 'fixture_loader.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HotUpdatesExampleApp());
}

class HotUpdatesExampleApp extends StatelessWidget {
  const HotUpdatesExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_hot_updates example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HotUpdatesHomePage(),
    );
  }
}

class HotUpdatesHomePage extends StatefulWidget {
  const HotUpdatesHomePage({super.key});

  @override
  State<HotUpdatesHomePage> createState() => _HotUpdatesHomePageState();
}

class _HotUpdatesHomePageState extends State<HotUpdatesHomePage> {
  String _status = 'Not initialized';
  double _progress = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeHotUpdates();
  }

  Future<void> _initializeHotUpdates() async {
    try {
      final fixtureRoot = await prepareExampleFixture();
      final storageRoot = Directory(
        '${Directory.systemTemp.path}/hot_updates_example',
      );
      if (await storageRoot.exists()) {
        await storageRoot.delete(recursive: true);
      }
      await storageRoot.create(recursive: true);

      await HotUpdates.initialize(
        projectId: 'basic_example',
        endpoint: Uri.file(fixtureRoot.path).toString(),
        publicKey: exampleFixturePublicKey(),
        storageRootOverride: storageRoot,
      );

      HotUpdates.events.listen((event) {
        if (!mounted) {
          return;
        }
        setState(() {
          _status = event.type.name;
          if (event.progress != null) {
            _progress = event.progress!.fraction;
          }
        });
      });

      setState(() {
        _initialized = true;
        _status = 'initialized';
      });
    } catch (error) {
      setState(() {
        _status = 'init failed: $error';
      });
    }
  }

  Future<void> _checkAndApplyUpdate() async {
    if (!_initialized) {
      return;
    }

    try {
      setState(() => _status = 'checking');
      final result = await HotUpdates.checkForUpdates();
      if (!result.updateAvailable || result.update == null) {
        setState(() => _status = result.reason ?? 'no update available');
        return;
      }

      await HotUpdates.downloadAndInstall(
        result.update!,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _progress = progress.fraction;
            _status = 'downloading ${progress.percent}%';
          });
        },
      );
      await HotUpdates.activate();
      setState(() => _status = 'activated patch ${result.update!.patch}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _status = 'update failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final showReferral =
        HotUpdates.config.getBool('showReferral', defaultValue: false) ?? false;
    final themeName =
        HotUpdates.config.getString('theme', defaultValue: 'default') ??
            'default';

    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_hot_updates'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HotImage(
              'assets/images/banner.png',
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 160,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Text('Bundled banner fallback'),
                );
              },
            ),
            const SizedBox(height: 24),
            HotTextAsset(
              'assets/copy/home_headline.txt',
              style: Theme.of(context).textTheme.headlineSmall,
              fallback: 'Welcome to flutter_hot_updates',
            ),
            const SizedBox(height: 16),
            Text('Status: $_status'),
            Text('Progress: ${(_progress * 100).round()}%'),
            Text('Remote config theme: $themeName'),
            if (showReferral)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Referral promo enabled by remote config'),
                ),
              ),
            const Spacer(),
            FilledButton(
              onPressed: _initialized ? _checkAndApplyUpdate : null,
              child: const Text('Check and apply update'),
            ),
          ],
        ),
      ),
    );
  }
}
