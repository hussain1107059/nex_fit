/// The report window selected by the user in the Progress & Analytics module.
///
/// [custom] relies on an explicit start/end date supplied by the caller.
enum ReportPeriod {
  today,
  last7Days,
  last30Days,
  last90Days,
  thisYear,
  custom;

  static ReportPeriod fromName(String? value) {
    return ReportPeriod.values.firstWhere(
      (period) => period.name == value,
      orElse: () => ReportPeriod.last30Days,
    );
  }
}
