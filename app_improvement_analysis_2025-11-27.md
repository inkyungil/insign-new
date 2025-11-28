# 인싸인(Insign) 앱 개선안 분석

**분석일:** 2025-11-27
**분석 대상:** 인싸인 디지털 계약 관리 앱 (Flutter)

---

## 🎯 현재 상태 요약

### 강점 ✅
- 핵심 기능 완성도 높음 (계약 생성→서명→완료 전체 플로우)
- 깔끔한 아키텍처 (Feature-based, Repository 패턴)
- 소셜 로그인 (Google/Kakao) 잘 구현됨
- 템플릿 시스템 동작 양호
- 멀티 플랫폼 지원 (Android/iOS/Web)
- Push 알림 인프라 구축 완료

### 약점 ❌
- 코드가 너무 거대함 (create_contract_screen.dart: 3,313줄!)
- Legacy 코드 많음 (podcast, stock 기능 사용 안 함)
- 보안 취약점 (토큰 암호화 안 됨)
- 테스트 거의 없음
- 에러 메시지 불친절
- 성능 최적화 여지 많음

---

## 💡 우선순위별 개선안

### 🔴 **우선순위 1 - 즉시 필요** (1-2주)

#### 1. **사용자 프로필에 연락처 정보 추가** ⭐⭐⭐
**문제:** User 모델에 phone이 없어서 매번 입력해야 함

**구현 방법:**
```dart
// lib/models/user.dart
class User {
  final int id;
  final String email;
  final String? displayName;
  final String? phone;  // 추가
  final String? address;  // 추가 (선택)
  final String? lastLoginAt;
  final String? provider;
  final String? avatarUrl;
}
```

**백엔드 수정 필요:**
- users 테이블에 phone, address 컬럼 추가
- 회원가입/프로필 수정 API 업데이트

**효과:**
- 계약서 작성 시 이름/이메일/연락처 모두 자동 채움
- 사용자 편의성 대폭 향상

---

#### 2. **계약서 검색 개선** ⭐⭐⭐
**현재:** 계약명으로만 검색
**개선 필요:**

**기능 추가:**
- 전체 텍스트 검색 (의뢰인명, 수행자명, 계약 내용)
- 날짜 범위 필터 (시작일/종료일)
- 금액 범위 필터
- 다중 상태 선택 (진행중 + 완료 동시 선택)
- 템플릿별 필터

**구현 위치:**
- `lib/features/contracts/view/contracts_screen.dart`
- 검색 결과 하이라이팅 추가

**예상 UI:**
```
🔍 검색: [___________]
📅 기간: [2025-01-01] ~ [2025-12-31]
💰 금액: [_____] ~ [_____] 원
📋 상태: ☑️진행중 ☑️완료 ☐만료 ☐거절
📄 템플릿: [전체 ▼]
```

---

#### 3. **서명 거절 시 사유 입력** ⭐⭐
**현재:** 거절만 가능, 이유 알 수 없음
**개선:**

```dart
// 서명 거절 다이얼로그
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('서명 거절'),
    content: Column(
      children: [
        Text('서명을 거절하시겠습니까?'),
        TextField(
          decoration: InputDecoration(
            labelText: '거절 사유 (선택)',
            hintText: '예: 계약 조건 재협의 필요',
          ),
          maxLines: 3,
        ),
      ],
    ),
    actions: [
      TextButton(child: Text('취소'), onPressed: () {}),
      TextButton(child: Text('거절'), onPressed: () {}),
    ],
  ),
);
```

**백엔드 추가:**
- contracts 테이블에 `decline_reason` 컬럼 추가
- 거절 사유 이메일 알림에 포함

---

#### 4. **토큰 암호화** 🔒 ⭐⭐⭐
**문제:** SharedPreferences에 평문 저장 → ADB로 추출 가능

**해결책:**
```yaml
# pubspec.yaml
dependencies:
  flutter_secure_storage: ^9.0.0
```

```dart
// lib/data/services/session_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionService {
  static const _storage = FlutterSecureStorage();

  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: 'accessToken', value: token);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: 'accessToken');
  }
}
```

**마이그레이션:**
- 기존 SharedPreferences → SecureStorage 이동
- 앱 업데이트 시 자동 마이그레이션 로직

---

### 🟡 **우선순위 2 - 중요** (1-2개월)

#### 5. **일괄 작업 기능** ⭐⭐⭐

**기능 목록:**
- [ ] 여러 계약서 선택 → PDF 일괄 다운로드
- [ ] 만료 임박 계약들에 일괄 알림 전송
- [ ] 완료된 계약들 일괄 보관/삭제

**UI 구현:**
```dart
// 계약서 목록 화면
AppBar(
  actions: [
    if (_selectedContracts.isNotEmpty)
      IconButton(
        icon: Icon(Icons.download),
        onPressed: _bulkDownloadPdf,
      ),
    if (_selectedContracts.isNotEmpty)
      IconButton(
        icon: Icon(Icons.archive),
        onPressed: _bulkArchive,
      ),
  ],
)

// 각 계약서 아이템에 체크박스 추가
CheckboxListTile(
  value: _selectedContracts.contains(contract.id),
  onChanged: (selected) => _toggleSelection(contract.id),
  // ...
)
```

---

#### 6. **템플릿 커스터마이징** ⭐⭐

**현재:** 백엔드 템플릿만 사용 가능
**개선 단계:**

**Phase 1: 즐겨찾기** (쉬움)
```dart
// 템플릿에 즐겨찾기 버튼 추가
IconButton(
  icon: Icon(
    isFavorite ? Icons.star : Icons.star_border,
    color: isFavorite ? Colors.amber : null,
  ),
  onPressed: () => _toggleFavorite(template.id),
)

// 즐겨찾기 목록을 SharedPreferences에 저장
// 템플릿 목록 상단에 즐겨찾기 섹션 추가
```

**Phase 2: 기존 계약서를 템플릿으로 저장** (중간)
```
계약서 상세 화면 → 메뉴 → "템플릿으로 저장"
→ 개인정보 마스킹 옵션 제공
→ 나만의 템플릿으로 저장
```

**Phase 3: 템플릿 에디터** (어려움)
- 드래그 앤 드롭으로 필드 배치
- WYSIWYG 에디터
- 고급 기능 (조건부 필드, 계산 필드)

---

#### 7. **계약서 알림 강화** ⭐⭐⭐

**추가할 알림:**

