import { common } from '@kit.AbilityKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { GrowthTask } from '../model/Entity';
import { Logger } from '../common/Logger';

export class ReminderService {
  async ensurePermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (enabled) {
        return true;
      }
      await notificationManager.requestEnableNotification(context);
      return await notificationManager.isNotificationEnabled();
    } catch (error) {
      Logger.info('Notification permission denied: ' + (error as Error).message);
      return false;
    }
  }

  async schedule(task: GrowthTask): Promise<number> {
    const date: Date = new Date(task.remindTime);
    const request: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: date.getFullYear(),
        month: date.getMonth() + 1,
        day: date.getDate(),
        hour: date.getHours(),
        minute: date.getMinutes(),
        second: date.getSeconds()
      },
      title: '成长任务提醒',
      content: task.taskTitle,
      expiredContent: task.taskTitle + '（已过期）',
      ringDuration: 1
    };
    const id: number = await reminderAgentManager.publishReminder(request);
    Logger.info('Reminder scheduled: ' + id);
    return id;
  }

  async cancel(reminderId: number): Promise<void> {
    await reminderAgentManager.cancelReminder(reminderId);
    Logger.info('Reminder cancelled: ' + reminderId);
  }
}
