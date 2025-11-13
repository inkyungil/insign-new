import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insign/data/services/onboarding_service.dart';

class OnboardingState {
  final bool isChecked;
  final bool isCompleted;

  const OnboardingState({this.isChecked = false, this.isCompleted = false});

  OnboardingState copyWith({bool? isChecked, bool? isCompleted}) {
    return OnboardingState(
      isChecked: isChecked ?? this.isChecked,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit() : super(const OnboardingState());

  Future<void> checkStatus() async {
    try {
      final completed = await OnboardingService.hasCompleted();
      emit(OnboardingState(isChecked: true, isCompleted: completed));
    } catch (_) {
      emit(state.copyWith(isChecked: true));
    }
  }

  Future<void> complete() async {
    await OnboardingService.markCompleted();
    emit(const OnboardingState(isChecked: true, isCompleted: true));
  }
}