```typescript
// nestjs_app/src/cron/contract-reminders.service.ts
@Cron('0 9 * * *')  // 매일 오전 9시
async sendSignatureReminders() {
  // 서명 요청 후 3일 지난 계약 찾기
  const pendingContracts = await this.contractRepository.find({
    where: {
      status: 'signature_pending',
      signatureSentAt: LessThan(moment().subtract(3, 'days')),
    },
  });

  // 알림 전송
  for (const contract of pendingContracts) {
    await this.pushService.send({
      userId: contract.performerId,
      title: '서명 요청 알림',
      body: `${contract.name} 계약서 서명이 대기 중입니다.`,
      data: { contractId: contract.id },
    });
  }
}

@Cron('0 9 * * *')
async sendExpirationWarnings() {
  // 만료 7일 전 계약 찾기
  const expiringContracts = await this.contractRepository.find({
    where: {
      endDate: Between(
        moment().add(7, 'days'),
        moment().add(8, 'days')
      ),
    },
  });

  // 양 당사자에게 알림
  for (const contract of expiringContracts) {
    await this.pushService.sendToMultiple({
      userIds: [contract.clientId, contract.performerId],
      title: '계약 만료 예정',
      body: `${contract.name} 계약이 7일 후 만료됩니다.`,
    });
  }
}
```

**Flutter 알림 처리:**
```dart
// lib/services/push_notification_service.dart
void _handleNotificationTap(RemoteMessage message) {
  final data = message.data;

  if (data['type'] == 'contract_reminder') {
    // 계약서 상세 화면으로 이동
    GoRouter.of(context).push('/contracts/${data['contractId']}');
  }
}
```

---

#### 8. **오프라인 모드** ⭐⭐

**구현 방법:**
```yaml
# pubspec.yaml
dependencies:
  sqflite: ^2.3.0  # 로컬 DB
  path_provider: ^2.1.0
```

```dart
// lib/data/local/contract_local_repository.dart
class ContractLocalRepository {
  Database? _db;

  // 계약서 로컬 저장
  Future<void> saveContract(Contract contract) async {
    final db = await _getDatabase();
    await db.insert('contracts', contract.toJson());
  }

  // PDF 로컬 저장
  Future<void> savePdf(int contractId, Uint8List pdfBytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/contract_$contractId.pdf');
    await file.writeAsBytes(pdfBytes);
  }

  // 오프라인 계약서 목록
  Future<List<Contract>> getOfflineContracts() async {
    final db = await _getDatabase();
    final maps = await db.query('contracts');
    return maps.map((m) => Contract.fromJson(m)).toList();
  }
}
```

**UI 표시:**
```dart
// 계약서 아이템에 오프라인 사용 가능 표시
Row(
  children: [
    Text(contract.name),
    if (contract.isOfflineAvailable)
      Icon(Icons.offline_pin, color: Colors.green, size: 16),
  ],
)
```

---

#### 9. **다크 모드** 🌙 ⭐

**구현:**
```dart
// lib/main.dart
class InsignApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Color(0xFF6A4C93),
        scaffoldBackgroundColor: Color(0xFF1A1A1A),
        // ... 커스텀 다크 테마
      ),
      themeMode: ThemeMode.system,  // 시스템 설정 따름
      // 또는 사용자 설정 기반:
      // themeMode: _themePreference,
    );
  }
}

// 설정 화면에 토글 추가
SwitchListTile(
  title: Text('다크 모드'),
  subtitle: Text('어두운 테마 사용'),
  value: _isDarkMode,
  onChanged: (value) {
    setState(() => _isDarkMode = value);
    // SharedPreferences에 저장
  },
)
```

---

### 🟢 **우선순위 3 - 있으면 좋음** (3-6개월)

#### 10. **협업 기능** ⭐⭐⭐

**기능 구성:**

```typescript
// 댓글 시스템
interface ContractComment {
  id: number;
  contractId: number;
  userId: number;
  content: string;
  createdAt: Date;
  parentId?: number;  // 대댓글
}

// 변경 이력
interface ContractRevision {
  id: number;
  contractId: number;
  userId: number;
  changes: {
    field: string;
    oldValue: any;
    newValue: any;
  }[];
  timestamp: Date;
}

// 읽음 표시
interface ContractView {
  contractId: number;
  userId: number;
  viewedAt: Date;
}
```

**Flutter UI:**
```dart
// 계약서 상세 화면에 댓글 탭 추가
TabBar(
  tabs: [
    Tab(text: '내용'),
    Tab(text: '댓글'),
    Tab(text: '변경이력'),
  ],
)

// 댓글 위젯
class CommentSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListView.builder(
          itemBuilder: (context, index) => CommentItem(...),
        ),
        TextField(
          decoration: InputDecoration(
            hintText: '댓글을 입력하세요',
            suffixIcon: IconButton(
              icon: Icon(Icons.send),
              onPressed: _postComment,
            ),
          ),
        ),
      ],
    );
  }
}
```

---

#### 11. **통계 & 분석** 📊 ⭐⭐

**대시보드 구성:**

```dart
// lib/features/profile/view/statistics_screen.dart
class StatisticsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 월별 계약 건수 그래프
          Card(
            child: Column(
              children: [
                Text('월별 계약 현황'),
                SizedBox(
                  height: 200,
                  child: LineChart(...),  // fl_chart 패키지
                ),
              ],
            ),
          ),

          // 주요 지표
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            children: [
              _StatCard(
                title: '평균 서명 소요 시간',
                value: '2.3일',
                icon: Icons.timer,
              ),
              _StatCard(
                title: '계약 금액 총합',
                value: '₩12,450,000',
                icon: Icons.attach_money,
              ),
              _StatCard(
                title: '이번 달 계약',
                value: '8건',
                icon: Icons.description,
              ),
              _StatCard(
                title: '서명 완료율',
                value: '94%',
                icon: Icons.check_circle,
              ),
            ],
          ),

          // 가장 많이 쓰는 템플릿 TOP 3
          Card(
            child: Column(
              children: [
                Text('자주 쓰는 템플릿'),
                ListTile(
                  leading: Text('1.'),
                  title: Text('표준 근로계약서'),
                  trailing: Text('23회'),
                ),
                ListTile(
                  leading: Text('2.'),
                  title: Text('프리랜서 계약서'),
                  trailing: Text('15회'),
                ),
                ListTile(
                  leading: Text('3.'),
                  title: Text('비밀유지서약서'),
                  trailing: Text('12회'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**백엔드 API:**
```typescript
// GET /api/users/statistics
{
  "monthlyContracts": [
    { "month": "2025-01", "count": 5 },
    { "month": "2025-02", "count": 8 },
    // ...
  ],
  "averageSigningTime": 2.3,  // days
  "totalContractValue": 12450000,
  "thisMonthContracts": 8,
  "completionRate": 0.94,
  "topTemplates": [
    { "name": "표준 근로계약서", "count": 23 },
    { "name": "프리랜서 계약서", "count": 15 },
    { "name": "비밀유지서약서", "count": 12 }
  ]
}
```

---

#### 12. **조직/팀 기능** 👥 ⭐⭐⭐

**데이터 모델:**

```typescript
// Organization
interface Organization {
  id: number;
  name: string;
  businessNumber: string;
  plan: 'free' | 'basic' | 'premium';
  createdAt: Date;
}

// OrganizationMember
interface OrganizationMember {
  id: number;
  organizationId: number;
  userId: number;
  role: 'owner' | 'admin' | 'member' | 'viewer';
  joinedAt: Date;
}

