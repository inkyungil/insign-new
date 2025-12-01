import 'package:insign/models/inquiry.dart';

class SupportState {
  final bool isSubmitting;
  final bool isLoadingHistory;
  final String? errorMessage;
  final String? successMessage;
  final List<Inquiry> inquiries;

  SupportState({
    this.isSubmitting = false,
    this.isLoadingHistory = false,
    this.errorMessage,
    this.successMessage,
    this.inquiries = const [],
  });

  SupportState copyWith({
    bool? isSubmitting,
    bool? isLoadingHistory,
    String? errorMessage,
    String? successMessage,
    List<Inquiry>? inquiries,
  }) {
    return SupportState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      errorMessage: errorMessage,
      successMessage: successMessage,
      inquiries: inquiries ?? this.inquiries,
    );
  }
}
