enum MeasurementInputStatus {
  empty,
  valid,
  invalidNumber,
  nonPositive,
}

class MeasurementInputResult {
  const MeasurementInputResult({required this.status, this.value});

  final MeasurementInputStatus status;
  final double? value;

  bool get isValid =>
      status == MeasurementInputStatus.empty ||
      status == MeasurementInputStatus.valid;
}

MeasurementInputResult parseMeasurementInput(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return const MeasurementInputResult(status: MeasurementInputStatus.empty);
  }

  final parsed = double.tryParse(normalized);
  if (parsed == null || !parsed.isFinite) {
    return const MeasurementInputResult(
      status: MeasurementInputStatus.invalidNumber,
    );
  }
  if (parsed <= 0) {
    return const MeasurementInputResult(
      status: MeasurementInputStatus.nonPositive,
    );
  }
  return MeasurementInputResult(
    status: MeasurementInputStatus.valid,
    value: parsed,
  );
}