// OrganizationTemplate
interface OrganizationTemplate {
  id: number;
  organizationId: number;
  name: string;
  content: string;
  isPublic: boolean;  // 전체 공개 여부
}

// 계약 승인 워크플로우
interface ContractApproval {
  id: number;
  contractId: number;
  approverId: number;
  status: 'pending' | 'approved' | 'rejected';
  comment?: string;
  decidedAt?: Date;
}
```

**Flutter UI:**

```dart
// 조직 선택기
class OrganizationSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      value: _selectedOrgId,
      items: _organizations.map((org) {
        return DropdownMenuItem(
          value: org.id,
          child: Row(
            children: [
              Icon(Icons.business),
              SizedBox(width: 8),
              Text(org.name),
            ],
          ),
        );
      }).toList(),
      onChanged: (orgId) {
        setState(() => _selectedOrgId = orgId);
        _loadOrganizationContracts(orgId);
      },
    );
  }
}

// 승인 요청 화면
class ApprovalRequestScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('승인 요청')),
      body: Column(
        children: [
          // 계약서 미리보기
          ContractPreview(contract: _contract),

          // 승인자 선택
          DropdownButton<int>(
            hint: Text('승인자 선택'),
            items: _admins.map((admin) {
              return DropdownMenuItem(
                value: admin.id,
                child: Text(admin.name),
              );
            }).toList(),
            onChanged: (adminId) => _selectedApproverId = adminId,
          ),

          // 메모
          TextField(
            decoration: InputDecoration(
              labelText: '승인 요청 메모',
            ),
            maxLines: 3,
          ),

          // 제출 버튼
          ElevatedButton(
            onPressed: _submitForApproval,
            child: Text('승인 요청'),
          ),
        ],
      ),
    );
  }
}
```

---

#### 13. **생체 인증** 🔐 ⭐⭐

**구현:**

```yaml
# pubspec.yaml
dependencies:
  local_auth: ^2.1.7
```

```dart
// lib/services/biometric_auth_service.dart
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // 생체 인증 가능 여부 확인
  Future<bool> canCheckBiometrics() async {
    return await _localAuth.canCheckBiometrics;
  }

  // 사용 가능한 생체 인증 목록
  Future<List<BiometricType>> getAvailableBiometrics() async {
    return await _localAuth.getAvailableBiometrics();
  }

  // 인증 실행
  Future<bool> authenticate({
    required String reason,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print('생체 인증 실패: $e');
      return false;
    }
  }
}

// 사용 예시
class LoginScreen extends StatelessWidget {
  final BiometricAuthService _biometricAuth = BiometricAuthService();

  Future<void> _loginWithBiometric() async {
    final authenticated = await _biometricAuth.authenticate(
      reason: '인싸인에 로그인하려면 인증이 필요합니다',
    );

    if (authenticated) {
      // 저장된 토큰으로 자동 로그인
      final token = await SessionService.getAccessToken();
      context.read<AuthCubit>().loginWithToken(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 기존 로그인 폼
        // ...

        // 생체 인증 버튼
        FutureBuilder<bool>(
          future: _biometricAuth.canCheckBiometrics(),
          builder: (context, snapshot) {
            if (snapshot.data == true) {
              return IconButton(
                icon: Icon(Icons.fingerprint, size: 48),
                onPressed: _loginWithBiometric,
              );
            }
            return SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

// 중요 작업 시 재인증
class ContractDeleteConfirmDialog extends StatelessWidget {
  final BiometricAuthService _biometricAuth = BiometricAuthService();

  Future<void> _confirmDelete() async {
    final canUseBiometric = await _biometricAuth.canCheckBiometrics();

    if (canUseBiometric) {
      final authenticated = await _biometricAuth.authenticate(
        reason: '계약서 삭제를 위해 인증이 필요합니다',
      );

      if (authenticated) {
        await _deleteContract();
      }
    } else {
      // 비밀번호 재입력 폴백
      await _showPasswordDialog();
    }
  }
}
```

---

#### 14. **외부 연동** 🔗 ⭐

**캘린더 연동:**

```yaml
dependencies:
  add_2_calendar: ^3.0.1
```

```dart
// 계약서 상세 화면에서 "캘린더에 추가" 버튼
import 'package:add_2_calendar/add_2_calendar.dart';

void _addToCalendar(Contract contract) {
  final Event event = Event(
    title: '${contract.name} 계약 만료',
    description: '계약자: ${contract.clientName} & ${contract.performerName}',
    location: '',
    startDate: contract.endDate,
    endDate: contract.endDate,
    allDay: true,
  );

  Add2Calendar.addEvent2Cal(event);
}
```

**Google Drive 백업:**

```yaml
dependencies:
  googleapis: ^11.4.0
  googleapis_auth: ^1.4.1
```

```dart
// 자동 백업 서비스
class GoogleDriveBackupService {
  Future<void> backupContract(int contractId, Uint8List pdfBytes) async {
    // Google OAuth 인증
    final credentials = await _getGoogleCredentials();
    final client = authenticatedClient(http.Client(), credentials);
    final driveApi = drive.DriveApi(client);

    // 폴더 생성 (없으면)
    final folderId = await _getOrCreateFolder(driveApi, 'Insign Contracts');

    // PDF 업로드
    final media = drive.Media(Stream.value(pdfBytes.toList()), pdfBytes.length);
    final driveFile = drive.File()
      ..name = 'contract_$contractId.pdf'
      ..parents = [folderId];

    await driveApi.files.create(driveFile, uploadMedia: media);
  }

  // 설정 화면에서 자동 백업 토글
  Future<void> enableAutoBackup(bool enable) async {
    await SharedPreferences.getInstance()
      .then((prefs) => prefs.setBool('auto_backup', enable));

    if (enable) {
      // 기존 계약서 모두 백업
      await _backupAllContracts();
    }
  }
}
```

**Slack 알림:**

```typescript
// nestjs_app/src/integrations/slack.service.ts
import { IncomingWebhook } from '@slack/webhook';

@Injectable()
export class SlackService {
  private webhook: IncomingWebhook;

  constructor() {
    this.webhook = new IncomingWebhook(process.env.SLACK_WEBHOOK_URL);
  }

  async sendContractNotification(contract: Contract, event: string) {
    await this.webhook.send({
      text: `계약서 알림: ${event}`,
      attachments: [{
        color: event === '서명 완료' ? 'good' : 'warning',
        fields: [
          { title: '계약명', value: contract.name, short: false },
          { title: '의뢰인', value: contract.clientName, short: true },
          { title: '수행자', value: contract.performerName, short: true },
        ],
      }],
    });
  }
}

// 사용 예시
await this.slackService.sendContractNotification(
  contract,
  '서명 완료'
);
```

---

## 🛠️ **코드 품질 개선 (개발자용)**

### 긴급 🔴

#### 1. **거대 파일 분할**

**현재 문제:**
- `create_contract_screen.dart`: 3,313줄
- 가독성 저하, 유지보수 어려움

**해결 방법:**

```
lib/features/contracts/view/create_contract/
├── create_contract_screen.dart          (100줄 - 메인 Scaffold)
├── widgets/
│   ├── basic_info_step.dart            (갑/을 정보 입력)
│   ├── contract_details_step.dart      (계약 조건)
│   ├── template_fields_step.dart       (템플릿 필드)
│   ├── performer_info_step.dart        (수행자 정보)
│   ├── summary_step.dart               (요약)
│   └── signature_section.dart          (서명 패드)
├── validators/
│   ├── phone_validator.dart
│   ├── email_validator.dart
│   └── business_number_validator.dart
└── formatters/
    ├── phone_formatter.dart
    └── currency_formatter.dart
```

**리팩토링 예시:**

```dart
// BEFORE (3,313줄)
class _CreateContractScreenState extends State<CreateContractScreen> {
  // 모든 로직이 한 파일에...
}

// AFTER (100줄)
class _CreateContractScreenState extends State<CreateContractScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stepper(
        currentStep: _currentStep,
        steps: [
          Step(
            title: Text('기본 정보'),
            content: BasicInfoStep(
              onFieldChanged: _handleFieldChange,
            ),
          ),
          Step(
            title: Text('계약 조건'),
            content: ContractDetailsStep(
              template: _template,
              onFieldChanged: _handleFieldChange,
            ),
          ),
          // ...
        ],
      ),
    );
  }
}

// 각 Step은 별도 파일
class BasicInfoStep extends StatelessWidget {
  final Function(String, String) onFieldChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(labelText: '계약명'),
          onChanged: (value) => onFieldChanged('name', value),
        ),
        // ...
      ],
    );
  }
}
```

---

#### 2. **Legacy 코드 제거**

**삭제 대상:**

```bash
# 완전히 사용하지 않는 파일들
rm -rf lib/features/podcast/
rm -rf lib/features/invest/
rm lib/data/podcast_repository.dart
rm lib/data/portfolio_repository.dart
rm lib/models/stock.dart
rm lib/models/portfolio.dart
rm lib/models/podcast.dart
rm lib/features/stock/cubit/stock_cubit.dart
```

**주의사항:**
- main.dart에서 Provider 등록 제거 확인
- app_router.dart에서 라우트 제거 확인
- import 문 정리

**영향:**
- APK 사이즈 감소 (~10-20%)
- 빌드 시간 단축
- 새로운 개발자 혼란 방지

---

#### 3. **State Management 통일**

**현재 문제:**
- 계약 생성: StatefulWidget (3,313줄 복잡도)
- 계약 목록: Cubit 사용
- 일관성 부족

**해결:**

```dart
// lib/features/contracts/cubit/create_contract_cubit.dart
class CreateContractCubit extends Cubit<CreateContractState> {
  final ContractRepository _repository;
  final TemplateRepository _templateRepository;

