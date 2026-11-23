import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { Constants } from '../common/Constants';
import { PrefsHelper } from '../common/PrefsHelper';
import { RouteHelper } from '../common/RouteHelper';
import { GrowthTask } from '../model/Entity';
import { TaskCategory } from '../model/Enums';
import { growthRepo, jobRepo } from '../repository/Repositories';
import { GrowthService } from '../service/GrowthService';
import { EmptyState } from '../view/EmptyState';

@Entry
@Component
struct GrowthGuidePage {
  @State studentId: number = 1;
  @State majorDirection: string = '软件开发';
  @State stage: string = '大一上';
  @State tasks: GrowthTask[] = [];
  @State newTask: string = '';
  @State jobDirections: string[] = [];
  @State advanceDays: number = 1;
  readonly advanceOptions: number[] = [0, 1, 3, 7];
  private service: GrowthService = new GrowthService();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    const params: Record<string, Object> = RouteHelper.params();
    if (params['studentId'] !== undefined) {
      this.studentId = Number(params['studentId']);
    }
    if (params['majorDirection'] !== undefined) {
      this.majorDirection = String(params['majorDirection']);
    }
    this.loadAdvanceDays();
    this.loadJobDirections();
    this.load();
  }

  private loadAdvanceDays(): void {
    PrefsHelper.getString(Constants.KEY_REMIND_ADVANCE, '1').then((text: string) => {
      const parsed: number = Number(text);
      this.advanceDays = Number.isNaN(parsed) ? 1 : parsed;
    });
  }

  private loadJobDirections(): void {
    jobRepo.listDirections().then((directions: string[]) => {
      this.jobDirections = directions;
    }).catch(() => {
      this.jobDirections = [];
    });
  }

  private load(): void {
    this.service.ensureTasks(this.context, this.studentId, this.majorDirection, this.stage).then(() => {
      return this.service.listTasks(this.studentId);
    }).then((tasks: GrowthTask[]) => {
      this.tasks = tasks.filter((task: GrowthTask) => task.academicStage === this.stage);
    }).catch((error: Error) => {
      promptAction.showToast({ message: '加载失败：' + error.message });
    });
  }

  private applyPlanning(): void {
    const direction: string = this.majorDirection.trim();
    const stage: string = this.stage.trim();
    if (direction.length === 0 || stage.length === 0) {
      promptAction.showToast({ message: '请填写专业方向和学年阶段' });
      return;
    }
    this.majorDirection = direction;
    this.stage = stage;
    this.load();
  }

  private completedCount(): number {
    return this.tasks.filter((task: GrowthTask) => task.status === 1).length;
  }

  private isOverdue(task: GrowthTask): boolean {
    return task.status === 0 && task.dueDate > 0 && task.dueDate < Date.now();
  }

  private overdueTasks(): number {
    const now: number = Date.now();
    return this.tasks.filter((task: GrowthTask) =>
      task.status === 0 && task.dueDate > 0 && task.dueDate < now).length;
  }

  private completionRate(): number {
    if (this.tasks.length === 0) {
      return 0;
    }
    return Math.round(this.completedCount() * 100 / this.tasks.length);
  }

  private semesterInfo(): string {
    const now: Date = new Date();
    const year: number = now.getFullYear();
    const month: number = now.getMonth();
    let start: Date;
    let end: Date;
    let label: string;
    if (month >= 8) {
      start = new Date(year, 8, 1);
      end = new Date(year + 1, 0, 15);
      label = '秋季学期';
    } else if (month === 0) {
      start = new Date(year - 1, 8, 1);
      end = new Date(year, 0, 15);
      label = '秋季学期';
    } else if (month >= 1 && month <= 6) {
      start = new Date(year, 1, 15);
      end = new Date(year, 6, 15);
      label = '春季学期';
    } else {
      return '暑假阶段 · 适合集中实践与竞赛准备';
    }
    const total: number = end.getTime() - start.getTime();
    const passed: number = now.getTime() - start.getTime();
    const percent: number = Math.max(0, Math.min(100, Math.round(passed * 100 / total)));
    const daysLeft: number = Math.max(0, Math.ceil((end.getTime() - now.getTime()) / (24 * 3600 * 1000)));
    return `${label}已进行 ${percent}% · 剩余 ${daysLeft} 天`;
  }

  private weekSummary(): string {
    const now: Date = new Date();
    const day: number = now.getDay() === 0 ? 7 : now.getDay();
    const weekStart: number = new Date(now.getFullYear(), now.getMonth(), now.getDate() - day + 1).getTime();
    const weekEnd: number = weekStart + 7 * 24 * 3600 * 1000;
    const dueThisWeek: GrowthTask[] = this.tasks.filter((task: GrowthTask) =>
      task.dueDate >= weekStart && task.dueDate < weekEnd);
    const doneThisWeek: number = dueThisWeek.filter((task: GrowthTask) => task.status === 1).length;
    if (dueThisWeek.length === 0) {
      return '本周暂无到期任务 · 可提前准备下一阶段的竞赛或证书';
    }
    const tip: string = this.overdueTasks() > 0 ? ' · 有逾期任务需优先处理' : '';
    return `本周到期 ${dueThisWeek.length} 项 · 已完成 ${doneThisWeek} 项${tip}`;
  }

  private advanceLabel(days: number): string {
    return days === 0 ? '当天' : `提前${days}天`;
  }

  private setAdvanceDays(days: number): void {
    this.advanceDays = days;
    PrefsHelper.put(Constants.KEY_REMIND_ADVANCE, String(days));
  }

  private reminderTime(task: GrowthTask): number {
    const target: number = task.dueDate > 0 ? task.dueDate : Date.now() + 3600 * 1000;
    const planned: number = target - this.advanceDays * 24 * 3600 * 1000;
    return planned > Date.now() ? planned : Date.now() + 3600 * 1000;
  }

  // 逾期任务的一次性"再提醒"，1 分钟后弹出，不改变任务本身的提醒开关
  private remindOverdue(task: GrowthTask): void {
    const updated: GrowthTask = {
      id: task.id,
      studentId: task.studentId,
      majorDirection: task.majorDirection,
      academicStage: task.academicStage,
      taskTitle: task.taskTitle,
      taskDesc: task.taskDesc,
      category: task.category,
      dueDate: task.dueDate,
      status: task.status,
      remindEnabled: true,
      remindTime: Date.now() + 60 * 1000,
      reminderId: 0
    };
    this.service.cancelReminder(task.reminderId !== undefined ? task.reminderId : 0).then(() => {
      return this.service.scheduleReminder(updated, this.context);
    }).then((reminderId: number) => {
      return this.service.setReminder(task, true, updated.remindTime, reminderId);
    }).then(() => {
      promptAction.showToast({ message: '将于 1 分钟后再次提醒该任务' });
      this.load();
    }).catch((error: Error) => {
      promptAction.showToast({ message: '提醒失败：' + error.message });
    });
  }

  private categoryText(category: TaskCategory): string {
    if (category === TaskCategory.COMPETITION) {
      return '竞赛';
    } else if (category === TaskCategory.CERT) {
      return '证书';
    } else if (category === TaskCategory.PROJECT) {
      return '项目';
    }
    return '课程';
  }

  private addTask(): void {
    if (this.newTask.trim().length === 0) {
      promptAction.showToast({ message: '请输入任务标题' });
      return;
    }
    const task: GrowthTask = {
      id: 0,
      studentId: this.studentId,
      majorDirection: this.majorDirection,
      academicStage: this.stage,
      taskTitle: this.newTask.trim(),
      taskDesc: '自定义补充任务',
      category: TaskCategory.PROJECT,
      dueDate: Date.now() + 30 * 24 * 60 * 60 * 1000,
      status: 0,
      remindEnabled: false,
      remindTime: 0
    };
    growthRepo.insert(task).then(() => {
      this.newTask = '';
      this.load();
    });
  }

  private toggleReminder(task: GrowthTask): void {
    const enabled: boolean = !task.remindEnabled;
    const remindTime: number = this.reminderTime(task);
    const oldReminderId: number = task.reminderId !== undefined ? task.reminderId : 0;
    this.service.cancelReminder(oldReminderId).then(() => {
      if (enabled) {
        const updated: GrowthTask = {
          id: task.id,
          studentId: task.studentId,
          majorDirection: task.majorDirection,
          academicStage: task.academicStage,
          taskTitle: task.taskTitle,
          taskDesc: task.taskDesc,
          category: task.category,
          dueDate: task.dueDate,
          status: task.status,
          remindEnabled: true,
          remindTime: remindTime,
          reminderId: 0
        };
        return this.service.scheduleReminder(updated, this.context);
      }
      return Promise.resolve(0);
    }).then((newReminderId: number) => {
      return this.service.setReminder(task, enabled, enabled ? remindTime : 0, newReminderId);
    }).then(() => {
      promptAction.showToast({ message: enabled ? '提醒已设置' : '提醒已取消' });
      this.load();
    }).catch((error: Error) => {
      promptAction.showToast({ message: '提醒设置失败：' + error.message });
    });
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 6 }) {
          Text('成长指引').fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          Text('按学年阶段，一步步完成该做的事')
            .fontSize(12).fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Image($r('app.media.hero_growth'))
          .width(64)
          .height(64)
          .borderRadius(16)
          .objectFit(ImageFit.Cover)
          .border({ width: 2, color: '#B3FFFFFF' })
          .shadow({ radius: 12, color: '#330E5C5C', offsetX: 0, offsetY: 5 })
          .rotate({ angle: -5 })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 14 })
      .borderRadius(20)
      .linearGradient({ angle: 140, colors: [['#FFFFFF', 0], [$r('app.color.brand_soft'), 1]] })
      .border({ width: 1, color: '#80FFFFFF' })
      .shadow({ radius: 16, color: '#1A0E5C5C', offsetX: 0, offsetY: 6 })

      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text(`${this.completionRate()}%`).fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.brand_primary'))
          Text('阶段完成率').fontSize(10).fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1).padding(10).borderRadius(14)
        .linearGradient({ angle: 145, colors: [['#FFFFFF', 0], ['#F1FAF9', 1]] })
        .border({ width: 1, color: '#80FFFFFF' })
        .shadow({ radius: 10, color: '#1A0E5C5C', offsetX: 0, offsetY: 4 })
        Column({ space: 3 }) {
          Text(`${this.overdueTasks()}`).fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(this.overdueTasks() > 0 ? $r('app.color.danger') : $r('app.color.success'))
          Text('逾期任务').fontSize(10).fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1).padding(10).borderRadius(14)
        .linearGradient({ angle: 145, colors: [['#FFFFFF', 0], ['#F1FAF9', 1]] })
        .border({ width: 1, color: '#80FFFFFF' })
        .shadow({ radius: 10, color: '#1A0E5C5C', offsetX: 0, offsetY: 4 })
        Column({ space: 3 }) {
          Text(`${this.completedCount()}/${this.tasks.length}`).fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('已完成任务').fontSize(10).fontColor($r('app.color.text_secondary'))
        }
        .layoutWeight(1).padding(10).borderRadius(14)
        .linearGradient({ angle: 145, colors: [['#FFFFFF', 0], ['#F1FAF9', 1]] })
        .border({ width: 1, color: '#80FFFFFF' })
        .shadow({ radius: 10, color: '#1A0E5C5C', offsetX: 0, offsetY: 4 })
      }
      .width('100%')

      Text(this.semesterInfo()).fontSize(11).fontColor($r('app.color.text_secondary'))
        .width('100%').padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .borderRadius(14).backgroundColor($r('app.color.chip_background'))

      Text(this.weekSummary()).fontSize(11).fontColor($r('app.color.text_label'))
        .width('100%').padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .borderRadius(14).backgroundColor($r('app.color.card_background'))

      Row({ space: 6 }) {
        Text('提前提醒').fontSize(11).fontColor($r('app.color.text_secondary'))
        ForEach(this.advanceOptions, (days: number) => {
          Text(this.advanceLabel(days)).fontSize(11)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(12)
            .backgroundColor(this.advanceDays === days ? $r('app.color.brand_primary') : $r('app.color.chip_background'))
            .fontColor(this.advanceDays === days ? $r('app.color.on_primary') : $r('app.color.text_label'))
            .onClick(() => this.setAdvanceDays(days))
        }, (days: number) => String(days))
      }
      .width('100%').padding({ left: 4, right: 4 })

      Column({ space: 10 }) {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text('专业方向').fontSize(12).fontColor($r('app.color.text_secondary'))
            TextInput({ placeholder: '如：软件开发', text: this.majorDirection })
              .height(40)
              .fontSize(14)
              .borderRadius(12)
              .backgroundColor($r('app.color.surface_muted'))
              .onChange((value: string) => { this.majorDirection = value; })
              .onSubmit(() => this.applyPlanning())
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Column({ space: 4 }) {
            Text('学年阶段').fontSize(12).fontColor($r('app.color.text_secondary'))
            TextInput({ placeholder: '如：大三上', text: this.stage })
              .height(40)
              .fontSize(14)
              .borderRadius(12)
              .backgroundColor($r('app.color.surface_muted'))
              .onChange((value: string) => { this.stage = value; })
              .onSubmit(() => this.applyPlanning())
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        Column({ space: 6 }) {
          Text('企业岗位方向').fontSize(11).fontColor($r('app.color.text_secondary'))
            .width('100%')
          if (this.jobDirections.length === 0) {
            Text('暂无在招岗位方向，可直接手动输入').fontSize(11)
              .fontColor($r('app.color.text_tertiary'))
          } else {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.jobDirections, (direction: string) => {
                Text(direction).fontSize(11)
                  .fontColor(this.majorDirection === direction ?
                    $r('app.color.on_primary') : $r('app.color.text_label'))
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .margin({ right: 6, bottom: 6 })
                  .borderRadius(14)
                  .backgroundColor(this.majorDirection === direction ?
                    $r('app.color.brand_primary') : $r('app.color.chip_background'))
                  .onClick(() => {
                    this.majorDirection = direction;
                    this.applyPlanning();
                  })
              }, (direction: string) => direction)
            }
            .width('100%')
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        Button('生成规划')
          .width('100%')
          .height(38)
          .fontSize(13)
          .borderRadius(19)
          .backgroundColor($r('app.color.brand_primary'))
          .fontColor($r('app.color.on_primary'))
          .onClick(() => this.applyPlanning())
      }
      .width('100%')
      .padding(14)
      .borderRadius(18)
      .backgroundColor($r('app.color.card_background'))
      .shadow({ radius: 10, color: $r('app.color.shadow'), offsetX: 0, offsetY: 3 })

      Row({ space: 8 }) {
        TextInput({ placeholder: '补充自定义任务', text: this.newTask })
          .layoutWeight(1)
          .borderRadius(18)
          .onChange((value: string) => { this.newTask = value; })
        Button('添加').borderRadius(18).backgroundColor($r('app.color.brand_primary'))
          .fontColor($r('app.color.on_primary')).onClick(() => this.addTask())
      }
      .width('100%')

      if (this.tasks.length === 0) {
        EmptyState({ text: '当前阶段暂无任务，可先添加自定义任务' })
      } else {
        List({ space: 10 }) {
          ForEach(this.tasks, (task: GrowthTask) => {
            ListItem() {
              Row({ space: 10 }) {
                Checkbox({ name: task.taskTitle, group: 'growth' })
                  .select(task.status === 1)
                  .onChange((value: boolean) => {
                    task.status = value ? 1 : 0;
                    this.service.toggleTask(task).then(() => this.load());
                  })
                Column({ space: 4 }) {
                  Text(task.taskTitle).fontSize(15).fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Text(`${this.categoryText(task.category)} · ${new Date(task.dueDate).toDateString()}`)
                    .fontSize(12).fontColor($r('app.color.text_secondary'))
                  Text(task.taskDesc).fontSize(12).fontColor($r('app.color.text_tertiary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Column({ space: 6 }) {
                  Button(task.remindEnabled ? '取消提醒' : '提醒')
                    .fontSize(12)
                    .borderRadius(16)
                    .backgroundColor(task.remindEnabled ? $r('app.color.accent_peach_soft') : $r('app.color.brand_primary'))
                    .fontColor(task.remindEnabled ? $r('app.color.text_primary') : $r('app.color.on_primary'))
                    .onClick(() => this.toggleReminder(task))
                  if (this.isOverdue(task)) {
                    Button('再提醒')
                      .fontSize(11).height(26).borderRadius(13)
                      .backgroundColor($r('app.color.accent_peach_soft'))
                      .fontColor($r('app.color.danger'))
                      .onClick(() => this.remindOverdue(task))
                  }
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              .padding(14)
              .borderRadius(18)
              .backgroundColor($r('app.color.card_background'))
              .shadow({ radius: 10, color: $r('app.color.shadow'), offsetX: 0, offsetY: 3 })
            }
          }, (task: GrowthTask) => String(task.id))
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding(18)
    .linearGradient({ angle: 165, colors: [[$r('app.color.app_background'), 0], [$r('app.color.app_background_end'), 1]] })
  }
}
