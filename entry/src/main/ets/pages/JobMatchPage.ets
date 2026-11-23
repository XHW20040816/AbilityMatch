import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { ResourceHelper } from '../common/ResourceHelper';
import { RouteHelper } from '../common/RouteHelper';
import {
  AbilityTag, AdviceLib, HonorCertificate, JobRequirement, MatchResult,
  ProjectExperience, SkillCertificate, SkillDict, Student
} from '../model/Entity';
import { honorRepo, jobRepo, matchRepo, profileRepo, studentRepo, tagRepo } from '../repository/Repositories';
import { MatchEngine } from '../service/MatchEngine';
import { EmptyState } from '../view/EmptyState';

interface JobView {
  job: JobRequirement;
  result: MatchResult;
}

interface CompanyGroup {
  companyId: number;
  companyName: string;
  jobCount: number;
  topJobs: string;
}

interface RelatedCompany {
  companyId: number;
  companyName: string;
  jobId: number;
  jobTitle: string;
  reason: string;
}

@Entry
@Component
struct JobMatchPage {
  @State studentId: number = 1;
  @State mode: number = 0;
  @State keyword: string = '';
  @State allViews: JobView[] = [];
  @State companyViews: JobView[] = [];
  @State selectedCompanyId: number = 0;
  @State selectedCompanyName: string = '';
  @State selectedJobId: number = 0;
  @State selectedJobTitle: string = '';
  @State selectedJobCompany: string = '';
  @State selectedJobScore: number = 0;
  @State relatedCompanies: RelatedCompany[] = [];
  private student: Student | null = null;
  private tags: AbilityTag[] = [];
  private certs: SkillCertificate[] = [];
  private projects: ProjectExperience[] = [];
  private honors: HonorCertificate[] = [];
  private advice: AdviceLib | null = null;
  private dict: SkillDict | null = null;
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    const params: Record<string, Object> = RouteHelper.params();
    if (params['studentId'] !== undefined) {
      this.studentId = Number(params['studentId']);
    }
    this.load();
  }

  private load(): void {
    Promise.all([
      studentRepo.getById(this.studentId),
      tagRepo.listByStudent(this.studentId),
      profileRepo.listSkillCerts(this.studentId),
      profileRepo.listProjects(this.studentId),
      honorRepo.list(this.studentId, { keyword: '', honorType: '', level: '', yearFrom: 0, yearTo: 0, issuer: '' }, 200, 0),
      jobRepo.listActive(),
      ResourceHelper.loadAdviceLib(this.context),
      ResourceHelper.loadSkillDict(this.context)
    ]).then((values: [Student | null, AbilityTag[], SkillCertificate[], ProjectExperience[],
      HonorCertificate[], JobRequirement[], AdviceLib, SkillDict]) => {
      this.student = values[0];
      this.tags = values[1];
      this.certs = values[2];
      this.projects = values[3];
      this.honors = values[4];
      this.advice = values[6];
      this.dict = values[7];
      if (this.student === null) {
        promptAction.showToast({ message: '未找到当前学生资料' });
        return;
      }
      this.allViews = this.computeViews(values[5]);
      const tasks: Promise<void>[] = [];
      for (const view of this.allViews) {
        tasks.push(this.saveMatch(view));
      }
      return Promise.all(tasks).then(() => {});
    }).catch((error: Error) => {
      promptAction.showToast({ message: '匹配数据加载失败：' + error.message });
    });
  }

  private computeViews(jobs: JobRequirement[]): JobView[] {
    const student: Student | null = this.student;
    const advice: AdviceLib | null = this.advice;
    const dict: SkillDict | null = this.dict;
    if (student === null || advice === null || dict === null) {
      return [];
    }
    const views: JobView[] = [];
    for (const job of jobs) {
      views.push({
        job: job,
        result: MatchEngine.compute(student, this.tags, this.certs, this.projects, this.honors, job, advice, dict)
      });
    }
    views.sort((a: JobView, b: JobView) => b.result.totalScore - a.result.totalScore);
    return views;
  }

  private async saveMatch(view: JobView): Promise<void> {
    await matchRepo.replaceToday({
      id: 0,
      studentId: this.studentId,
      jobId: view.job.id,
      direction: 0,
      totalScore: view.result.totalScore,
      dimensionScores: view.result.dimensionScores,
      gapItems: view.result.gapItems,
      suggestions: view.result.suggestions,
      createTime: Date.now()
    });
  }

  private filteredJobViews(): JobView[] {
    const kw: string = this.keyword.trim().toLowerCase();
    if (kw.length === 0) {
      return this.allViews;
    }
    return this.allViews.filter((view: JobView) => {
      const skillText: string = view.job.skillReq.join(' ').toLowerCase();
      return view.job.jobTitle.toLowerCase().includes(kw) ||
        view.job.companyName.toLowerCase().includes(kw) || skillText.includes(kw);
    });
  }

  private companyGroups(): CompanyGroup[] {
    const kw: string = this.keyword.trim().toLowerCase();
    const groups: CompanyGroup[] = [];
    for (const view of this.allViews) {
      let group: CompanyGroup | undefined = groups.find(
        (item: CompanyGroup) => item.companyId === view.job.companyId
      );
      if (group === undefined) {
        group = {
          companyId: view.job.companyId,
          companyName: view.job.companyName,
          jobCount: 0,
          topJobs: ''
        };
        groups.push(group);
      }
      group.jobCount++;
      if (group.topJobs.length === 0) {
        group.topJobs = view.job.jobTitle;
      } else if (group.topJobs.split(' · ').length < 3) {
        group.topJobs += ' · ' + view.job.jobTitle;
      }
    }
    groups.sort((a: CompanyGroup, b: CompanyGroup) => b.jobCount - a.jobCount);
    if (kw.length === 0) {
      return groups;
    }
    return groups.filter((group: CompanyGroup) =>
      group.companyName.toLowerCase().includes(kw) || group.topJobs.toLowerCase().includes(kw));
  }

  private selectCompany(group: CompanyGroup): void {
    this.selectedCompanyId = group.companyId;
    this.selectedCompanyName = group.companyName;
    const jobs: JobRequirement[] = this.allViews
      .filter((view: JobView) => view.job.companyId === group.companyId)
      .map((view: JobView) => view.job);
    this.companyViews = this.computeViews(jobs);
  }

  private selectJob(view: JobView): void {
    this.selectedJobId = view.job.id;
    this.selectedJobTitle = view.job.jobTitle;
    this.selectedJobCompany = view.job.companyName;
    this.selectedJobScore = view.result.totalScore;
    this.relatedCompanies = this.buildRelatedCompanies(view.job);
    this.saveMatch(view).catch((error: Error) => {
      promptAction.showToast({ message: '匹配记录保存失败：' + error.message });
    });
  }

  private buildRelatedCompanies(job: JobRequirement): RelatedCompany[] {
    const result: RelatedCompany[] = [{
      companyId: job.companyId,
      companyName: job.companyName,
      jobId: job.id,
      jobTitle: job.jobTitle,
      reason: '目标岗位'
    }];
    const seen: number[] = [job.companyId];
    for (const view of this.allViews) {
      const item: JobRequirement = view.job;
      if (item.id === job.id || seen.indexOf(item.companyId) >= 0) {
        continue;
      }
      const sameTitle: boolean = item.jobTitle === job.jobTitle;
      let overlap: number = 0;
      for (const skill of job.skillReq) {
        if (item.skillReq.indexOf(skill) >= 0) {
          overlap++;
        }
      }
      if (sameTitle || overlap > 0) {
        seen.push(item.companyId);
        result.push({
          companyId: item.companyId,
          companyName: item.companyName,
          jobId: item.id,
          jobTitle: item.jobTitle,
          reason: sameTitle ? '同名岗位' : `技能重合 ${overlap} 项`
        });
      }
    }
    return result;
  }

  private openJob(jobId: number): void {
    router.pushUrl({
      url: 'pages/JobDetailPage',
      params: { jobId: jobId, studentId: this.studentId }
    }).catch((error: Error) => {
      promptAction.showToast({ message: '打开岗位失败：' + error.message });
    });
  }

  private switchMode(mode: number): void {
    this.mode = mode;
    this.keyword = '';
    this.resetSelection();
  }

  private resetSelection(): void {
    this.selectedCompanyId = 0;
    this.selectedCompanyName = '';
    this.selectedJobId = 0;
    this.relatedCompanies = [];
  }

  @Builder
  jobCard(view: JobView) {
    Column({ space: 8 }) {
      Row() {
        Text(view.job.jobTitle).fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
        Text(`${view.result.totalScore}`).fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_primary'))
      }.width('100%')
      Text(view.job.companyName + (view.job.majorDirection.length > 0 ?
        ' · ' + view.job.majorDirection : ''))
        .fontSize(12).fontColor($r('app.color.text_secondary'))
      Text(view.job.skillReq.length > 0 ? view.job.skillReq.join(' · ') : '技能不限')
        .fontSize(11).fontColor($r('app.color.text_label')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%').alignItems(HorizontalAlign.Start).padding(14).borderRadius(16)
    .backgroundColor($r('app.color.card_background'))
  }

  build() {
    Column({ space: 10 }) {
      Column({ space: 4 }) {
        Text('选择企业或岗位进行匹配').fontSize(21).fontWeight(FontWeight.Bold)
        Text('按企业找岗位，或按岗位找相关企业').fontSize(12).fontColor($r('app.color.text_secondary'))
      }.width('100%').alignItems(HorizontalAlign.Start).padding(16).borderRadius(18)
      .backgroundColor($r('app.color.brand_soft'))

      Row({ space: 6 }) {
        Button('按企业找岗位').fontSize(12).height(36).layoutWeight(1)
          .backgroundColor(this.mode === 0 ? $r('app.color.brand_primary') : $r('app.color.surface_muted'))
          .fontColor(this.mode === 0 ? $r('app.color.on_primary') : $r('app.color.text_primary'))
          .onClick(() => this.switchMode(0))
        Button('按岗位找企业').fontSize(12).height(36).layoutWeight(1)
          .backgroundColor(this.mode === 1 ? $r('app.color.brand_primary') : $r('app.color.surface_muted'))
          .fontColor(this.mode === 1 ? $r('app.color.on_primary') : $r('app.color.text_primary'))
          .onClick(() => this.switchMode(1))
      }.width('100%')

      Row({ space: 8 }) {
        TextInput({
          placeholder: this.mode === 0 ? '搜索企业名称' : '搜索岗位名称或技能',
          text: this.keyword
        }).layoutWeight(1).height(42).fontSize(13)
        .backgroundColor($r('app.color.surface_muted')).borderRadius(12)
        .onChange((value: string) => { this.keyword = value; })
        Button('清除').fontSize(11).height(36).borderRadius(18)
          .backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.text_secondary'))
          .onClick(() => { this.keyword = ''; })
      }.width('100%')

      if (this.selectedCompanyId > 0) {
        Row({ space: 8 }) {
          Button('返回企业').fontSize(11).height(32).borderRadius(16)
            .backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.text_primary'))
            .onClick(() => this.resetSelection())
          Text(this.selectedCompanyName).fontSize(15).fontWeight(FontWeight.Medium).layoutWeight(1)
        }.width('100%')
      } else if (this.selectedJobId > 0) {
        Row({ space: 8 }) {
          Button('返回岗位').fontSize(11).height(32).borderRadius(16)
            .backgroundColor($r('app.color.surface_muted')).fontColor($r('app.color.text_primary'))
            .onClick(() => this.resetSelection())
          Text(this.selectedJobTitle).fontSize(15).fontWeight(FontWeight.Medium).layoutWeight(1)
          Text(`${this.selectedJobScore} 分`).fontSize(13).fontColor($r('app.color.brand_primary'))
        }.width('100%')
      }

      if (this.selectedCompanyId > 0) {
        if (this.companyViews.length === 0) {
          EmptyState({ text: '该企业暂无在招岗位' })
        } else {
          List({ space: 10 }) {
            ForEach(this.companyViews, (view: JobView) => {
              ListItem() {
                Column() {
                  this.jobCard(view)
                }.onClick(() => this.openJob(view.job.id))
              }
            }, (view: JobView) => String(view.job.id))
          }.layoutWeight(1).width('100%')
        }
      } else if (this.selectedJobId > 0) {
        Column({ space: 4 }) {
          Text(this.selectedJobCompany).fontSize(12).fontColor($r('app.color.text_secondary'))
          Text('选择一家企业，基于其关联岗位开始匹配').fontSize(12)
            .fontColor($r('app.color.text_primary'))
        }.width('100%').alignItems(HorizontalAlign.Start).padding(12).borderRadius(12)
        .backgroundColor($r('app.color.accent_peach_soft'))
        List({ space: 10 }) {
          ForEach(this.relatedCompanies, (item: RelatedCompany) => {
            ListItem() {
              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Text(item.companyName).fontSize(15).fontWeight(FontWeight.Medium)
                  Text(`关联岗位：${item.jobTitle}`).fontSize(12).fontColor($r('app.color.text_secondary'))
                  Text(item.reason).fontSize(10).fontColor($r('app.color.brand_primary'))
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('匹配').fontSize(12).fontColor($r('app.color.brand_primary'))
              }.width('100%').padding(14).borderRadius(16).backgroundColor($r('app.color.card_background'))
              .onClick(() => this.openJob(item.jobId))
            }
          }, (item: RelatedCompany) => `${item.companyId}_${item.jobId}`)
        }.layoutWeight(1).width('100%')
      } else if (this.mode === 0) {
        if (this.companyGroups().length === 0) {
          EmptyState({ text: '没有匹配的企业，换个关键词试试' })
        } else {
          List({ space: 10 }) {
            ForEach(this.companyGroups(), (group: CompanyGroup) => {
              ListItem() {
                Column({ space: 5 }) {
                  Row() {
                    Text(group.companyName).fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
                    Text(`${group.jobCount} 个岗位`).fontSize(11).fontColor($r('app.color.brand_primary'))
                  }.width('100%')
                  Text(group.topJobs).fontSize(11).fontColor($r('app.color.text_secondary'))
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }.width('100%').alignItems(HorizontalAlign.Start).padding(14).borderRadius(16)
                .backgroundColor($r('app.color.card_background'))
                .onClick(() => this.selectCompany(group))
              }
            }, (group: CompanyGroup) => String(group.companyId))
          }.layoutWeight(1).width('100%')
        }
      } else {
        if (this.filteredJobViews().length === 0) {
          EmptyState({ text: '没有匹配的岗位，换个关键词试试' })
        } else {
          List({ space: 10 }) {
            ForEach(this.filteredJobViews(), (view: JobView) => {
              ListItem() {
                Column() {
                  this.jobCard(view)
                }.onClick(() => this.selectJob(view))
              }
            }, (view: JobView) => String(view.job.id))
          }.layoutWeight(1).width('100%')
        }
      }
    }
    .width('100%').height('100%').padding(16)
    .linearGradient({ angle: 165, colors: [[$r('app.color.app_background'), 0], [$r('app.color.app_background_end'), 1]] })
  }
}
