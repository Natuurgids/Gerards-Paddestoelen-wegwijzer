import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/safety_notice.dart';

class SpeciesScreen extends StatefulWidget {
  const SpeciesScreen({super.key, required this.locale, required this.speciesId});
  final Locale locale;
  final int speciesId;

  @override
  State<SpeciesScreen> createState() => _SpeciesScreenState();
}

class _SpeciesScreenState extends State<SpeciesScreen> {
  final _controller = PageController();
  late Future<SpeciesDetail?> _future;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _future = SpeciesRepository().detail(widget.speciesId, widget.locale.languageCode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _label(String key) {
    const values = {
      'nl': {'habitat':'Habitat','lookalikes':'Gelijkende soorten','status':'Veiligheidsstatus','missing':'Afbeelding nog niet beschikbaar','measurements':'Afmetingen','season':'Seizoen','seasonRegion':'Regionale referentie','cap_diameter':'Hoeddiameter','stem_height':'Steelhoogte','stem_diameter':'Steeldiameter'},
      'en': {'habitat':'Habitat','lookalikes':'Lookalikes','status':'Safety status','missing':'Image not available yet','measurements':'Measurements','season':'Season','seasonRegion':'Regional reference','cap_diameter':'Cap diameter','stem_height':'Stem height','stem_diameter':'Stem diameter'},
      'de': {'habitat':'Lebensraum','lookalikes':'Verwechslungsarten','status':'Sicherheitsstatus','missing':'Bild noch nicht verfügbar','measurements':'Maße','season':'Saison','seasonRegion':'Regionale Referenz','cap_diameter':'Hutdurchmesser','stem_height':'Stielhöhe','stem_diameter':'Stieldurchmesser'},
    };
    return (values[widget.locale.languageCode] ?? values['en']!)[key] ?? key;
  }

  String _measurement(SpeciesMeasurement m) {
    final min = m.minValue;
    final max = m.maxValue;
    if (min != null && max != null) return '${_format(min)}–${_format(max)} ${m.unit}';
    if (min != null) return '≥ ${_format(min)} ${m.unit}';
    if (max != null) return '≤ ${_format(max)} ${m.unit}';
    return '-';
  }

  String _format(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

  String _monthName(int month) {
    const nl=['','jan','feb','mrt','apr','mei','jun','jul','aug','sep','okt','nov','dec'];
    const en=['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const de=['','Jan','Feb','Mär','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'];
    final values=widget.locale.languageCode=='nl'?nl:widget.locale.languageCode=='de'?de:en;
    return values[month];
  }

  String _regionName(String code) {
    if (code == 'GB-IE') {
      return widget.locale.languageCode == 'nl'
          ? 'Groot-Brittannië en Ierland'
          : widget.locale.languageCode == 'de'
              ? 'Großbritannien und Irland'
              : 'Britain and Ireland';
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<SpeciesDetail?>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final species = snapshot.data;
                  if (species == null) return const Center(child: Text('Species not found'));
                  final images = species.images.isEmpty ? List<SpeciesImage>.generate(5, (i) => SpeciesImage(path:'', angleCode:null, sortOrder:i)) : species.images;
                  final seasonRegion = species.season.map((m)=>m.regionCode).whereType<String>().where((v)=>v.isNotEmpty).toSet();
                  return ListView(
                    children: [
                      AspectRatio(
                        aspectRatio: 4/3,
                        child: Stack(
                          children: [
                            PageView.builder(
                              controller: _controller,
                              itemCount: images.length,
                              onPageChanged: (value) => setState(() => _page=value),
                              itemBuilder: (_, index) => _SpeciesImage(path: images[index].path, missingLabel: _label('missing')),
                            ),
                            Positioned(right:12,bottom:12,child:DecoratedBox(decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(20)),child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),child:Text('${_page+1} / ${images.length}',style:const TextStyle(color:Colors.white))))),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(species.commonName,style:Theme.of(context).textTheme.headlineMedium),
                          Text(species.scientificName,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontStyle:FontStyle.italic)),
                          const SizedBox(height:16),
                          Text(species.description ?? species.summary ?? ''),
                          if(species.measurements.isNotEmpty)...[
                            const SizedBox(height:20),
                            Text(_label('measurements'),style:Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height:6),
                            ...species.measurements.map((m)=>Padding(padding:const EdgeInsets.only(bottom:4),child:Text('${_label(m.code)}: ${_measurement(m)}'))),
                          ],
                          if(species.season.isNotEmpty)...[
                            const SizedBox(height:20),
                            Text(_label('season'),style:Theme.of(context).textTheme.titleMedium),
                            if(seasonRegion.isNotEmpty)Padding(padding:const EdgeInsets.only(top:2,bottom:6),child:Text('${_label('seasonRegion')}: ${seasonRegion.map(_regionName).join(', ')}',style:Theme.of(context).textTheme.bodySmall)),
                            Wrap(spacing:6,runSpacing:6,children:species.season.map((m)=>Chip(label:Text(_monthName(m.month)),avatar:Icon(m.likelihood>=3?Icons.circle:Icons.circle_outlined,size:m.likelihood>=3?14:m.likelihood==2?11:8))).toList()),
                          ],
                          const SizedBox(height:20),
                          Text(_label('habitat'),style:Theme.of(context).textTheme.titleMedium),
                          Text(species.habitat ?? '-'),
                          const SizedBox(height:16),
                          Text(_label('lookalikes'),style:Theme.of(context).textTheme.titleMedium),
                          Text(species.lookalikes ?? '-'),
                          const SizedBox(height:16),
                          Text(_label('status'),style:Theme.of(context).textTheme.titleMedium),
                          Text('${species.edibleStatus} · ${species.toxicityLevel}'),
                        ]),
                      ),
                    ],
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

class _SpeciesImage extends StatelessWidget {
  const _SpeciesImage({required this.path,required this.missingLabel});
  final String path;
  final String missingLabel;
  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(color:Theme.of(context).colorScheme.surfaceContainerHighest,alignment:Alignment.center,child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.image_not_supported_outlined,size:56),const SizedBox(height:8),Text(missingLabel)]));
    if(path.isEmpty) return fallback();
    return Image.asset(path,fit:BoxFit.cover,errorBuilder:(_,__,___)=>fallback());
  }
}
