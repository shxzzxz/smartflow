enum InsuranceCoverageField {
  summary('保障概要'),
  highlights('保障亮点'),
  waitingPeriod('等待期'),
  exclusions('除外责任');

  const InsuranceCoverageField(this.label);

  final String label;
}