  CreateContractCubit(this._repository, this._templateRepository)
    : super(CreateContractState.initial());

  Future<void> loadTemplate(int templateId) async {
    emit(state.copyWith(loading: true));
    try {
      final template = await _templateRepository.fetchTemplate(templateId);
      emit(state.copyWith(
        template: template,
        loading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        error: e.toString(),
        loading: false,
      ));
    }
  }

  void updateField(String key, dynamic value) {
    final updatedFields = Map<String, dynamic>.from(state.fields);
    updatedFields[key] = value;
    emit(state.copyWith(fields: updatedFields));
  }

  Future<void> submitContract() async {
    if (!_validateFields()) {
      emit(state.copyWith(error: '필수 항목을 모두 입력해주세요'));
      return;
    }

    emit(state.copyWith(submitting: true));
    try {
      final contract = await _repository.createContract(
        name: state.fields['name'],
        // ...
      );
      emit(state.copyWith(
        submitting: false,
        submitted: true,
        contract: contract,
      ));
    } catch (e) {
      emit(state.copyWith(
        error: e.toString(),
        submitting: false,
      ));
    }
  }

  bool _validateFields() {
    // 유효성 검사 로직
    return true;
  }
}

// State 정의
class CreateContractState {
  final Template? template;
  final Map<String, dynamic> fields;
  final bool loading;
  final bool submitting;
  final bool submitted;
  final String? error;
  final Contract? contract;

  CreateContractState({
    this.template,
    this.fields = const {},
    this.loading = false,
    this.submitting = false,
    this.submitted = false,
    this.error,
    this.contract,
  });

  CreateContractState copyWith({
    Template? template,
    Map<String, dynamic>? fields,
    bool? loading,
    bool? submitting,
    bool? submitted,
    String? error,
    Contract? contract,
  }) {
    return CreateContractState(
      template: template ?? this.template,
      fields: fields ?? this.fields,
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      submitted: submitted ?? this.submitted,
      error: error,
      contract: contract ?? this.contract,
    );
  }

  factory CreateContractState.initial() {
    return CreateContractState();
  }
}
```

**장점:**
- 테스트 가능
- 상태 복원 쉬움
- 로직 재사용 가능

---

#### 4. **에러 처리 개선**

**현재 문제:**
```dart
// 사용자에게 의미 없는 메시지
catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Exception: ${e.toString()}')),
  );
}
```

**개선:**

```dart
// lib/core/errors/app_exception.dart
abstract class AppException implements Exception {
  final String message;
  final String? details;

  AppException(this.message, [this.details]);

  String getUserMessage();
}

class NetworkException extends AppException {
  NetworkException([String? details])
    : super('네트워크 오류', details);

  @override
  String getUserMessage() {
    return '인터넷 연결을 확인해주세요.';
  }
}

class UnauthorizedException extends AppException {
  UnauthorizedException([String? details])
    : super('인증 오류', details);

  @override
  String getUserMessage() {
    return '다시 로그인해주세요.';
  }
}

class ServerException extends AppException {
  ServerException([String? details])
    : super('서버 오류', details);

  @override
  String getUserMessage() {
    return '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
  }
}

class ValidationException extends AppException {
  ValidationException(String message, [String? details])
    : super(message, details);

  @override
  String getUserMessage() => message;
}

// lib/data/services/api_client.dart
Future<T> request<T>(...) async {
  try {
    final response = await http.post(...);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      throw UnauthorizedException(response.body);
    } else if (response.statusCode >= 500) {
      throw ServerException(response.body);
    } else {
      throw ValidationException(response.body);
    }
  } on SocketException {
    throw NetworkException('네트워크 연결 실패');
  } on TimeoutException {
    throw NetworkException('요청 시간 초과');
  }
}

// 사용
try {
  await contractRepository.createContract(...);
} on AppException catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(e.getUserMessage()),
      backgroundColor: Colors.red,
    ),
  );
}
```

---

### 중요 🟡

#### 5. **API Client 개선**

**현재 문제:**
- 재시도 로직 없음
- 타임아웃 설정 불명확
- 토큰 만료 시 처리 없음

**개선:**

```dart
// lib/data/services/api_client.dart
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

