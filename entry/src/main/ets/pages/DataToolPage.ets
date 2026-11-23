import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { DbHelper } from '../common/DbHelper';
import { FileHelper, ImageStats } from '../common/FileHelper';
import { BackupService } from '../service/BackupService';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Entry
@Component
struct DataToolPage {
  @State busy: boolean = false;
  @State lastMessage: string = '';
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  private backup(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.lastMessage = '正在导出备份…';
    BackupService.exportSnapshot(this.context).then((saved: boolean) => {
      this.lastMessage = saved ? '备份已保存到你选择的目录' : '已取消导出';
      promptAction.showToast({ message: this.lastMessage });
    }).catch((error: Error) => {
      this.lastMessage = '备份失败：' + error.message;
      promptAction.showToast({ message: this.lastMessage });
    }).finally(() => {
      this.busy = false;
    });
  }

  private confirmRestore(): void {
    AlertDialog.show({
      title: '从备份恢复',
      message: '恢复会用备份文件覆盖当前全部数据（学生、岗位、证书、账号等），是否继续？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '继续恢复',
        fontColor: '#E86A67',
        action: () => { this.restore(); }
      }
    });
  }

  private restore(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.lastMessage = '正在读取备份文件…';
    BackupService.restoreSnapshot(this.context).then((count: number) => {
      if (count < 0) {
        this.lastMessage = '已取消恢复';
        promptAction.showToast({ message: this.lastMessage });
        return;
      }
      this.lastMessage = `已恢复 ${count} 条记录，请重新登录`;
      promptAction.showToast({ message: this.lastMessage });
      return AppViewModel.logout().then(() => {
        router.replaceUrl({ url: 'pages/AuthPage' });
      });
    }).catch((error: Error) => {
      this.lastMessage = '恢复失败：' + error.message;
      promptAction.showToast({ message: this.lastMessage });
    }).finally(() => {
      this.busy = false;
    });
  }

  private confirmReset(): void {
    AlertDialog.show({
      title: '重置演示数据',
      message: '将清空当前所有业务数据并写入初始演示数据，证书图片也会一并清理。此操作不可撤销，是否继续？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '确认重置',
        fontColor: '#E86A67',
        action: () => { this.reset(); }
      }
    });
  }

  private reset(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.lastMessage = '正在重置数据…';
    DbHelper.clearAllData().then(() => {
      return FileHelper.cleanupOrphans(this.context, []);
    }).then(() => {
      this.lastMessage = '已恢复为初始演示数据，请重新登录';
      promptAction.showToast({ message: this.lastMessage });
      return AppViewModel.logout();
    }).then(() => {
      router.replaceUrl({ url: 'pages/AuthPage' });
    }).catch((error: Error) => {
      this.lastMessage = '重置失败：' + error.message;
      promptAction.showToast({ message: this.lastMessage });
    }).finally(() => {
      this.busy = false;
    });
  }

  private seedStudents(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.lastMessage = '正在生成演示学生…';
    DbHelper.seedDemoStudents(20).then((created: number) => {
      this.lastMessage = created > 0 ? `已生成 ${created} 名演示学生` : '演示学生已存在，未重复生成';
      promptAction.showToast({ message: this.lastMessage });
    }).catch((error: Error) => {
      this.lastMessage = '生成失败：' + error.message;
      promptAction.showToast({ message: this.lastMessage });
    }).finally(() => {
      this.busy = false;
    });
  }

  private confirmClearThumbs(): void {
    const stats: ImageStats = FileHelper.imageStats(this.context);
    AlertDialog.show({
      title: '清理缩略图缓存',
      message: `当前图片 ${stats.fileCount} 个，占用 ${(stats.totalBytes / 1024 / 1024).toFixed(1)} MB，` +
        `其中缩略图 ${stats.thumbCount} 个。清理缩略图不影响原图，是否继续？`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '清理',
        fontColor: '#E86A67',
        action: () => {
          const removed: number = FileHelper.clearThumbnails(this.context);
          this.lastMessage = `已清理 ${removed} 个缩略图`;
          promptAction.showToast({ message: this.lastMessage });
        }
      }
    });
  }

  @Builder
  toolCard(title: string, desc: string, actionText: string, danger: boolean,
           action: () => void) {
    Column({ space: 8 }) {
      Text(title).fontSize(15).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary')).width('100%')
      Text(desc).fontSize(11).fontColor($r('app.color.text_secondary')).width('100%')
      Button(actionText)
        .fontSize(12).height(34).borderRadius(17)
        .backgroundColor(danger ? $r('app.color.accent_peach_soft') : $r('app.color.brand_primary'))
        .fontColor(danger ? $r('app.color.danger') : $r('app.color.on_primary'))
        .enabled(!this.busy)
        .onClick(action)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .borderRadius(16)
    .backgroundColor($r('app.color.card_background'))
    .shadow({ radius: 10, color: $r('app.color.shadow'), offsetX: 0, offsetY: 3 })
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Button('返回')
          .fontSize(12).height(34).borderRadius(17)
          .backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        Text('数据工具')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Blank()
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18 })

      Scroll() {
        Column({ space: 10 }) {
          Text('用于课程演示与异常恢复：可导出完整数据快照、从快照恢复，或重置为初始演示数据。')
            .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')

          this.toolCard('导出数据备份', '把所有业务表导出为单个 JSON 文件，包含账号与关联记录。',
            '导出备份', false, () => this.backup())
          this.toolCard('从备份恢复', '选择此前导出的 JSON 备份，覆盖当前数据。恢复后需要重新登录。',
            '选择备份文件', false, () => this.confirmRestore())
          this.toolCard('生成演示学生', '批量生成 20 名不同年级与方向的演示学生，便于演示分页、方向筛选与匹配性能。',
            '生成 20 名', false, () => this.seedStudents())
          this.toolCard('图片与缓存', '查看证书图片占用空间，并可清理缩略图缓存（原图保留）。',
            '查看并清理', false, () => this.confirmClearThumbs())
          this.toolCard('重置演示数据', '清空全部业务数据并重建初始示例学生、企业与岗位。',
            '重置数据', true, () => this.confirmReset())

          if (this.busy) {
            Text('处理中，请稍候…').fontSize(11).fontColor($r('app.color.brand_primary')).width('100%')
          } else if (this.lastMessage.length > 0) {
            Text(this.lastMessage).fontSize(11).fontColor($r('app.color.text_secondary')).width('100%')
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 20 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%').height('100%').linearGradient({ angle: 165, colors: [[$r('app.color.app_background'), 0], [$r('app.color.app_background_end'), 1]] })
  }
}
