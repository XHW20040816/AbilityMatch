import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { ResourceHelper } from '../common/ResourceHelper';
import {
  AbilityTag, AdviceLib, HonorCertificate, JobRequirement, MatchResult,
  ProjectExperience, SelectItem, SkillCertificate, SkillDict, Student
} from '../model/Entity';
import { MatchDirection } from '../model/Enums';
import { honorRepo, jobRepo, matchRepo, profileRepo, studentRepo, tagRepo } from '../repository/Repositories';
import { MatchEngine } from '../service/MatchEngine';
import { EmptyState } from '../view/EmptyState';
import { AppViewModel } from '../viewmodel/AppViewModel';

interface CandidateView {
  student: Student;
  result: MatchResult;
}

@Entry
@Component
struct CandidatePage {
  @State jobs: JobRequirement[] = [];
  @State jobIndex: number = 0;
  @State candidates: CandidateView[] = [];
  @State sameDirection: boolean = false;
  @State page: number = 0;
  @State total: number = 0;
  private pageSize: number = 10;
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private dict: SkillDict | null = null;

  aboutToAppear(): void {
    Promise.all([AppViewModel.load(), ResourceHelper.loadSkillDict(this.context)])
      .then((values: [void, SkillDict]) => {
        this.dict = values[1] as SkillDict;
        this.loadJobs(AppViewModel.companyId);
      }).catch((error: Error) => {
        promptAction.showToast({ message: '加载失败：' + error.message });
      });
  }

  private loadJobs(companyId: number): void {
    jobRepo.listByCompany(companyId).then((jobs: JobRequirement[]) => {
      this.jobs = jobs.filter((job: JobRequirement) => job.status === 1);
      this.jobIndex = 0;
      this.page = 0;
      this.load();
    }).catch((error: Error) => {
      promptAction.showToast({ message: '加载失败：' + error.message });
    });
  }

  private load(): void {
    if (this.jobs.length === 0) {
      this.candidates = [];
      this.total = 0;
      return;
    }
    const job: JobRequirement = this.jobs[this.jobIndex];
    const direction: string = this.sameDirection ? job.majorDirection : '';
    this.candidates = [];
    Promise.all([
      studentRepo.listPage(this.pageSize, this.page * this.pageSize, direction),
      studentRepo.countByDirection(direction),
      ResourceHelper.loadAdviceLib(this.context)
    ]).then((values: [Student[], number, AdviceLib]) => {
      const students: Student[] = values[0] as Student[];
      this.total = values[1] as number;
      const advice: AdviceLib = values[2] as AdviceLib;
      if (this.page > 0 && students.length === 0 && this.total > 0) {
        this.page = Math.max(0, Math.ceil(this.total / this.pageSize) - 1);
        this.load();
        return [];
      }
      const tasks: Promise<CandidateView>[] = [];
      for (const student of students) {
        tasks.push(this.buildCandidate(student, job, advice));
      }
      return Promise.all(tasks);
    }).then((views: CandidateView[]) => {
      views.sort((a: CandidateView, b: CandidateView) => b.result.totalScore - a.result.totalScore);
      this.candidates = views;
    }).catch((error: Error) => {
      promptAction.showToast({ message: '加载失败：' + error.message });
    });
  }

  private totalPages(): number {
    return this.total === 0 ? 1 : Math.ceil(this.total / this.pageSize);
  }

  private buildCandidate(student: Student, job: JobRequirement, advice: AdviceLib): Promise<CandidateView> {
    return Promise.all([
      tagRepo.listByStudent(student.id),
      profileRepo.listSkillCerts(student.id),
      profileRepo.listProjects(student.id),
      honorRepo.list(student.id, { keyword: '', honorType: '', level: '', yearFrom: 0, yearTo: 0, issuer: '' }, 200, 0)
    ]).then((values: [AbilityTag[], SkillCertificate[], ProjectExperience[], HonorCertificate[]]) => {
      const tags: AbilityTag[] = values[0] as AbilityTag[];
      const certs: SkillCertificate[] = values[1] as SkillCertificate[];
      const projects: ProjectExperience[] = values[2] as ProjectExperience[];
      const honors: HonorCertificate[] = values[3] as HonorCertificate[];
      const result: MatchResult = MatchEngine.compute(student, tags, certs, projects, honors, job, advice, this.dict);
      const view: CandidateView = { student: student, result: result };
      return matchRepo.replaceToday({
        id: 0,
        studentId: student.id,
        jobId: job.id,
        direction: MatchDirection.COMPANY_TO_STUDENT,
        totalScore: result.totalScore,
        dimensionScores: result.dimensionScores,
        gapItems: result.gapItems,
        suggestions: result.suggestions,
        createTime: Date.now()
      }).then(() => view);
    });
  }

