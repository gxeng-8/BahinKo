import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bahinko/app.dart';
import 'package:bahinko/data/in_memory_group_service.dart';
import 'package:bahinko/data/mock_data.dart';
import 'package:bahinko/screens/group/group_detail_screen.dart';
import 'package:bahinko/screens/notifications/notifications_screen.dart';
import 'package:bahinko/services/auth_service.dart';
import 'package:bahinko/services/group_service.dart';
import 'package:bahinko/services/settings_service.dart';
import 'package:bahinko/widgets/refreshable.dart';

import 'fakes.dart';

/// Sample data that counts refreshes, and can pretend to be offline.
class CountingService extends InMemoryGroupService {
  int refreshes = 0;
  bool fail = false;

  @override
  Future<void> refresh() async {
    refreshes++;
    if (fail) {
      throw const GroupFailure(
        "Can't reach the server. Check your internet connection.",
      );
    }
  }
}

late CountingService service;

Future<void> pull(WidgetTester tester) async {
  await tester.fling(find.byType(Scrollable).first, const Offset(0, 500), 1200);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    groupMembers.value = people;
    GroupService.instance = service = CountingService();
    AuthService.instance = FakeAuthService(name: 'Yumi');
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance = SettingsService();
  });

  testWidgets('swiping down on Home refreshes it', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const BahinKoApp(signedIn: true, lockOnStart: false),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RefreshIndicator), findsWidgets);
    await pull(tester);
    expect(service.refreshes, 1);
    expect(find.text('Net balance'), findsOneWidget); // rebuilt fine
  });

  testWidgets('swiping down on a group page refreshes it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        scrollBehavior: AlwaysPullableScrollBehavior(),
        home: GroupDetail(groupId: demoGroupId),
      ),
    );
    await tester.pumpAndSettle();
    await pull(tester);
    expect(service.refreshes, 1);
  });

  testWidgets('short pages can be pulled too', (tester) async {
    // Notifications is empty here, so the page doesn't fill the screen.
    await tester.pumpWidget(
      const MaterialApp(
        scrollBehavior: AlwaysPullableScrollBehavior(),
        home: NotificationsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await pull(tester);
    expect(service.refreshes, 1);
  });

  testWidgets('no internet: says so, page still works', (tester) async {
    service.fail = true;
    await tester.pumpWidget(
      const MaterialApp(
        scrollBehavior: AlwaysPullableScrollBehavior(),
        home: GroupDetail(groupId: demoGroupId),
      ),
    );
    await tester.pumpAndSettle();
    await pull(tester);
    expect(find.textContaining("Can't reach the server"), findsOneWidget);
    expect(find.byType(GroupDetail), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // let the toast go
  });
}
