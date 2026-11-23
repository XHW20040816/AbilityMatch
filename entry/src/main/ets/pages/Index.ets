import { promptAction, router } from '@kit.ArkUI';
import { Style3D } from '../common/Style3D';
import { GrowthTask } from '../model/Entity';
import { AppRole, verifyStatusLabel, VerifyStatus } from '../model/Enums';
import { growthRepo } from '../repository/Repositories';
import { Card3D } from '../view/Card3D';
import { ModuleTile } from '../view/ModuleTile';
import { AppViewModel } from '../viewmodel/AppViewModel';

interface ModuleItem {
  title: string;
  desc: string;
  path: string;
}

interface IndexRouteParams {
  studentId: number;
  companyId: number;
  role: AppRole;
}

@Entry
@Component
struct Index {
  @State role: AppRole = AppRole.STUDENT;
  @State studentName: string = '';
  @State studentGrade: string = '';
  @State companyName: string = '';
  @State studentId: number = 0;
  @State companyId: number = 0;
  @State accountName: string = '';
  @State verifyStatus: string = VerifyStatus.PENDING;
  @State overdueCount: number = 0;
  @State entered: boolean = false;
  /** 彩蛋：点击顶部立体卡片弹出「休息一下」插画，学生端与企业端各一张 */
  @State showEgg: boolean = false;
  @State eggForStudent: boolean = true;

  aboutToAppear(): void {
    AppViewModel.load().then((): Promise<GrowthTask[]> => {
      if (!AppViewModel.loggedIn) {
        router.replaceUrl({ url: 'pages/AuthPage' });
        return Promise.resolve([]);
      }
      this.role = AppViewModel.role;
      this.studentName = AppViewModel.studentName;
      this.studentGrade = AppViewModel.studentGrade;
      this.companyName = AppViewModel.companyName;
      this.studentId = AppViewModel.studentId;
      this.companyId = AppViewModel.companyId;
      this.accountName = AppViewModel.accountName;
      this.verifyStatus = AppViewModel.verifyStatus;
      return this.role === AppRole.STUDENT
        ? growthRepo.listByStudent(this.studentId)
        : Promise.resolve([]);
    }).then((tasks: GrowthTask[]) => {
      this.overdueCount = tasks.filter((task: GrowthTask) =>
        task.status === 0 && task.dueDate > 0 && task.dueDate < Date.now()).length;
    }).catch((error: Error) => {
      promptAction.showToast({ message: '本地数据加载失败：' + error.message });
    });
  }

  private isSenior(): boolean {
    const grade: string = this.studentGrade;
    if (grade.includes('大三') || grade.includes('大四') || grade.includes('研')
      || grade.includes('毕业') || grade.includes('硕士')) {
      return true;
    }
    const match: RegExpMatchArray | null = grade.match(/(\d{4})/);
    if (match !== null) {
      const year: number = Number(match[1]);
      return year > 0 && new Date().getFullYear() - year >= 2;
    }
    return false;
  }

  private studentModules(): ModuleItem[] {
    const info: ModuleItem =
      { title: '学生资料', desc: '维护学籍、专业、隐私与联系方式', path: 'pages/StudentEditPage' };
    const growth: ModuleItem =
      { title: '成长规划', desc: '阶段任务进度、逾期提醒与方向清单', path: 'pages/GrowthGuidePage' };
    const certificate: ModuleItem =
      { title: '荣誉证书', desc: '拍照录入、归档检索与图片预览', path: 'pages/CertificatePage' };
    const portrait: ModuleItem =
      { title: '能力画像', desc: '能力标签统计与档案导出', path: 'pages/PortraitPage' };
    const match: ModuleItem =
      { title: '岗位匹配', desc: '按企业或岗位双向选择并匹配', path: 'pages/JobMatchPage' };
    const jobs: ModuleItem =
      { title: '岗位列表', desc: '浏览全部在招岗位与匹配度', path: 'pages/JobListPage' };
    const records: ModuleItem =
      { title: '匹配记录', desc: '查看历史匹配结果', path: 'pages/MatchRecordPage' };
    const data: ModuleItem =
      { title: '数据工具', desc: '备份、恢复与演示数据重置', path: 'pages/DataToolPage' };
    if (this.isSenior()) {
      return [portrait, match, certificate, growth, jobs, info, records, data];
    }
    return [growth, info, certificate, portrait, jobs, match, records, data];
  }

  private companyModules(): ModuleItem[] {
    return [
      { title: '企业信息', desc: '维护企业基础资料与联系方式', path: 'pages/CompanyPage' },
      { title: '招聘发布', desc: '录入简章并解析岗位要求', path: 'pages/JobPublishPage' },
      { title: '候选人列表', desc: '按岗位查看匹配候选人', path: 'pages/CandidatePage' },
      { title: '匹配记录', desc: '查看历史匹配结果', path: 'pages/MatchRecordPage' },
      { title: '数据工具', desc: '备份、恢复与演示数据重置', path: 'pages/DataToolPage' }
    ];
  }

