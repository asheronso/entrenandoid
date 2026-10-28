class SetData {
  final int reps;
  final double weight;
  final int rest;
  final String type;
  const SetData(this.reps, this.weight, this.rest, [this.type = 'efectiva']);

  /// Volumen = repeticiones × peso (estimación de carga).
  double get volume => reps * weight;

  /// Peso cero es válido (peso corporal); negativos no.
  bool get isValid => reps >= 0 && weight >= 0 && rest >= 0;
}

/// Suma de volúmenes de las series válidas.
double totalVolume(Iterable<SetData> sets) =>
    sets.where((s) => s.isValid).fold(0.0, (a, s) => a + s.volume);
