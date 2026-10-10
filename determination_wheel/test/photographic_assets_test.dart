import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushroom_determination_wheel/detail_keys.dart';
import 'package:mushroom_determination_wheel/photographic_assets.dart';
import 'package:mushroom_determination_wheel/wheel_steps.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Every wheel and details choice resolves to a decodable bundled photograph', () async {
    final labels={
      for(final step in wheelSteps.values) for(final option in step.options) option.label,
      for(final key in [russulaceaeDetailKey,shellDetailKey,pleurotusDetailKey,pluteusDetailKey,galerinaDetailKey,hebelomaDetailKey,agrocybeDetailKey,parasolDetailKey,laccariaDetailKey,waxcapDetailKey,funnelDetailKey,toughshankDetailKey,pholiotaDetailKey,strophariaDetailKey,paxillusDetailKey,cantharellusDetailKey])
        for(final step in key.steps.values) for(final option in step.options) option.label,
    };
    expect(observationPhotographs.keys.toSet().containsAll(labels),isTrue,
      reason:'An observation choice must never fall back to a schematic or unrelated generic mushroom.');
    final paths={for(final label in labels) observationPhotographs[label]!,mushroomInstrumentAsset,woodlandBackgroundAsset,stemRingTextureAsset};
    for(final path in paths) {
      final data=await rootBundle.load(path);
      final codec=await ui.instantiateImageCodec(data.buffer.asUint8List(data.offsetInBytes,data.lengthInBytes),targetWidth:128);
      final frame=await codec.getNextFrame();
      expect(frame.image.width,greaterThan(0),reason:path);
      expect(frame.image.height,greaterThan(0),reason:path);
      frame.image.dispose();codec.dispose();
    }
  });
}