  build() {
    Column({ space: 12 }) {
      Column({ space: 6 }) {
        Text('候选人').fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Text('按匹配度排序，点击候选人查看差距与建议')
          .fontSize(12).fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 18, right: 18, top: 16, bottom: 14 })
      .borderRadius(20)
      .backgroundColor($r('app.color.accent_peach_soft'))

      if (this.jobs.length > 0) {
        Select(this.jobs.map((job: JobRequirement): SelectItem => ({ value: job.jobTitle })))
          .selected(this.jobIndex)
          .onSelect((index: number) => {
            this.jobIndex = index;
            this.page = 0;
            this.sameDirection = false;
            this.load();
          })
          .width('100%')
          .borderRadius(18)
        if (this.jobs[this.jobIndex].majorDirection.length > 0) {
          Row({ space: 6 }) {
            Checkbox({ name: '只看同方向', group: 'candidate_direction' })
              .select(this.sameDirection)
              .accessibilityText(`只看同方向候选人：${this.jobs[this.jobIndex].majorDirection}`)
              .onChange((value: boolean) => {
                this.sameDirection = value;
                this.page = 0;
                this.load();
              })
            Text(`只看同方向：${this.jobs[this.jobIndex].majorDirection}`)
              .fontSize(12).fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
        }
      }
      if (this.candidates.length === 0) {
        EmptyState({ text: this.jobs.length === 0 ? '该企业暂无在招岗位' : '暂无候选人数据' })
      } else {
        List({ space: 10 }) {
          ForEach(this.candidates, (item: CandidateView, index: number) => {
            ListItem() {
              Row({ space: 12 }) {
                Column() {
                  Text(item.student.name.substring(0, 1)).fontSize(18).fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.on_primary'))
                }
                .width(48).height(48).borderRadius(24)
                .backgroundColor(index % 2 === 0 ? $r('app.color.brand_primary') : $r('app.color.accent_peach'))
                .justifyContent(FlexAlign.Center)

                Column({ space: 4 }) {
                  Text(item.student.name).fontSize(16).fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Text(item.student.major + ' · ' + item.student.grade + ' · ' + item.student.education +
                    (item.student.schoolLevel.length > 0 ? ' · ' + item.student.schoolLevel : ''))
                    .fontSize(12).fontColor($r('app.color.text_secondary'))
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Column({ space: 2 }) {
                  Text(`${item.result.totalScore}`).fontSize(18).fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.brand_primary'))
                  Text('匹配分').fontSize(10).fontColor($r('app.color.text_secondary'))
                }
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .borderRadius(14)
                .backgroundColor($r('app.color.chip_background'))
              }
              .width('100%').padding(16).borderRadius(20)
              .backgroundColor($r('app.color.card_background'))
              .shadow({ radius: 10, color: $r('app.color.shadow'), offsetX: 0, offsetY: 3 })
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/CandidateDetailPage',
                  params: { studentId: item.student.id, jobId: this.jobs[this.jobIndex].id }
                }).catch((error: Error) => {
                  promptAction.showToast({ message: '打开详情失败：' + error.message });
                });
              })
            }
          }, (item: CandidateView) => String(item.student.id))
        }
        .layoutWeight(1).width('100%')
        Row({ space: 10 }) {
          Button('上一页')
            .fontSize(12)
            .height(32)
            .borderRadius(16)
            .backgroundColor($r('app.color.chip_background'))
            .fontColor($r('app.color.text_label'))
            .enabled(this.page > 0)
            .onClick(() => {
              if (this.page > 0) {
                this.page--;
                this.load();
              }
            })
          Text(`第 ${this.page + 1} / ${this.totalPages()} 页 · 共 ${this.total} 人`)
            .fontSize(11).fontColor($r('app.color.text_secondary')).layoutWeight(1)
            .textAlign(TextAlign.Center)
          Button('下一页')
            .fontSize(12)
            .height(32)
            .borderRadius(16)
            .backgroundColor($r('app.color.brand_primary'))
            .fontColor($r('app.color.on_primary'))
            .enabled((this.page + 1) * this.pageSize < this.total)
            .onClick(() => {
              if ((this.page + 1) * this.pageSize < this.total) {
                this.page++;
                this.load();
              }
            })
        }
        .width('100%')
      }
    }
    .width('100%').height('100%').padding(18).linearGradient({ angle: 165, colors: [[$r('app.color.app_background'), 0], [$r('app.color.app_background_end'), 1]] })
  }
}
