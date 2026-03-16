import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:provider/provider.dart';
import 'package:refilc/api/providers/user_provider.dart';
import 'package:refilc/helpers/notification_helper.dart';
import 'package:refilc/models/settings.dart';
import 'package:refilc/theme/colors/colors.dart';
import 'package:refilc_mobile_ui/common/panel/panel_button.dart';
import 'package:refilc_mobile_ui/common/splitted_panel/splitted_panel.dart';

import 'notifications_screen.i18n.dart';

class MenuNotifications extends StatelessWidget {
  const MenuNotifications({
    super.key,
    this.borderRadius = const BorderRadius.vertical(
      top: Radius.circular(4.0),
      bottom: Radius.circular(4.0),
    ),
  });

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return PanelButton(
      onPressed: () => Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(builder: (context) => const NotificationsScreen()),
      ),
      title: Text('notifications_screen'.i18n),
      leading: Icon(
        FeatherIcons.bell,
        size: 22.0,
        color: AppColors.of(context).text.withValues(alpha: 0.95),
      ),
      trailing: Icon(
        FeatherIcons.chevronRight,
        size: 22.0,
        color: AppColors.of(context).text.withValues(alpha: 0.95),
      ),
      borderRadius: borderRadius,
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _setEnabled(
    BuildContext context, {
    required LastSeenCategory category,
    required bool oldValue,
    required bool newValue,
    required Future<void> Function() update,
  }) async {
    await update();

    if (!oldValue && newValue) {
      await NotificationsHelper().setCategorySeenForAllUsers(
        Provider.of<UserProvider>(context, listen: false),
        category,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
        leading: BackButton(color: AppColors.of(context).text),
        title: Text(
          'notifications_screen'.i18n,
          style: TextStyle(color: AppColors.of(context).text),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          child: Column(
            children: [
              SplittedPanel(
                padding: const EdgeInsets.only(top: 8.0),
                cardPadding: const EdgeInsets.all(4.0),
                isSeparated: true,
                children: [
                  PanelButton(
                    padding: const EdgeInsets.only(left: 14.0, right: 6.0),
                    onPressed: () async {
                      final wasEnabled = settings.notificationsEnabled;
                      await settings.update(
                        notificationsEnabled: !settings.notificationsEnabled,
                      );

                      if (!wasEnabled && settings.notificationsEnabled) {
                        await NotificationsHelper().setAllCategoriesSeen(
                          Provider.of<UserProvider>(context, listen: false),
                        );
                      }
                    },
                    title: Text(
                      'notifications_screen'.i18n,
                      style: TextStyle(
                        color: AppColors.of(context).text.withValues(
                            alpha: settings.notificationsEnabled ? .95 : .25),
                      ),
                    ),
                    leading: Icon(
                      FeatherIcons.bell,
                      size: 22.0,
                      color: AppColors.of(context).text.withValues(
                          alpha: settings.notificationsEnabled ? .95 : .25),
                    ),
                    trailing: Switch(
                      onChanged: (value) async {
                        final wasEnabled = settings.notificationsEnabled;
                        await settings.update(notificationsEnabled: value);
                        if (!wasEnabled && value) {
                          await NotificationsHelper().setAllCategoriesSeen(
                            Provider.of<UserProvider>(context, listen: false),
                          );
                        }
                      },
                      value: settings.notificationsEnabled,
                      activeColor: Theme.of(context).colorScheme.secondary,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12.0),
                      bottom: Radius.circular(12.0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SplittedPanel(
                padding: const EdgeInsets.only(top: 8.0),
                cardPadding: const EdgeInsets.all(4.0),
                isSeparated: true,
                children: [
                  PanelButton(
                    padding: const EdgeInsets.only(left: 14.0, right: 6.0),
                    onPressed: () async {
                      final oldValue = settings.notificationsGradesEnabled;
                      final newValue = !oldValue;
                      await _setEnabled(
                        context,
                        category: LastSeenCategory.grade,
                        oldValue: oldValue,
                        newValue: newValue,
                        update: () => settings.update(
                          notificationsGradesEnabled: newValue,
                        ),
                      );
                    },
                    title: Text(
                      'grades'.i18n,
                      style: TextStyle(
                        color: AppColors.of(context).text.withValues(
                            alpha:
                                settings.notificationsGradesEnabled ? .95 : .25),
                      ),
                    ),
                    leading: Icon(
                      FeatherIcons.bookmark,
                      size: 22.0,
                      color: AppColors.of(context).text.withValues(
                          alpha:
                              settings.notificationsGradesEnabled ? .95 : .25),
                    ),
                    trailing: Switch(
                      onChanged: (value) async {
                        await _setEnabled(
                          context,
                          category: LastSeenCategory.grade,
                          oldValue: settings.notificationsGradesEnabled,
                          newValue: value,
                          update: () => settings.update(
                            notificationsGradesEnabled: value,
                          ),
                        );
                      },
                      value: settings.notificationsGradesEnabled,
                      activeColor: Theme.of(context).colorScheme.secondary,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12.0),
                      bottom: Radius.circular(12.0),
                    ),
                  ),
                ],
              ),
              SplittedPanel(
                padding: const EdgeInsets.only(top: 8.0),
                cardPadding: const EdgeInsets.all(4.0),
                isSeparated: true,
                children: [
                  PanelButton(
                    padding: const EdgeInsets.only(left: 14.0, right: 6.0),
                    onPressed: () async {
                      final oldValue = settings.notificationsAbsencesEnabled;
                      final newValue = !oldValue;
                      await _setEnabled(
                        context,
                        category: LastSeenCategory.absence,
                        oldValue: oldValue,
                        newValue: newValue,
                        update: () => settings.update(
                          notificationsAbsencesEnabled: newValue,
                        ),
                      );
                    },
                    title: Text(
                      'absences'.i18n,
                      style: TextStyle(
                        color: AppColors.of(context).text.withValues(
                            alpha: settings.notificationsAbsencesEnabled
                                ? .95
                                : .25),
                      ),
                    ),
                    leading: Icon(
                      FeatherIcons.clock,
                      size: 22.0,
                      color: AppColors.of(context).text.withValues(
                          alpha:
                              settings.notificationsAbsencesEnabled ? .95 : .25),
                    ),
                    trailing: Switch(
                      onChanged: (value) async {
                        await _setEnabled(
                          context,
                          category: LastSeenCategory.absence,
                          oldValue: settings.notificationsAbsencesEnabled,
                          newValue: value,
                          update: () => settings.update(
                            notificationsAbsencesEnabled: value,
                          ),
                        );
                      },
                      value: settings.notificationsAbsencesEnabled,
                      activeColor: Theme.of(context).colorScheme.secondary,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12.0),
                      bottom: Radius.circular(12.0),
                    ),
                  ),
                ],
              ),
              SplittedPanel(
                padding: const EdgeInsets.only(top: 8.0),
                cardPadding: const EdgeInsets.all(4.0),
                isSeparated: true,
                children: [
                  PanelButton(
                    padding: const EdgeInsets.only(left: 14.0, right: 6.0),
                    onPressed: () async {
                      final oldValue = settings.notificationsMessagesEnabled;
                      final newValue = !oldValue;
                      await _setEnabled(
                        context,
                        category: LastSeenCategory.message,
                        oldValue: oldValue,
                        newValue: newValue,
                        update: () => settings.update(
                          notificationsMessagesEnabled: newValue,
                        ),
                      );
                    },
                    title: Text(
                      'messages'.i18n,
                      style: TextStyle(
                        color: AppColors.of(context).text.withValues(
                            alpha: settings.notificationsMessagesEnabled
                                ? .95
                                : .25),
                      ),
                    ),
                    leading: Icon(
                      FeatherIcons.messageSquare,
                      size: 22.0,
                      color: AppColors.of(context).text.withValues(
                          alpha:
                              settings.notificationsMessagesEnabled ? .95 : .25),
                    ),
                    trailing: Switch(
                      onChanged: (value) async {
                        await _setEnabled(
                          context,
                          category: LastSeenCategory.message,
                          oldValue: settings.notificationsMessagesEnabled,
                          newValue: value,
                          update: () => settings.update(
                            notificationsMessagesEnabled: value,
                          ),
                        );
                      },
                      value: settings.notificationsMessagesEnabled,
                      activeColor: Theme.of(context).colorScheme.secondary,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12.0),
                      bottom: Radius.circular(12.0),
                    ),
                  ),
                ],
              ),
              SplittedPanel(
                padding: const EdgeInsets.only(top: 8.0),
                cardPadding: const EdgeInsets.all(4.0),
                isSeparated: true,
                children: [
                  PanelButton(
                    padding: const EdgeInsets.only(left: 14.0, right: 6.0),
                    onPressed: () async {
                      final oldValue = settings.notificationsLessonsEnabled;
                      final newValue = !oldValue;
                      await _setEnabled(
                        context,
                        category: LastSeenCategory.lesson,
                        oldValue: oldValue,
                        newValue: newValue,
                        update: () => settings.update(
                          notificationsLessonsEnabled: newValue,
                        ),
                      );
                    },
                    title: Text(
                      'lessons'.i18n,
                      style: TextStyle(
                        color: AppColors.of(context).text.withValues(
                            alpha:
                                settings.notificationsLessonsEnabled ? .95 : .25),
                      ),
                    ),
                    leading: Icon(
                      FeatherIcons.calendar,
                      size: 22.0,
                      color: AppColors.of(context).text.withValues(
                          alpha:
                              settings.notificationsLessonsEnabled ? .95 : .25),
                    ),
                    trailing: Switch(
                      onChanged: (value) async {
                        await _setEnabled(
                          context,
                          category: LastSeenCategory.lesson,
                          oldValue: settings.notificationsLessonsEnabled,
                          newValue: value,
                          update: () => settings.update(
                            notificationsLessonsEnabled: value,
                          ),
                        );
                      },
                      value: settings.notificationsLessonsEnabled,
                      activeColor: Theme.of(context).colorScheme.secondary,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12.0),
                      bottom: Radius.circular(12.0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
