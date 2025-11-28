import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insign/features/auth/cubit/auth_cubit.dart';
import 'package:insign/features/events/view/check_in_screen.dart';
import 'package:insign/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuthCubit extends AuthCubit {
  _TestAuthCubit(AuthState initialState) : super() {
    emit(initialState);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CheckInScreen', () {
    testWidgets('renders intro, card, and calendar details for logged-in user', (tester) async {
      final user = User(
        id: 1,
        email: 'test@example.com',
        points: 12,
        monthlyPointsLimit: 30,
        pointsEarnedThisMonth: 5,
        lastCheckInDate: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      );

      final authCubit = _TestAuthCubit(
        AuthState(isLoggedIn: true, user: user, isSessionChecked: true),
      );

      addTearDown(authCubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthCubit>.value(
            value: authCubit,
            child: const CheckInScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('오늘의 출석 체크'), findsOneWidget);
      expect(find.text('출석 체크 하기'), findsOneWidget);
      expect(find.text('이번 달 출석 캘린더'), findsOneWidget);
      expect(find.textContaining('마지막 출석일'), findsOneWidget);
    });
  });
}
