import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/species_browser_repository.dart';
import '../../theme/app_theme.dart';
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
  bool _loadFailed = false;
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
      _loadFailed = false;
    });

    try {
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
    } on Object {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _loadingInitial = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingInitial || _loadingMore) return;
    final generation = _requestGeneration;
    setState(() => _loadingMore = true);

    try {
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
    } on Object {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  ShapeBorder get _cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      );

  Widget _searchPanel(BuildContext context, AppLocalizations l10n) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.forest, AppTheme.forestDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.menu_book_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.speciesBrowserTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.speciesBrowserSearchHint,
                filled: true,
                fillColor: AppTheme.creamStrong,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ],
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
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal = constraints.maxWidth >= 840 ? 28.0 : 14.0;
                  return CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 10),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 980),
                              child: _searchPanel(context, l10n),
                            ),
                          ),
                        ),
                      ),
                      if (_loadingInitial)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_loadFailed)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: IconButton.filledTonal(
                              onPressed: _loadFirstPage,
                              icon: const Icon(Icons.refresh),
                              iconSize: 32,
                            ),
                          ),
                        )
                      else if (_items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text(l10n.speciesBrowserEmpty)),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(horizontal, 2, horizontal, 18),
                          sliver: SliverList.builder(
                            itemCount: _items.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _items.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final s = _items[index];
                              return Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 980),
                                  child: Card(
                                    elevation: 0,
                                    color: AppTheme.creamStrong,
                                    shape: _cardShape,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SpeciesScreen(
                                            locale: widget.locale,
                                            speciesId: s.id,
                                          ),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 76,
                                              height: 76,
                                              child: _Thumb(path: s.imagePath),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    s.commonName,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          color: AppTheme.ink,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    s.scientificName,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          color: AppTheme.forest,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                  ),
                                                  if ((s.summary ?? '').isNotEmpty) ...[
                                                    const SizedBox(height: 5),
                                                    Text(
                                                      s.summary!,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.chevron_right,
                                              color: AppTheme.forest,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
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
    const fallback = ColoredBox(
      color: AppTheme.cream,
      child: Center(
        child: Icon(Icons.image_not_supported_outlined, color: AppTheme.moss),
      ),
    );
    if (path == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        path!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
