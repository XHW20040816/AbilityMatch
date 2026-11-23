import { promptAction, router } from '@kit.ArkUI';
import { Constants } from '../common/Constants';
import { PrefsHelper } from '../common/PrefsHelper';
import { Company, JobRequirement } from '../model/Entity';
import { VerifyStatus } from '../model/Enums';
import { accountRepo, companyRepo, jobRepo, matchRepo } from '../repository/Repositories';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Entry
@Component
struct CompanyPage {
  @State companyId: number = 0;
  @State name: string = '';
  @State industry: string = '';
  @State scaleText: string = '';
  @State contact: string = '';
  @State phone: string = '';
  @State address: string = '';
  @State jobs: JobRequirement[] = [];
  @State verifyStatus: string = VerifyStatus.PENDING;

  aboutToAppear(): void {
    AppViewModel.load().then(() => {
      this.companyId = AppViewModel.companyId;
      this.verifyStatus = AppViewModel.verifyStatus;
      return companyRepo.getById(this.companyId);
    }).then((company: Company | null) => {
      if (company !== null) {
        this.applyCompany(company);
        this.loadJobs();
      }
    }).catch((error: Error) => {
      promptAction.showToast({ message: '加载失败：' + error.message });
    });
  }

  private auditLocally(status: string): void {
    if (AppViewModel.accountId <= 0) {
      promptAction.showToast({ message: '未找到企业账号' });
      return;
    }
    accountRepo.setVerifyStatus(AppViewModel.accountId, status).then(() => {
      this.verifyStatus = status;
      AppViewModel.verifyStatus = status;
      return PrefsHelper.put(Constants.KEY_VERIFY_STATUS, status);
    }).then(() => {
      let message: string = '已撤回为待审核，可重新提交材料';
      if (status === VerifyStatus.VERIFIED) {
        message = '本地模拟审核已通过';
      } else if (status === VerifyStatus.REJECTED) {
        message = '已模拟驳回，可修改材料后重审';
      }
      promptAction.showToast({ message: message });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '审核状态更新失败：' + error.message });
    });
  }

  private verifyStatusText(): string {
    if (this.verifyStatus === VerifyStatus.VERIFIED) {
      return '已通过（本地模拟审核）';
    }
    if (this.verifyStatus === VerifyStatus.REJECTED) {
      return '未通过，可修改材料后重新提交';
    }
    return '待审核';
  }

  private applyCompany(company: Company): void {
    this.name = company.companyName;
    this.industry = company.industry;
    this.scaleText = company.scale;
    this.contact = company.contactPerson;
    this.phone = company.contactPhone;
    this.address = company.address;
  }

  private loadJobs(): void {
    jobRepo.listByCompany(this.companyId).then((jobs: JobRequirement[]) => {
      this.jobs = jobs;
    });
  }

  private saveCompany(): void {
    if (this.name.trim().length < 2) {
      promptAction.showToast({ message: '企业名称至少 2 个字符' });
      return;
    }
    if (this.companyId <= 0) {
      promptAction.showToast({ message: '未找到当前企业账号' });
      return;
    }
    const company: Company = {
      id: this.companyId,
      companyName: this.name.trim(),
      industry: this.industry.trim(),
      scale: this.scaleText.trim(),
      contactPerson: this.contact.trim(),
      contactPhone: this.phone.trim(),
      address: this.address.trim()
    };
    companyRepo.update(company).then(() => {
      AppViewModel.companyName = company.companyName;
      promptAction.showToast({ message: '企业资料已保存' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '保存失败：' + error.message });
    });
  }

  private toggleJob(job: JobRequirement): void {
    const task: Promise<void> = job.status === 1 ? jobRepo.archive(job.id) : jobRepo.activate(job.id);
    task.then(() => {
      this.loadJobs();
      promptAction.showToast({ message: job.status === 1 ? '岗位已关闭' : '岗位已启用' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '操作失败：' + error.message });
    });
  }

  private confirmRemoveJob(job: JobRequirement): void {
    AlertDialog.show({
      title: '删除岗位',
      message: `删除“${job.jobTitle}”后，相关匹配记录也会清除，是否继续？`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '删除',
        fontColor: '#E86A67',
        action: () => { this.removeJob(job); }
      }
    });
  }

  private removeJob(job: JobRequirement): void {
    matchRepo.removeByJob(job.id).then(() => {
      return jobRepo.remove(job.id);
    }).then(() => {
      this.loadJobs();
      promptAction.showToast({ message: '岗位已删除' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '删除失败：' + error.message });
    });
  }

  @Builder
  infoInput(placeholder: string, value: string, onChange: (value: string) => void) {
    TextInput({ placeholder: placeholder, text: value })
      .width('100%')
      .height(46)
      .fontSize(14)
      .backgroundColor($r('app.color.surface_muted'))
      .borderRadius(13)
      .onChange(onChange)
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Button('返回')
          .fontSize(12).height(34).borderRadius(17)
          .backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        Text('企业信息')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Blank()
        Button('保存')
          .fontSize(13).height(36).borderRadius(18)
          .backgroundColor($r('app.color.brand_primary')).fontColor($r('app.color.on_primary'))
          .onClick(() => this.saveCompany())
      }
      .width('100%').padding({ left: 18, right: 18, top: 18 })

      Scroll() {
        Column({ space: 10 }) {
          Text('企业资料')
            .fontSize(13).fontColor($r('app.color.text_secondary')).width('100%')
          Column({ space: 6 }) {
            Row() {
              Text('企业身份核验').fontSize(13).fontWeight(FontWeight.Medium).layoutWeight(1)
              Text(this.verifyStatusText()).fontSize(11)
                .fontColor(this.verifyStatus === VerifyStatus.VERIFIED ?
                  $r('app.color.success') : $r('app.color.text_secondary'))
            }.width('100%')
            Text('单机演示版不接入真实审核服务，可在此模拟审核结果；正式环境应由平台人工审核。')
              .fontSize(10).fontColor($r('app.color.text_tertiary')).width('100%')
            if (this.verifyStatus !== VerifyStatus.VERIFIED) {
              Row({ space: 8 }) {
                Button('本地模拟审核通过')
                  .fontSize(11).height(30).borderRadius(15)
                  .backgroundColor($r('app.color.brand_primary')).fontColor($r('app.color.on_primary'))
                  .onClick(() => this.auditLocally(VerifyStatus.VERIFIED))
                Button('模拟驳回')
                  .fontSize(11).height(30).borderRadius(15)
                  .backgroundColor($r('app.color.accent_peach_soft')).fontColor($r('app.color.danger'))
                  .onClick(() => this.auditLocally(VerifyStatus.REJECTED))
              }.width('100%')
            } else {
              Row({ space: 8 }) {
                Button('撤回为待审核')
                  .fontSize(11).height(30).borderRadius(15)
                  .backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.text_secondary'))
                  .onClick(() => this.auditLocally(VerifyStatus.PENDING))
              }.width('100%')
            }
          }
          .width('100%').padding(12).borderRadius(14)
          .backgroundColor($r('app.color.card_background'))
          this.infoInput('企业名称', this.name, (value: string) => { this.name = value; })
          this.infoInput('所属行业', this.industry, (value: string) => { this.industry = value; })
          this.infoInput('企业规模，如 51-200 人', this.scaleText, (value: string) => { this.scaleText = value; })
          this.infoInput('联系人', this.contact, (value: string) => { this.contact = value; })
          this.infoInput('联系电话', this.phone, (value: string) => { this.phone = value; })
          this.infoInput('办公地址', this.address, (value: string) => { this.address = value; })

          Text(`本企业岗位（${this.jobs.length}）`)
            .fontSize(16).fontWeight(FontWeight.Medium)
            .width('100%').margin({ top: 10 })
          if (this.jobs.length === 0) {
            Text('暂无岗位，可前往“招聘发布”录入')
              .fontSize(13).fontColor($r('app.color.text_secondary')).width('100%')
          }
          ForEach(this.jobs, (job: JobRequirement) => {
            Column({ space: 8 }) {
              Row() {
                Text(job.jobTitle)
                  .fontSize(14).fontWeight(FontWeight.Medium).layoutWeight(1)
                Text(job.status === 1 ? '在招' : '已关闭')
                  .fontSize(11)
                  .fontColor(job.status === 1 ? $r('app.color.success') : $r('app.color.text_tertiary'))
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(10)
                  .backgroundColor($r('app.color.surface_muted'))
              }.width('100%')
              if (job.majorDirection.length > 0) {
                Text('专业方向：' + job.majorDirection)
                  .fontSize(11).fontColor($r('app.color.brand_primary'))
              }
              Row({ space: 8 }) {
                Button(job.status === 1 ? '关闭岗位' : '重新启用')
                  .fontSize(11).height(28).borderRadius(14)
                  .backgroundColor($r('app.color.chip_background')).fontColor($r('app.color.text_primary'))
                  .onClick(() => this.toggleJob(job))
                Button('删除岗位')
                  .fontSize(11).height(28).borderRadius(14)
                  .backgroundColor($r('app.color.accent_peach_soft')).fontColor($r('app.color.danger'))
                  .onClick(() => this.confirmRemoveJob(job))
              }.width('100%')
            }
            .width('100%').alignItems(HorizontalAlign.Start)
            .padding(12).borderRadius(12).backgroundColor($r('app.color.card_background'))
          }, (job: JobRequirement) => String(job.id))
        }
        .width('100%').padding({ left: 18, right: 18, bottom: 20 })
      }
      .layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').linearGradient({ angle: 165, colors: [[$r('app.color.app_background'), 0], [$r('app.color.app_background_end'), 1]] })
  }
}
