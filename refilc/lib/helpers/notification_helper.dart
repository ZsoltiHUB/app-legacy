import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Message;
import 'package:intl/intl.dart';
import 'package:refilc/api/providers/database_provider.dart';
import 'package:refilc/api/providers/status_provider.dart';
import 'package:refilc/api/providers/user_provider.dart';
import 'package:refilc/models/settings.dart';
import 'package:refilc/utils/navigation_service.dart';
import 'package:refilc/utils/service_locator.dart';
import 'package:refilc_kreta_api/client/api.dart';
import 'package:refilc_kreta_api/client/client.dart';
import 'package:refilc_kreta_api/models/absence.dart';
import 'package:refilc_kreta_api/models/exam.dart';
import 'package:refilc_kreta_api/models/grade.dart';
import 'package:refilc_kreta_api/models/lesson.dart';
import 'package:refilc_kreta_api/models/message.dart';
import 'package:refilc_kreta_api/models/week.dart';
import 'package:refilc_kreta_api/providers/timetable_provider.dart';

enum LastSeenCategory {
  grade,
  surprisegrade,
  absence,
  message,
  lesson,
  exam,
}

class NotificationsHelper {
  NotificationsHelper._();
  static final NotificationsHelper _instance = NotificationsHelper._();
  factory NotificationsHelper() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    const darwin = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    const android = AndroidInitializationSettings('ic_notification');
    const linux = LinuxInitializationSettings(defaultActionName: 'Open');
    const init = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: linux,
    );

    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'GENERAL',
              'General',
              description: 'General notifications',
              importance: Importance.max,
            ),
          );
    }

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    await initialize();

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return;
    }

    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return;
    }

    if (Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  @pragma('vm:entry-point')
  static void onDidReceiveBackgroundNotificationResponse(
      NotificationResponse notificationResponse) {
    NotificationsHelper()
        .onDidReceiveNotificationResponse(notificationResponse);
  }

  @pragma('vm:entry-point')
  Future<void> backgroundJob() async {
    await initialize();

    final database = DatabaseProvider();
    await database.init();

    final settings = await database.query.getSettings(database);
    final users = await database.query.getUsers(settings);

    if (!settings.notificationsEnabled || users.id == null) return;

    for (final user in users.getUsers()) {
      final userProviderForUser = await database.query.getUsers(settings);
      userProviderForUser.setUser(user.id);

      final status = StatusProvider();
      final kreta = KretaClient(
        user: userProviderForUser,
        settings: settings,
        database: database,
        status: status,
      );

      final loginResult = await kreta.refreshLogin();
      if (loginResult != null && loginResult != 'success') {
        continue;
      }

      if (settings.notificationsGradesEnabled && _bitEnabled(settings, 2)) {
        await _gradeNotifications(
          database: database,
          settings: settings,
          userProvider: userProviderForUser,
          kreta: kreta,
        );
      }

      if (settings.notificationsAbsencesEnabled && _bitEnabled(settings, 6)) {
        await _absenceNotifications(
          database: database,
          settings: settings,
          userProvider: userProviderForUser,
          kreta: kreta,
        );
      }

      if (settings.notificationsMessagesEnabled && _bitEnabled(settings, 4)) {
        await _messageNotifications(
          database: database,
          settings: settings,
          userProvider: userProviderForUser,
          kreta: kreta,
        );
      }

      if (settings.notificationsLessonsEnabled && _bitEnabled(settings, 5)) {
        await _lessonNotifications(
          database: database,
          settings: settings,
          userProvider: userProviderForUser,
          kreta: kreta,
        );
      }

      if (_bitEnabled(settings, 7)) {
        await _examNotifications(
          database: database,
          settings: settings,
          userProvider: userProviderForUser,
          kreta: kreta,
        );
      }
    }
  }

  bool _bitEnabled(SettingsProvider settings, int bit) {
    return (settings.notificationsBitfield & (1 << bit)) != 0;
  }

  NotificationDetails _details(SettingsProvider settings, String channelName) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'GENERAL',
        'General',
        channelDescription: channelName,
        importance: Importance.max,
        priority: Priority.max,
        color: settings.customAccentColor,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
      linux: const LinuxNotificationDetails(),
    );
  }

  String _subjectName(dynamic subject, SettingsProvider settings) {
    if ((subject.isRenamed as bool) && settings.renamedSubjectsEnabled) {
      return (subject.renamedTo as String?) ?? (subject.name as String);
    }
    return subject.name as String;
  }

  String _teacherName(dynamic teacher, SettingsProvider settings) {
    if ((teacher.isRenamed as bool) && settings.renamedTeachersEnabled) {
      return (teacher.renamedTo as String?) ?? (teacher.name as String);
    }
    return teacher.name as String;
  }

  String _dayName(DateTime date, String lang) {
    final locale = '${lang}_${lang.toUpperCase()}';
    final day = DateFormat('EEEE', locale).format(date);
    return day[0].toUpperCase() + day.substring(1);
  }

  bool _isLessonChanged(Lesson lesson) {
    final isCanceled = lesson.status?.name == 'Elmaradt';
    final hasSubstitute = lesson.substituteTeacher != null &&
        lesson.substituteTeacher!.name != '';
    return isCanceled || hasSubstitute;
  }

  String _lessonChangeFingerprint(Lesson lesson) {
    final isCanceled = lesson.status?.name == 'Elmaradt';
    if (isCanceled) return 'canceled';
    final substituteName = lesson.substituteTeacher?.name ?? '';
    return 'substitute:$substituteName';
  }

  Future<DateTime?> _lastSeenOrPrime({
    required DatabaseProvider database,
    required String userId,
    required LastSeenCategory category,
  }) async {
    final lastSeen =
        await database.userQuery.lastSeen(userId: userId, category: category);
    if (lastSeen.millisecondsSinceEpoch <= 0 || lastSeen.year <= 1970) {
      await database.userStore.storeLastSeen(
        DateTime.now(),
        userId: userId,
        category: category,
      );
      return null;
    }
    return lastSeen;
  }

  Future<void> _gradeNotifications({
    required DatabaseProvider database,
    required SettingsProvider settings,
    required UserProvider userProvider,
    required KretaClient kreta,
  }) async {
    final userId = userProvider.id;
    if (userId == null || userProvider.user == null) return;

    final iss = userProvider.user!.instituteCode;
    final gradesJson = await kreta.getAPI(KretaAPI.grades(iss));
    if (gradesJson is! List) return;

    final primed = await _lastSeenOrPrime(
      database: database,
      userId: userId,
      category: LastSeenCategory.grade,
    );
    if (primed == null) return;
    final grades = gradesJson.map((e) => Grade.fromJson(e)).toList();

    for (final grade in grades) {
      if (![1, 2, 3, 4, 5].contains(grade.value.value)) continue;
      if (!grade.date.isAfter(primed)) continue;
      if (DateTime.now().difference(grade.date).inDays >= 7) continue;

      final title = settings.language == 'hu'
          ? 'Új jegy'
          : (settings.language == 'de' ? 'Neue Note' : 'New grade');

      final subject = _subjectName(grade.subject, settings);
      final surpriseBody = settings.language == 'hu'
          ? '$subject: Nyisd meg az alkalmazást a jegyed megtekintéséhez!'
          : (settings.language == 'de'
              ? '$subject: Öffnen Sie die App, um Ihre Note anzuzeigen!'
              : '$subject: Open the app to see your grade!');
      final bodySingle = settings.gradeOpeningFun
          ? surpriseBody
          : '$subject: ${grade.value.value}';
      final bodyMulti =
          '(${userProvider.displayName ?? userProvider.name ?? ''}) $bodySingle';

      await _plugin.show(
        grade.id.hashCode,
        title,
        userProvider.getUsers().length == 1 ? bodySingle : bodyMulti,
        _details(settings, 'Grade notifications'),
        payload: 'grades',
      );
    }

    await database.userStore.storeLastSeen(
      DateTime.now(),
      userId: userId,
      category: LastSeenCategory.grade,
    );
  }

  Future<void> _absenceNotifications({
    required DatabaseProvider database,
    required SettingsProvider settings,
    required UserProvider userProvider,
    required KretaClient kreta,
  }) async {
    final userId = userProvider.id;
    if (userId == null || userProvider.user == null) return;

    final absencesJson =
        await kreta.getAPI(KretaAPI.absences(userProvider.user!.instituteCode));
    if (absencesJson is! List) return;

    final primed = await _lastSeenOrPrime(
      database: database,
      userId: userId,
      category: LastSeenCategory.absence,
    );
    if (primed == null) return;
    final absences = absencesJson.map((e) => Absence.fromJson(e)).toList();

    for (final absence in absences) {
      if (!absence.date.isAfter(primed)) continue;

      final title = settings.language == 'hu'
          ? 'Új hiányzás'
          : (settings.language == 'de'
              ? 'Abwesenheit aufgezeichnet'
              : 'Absence recorded');
      final subject = _subjectName(absence.subject, settings);
      final dateText = DateFormat('yyyy-MM-dd').format(absence.date);
      final baseBody = settings.language == 'hu'
          ? '$dateText napon $subject tantárgyból'
          : 'on $dateText for $subject';

      await _plugin.show(
        absence.id.hashCode,
        title,
        userProvider.getUsers().length == 1
            ? baseBody
            : '(${userProvider.displayName ?? userProvider.name ?? ''}) $baseBody',
        _details(settings, 'Absence notifications'),
        payload: 'absences',
      );
    }

    await database.userStore.storeLastSeen(
      DateTime.now(),
      userId: userId,
      category: LastSeenCategory.absence,
    );
  }

  Future<void> _messageNotifications({
    required DatabaseProvider database,
    required SettingsProvider settings,
    required UserProvider userProvider,
    required KretaClient kreta,
  }) async {
    final userId = userProvider.id;
    if (userId == null) return;

    final messagesJson = await kreta.getAPI(KretaAPI.messages('beerkezett'));
    if (messagesJson is! List) return;

    final primed = await _lastSeenOrPrime(
      database: database,
      userId: userId,
      category: LastSeenCategory.message,
    );
    if (primed == null) return;

    final messages = <Message>[];
    for (final item in messagesJson.cast<Map>()) {
      final messageId = item['azonosito']?.toString();
      if (messageId == null || messageId.isEmpty) continue;
      final fullMessage = await kreta.getAPI(KretaAPI.message(messageId));
      if (fullMessage is Map) {
        messages
            .add(Message.fromJson(fullMessage, forceType: MessageType.inbox));
      }
    }

    for (final message in messages) {
      if (!message.date.isAfter(primed)) continue;

      final body = message.content.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      final title = userProvider.getUsers().length == 1
          ? message.author
          : '(${userProvider.displayName ?? userProvider.name ?? ''}) ${message.author}';

      await _plugin.show(
        message.id,
        title,
        body,
        _details(settings, 'Message notifications'),
        payload: 'messages',
      );
    }

    await database.userStore.storeLastSeen(
      DateTime.now(),
      userId: userId,
      category: LastSeenCategory.message,
    );
  }

  Future<void> _lessonNotifications({
    required DatabaseProvider database,
    required SettingsProvider settings,
    required UserProvider userProvider,
    required KretaClient kreta,
  }) async {
    final userId = userProvider.id;
    if (userId == null) return;

    final previousLessonsByWeek =
        await database.userQuery.getLessons(userId: userId);
    final previousLessons = previousLessonsByWeek[Week.current()] ?? <Lesson>[];
    final previousById = {
      for (final lesson in previousLessons) lesson.id: lesson,
    };

    final timetableProvider = TimetableProvider(
      user: userProvider,
      database: database,
      kreta: kreta,
    );
    await timetableProvider.restoreUser();
    await timetableProvider.fetch(week: Week.current());
    final lessons = timetableProvider.getWeek(Week.current()) ?? <Lesson>[];

    final primed = await _lastSeenOrPrime(
      database: database,
      userId: userId,
      category: LastSeenCategory.lesson,
    );
    if (primed == null) return;

    Lesson? latestChangedLesson;

    for (final lesson in lessons) {
      final isCanceled = lesson.status?.name == 'Elmaradt';
      final isChanged = _isLessonChanged(lesson);

      final previousLesson = previousById[lesson.id];
      final wasChanged =
          previousLesson != null && _isLessonChanged(previousLesson);
      final isNewChange = !wasChanged ||
          _lessonChangeFingerprint(previousLesson) !=
              _lessonChangeFingerprint(lesson);

      if (!isChanged || !isNewChange || !lesson.start.isAfter(primed)) continue;

      if (latestChangedLesson == null ||
          lesson.start.isAfter(latestChangedLesson.start)) {
        latestChangedLesson = lesson;
      }

      final title = settings.language == 'hu'
          ? 'Órarend szerkesztve'
          : (settings.language == 'de'
              ? 'Fahrplan geändert'
              : 'Timetable modified');

      final day = _dayName(lesson.date, settings.language);
      final subject = lesson.name;

      String body;
      if (isCanceled) {
        body = settings.language == 'hu'
            ? '$day: ${lesson.lessonIndex}. óra ($subject) elmarad'
            : 'Lesson #${lesson.lessonIndex} ($subject) has been canceled on $day';
      } else {
        final teacherName = _teacherName(lesson.substituteTeacher!, settings);
        body = settings.language == 'hu'
            ? '$day: ${lesson.lessonIndex}. óra ($subject), helyettesítő: $teacherName'
            : 'Lesson #${lesson.lessonIndex} ($subject) on $day will be substituted by $teacherName';
      }

      if (userProvider.getUsers().length > 1) {
        body = '(${userProvider.displayName ?? userProvider.name ?? ''}) $body';
      }

      await _plugin.show(
        lesson.id.hashCode,
        title,
        body,
        _details(settings, 'Timetable notifications'),
        payload: 'timetable',
      );
    }

    await database.userStore.storeLastSeen(
      latestChangedLesson?.start ?? DateTime.now(),
      userId: userId,
      category: LastSeenCategory.lesson,
    );
  }

  Future<void> _examNotifications({
    required DatabaseProvider database,
    required SettingsProvider settings,
    required UserProvider userProvider,
    required KretaClient kreta,
  }) async {
    final userId = userProvider.id;
    if (userId == null || userProvider.user == null) return;

    final examsJson =
        await kreta.getAPI(KretaAPI.exams(userProvider.user!.instituteCode));
    if (examsJson is! List) return;

    final primed = await _lastSeenOrPrime(
      database: database,
      userId: userId,
      category: LastSeenCategory.exam,
    );
    if (primed == null) return;
    final exams = examsJson.map((e) => Exam.fromJson(e)).toList();

    for (final exam in exams) {
      final announceDate = exam.date;
      if (!announceDate.isAfter(primed)) continue;

      final title = settings.language == 'hu'
          ? 'Új dolgozat'
          : (settings.language == 'de' ? 'Neue Prüfung' : 'New exam');
      final subject = _subjectName(exam.subject, settings);
      final examDay = DateFormat('yyyy-MM-dd').format(exam.writeDate);
      var body = settings.language == 'hu'
          ? '$subject • $examDay'
          : '$subject • $examDay';

      if (userProvider.getUsers().length > 1) {
        body = '(${userProvider.displayName ?? userProvider.name ?? ''}) $body';
      }

      await _plugin.show(
        exam.id.hashCode,
        title,
        body,
        _details(settings, 'Exam notifications'),
        payload: 'timetable',
      );
    }

    await database.userStore.storeLastSeen(
      DateTime.now(),
      userId: userId,
      category: LastSeenCategory.exam,
    );
  }

  Future<void> setAllCategoriesSeen(UserProvider userProvider) async {
    final database = DatabaseProvider();
    await database.init();

    final now = DateTime.now();
    for (final user in userProvider.getUsers()) {
      for (final category in LastSeenCategory.values) {
        await database.userStore.storeLastSeen(
          now,
          userId: user.id,
          category: category,
        );
      }
    }
  }

  Future<void> setCategorySeenForAllUsers(
    UserProvider userProvider,
    LastSeenCategory category, {
    DateTime? at,
  }) async {
    final database = DatabaseProvider();
    await database.init();

    final now = at ?? DateTime.now();
    for (final user in userProvider.getUsers()) {
      await database.userStore.storeLastSeen(
        now,
        userId: user.id,
        category: category,
      );
    }
  }

  void onDidReceiveNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    switch (payload) {
      case 'timetable':
      case 'grades':
      case 'messages':
      case 'absences':
      case 'settings':
        locator<NavigationService>().navigateTo(payload);
        break;
      default:
        break;
    }
  }
}
