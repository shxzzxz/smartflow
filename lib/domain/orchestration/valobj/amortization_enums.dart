const String orchestrationAmortizationOwnerType = 'orchestration.amortization';

enum AmortizationKind { prepaidExpense, deferredIncome }

enum AmortizationCadenceUnit { daily, monthly, yearly }

enum AmortizationStatus { active, completed, terminated }

enum AmortizationPeriodStatus { pending, posted, zero, canceled }

enum AmortizationSubjectType { plan, period, refund, termination }

enum AmortizationAllocationDimension { funding, category, settlement }