class ApiClient {
  late final http.Client _client;

  ApiClient() {
    // 재시도 로직이 포함된 클라이언트
    _client = RetryClient(
      http.Client(),
      retries: 3,
      when: (response) {
        // 5xx 오류나 네트워크 오류 시 재시도
        return response.statusCode >= 500;
      },
      delay: (retryCount) {
        // 지수 백오프
        return Duration(seconds: math.pow(2, retryCount).toInt());
      },
    );
  }

  Future<T> request<T>({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    required T Function(Map<String, dynamic>) fromJson,
    int timeoutSeconds = 30,
  }) async {
    final token = await SessionService.getAccessToken();

    // 토큰 만료 확인
    if (token != null && await _isTokenExpired()) {
      await _refreshToken();
    }

    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await _client
        .post(
          Uri.parse('$baseUrl$endpoint'),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(Duration(seconds: timeoutSeconds));

      if (response.statusCode == 401) {
        // 토큰 만료 → 재로그인 필요
        await _handleUnauthorized();
        throw UnauthorizedException();
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      }

      throw _handleErrorResponse(response);
    } on TimeoutException {
      throw NetworkException('요청 시간이 초과되었습니다');
    } on SocketException {
      throw NetworkException('인터넷 연결을 확인해주세요');
    }
  }

  Future<bool> _isTokenExpired() async {
    final expiresAt = await SessionService.getExpiresAt();
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt);
  }

  Future<void> _refreshToken() async {
    // 리프레시 토큰으로 새 액세스 토큰 받기
    // 백엔드에 /auth/refresh 엔드포인트 필요
  }

  Future<void> _handleUnauthorized() async {
    await SessionService.clearSession();
    // 로그인 화면으로 리다이렉트
    // (Cubit에서 처리하도록 이벤트 발생)
  }
}
```

---

#### 6. **테스트 추가**

**현재 상태:** 테스트 거의 없음

**추가할 테스트:**

```dart
// test/data/repositories/contract_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late ContractRepository repository;
  late MockApiClient mockApiClient;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = ContractRepository(mockApiClient);
  });

  group('ContractRepository', () {
    test('fetchContracts returns list of contracts', () async {
      // Arrange
      when(mockApiClient.requestList<Contract>(
        endpoint: '/contracts',
        method: 'GET',
        fromJson: any,
      )).thenAnswer((_) async => [
        Contract(id: 1, name: 'Test Contract'),
      ]);

      // Act
      final contracts = await repository.fetchContracts(token: 'test-token');

      // Assert
      expect(contracts.length, 1);
      expect(contracts[0].name, 'Test Contract');
    });

    test('createContract throws ValidationException on invalid data', () async {
      // Arrange
      when(mockApiClient.request<Contract>(
        endpoint: '/contracts',
        method: 'POST',
        body: any,
        fromJson: any,
      )).thenThrow(ValidationException('계약명은 필수입니다'));

      // Act & Assert
      expect(
        () => repository.createContract(name: ''),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}

// test/features/auth/cubit/auth_cubit_test.dart
void main() {
  late AuthCubit authCubit;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    authCubit = AuthCubit(mockAuthRepository);
  });

  tearDown(() {
    authCubit.close();
  });

  blocTest<AuthCubit, AuthState>(
    'login emits authenticated state on success',
    build: () {
      when(mockAuthRepository.login(
        email: 'test@example.com',
        password: 'password123',
      )).thenAnswer((_) async => AuthResponse(
        user: User(id: 1, email: 'test@example.com'),
        accessToken: 'token',
        expiresIn: 3600,
      ));
      return authCubit;
    },
    act: (cubit) => cubit.login(
      email: 'test@example.com',
      password: 'password123',
    ),
    expect: () => [
      AuthState(status: AuthStatus.loading),
      AuthState(
        status: AuthStatus.authenticated,
        user: User(id: 1, email: 'test@example.com'),
      ),
    ],
  );
}

// test/features/contracts/widgets/contract_card_test.dart
void main() {
  testWidgets('ContractCard displays contract information', (tester) async {
    // Arrange
    final contract = Contract(
      id: 1,
      name: 'Test Contract',
      status: 'active',
      clientName: 'Client A',
      performerName: 'Performer B',
    );

    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContractCard(contract: contract),
        ),
      ),
    );

    // Assert
    expect(find.text('Test Contract'), findsOneWidget);
    expect(find.text('Client A'), findsOneWidget);
    expect(find.text('Performer B'), findsOneWidget);
  });
}
```

**테스트 실행:**
```bash
# 전체 테스트
flutter test

# 커버리지
flutter test --coverage
lcov --summary coverage/lcov.info

# 특정 파일
flutter test test/data/repositories/contract_repository_test.dart
```

---

#### 7. **성능 최적화**

**계약서 목록 페이지네이션:**

```dart
// lib/features/contracts/view/contracts_screen.dart
class _ContractsScreenState extends State<ContractsScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadContracts();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // 스크롤이 80%에 도달하면 다음 페이지 로드
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreContracts();
      }
    }
  }

  Future<void> _loadMoreContracts() async {
    setState(() => _isLoadingMore = true);

    try {
      final newContracts = await _contractRepository.fetchContracts(
        page: _currentPage + 1,
        pageSize: _pageSize,
      );

      if (newContracts.isEmpty) {
        setState(() => _hasMoreData = false);
      } else {
        setState(() {
          _contracts.addAll(newContracts);
          _currentPage++;
        });
      }
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _contracts.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _contracts.length) {
          // 로딩 인디케이터
          return Center(child: CircularProgressIndicator());
        }
        return ContractCard(contract: _contracts[index]);
      },
    );
  }
}
```

**백엔드 페이지네이션:**

```typescript
// nestjs_app/src/contracts/contracts.controller.ts
@Get()
async findAll(
  @Query('page') page: number = 1,
  @Query('pageSize') pageSize: number = 20,
  @Query('status') status?: string,
) {
  const skip = (page - 1) * pageSize;
  const take = pageSize;

  const [contracts, total] = await this.contractsRepository.findAndCount({
    where: status ? { status } : {},
    skip,
    take,
    order: { createdAt: 'DESC' },
  });

  return {
    data: contracts,
    meta: {
      page,
      pageSize,
      total,
      totalPages: Math.ceil(total / pageSize),
    },
  };
}
```

**이미지 최적화:**

```dart
// 계약서 서명 이미지 캐싱
import 'package:cached_network_image/cached_network_image.dart';

CachedNetworkImage(
  imageUrl: signatureUrl,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
  fadeInDuration: Duration(milliseconds: 300),
  memCacheWidth: 500,  // 메모리 절약
)
```

---

## 🎨 **UX 개선 아이디어**

### 즉시 가능

#### 1. **계약서 작성 진행률 표시**

```dart
// lib/features/contracts/view/create_contract_screen.dart
class _CreateContractScreenState extends State<CreateContractScreen> {
  int _currentStep = 0;
  final int _totalSteps = 4;

