import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/community/domain/community_models.dart';
import 'package:frontend/features/community/presentation/submit_station_sheet.dart';
import 'package:frontend/features/community/presentation/widgets/micro_survey_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Community & Survei Mikro Model Tests', () {
    test('MicroSurveyConsensus parses JSON and computes summary text correctly', () {
      final consensus = MicroSurveyConsensus.fromJson({
        'station_id': 'stat-123',
        'total_votes': 4,
        'consensus_threshold': 3,
        'consensus_plug_status': 'working',
        'consensus_parking_status': 'free',
        'consensus_access_difficulty': 'easy',
        'station_auto_updated': true,
      });

      expect(consensus.stationId, equals('stat-123'));
      expect(consensus.totalVotes, equals(4));
      expect(consensus.hasConsensus, isTrue);
      expect(consensus.summaryBadgeText, contains('Plugs Working'));
      expect(consensus.summaryBadgeText, contains('Free Entry'));
    });

    test('StationReview parses JSON and serializes idempotently', () {
      final review = StationReview.fromJson({
        'id': 'rev-01',
        'station_id': 'stat-123',
        'author_name': 'Hafiz',
        'rating': 5,
        'comment': 'Smooth charging, no queue at all.',
        'working_status': 'working',
        'wait_time_minutes': 0,
        'created_at': DateTime(2026, 2, 1).toIso8601String(),
      });

      expect(review.id, equals('rev-01'));
      expect(review.rating, equals(5));
      expect(review.authorName, equals('Hafiz'));
      expect(review.toJson()['working_status'], equals('working'));
    });
  });

  group('MicroSurveyCard Widget Tests', () {
    testWidgets('Renders 1-tap survey chips, consensus badge, and review form',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MicroSurveyCard(stationId: 'test-station-1'),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Survei Mikro header
      expect(find.text('Survei Mikro Community Consensus'), findsOneWidget);
      expect(find.text('Submit 1-Tap Survey Vote'), findsOneWidget);

      // Verify choice chips exist
      expect(find.text('Plugs: Working'), findsOneWidget);
      expect(find.text('Plugs: Broken'), findsOneWidget);
      expect(find.text('Parking: Free'), findsOneWidget);
      expect(find.text('Parking: Paid'), findsOneWidget);

      // Tap Broken chip and submit vote
      await tester.tap(find.text('Plugs: Broken'));
      await tester.pump();
      await tester.tap(find.text('Submit 1-Tap Survey Vote'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Driver Check-Ins section and Write Review toggle
      expect(find.textContaining('Driver Check-Ins'), findsOneWidget);
      expect(find.text('Write Review'), findsOneWidget);

      await tester.tap(find.text('Write Review'));
      await tester.pump();
      expect(find.text('Post Check-In'), findsOneWidget);
    });
  });

  group('SubmitStationSheet Widget Tests', () {
    testWidgets('Renders submission form and switches to moderation queue tab',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SubmitStationSheet(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify tab titles
      expect(find.text('Submit Charger'), findsOneWidget);
      expect(find.text('Moderation Queue'), findsOneWidget);

      // Verify form fields in Submit Charger tab
      expect(find.text('Station Name *'), findsOneWidget);
      expect(find.text('City *'), findsOneWidget);
      expect(find.text('Submit Station for Verification'), findsOneWidget);

      // Switch to Moderation Queue tab
      await tester.tap(find.text('Moderation Queue'));
      await tester.pumpAndSettle();
      expect(find.text('Moderation Queue Empty'), findsOneWidget);
    });
  });
}
