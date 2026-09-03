const capDiameterMeasurementCode = 'cap_diameter';
const stemHeightMeasurementCode = 'stem_height';
const stemDiameterMeasurementCode = 'stem_diameter';

const fieldMeasurementUnits = <String, String>{
  capDiameterMeasurementCode: 'cm',
  stemHeightMeasurementCode: 'cm',
  stemDiameterMeasurementCode: 'cm',
};

String? expectedFieldMeasurementUnit(String code) => fieldMeasurementUnits[code];
