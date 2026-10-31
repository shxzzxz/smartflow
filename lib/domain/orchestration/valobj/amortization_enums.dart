const String orchestrationAmortizationOwnerType = 'orchestration.amortization';

enum AmortizationKind { prepaidExpense, deferredIncome }

enum AmortizationCadenceUnit { daily, monthly, yearly }

enum AmortizationStatus { active, completed, terminated }

enum AmortizationReportingScope { futureOnly, all }