  double get _progress => (_currentStep + 1) / _totalSteps;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('계약서 작성'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(8),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Step ${_currentStep + 1} / $_totalSteps',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${(_progress * 100).toInt()}% 완료',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stepper(
              currentStep: _currentStep,
              // ...
            ),
          ),
        ],
      ),
    );
  }
}
```

---

#### 2. **서명 요청 상태 실시간 표시**

```dart
// lib/features/contracts/widgets/signature_status_tracker.dart
class SignatureStatusTracker extends StatelessWidget {
  final Contract contract;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          _StatusStep(
            icon: Icons.email,
            label: '이메일 발송',
            isCompleted: contract.signatureSentAt != null,
            isActive: contract.signatureSentAt != null,
          ),
          _StatusConnector(
            isCompleted: contract.signatureViewedAt != null,
          ),
          _StatusStep(
            icon: Icons.visibility,
            label: '읽음',
            isCompleted: contract.signatureViewedAt != null,
            isActive: contract.signatureViewedAt != null,
          ),
          _StatusConnector(
            isCompleted: contract.signatureStartedAt != null,
          ),
          _StatusStep(
            icon: Icons.edit,
            label: '서명 중',
            isCompleted: contract.signatureStartedAt != null,
            isActive: contract.signatureStartedAt != null,
          ),
          _StatusConnector(
            isCompleted: contract.signatureCompletedAt != null,
          ),
          _StatusStep(
            icon: Icons.check_circle,
            label: '완료',
            isCompleted: contract.signatureCompletedAt != null,
            isActive: contract.signatureCompletedAt != null,
          ),
        ],
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isCompleted;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted ? primaryColor : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isCompleted ? Colors.white : Colors.grey[600],
            size: 20,
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isCompleted ? primaryColor : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
```

**백엔드 추가 필드:**
```typescript
// contracts 테이블
{
  signatureSentAt: Date,
  signatureViewedAt: Date,      // 새로 추가
  signatureStartedAt: Date,      // 새로 추가
  signatureCompletedAt: Date,
}
```

---

#### 3. **자주 쓰는 템플릿 홈 화면 바로가기**

```dart
// lib/features/home/view/home_screen.dart
class _HomeScreenState extends State<HomeScreen> {
  List<Template> _favoriteTemplates = [];

  @override
  void initState() {
    super.initState();
    _loadFavoriteTemplates();
  }

  Future<void> _loadFavoriteTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList('favorite_templates') ?? [];

    final templates = await _templateRepository.fetchTemplates();
    setState(() {
      _favoriteTemplates = templates
        .where((t) => favoriteIds.contains(t.id.toString()))
        .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 통계 카드
          _buildStatisticsCards(),

          // 자주 쓰는 템플릿 바로가기
          if (_favoriteTemplates.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '자주 쓰는 템플릿',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: _favoriteTemplates.length,
                    itemBuilder: (context, index) {
                      final template = _favoriteTemplates[index];
                      return _QuickTemplateCard(
                        template: template,
                        onTap: () {
                          context.push(
                            '/contracts/create',
                            extra: {'templateId': template.id},
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

          // 최근 계약서
          _buildRecentContracts(),
        ],
      ),
    );
  }
}

class _QuickTemplateCard extends StatelessWidget {
  final Template template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description,
              size: 32,
              color: primaryColor,
            ),
            SizedBox(height: 8),
            Text(
              template.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
```

---

#### 4. **계약서 미리보기 개선**

```dart
// lib/features/contracts/widgets/contract_preview.dart
class ContractPreview extends StatefulWidget {
  final String htmlContent;

  @override
  State<ContractPreview> createState() => _ContractPreviewState();
}

class _ContractPreviewState extends State<ContractPreview> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 줌 컨트롤
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.zoom_out),
              onPressed: _zoomOut,
            ),
            IconButton(
              icon: Icon(Icons.zoom_in),
              onPressed: _zoomIn,
            ),
            IconButton(
              icon: Icon(Icons.fullscreen),
              onPressed: _showFullscreen,
            ),
          ],
        ),

        // 확대/축소 가능한 미리보기
        Expanded(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 3.0,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: HtmlWidget(
                  widget.htmlContent,
                  textStyle: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    _transformationController.value = Matrix4.identity()
      ..scale(currentScale * 1.2);
  }

  void _zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    _transformationController.value = Matrix4.identity()
      ..scale(currentScale / 1.2);
  }

  void _showFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('계약서 전체 보기'),
            actions: [
              IconButton(
                icon: Icon(Icons.download),
                onPressed: () {
                  // PDF 다운로드
                },
              ),
            ],
          ),
          body: ContractPreview(htmlContent: widget.htmlContent),
        ),
      ),
    );
  }
}
```

---

## 📈 **비즈니스 관점 개선안**

### 수익화 가능 기능

#### 1. **프리미엄 템플릿** 💰

**무료 vs 프리미엄 구분:**

```typescript
// Template 모델 확장
interface Template {
  id: number;
  name: string;
  category: string;
  content: string;
  isPremium: boolean;         // 추가
  price?: number;             // 추가 (원 단위)
  reviewedByLawyer: boolean;  // 추가 (변호사 검수 여부)
}
```

**Flutter UI:**

```dart
// 템플릿 카드에 프리미엄 뱃지
class TemplateCard extends StatelessWidget {
  final Template template;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Stack(
        children: [
          // 템플릿 내용
          ListTile(
            title: Text(template.name),
            subtitle: Text(template.category),
          ),

          // 프리미엄 뱃지
          if (template.isPremium)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 프리미엄 템플릿 사용 시 결제 화면
void _useTemplate(Template template) {
  if (template.isPremium && !_user.isPremiumMember) {
    _showPurchaseDialog(template);
  } else {
    _navigateToCreateContract(template);
  }
}

void _showPurchaseDialog(Template template) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('프리미엄 템플릿'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 48, color: Colors.amber),
          SizedBox(height: 16),
          Text(
            '이 템플릿은 전문 변호사가 검수한\n프리미엄 템플릿입니다.',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            '${NumberFormat.currency(symbol: '₩').format(template.price)}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소'),
        ),
        ElevatedButton(
          onPressed: () => _purchaseTemplate(template),
          child: Text('구매하기'),
        ),
      ],
    ),
  );
}
```

---

#### 2. **계약서 개수 제한** 💰

**플랜 구조:**

```typescript
enum SubscriptionPlan {
  Free = 'free',      // 월 10건
  Basic = 'basic',    // 월 50건, ₩9,900
  Pro = 'pro',        // 무제한, ₩19,900
}

