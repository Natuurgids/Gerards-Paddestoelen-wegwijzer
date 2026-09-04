import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/species_browser_repository.dart';
import '../../widgets/safety_notice.dart';
import 'species_screen.dart';

class SpeciesBrowserScreen extends StatefulWidget {
  const SpeciesBrowserScreen({super.key, required this.locale});

  final Locale locale;

  @override
  State<SpeciesBrowserScreen> createState() => _SpeciesBrowserScreenState();
}

class _SpeciesBrowserScreenState extends State<SpeciesBrowserScreen> {
  static const _pageSize = SpeciesBrowserRepository.defaultPageSize;

  final _repo = SpeciesBrowserRepository();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final List<SpeciesSummary> _items = [];

  Timer? _debounce;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _loadFirstPage);
  }

  void _onScroll() {
    if (!_hasMore || _loadingInitial || _loadingMore || !_scroll.hasClients) {
      return;
    }
    if (_scroll.position.extentAfter < 500) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    final generation = ++_requestGeneration;
    setState(() {
      _loadingInitial = true;
      _loadingMore = false;
      _hasMore = true;
    });

    final rows = await _repo.searchPage(
      widget.locale.languageCode,
      query: _search.text,
      limit: _pageSize + 1,
    );
    if (!mounted || generation != _requestGeneration) return;

    setState(() {
      _items
        ..clear()
        ..addAll(rows.take(_pageSize));
      _hasMore = rows.length > _pageSize;
      _loadingInitial = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingInitial || _loadingMore) return;
    final generation = _requestGeneration;
    setState(() => _loadingMore = true);

    final rows = await _repo.searchPage(
      widget.locale.languageCode,
      query: _search.text,
      offset: _items.length,
      limit: _pageSize + 1,
    );
    if (!mounted || generation != _requestGeneration) return;

    setState(() {
      _items.addAll(rows.take(_pageSize));
      _hasMore = rows.length > _pageSize;
      _loadingMore = false;
    });
  }

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
                onChanged: _onSearchChanged,
              ),
            ),
            Expanded(
              child: _loadingInitial
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? Center(child: Text(l10n.speciesBrowserEmpty))
                      : ListView.separated(
                          controller: _scroll,
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length + (_loadingMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (index == _items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final s = _items[index];
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
                        ),
            ),
            const SafetyNotice(),
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
