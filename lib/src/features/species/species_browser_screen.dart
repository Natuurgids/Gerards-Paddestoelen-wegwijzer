import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/safety_notice.dart';
import 'species_screen.dart';

class SpeciesBrowserScreen extends StatefulWidget {
  const SpeciesBrowserScreen({super.key, required this.locale});

  final Locale locale;

  @override
  State<SpeciesBrowserScreen> createState() => _SpeciesBrowserScreenState();
}

class _SpeciesBrowserScreenState extends State<SpeciesBrowserScreen> {
  final _repo = SpeciesRepository();
  final _search = TextEditingController();
  late Future<List<SpeciesSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.search(widget.locale.languageCode);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(
        () => _future = _repo.search(
          widget.locale.languageCode,
          query: _search.text,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.speciesBrowserTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.speciesBrowserSearchHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _reload(),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<SpeciesSummary>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!;
                  if (items.isEmpty) {
                    return Center(child: Text(l10n.speciesBrowserEmpty));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = items[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        leading: SizedBox(
                          width: 64,
                          height: 64,
                          child: _Thumb(path: s.imagePath),
                        ),
                        title: Text(s.commonName),
                        subtitle: Text(
                          '${s.scientificName}\n${s.summary ?? ''}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SpeciesScreen(
                              locale: widget.locale,
                              speciesId: s.id,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafetyNotice(locale: widget.locale),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null) return const Icon(Icons.image_not_supported_outlined);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        path!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.image_not_supported_outlined),
        ),
      ),
    );
  }
}
