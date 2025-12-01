import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insign/data/support_repository.dart';
import 'package:insign/features/support/cubit/support_state.dart';

class SupportCubit extends Cubit<SupportState> {
  final SupportRepository _repository = SupportRepository();

  SupportCubit() : super(SupportState());

  Future<void> submitInquiry({
    required String category,
    required String subject,
    required String content,
    List<String>? attachmentUrls,
  }) async {
    emit(state.copyWith(isSubmitting: true, errorMessage: null));

    try {
      await _repository.submitInquiry(
        category: category,
        subject: subject,
        content: content,
        attachmentUrls: attachmentUrls,
      );

      emit(state.copyWith(
        isSubmitting: false,
        successMessage: '문의가 성공적으로 접수되었습니다.',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: '문의 접수 중 오류가 발생했습니다: ${e.toString()}',
      ));
    }
  }

  Future<void> loadInquiries() async {
    emit(state.copyWith(isLoadingHistory: true, errorMessage: null));

    try {
      final inquiries = await _repository.getMyInquiries();
      emit(state.copyWith(
        isLoadingHistory: false,
        inquiries: inquiries,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingHistory: false,
        errorMessage: '문의 내역을 불러오는 중 오류가 발생했습니다.',
      ));
    }
  }

  void clearMessages() {
    emit(state.copyWith(
      errorMessage: null,
      successMessage: null,
    ));
  }
}