interface User {
  // ...
  subscriptionPlan: SubscriptionPlan;
  subscriptionExpiresAt?: Date;
  monthlyContractQuota: number;     // 이번 달 남은 개수
  monthlyContractQuotaResetAt: Date;
}
```

**Flutter 제한 로직:**

```dart
// 계약서 생성 전 체크
Future<void> _createContract() async {
  final user = context.read<AuthCubit>().currentUser;

  if (user.subscriptionPlan == 'free' &&
      user.monthlyContractQuota <= 0) {
    _showUpgradeDialog();
    return;
  }

  // 계약서 생성 진행
  await _contractRepository.createContract(...);

  // 할당량 감소
  await _userRepository.decrementQuota();
}

void _showUpgradeDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('월 할당량 초과'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.orange),
          SizedBox(height: 16),
          Text(
            '이번 달 무료 계약서 10건을\n모두 사용하셨습니다.',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            '프리미엄으로 업그레이드하고\n무제한으로 이용하세요!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('나중에'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            context.push('/subscription');
          },
          child: Text('업그레이드'),
        ),
      ],
    ),
  );
}
```

---

#### 3. **팀/조직 플랜** 💰

**가격 구조:**

```
개인 플랜
- Free: ₩0 (월 10건)
- Pro: ₩19,900 (무제한)

