import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insign/features/auth/cubit/auth_cubit.dart';
import 'package:insign/features/contracts/view/create_contract_screen.dart';
import 'package:insign/models/user.dart';

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit()
      : _currentUser = const User(
          id: 'test',
          email: 'test@example.com',
          displayName: '테스트 사용자',
          photoUrl: null,
          isAnonymous: false,
          isEmailVerified: true,
          createdAt: null,
          contractsUsedThisMonth: 0,
          monthlyContractLimit: 10,
          points: 0,
          isPremium: false,
        ),
        super(AuthInitial());

  final User _currentUser;

  @override
  User? get currentUser => _currentUser;
}

void main() {
  group('CreateContractScreen', () {
    testWidgets('renders first step with basic fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthCubit>(
            create: (_) => _FakeAuthCubit(),
            child: const CreateContractScreen(),
          ),
        ),
      );

      expect(find.text('계약서 제목'), findsOneWidget);
      expect(find.textContaining('갑 (의뢰인)'), findsWidgets);
    });
  });
}

