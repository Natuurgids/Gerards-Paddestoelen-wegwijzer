import 'package:flutter/material.dart';

class SpeciesScreen extends StatefulWidget {
  const SpeciesScreen({super.key, required this.locale});

  final Locale locale;

  @override
  State<SpeciesScreen> createState() => _SpeciesScreenState();
}

class _SpeciesScreenState extends State<SpeciesScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _imageSlots = [
    'assets/images/example_species_top.jpg',
    'assets/images/example_species_underside.jpg',
    'assets/images/example_species_side.jpg',
    'assets/images/example_species_base.jpg',
    'assets/images/example_species_habitat.jpg',
  ];

  String get _safety {
    switch (widget.locale.languageCode) {
      case 'nl':
        return 'Veiligheidswaarschuwing: Eet nooit een paddenstoel uitsluitend op basis van identificatie door deze app. Laat eetbare paddenstoelen altijd controleren door een gekwalificeerde lokale deskundige.';
      case 'de':
        return 'Sicherheitshinweis: Verzehren Sie niemals einen Pilz ausschließlich aufgrund einer Bestimmung durch diese App. Lassen Sie essbare Pilze immer von einer qualifizierten örtlichen Fachperson überprüfen.';
      default:
        return 'Safety notice: Never consume a mushroom based solely on identification by this app. Always have edible mushrooms verified by a qualified local expert.';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Amanita muscaria')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _controller,
                          itemCount: _imageSlots.length,
                          onPageChanged: (value) => setState(() => _page = value),
                          itemBuilder: (context, index) => _SpeciesImage(
                            path: _imageSlots[index],
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              child: Text(
                                '${_page + 1} / ${_imageSlots.length}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Amanita muscaria', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                        SizedBox(height: 8),
                        Text('Example species page. Species content will be loaded from the offline SQLite database.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Text(
                _safety,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeciesImage extends StatelessWidget {
  const _SpeciesImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 56),
            SizedBox(height: 8),
            Text('Image not available yet'),
          ],
        ),
      ),
    );
  }
}