조직 플랜
- Team (5인): ₩49,000/월
- Business (20인): ₩149,000/월
- Enterprise: 별도 협의
```

**구독 화면:**

```dart
// lib/features/subscription/view/subscription_screen.dart
class SubscriptionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('플랜 선택')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _PlanCard(
            name: 'Free',
            price: 0,
            features: [
              '월 10건 계약서 생성',
              '기본 템플릿 사용',
              'PDF 다운로드',
            ],
            isCurrentPlan: true,
          ),
          SizedBox(height: 16),
          _PlanCard(
            name: 'Pro',
            price: 19900,
            features: [
              '무제한 계약서 생성',
              '프리미엄 템플릿 사용',
              '통계 및 분석',
              '우선 고객 지원',
            ],
            isRecommended: true,
          ),
          SizedBox(height: 16),
          _PlanCard(
            name: 'Team',
            price: 49000,
            features: [
              'Pro 플랜 모든 기능',
              '팀원 5명 포함',
              '팀 공용 템플릿',
              '승인 워크플로우',
              '통합 청구서',
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final int price;
  final List<String> features;
  final bool isCurrentPlan;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isRecommended ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isRecommended
          ? BorderSide(color: primaryColor, width: 2)
          : BorderSide.none,
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isRecommended)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '추천',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            SizedBox(height: 12),
            Text(
              name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₩${NumberFormat('#,###').format(price)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
                if (price > 0)
                  Text(
                    ' /월',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 20),
            ...features.map((feature) => Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: Colors.green,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCurrentPlan ? null : () {
                  // 결제 화면으로
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrentPlan ? Colors.grey : primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  isCurrentPlan ? '현재 플랜' : '선택하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

#### 4. **AI 요약 기능** 🤖 💰

**OpenAI API 연동:**

```typescript
// nestjs_app/src/ai/ai.service.ts
import { Configuration, OpenAIApi } from 'openai';

@Injectable()
export class AiService {
  private openai: OpenAIApi;

  constructor() {
    const configuration = new Configuration({
      apiKey: process.env.OPENAI_API_KEY,
    });
    this.openai = new OpenAIApi(configuration);
  }

  async summarizeContract(htmlContent: string): Promise<string> {
    // HTML에서 텍스트만 추출
    const textContent = this.stripHtml(htmlContent);

    const response = await this.openai.createChatCompletion({
      model: 'gpt-4',
      messages: [
        {
          role: 'system',
          content: '당신은 계약서를 분석하고 요약하는 전문가입니다. 한국어로 답변하세요.',
        },
        {
          role: 'user',
          content: `다음 계약서를 3-5개의 핵심 조항으로 요약해주세요:\n\n${textContent}`,
        },
      ],
      temperature: 0.3,
      max_tokens: 500,
    });

    return response.data.choices[0].message?.content || '';
  }

  async highlightKeyTerms(htmlContent: string): Promise<string[]> {
    const textContent = this.stripHtml(htmlContent);

    const response = await this.openai.createChatCompletion({
      model: 'gpt-4',
      messages: [
        {
          role: 'system',
          content: '계약서에서 중요한 조항을 찾아주세요.',
        },
        {
          role: 'user',
          content: `다음 계약서에서 특별히 주의해야 할 조항이나 단어를 찾아 리스트로 반환해주세요:\n\n${textContent}`,
        },
      ],
      temperature: 0.3,
    });

    const content = response.data.choices[0].message?.content || '';
    // "- 항목" 형식으로 파싱
    return content.split('\n')
      .filter(line => line.trim().startsWith('-'))
      .map(line => line.replace(/^-\s*/, '').trim());
  }

  private stripHtml(html: string): string {
    return html.replace(/<[^>]*>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }
}
```

**Flutter UI:**

```dart
// 계약서 상세 화면에 AI 요약 버튼
class ContractDetailScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 계약서 내용
          // ...

          // AI 요약 섹션
          if (_aiSummary != null)
            Card(
              margin: EdgeInsets.all(16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.purple),
                        SizedBox(width: 8),
                        Text(
                          'AI 요약',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      _aiSummary!,
                      style: TextStyle(height: 1.6),
                    ),
                  ],
                ),
              ),
            ),

          // AI 요약 버튼
          if (_aiSummary == null)
            ElevatedButton.icon(
              onPressed: _generateAiSummary,
              icon: Icon(Icons.auto_awesome),
              label: Text('AI 요약 생성 (Pro)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _generateAiSummary() async {
    // Pro 플랜 체크
    if (!_user.isPro) {
      _showUpgradeDialog();
      return;
    }

    setState(() => _generatingSummary = true);

    try {
      final summary = await _contractRepository.generateAiSummary(
        contractId: widget.contractId,
      );

      setState(() {
        _aiSummary = summary;
        _generatingSummary = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('요약 생성 실패: $e')),
      );
    }
  }
}
```

---

## ⚡ **빠른 개선 체크리스트** (1-2일 소요)

### 즉시 적용 가능

- [ ] **계약서 목록 페이지네이션** (성능)
  - 현재: 전체 로드
  - 개선: 20개씩 로드, 무한 스크롤

- [ ] **로딩 스피너 통일** (UX)
  - 일관된 디자인 적용
  - 색상: primaryColor

- [ ] **에러 메시지 한국어 통일** (UX)
  - "Exception: ..." → "인터넷 연결을 확인해주세요"
  - 상황별 맞춤 메시지

- [ ] **임시 저장 자동 저장** (기능)
  - 현재: 수동 저장
  - 개선: 30초마다 자동 저장

- [ ] **계약서 삭제 확인 대화상자** (안전)
  - "정말 삭제하시겠습니까?" 추가
  - 복구 불가 안내

- [ ] **서명 요청 이메일 템플릿 개선** (UX)
  - HTML 이메일로 변경
  - 회사 로고, 버튼 스타일 추가

- [ ] **계약서 상세 화면 공유 버튼** (기능)
  - 카카오톡, 이메일 공유
  - 링크 복사

- [ ] **알림 배지 표시** (UX)
  - 읽지 않은 메시지 개수 표시
  - 하단 네비게이션 바에

---

## 🎯 **추천 로드맵**

### Phase 1: 기초 개선 (1개월)
**목표:** 사용자 불편 해소, 보안 강화

✅ **Week 1-2:**
- [ ] User 모델에 연락처 추가
- [ ] 토큰 암호화 (flutter_secure_storage)
- [ ] 에러 처리 개선
- [ ] 계약서 삭제 확인 추가

✅ **Week 3-4:**
- [ ] 검색 기능 개선 (전체 텍스트, 필터)
- [ ] 서명 거절 사유 입력
- [ ] 페이지네이션 추가
- [ ] 로딩 스피너 통일

---

### Phase 2: 기능 확장 (2-3개월)
**목표:** 생산성 향상, 사용자 편의

✅ **Month 2:**
- [ ] 일괄 작업 기능 (PDF 다운로드, 보관, 삭제)
- [ ] 템플릿 즐겨찾기
- [ ] 홈 화면 템플릿 바로가기
- [ ] 계약서 알림 강화 (만료 예정, 서명 독촉)

✅ **Month 3:**
- [ ] 다크 모드
- [ ] 계약서 미리보기 개선 (확대/축소)
- [ ] 임시 저장 자동화
- [ ] 서명 상태 트래커 UI

---

### Phase 3: 고급 기능 (4-6개월)
**목표:** 협업, 통계, 차별화

✅ **Month 4-5:**
- [ ] 통계 대시보드 (그래프, 지표)
- [ ] 오프라인 모드 (로컬 DB, PDF 저장)
- [ ] 생체 인증 (지문/얼굴인식)
- [ ] Legacy 코드 완전 제거

✅ **Month 6:**
- [ ] 협업 기능 기초 (댓글, 변경 이력)
- [ ] 캘린더 연동
- [ ] 테스트 커버리지 50% 이상
- [ ] 성능 최적화 (이미지 캐싱, 메모리)

---

### Phase 4: 비즈니스 확장 (6개월+)
**목표:** 수익화, 팀 기능, AI

✅ **Month 7-9:**
- [ ] 조직/팀 기능 (멤버 관리, 권한, 승인)
- [ ] 프리미엄 템플릿 마켓
- [ ] 구독 시스템 (Free/Pro/Team)
- [ ] 결제 연동 (Iamport/Toss Payments)

✅ **Month 10-12:**
- [ ] AI 계약서 요약
- [ ] AI 주요 조항 하이라이트
- [ ] 외부 연동 (Google Drive, Slack)
- [ ] 관리자 대시보드 (통계, 사용자 관리)

---

## 🏆 **가장 큰 영향력 TOP 10**

### 사용자 만족도 관점

1. 🥇 **사용자 프로필에 연락처 추가**
   - 매번 입력하는 불편함 완전 해소
   - 개발 난이도: ⭐ (쉬움)
   - 영향력: ⭐⭐⭐⭐⭐

2. 🥈 **검색 기능 개선**
   - 계약서 많아질수록 필수
   - 개발 난이도: ⭐⭐ (중간)
   - 영향력: ⭐⭐⭐⭐⭐

3. 🥉 **일괄 작업 기능**
   - 생산성 10배 향상
   - 개발 난이도: ⭐⭐⭐ (어려움)
   - 영향력: ⭐⭐⭐⭐⭐

4. **템플릿 즐겨찾기**
   - 자주 쓰는 템플릿 빠른 접근
   - 개발 난이도: ⭐ (쉬움)
   - 영향력: ⭐⭐⭐⭐

5. **계약서 알림 강화**
   - 놓치는 서명 없음
   - 개발 난이도: ⭐⭐ (중간)
   - 영향력: ⭐⭐⭐⭐

6. **통계 대시보드**
   - 계약 현황 한눈에
   - 개발 난이도: ⭐⭐⭐ (어려움)
   - 영향력: ⭐⭐⭐⭐

7. **다크 모드**
   - 야간 사용자 편의
   - 개발 난이도: ⭐⭐ (중간)
   - 영향력: ⭐⭐⭐

8. **오프라인 모드**
   - 언제 어디서나 열람
   - 개발 난이도: ⭐⭐⭐ (어려움)
   - 영향력: ⭐⭐⭐

9. **협업 기능**
   - 팀 작업 효율 증가
   - 개발 난이도: ⭐⭐⭐⭐ (매우 어려움)
   - 영향력: ⭐⭐⭐⭐⭐

10. **AI 요약**
    - 긴 계약서 빠른 파악
    - 개발 난이도: ⭐⭐⭐ (어려움)
    - 영향력: ⭐⭐⭐⭐

---

### 비즈니스 관점

1. 🥇 **구독 시스템** (수익화)
2. 🥈 **팀/조직 기능** (B2B 확장)
3. 🥉 **프리미엄 템플릿** (부가 수익)
4. **AI 기능** (차별화)
5. **API 제공** (파트너십)

---

## 📝 **결론**

### 즉시 시작하면 좋은 것 (Quick Wins)

1. ✅ **User 모델에 phone 추가** (1일)
2. ✅ **토큰 암호화** (1일)
3. ✅ **템플릿 즐겨찾기** (2일)
4. ✅ **페이지네이션** (2일)
5. ✅ **에러 메시지 개선** (1일)

👉 **1주일이면 5개 완료 가능!**

---

### 중장기적으로 준비할 것

1. 📈 **검색 & 필터링** (1-2주)
2. 📊 **통계 대시보드** (2-3주)
3. 👥 **팀 기능** (1-2개월)
4. 🤖 **AI 통합** (1-2개월)
5. 💰 **구독 시스템** (1개월)

---

### 기술 부채 해결

1. 🔨 **거대 파일 리팩토링** (2-3주)
2. 🧹 **Legacy 코드 제거** (1주)
3. 🧪 **테스트 추가** (지속적)
4. 🏗️ **State Management 통일** (2-3주)

---

## 📌 **다음 액션 아이템**

**오늘 시작할 수 있는 것:**
1. User 모델에 phone, address 필드 추가
2. flutter_secure_storage 패키지 추가
3. 템플릿 즐겨찾기 기능 구현

**이번 주 목표:**
1. 사용자 프로필 연락처 자동 채우기 완성
2. 토큰 암호화 적용
3. 계약서 목록 페이지네이션

**이번 달 목표:**
1. 검색 기능 전면 개선
2. 일괄 작업 기능 베타
3. Legacy 코드 50% 제거

---

이 분석을 바탕으로 어떤 기능부터 시작하시겠습니까? 구체적인 구현 방법이 필요하면 말씀해주세요! 🚀
