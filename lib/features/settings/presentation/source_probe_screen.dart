import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/sources/playlist_source.dart';
import '../../../data/sources/xtream_source.dart';
import '../../../domain/models/models.dart';

/// Temporary dev harness (Task 0.2): enter Xtream credentials at runtime and
/// probe the panel — auth, category counts, sample items, a stream URL.
/// Nothing is persisted. Folds into real onboarding validation in Task 0.5.
class SourceProbeScreen extends StatefulWidget {
  const SourceProbeScreen({super.key});

  @override
  State<SourceProbeScreen> createState() => _SourceProbeScreenState();
}

class _SourceProbeScreenState extends State<SourceProbeScreen> {
  final _server = TextEditingController(text: 'http://');
  final _username = TextEditingController();
  final _password = TextEditingController();

  final List<(String, bool)> _lines = [];
  bool _running = false;

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _log(String line, {bool error = false}) {
    setState(() => _lines.add((line, error)));
  }

  Future<void> _probe() async {
    setState(() {
      _lines.clear();
      _running = true;
    });

    final account = Account(
      id: 'probe',
      type: AccountType.xtream,
      name: 'Probe',
      serverUrl: _server.text.trim(),
      username: _username.text.trim(),
      password: _password.text.trim(),
      createdAt: DateTime.now().toUtc(),
    );
    final source = XtreamSource(
      account: account,
      onSkippedRow: (m) => _log('  ! $m', error: true),
    );

    try {
      _log('Authenticating…');
      await source.authenticate();
      _log('  OK — account is active');

      final liveCats = await source.getLiveCategories();
      final vodCats = await source.getVodCategories();
      final seriesCats = await source.getSeriesCategories();
      _log('Categories: ${liveCats.length} live · '
          '${vodCats.length} VOD · ${seriesCats.length} series');

      _log('Fetching live streams…');
      final channels = await source.getLiveStreams();
      _log('  ${channels.length} channels');
      for (final c in channels.take(3)) {
        _log('  • [${c.id}] ${c.name} (epg: ${c.epgChannelId ?? '-'})');
      }

      _log('Fetching VOD…');
      final movies = await source.getVodStreams();
      _log('  ${movies.length} movies');
      for (final m in movies.take(3)) {
        _log('  • [${m.id}] ${m.name} (${m.year ?? '?'}, ${m.containerExt ?? '?'})');
      }

      _log('Fetching series…');
      final series = await source.getSeries();
      _log('  ${series.length} series');
      for (final s in series.take(3)) {
        _log('  • [${s.id}] ${s.name} (${s.year ?? '?'})');
      }

      if (movies.isNotEmpty) {
        final detail = await source.getVodInfo(movies.first.id);
        _log('VOD info "${detail.name}": '
            'plot=${detail.plot != null} genre=${detail.genre ?? '-'} '
            'duration=${detail.durationSeconds ?? '?'}s');
        _log('Stream URL: ${source.buildStreamUrl(StreamRef(
          accountId: account.id,
          type: StreamType.movie,
          streamId: detail.id,
          containerExt: detail.containerExt,
        ))}');
      }

      if (series.isNotEmpty) {
        final detail = await source.getSeriesInfo(series.first.id);
        _log('Series info "${detail.series.name}": '
            '${detail.seasons.length} seasons, ${detail.episodes.length} episodes');
      }

      if (channels.isNotEmpty) {
        final epg = await source.getShortEpg(channels.first.id);
        _log('EPG for "${channels.first.name}": ${epg.length} entries');
        for (final e in epg.take(2)) {
          _log('  • ${e.start.toLocal()} ${e.title}');
        }
      }

      _log('Probe complete.');
    } on SourceException catch (e) {
      _log('FAILED: ${e.message}', error: true);
    } catch (e) {
      _log('FAILED (unexpected): $e', error: true);
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Source probe (dev)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _server,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _username,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _password,
                      autocorrect: false,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _running ? null : _probe,
                child: Text(_running ? 'Probing…' : 'Probe'),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _lines.length,
                    itemBuilder: (context, i) {
                      final (text, error) = _lines[i];
                      return Text(
                        text,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: error ? AppColors.error : AppColors.textPrimary,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