  private modules(): ModuleItem[] {
    return this.role === AppRole.STUDENT ? this.studentModules() : this.companyModules();
  }

  private displayName(): string {
    if (this.role === AppRole.STUDENT) {
      return this.studentName.length > 0 ? this.studentName : '待完善学生资料';
    }
    return this.companyName.length > 0 ? this.companyName : '待完善企业资料';
  }

  private go(path: string): void {
    const params: IndexRouteParams = {
      studentId: this.studentId,
      companyId: this.companyId,
      role: this.role
    };
    router.pushUrl({ url: path, params: params }).catch((error: Error) => {
      promptAction.showToast({ message: '页面打开失败：' + error.message });
    });
  }

  private confirmLogout(): void {
    AlertDialog.show({
      title: '退出登录',
      message: '退出后需要重新输入账号密码，是否继续？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '退出',
        fontColor: '#E86A67',
        action: () => {
          AppViewModel.logout().then(() => {
            router.replaceUrl({ url: 'pages/AuthPage' });
          });
        }
      }
    });
  }

  private openEgg(): void {
    this.eggForStudent = this.role === AppRole.STUDENT;
    animateTo({ duration: 260, curve: Curve.FastOutSlowIn }, () => {
      this.showEgg = true;
    });
  }

  private closeEgg(): void {
    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      this.showEgg = false;
    });
  }

  onBackPress(): boolean {
    if (this.showEgg) {
      this.closeEgg();
      return true;
    }
    return false;
  }

  private statusColor(): Resource {
    if (this.verifyStatus === VerifyStatus.VERIFIED) {
      return $r('app.color.success');
    }
    if (this.verifyStatus === VerifyStatus.REJECTED) {
      return $r('app.color.danger');
    }
    return $r('app.color.warning');
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 165,
          colors: [[$r('app.color.app_background'), 0], [$r('app.color.app_background_end'), 1]]
        })

      Column()
        .width('100%')
        .height(260)
        .radialGradient({
          center: ['78%', '0%'],
          radius: 260,
          colors: [['#80FFFFFF', 0], ['#00FFFFFF', 1]]
        })

      Column({ space: 14 }) {
        Column() {
          Card3D({
            faceColors: Style3D.heroFace,
            depthColor: Style3D.heroDepth,
            radius: 26,
            depth: 8,
            facePadding: 20,
            faceBorderColor: '#40FFFFFF',
            shadowColor: Style3D.shadowDeep,
            shadowRadius: 26,
            action: () => this.openEgg()
          }) {
            Column({ space: 14 }) {
              Row() {
                Column({ space: 8 }) {
                  Text(this.role === AppRole.STUDENT ? '学生成长工作台' : '招聘方工作台')
                    .fontSize(11)
                    .fontColor('#FFFFFF')
                    .padding({ left: 10, right: 10, top: 3, bottom: 3 })
                    .borderRadius(11)
                    .backgroundColor('#33FFFFFF')
                  Text('能力画像与岗位匹配')
                    .fontSize(23)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                  Text(this.role === AppRole.STUDENT ? '记录成长轨迹，匹配更合适的岗位' : '发布真实岗位，找到更合适的人')
                    .fontSize(12)
                    .fontColor('#D9FFFFFF')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Image($r('app.media.hero_discover'))
                  .width(78)
                  .height(78)
                  .borderRadius(20)
                  .objectFit(ImageFit.Cover)
                  .border({ width: 2, color: '#66FFFFFF' })
                  .shadow({ radius: 14, color: '#66065A6B', offsetX: 0, offsetY: 8 })
                  .rotate({ angle: -6 })
              }
              .width('100%')

              Row({ space: 8 }) {
                Row({ space: 6 }) {
                  Circle()
                    .width(6)
                    .height(6)
                    .backgroundColor(this.statusColor())
                  Text(verifyStatusLabel(this.verifyStatus))
                    .fontSize(11)
                    .fontColor('#FFFFFF')
                }
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .borderRadius(14)
                .backgroundColor('#26FFFFFF')
                .accessibilityText('身份核验状态：' + verifyStatusLabel(this.verifyStatus))

                if (this.overdueCount > 0) {
                  Text(`逾期 ${this.overdueCount} 项`)
                    .fontSize(11)
                    .fontColor('#FFFFFF')
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .borderRadius(14)
                    .backgroundColor('#40FFD9C2')
                    .accessibilityText(`有 ${this.overdueCount} 项成长任务已逾期，点击处理`)
                    .onClick(() => this.go('pages/GrowthGuidePage'))
                }
                Blank()
                Text(this.role === AppRole.STUDENT ? '查看画像 ›' : '候选人 ›')
                  .fontSize(11)
                  .fontColor('#FFFFFF')
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .borderRadius(14)
                  .backgroundColor('#26FFFFFF')
                  .onClick(() => this.go(this.role === AppRole.STUDENT ? 'pages/PortraitPage' : 'pages/CandidatePage'))
              }
              .width('100%')
            }
            .width('100%')
          }
        }
        .opacity(this.entered ? 1 : 0)
        .translate({ y: this.entered ? 0 : 22 })
        .animation({ duration: 420, curve: Curve.FastOutSlowIn })

        Column() {
          Card3D({
            faceColors: Style3D.whiteFace,
            depthColor: Style3D.whiteDepth,
            radius: 20,
            depth: 5,
            facePadding: 16,
            shadowRadius: 16
          }) {
            Row({ space: 12 }) {
              Column({ space: 6 }) {
                Text(this.role === AppRole.STUDENT ? '学生端' : '企业端')
                  .fontSize(11)
                  .fontColor($r('app.color.brand_primary'))
                  .padding({ left: 9, right: 9, top: 3, bottom: 3 })
                  .borderRadius(10)
                  .backgroundColor($r('app.color.chip_background'))
                Text(this.displayName())
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Text(this.accountName)
                  .fontSize(11)
                  .fontColor($r('app.color.text_tertiary'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Button('退出')
                .fontSize(12)
                .height(34)
                .borderRadius(17)
                .backgroundColor($r('app.color.surface_muted'))
                .fontColor($r('app.color.text_secondary'))
                .onClick(() => this.confirmLogout())
            }
            .width('100%')
          }
        }
        .opacity(this.entered ? 1 : 0)
        .translate({ y: this.entered ? 0 : 22 })
        .animation({ duration: 420, delay: 40, curve: Curve.FastOutSlowIn })

        List({ space: 12 }) {
          ForEach(this.modules(), (item: ModuleItem, index: number) => {
            ListItem() {
              Column() {
                ModuleTile({
                  title: item.title,
                  desc: item.desc,
                  colorIndex: index,
                  action: () => this.go(item.path)
                })
              }
              .width('100%')
              .opacity(this.entered ? 1 : 0)
              .translate({ y: this.entered ? 0 : 24 })
              .animation({ duration: 360, delay: 90 + index * 45, curve: Curve.FastOutSlowIn })
            }
          }, (item: ModuleItem) => item.path)
        }
        .id('home_module_list')
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 18, top: 30, bottom: 18 })
      .onAppear(() => {
        animateTo({ duration: 460, curve: Curve.FastOutSlowIn }, () => {
          this.entered = true;
        });
      })

      if (this.showEgg) {
        Column() {
          Column({ space: 14 }) {
            Image(this.eggForStudent ? $r('app.media.egg_pause') : $r('app.media.egg_company'))
              .width('100%')
              .aspectRatio(this.eggForStudent ? 1.3 : 1)
              .objectFit(ImageFit.Cover)
              .borderRadius(20)
              .shadow({ radius: 18, color: '#330E5C5C', offsetX: 0, offsetY: 8 })

            Text(this.eggForStudent ? '如果感到疲惫，\n为自己按下暂停键睡个好觉' : '在伏案翻卷的辛苦中\n也别忘了围炉煮茶的休息')
              .fontSize(15)
              .lineHeight(24)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .textAlign(TextAlign.Center)
              .width('100%')

            Text(this.eggForStudent ? '轻触任意位置，继续加油' : '轻触任意位置，继续出发')
              .fontSize(11)
              .fontColor($r('app.color.text_tertiary'))

            Button('回去继续')
              .fontSize(14)
              .height(42)
              .width('100%')
              .borderRadius(21)
              .linearGradient({ angle: 135, colors: [['#3AD8DA', 0], ['#0FA3AE', 1]] })
              .border({ width: 1, color: '#4DFFFFFF' })
              .shadow({ radius: 12, color: '#400A8089', offsetX: 0, offsetY: 5 })
              .fontColor($r('app.color.on_primary'))
              .onClick(() => this.closeEgg())
          }
          .width('84%')
          .padding(16)
          .borderRadius(26)
          .linearGradient({ angle: 145, colors: [['#FFFFFF', 0], ['#F1FAF9', 1]] })
          .border({ width: 1, color: '#8CFFFFFF' })
          .shadow({ radius: 26, color: '#400E5C5C', offsetX: 0, offsetY: 12 })
          .onClick(() => {})
          .transition(TransitionEffect.scale({ x: 0.92, y: 0.92 }).combine(TransitionEffect.OPACITY))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#8C04222B')
        .onClick(() => this.closeEgg())
        .transition(TransitionEffect.OPACITY)
        .zIndex(9)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }
}
