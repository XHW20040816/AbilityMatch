import { common } from '@kit.AbilityKit';
import { ResourceHelper } from '../common/ResourceHelper';
import { GrowthTask } from '../model/Entity';
import { TaskCategory } from '../model/Enums';
import { growthRepo } from '../repository/Repositories';
import { ReminderService } from './ReminderService';

export class GrowthService {
  private reminderService: ReminderService = new ReminderService();

  async ensureTasks(context: common.UIAbilityContext, studentId: number,
                    direction: string, stage: string): Promise<void> {
    const existing: number = await growthRepo.countByDirectionStage(studentId, direction, stage);
    if (existing > 0) {
      return;
    }
    const lib = await ResourceHelper.loadGrowthTemplates(context);
    let created: number = 0;
    for (const template of lib.templates) {
      if (template.direction !== direction || template.stage !== stage) {
        continue;
      }
      for (const item of template.tasks) {
        const task: GrowthTask = {
          id: 0,
          studentId: studentId,
          majorDirection: direction,
          academicStage: stage,
          taskTitle: item.title,
          taskDesc: item.desc,
          category: item.category as TaskCategory,
          dueDate: Date.now() + item.offsetDays * 24 * 60 * 60 * 1000,
          status: 0,
          remindEnabled: false,
          remindTime: 0
        };
        await growthRepo.insert(task);
        created++;
      }
    }
    if (created === 0) {
      await this.insertDefaultTasks(studentId, direction, stage);
    }
  }

  private async insertDefaultTasks(studentId: number, direction: string, stage: string): Promise<void> {
    const defaults: GrowthTask[] = [
      {
        id: 0,
        studentId: studentId,
        majorDirection: direction,
        academicStage: stage,
        taskTitle: `${direction}方向学习路线`,
        taskDesc: `梳理${stage}阶段${direction}方向的核心课程与学习资源，形成阶段学习计划`,
        category: TaskCategory.COURSE,
        dueDate: Date.now() + 30 * 24 * 60 * 60 * 1000,
        status: 0,
        remindEnabled: false,
        remindTime: 0
      },
      {
        id: 0,
        studentId: studentId,
        majorDirection: direction,
        academicStage: stage,
        taskTitle: `${direction}实践任务`,
        taskDesc: `围绕${stage}阶段完成一个${direction}方向的小型项目或练习，沉淀可展示成果`,
        category: TaskCategory.PROJECT,
        dueDate: Date.now() + 60 * 24 * 60 * 60 * 1000,
        status: 0,
        remindEnabled: false,
        remindTime: 0
      }
    ];
    for (const task of defaults) {
      await growthRepo.insert(task);
    }
  }

  async listTasks(studentId: number): Promise<GrowthTask[]> {
    return await growthRepo.listByStudent(studentId);
  }

  async toggleTask(task: GrowthTask): Promise<void> {
    await growthRepo.updateStatus(task.id, task.status === 1 ? 0 : 1);
  }

  async setReminder(task: GrowthTask, enabled: boolean, remindTime: number, reminderId: number): Promise<void> {
    await growthRepo.setReminder(task.id, enabled, remindTime, reminderId);
  }

  async scheduleReminder(task: GrowthTask, context: common.UIAbilityContext): Promise<number> {
    const allowed: boolean = await this.reminderService.ensurePermission(context);
    if (!allowed) {
      throw new Error('通知权限未开启，任务已保留但不会弹出提醒');
    }
    return await this.reminderService.schedule(task);
  }

  async cancelReminder(reminderId: number): Promise<void> {
    if (reminderId > 0) {
      await this.reminderService.cancel(reminderId);
    }
  }
}
