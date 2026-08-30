/// Bangla display copy for a single seeded exercise/workout entry.
///
/// Every field is optional so an entry can override only what it needs;
/// missing fields fall back to the original English content.
class BxCopy {
  const BxCopy({
    this.name,
    this.scientificName,
    this.bodyPart,
    this.secondaryMuscle,
    this.equipment,
    this.description,
    this.instructions,
    this.tips,
    this.commonMistakes,
    this.safetyInstructions,
  });

  final String? name;
  final String? scientificName;
  final String? bodyPart;
  final String? secondaryMuscle;
  final String? equipment;
  final String? description;
  final List<String>? instructions;
  final List<String>? tips;
  final List<String>? commonMistakes;
  final List<String>? safetyInstructions;
}
