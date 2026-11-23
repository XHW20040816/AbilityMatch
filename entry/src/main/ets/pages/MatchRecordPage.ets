import { promptAction } from '@kit.ArkUI';
import { AppViewModel } from '../viewmodel/AppViewModel';
import { AppRole } from '../model/Enums';
import { JobRequirement, MatchRecord, SelectItem } from '../model/Entity';
import { jobRepo, matchRepo } from '../repository/Repositories';
import { EmptyState } from '../view/EmptyState';

@Entry
@Component
struct MatchRecordPage {
  @State role: AppRole = AppRole.STUDENT;
  @State studentId: number = 1;
  @State jobs: JobRequirement[] = [];
  @State jobIndex: number = 0;
  @State records: MatchRecord[] = [];

  aboutToAppear(): void {
    AppViewModel.load().then((): Promise<JobRequirement[]> => {
      this.role = AppViewModel.role;
      this.studentId = AppViewModel.studentId;
      if (this.role === AppRole.COMPANY) {
        return jobRepo.listByCompany(AppViewModel.companyId).then((jobs: JobRequirement[]) => {
          return jobs.filter((job: JobRequirement) => job.status === 1);
        });
      }
      return jobRepo.listActive();
    }).then((jobs: JobRequirement[]) => {
      this.jobs = jobs;
      this.load();
    }).catch((error: Error) => {
      promptAction.showToast({ message: '加载失败：' + error.message });
    });
  }

  private load(): void {
    const task: Promise<MatchRecord[]> = this.role === AppRole.STUDENT
      ? matchRepo.listByStudent(this.studentId)
      : (this.jobs.length > 0 ? matchRepo.listByJob(this.jobs[this.jobIndex].id) : Promise.resolve([]));
    task.then((records: MatchRecord[]) => { this.records = records; })
      .catch((error: Error) => promptAction.showToast({ message: '加载失败：' + error.message }));
  }

  private jobTitle(jobId: number): string {
    for (const job of this.jobs) {
      if (job.id === jobId) {
        return job.jobTitle;
      }
    }
    return '岗位 #' + jobId;
  }

  build() {
    Column({ space: 12 }) {
      Text('匹配记录').fontSize(20).fontWeight(FontWeight.Bold)
      if (this.role === AppRole.COMPANY && this.jobs.length > 0) {
        Select(this.jobs.map((job: JobRequirement): SelectItem => ({ value: job.jobTitle })))
          .selected(this.jobIndex)
          .onSelect((index: number) => { this.jobIndex = index; this.load(); })
          .width('100%')
      }
      if (this.records.length === 0) {
        EmptyState({ text: '暂无匹配记录，请先浏览岗位或候选人' })
      } else {
        List({ space: 10 }) {
          ForEach(this.records, (record: MatchRecord) => {
            ListItem() {
              Column({ space: 4 }) {
                Row() {
                  Text(this.jobTitle(record.jobId)).fontSize(15).fontWeight(FontWeight.Medium)
                  Blank()
                  Text(`${record.totalScore}分`).fontSize(16).fontColor($r('app.color.brand_primary'))
                }.width('100%')
                Text(new Date(record.createTime).toLocaleString()).fontSize(12).fontColor($r('app.color.text_secondary'))
                if (record.gapItems.length > 0) {
                  Text('差距：' + record.gapItems.join('；')).fontSize(12).fontColor($r('app.color.danger'))
                }
              }
              .width('100%').alignItems(HorizontalAlign.Start)
              .padding(14).borderRadius(12).backgroundColor($r('app.color.card_background'))
            }
          }, (record: MatchRecord) => String(record.id))
        }
        .layoutWeight(1).width('100%')
      }
    }
    .width('100%').height('100%').padding(20).linearGradient({ angle: 165, colors: [[$r('app.color.app_background'), 0], [$r('app.color.app_background_end'), 1]] })
  }
}
