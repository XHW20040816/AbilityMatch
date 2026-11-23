import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { Constants } from '../common/Constants';
import { JobFilter } from '../common/JobFilter';
import { PrefsHelper } from '../common/PrefsHelper';
import { ResourceHelper } from '../common/ResourceHelper';
import { RouteHelper } from '../common/RouteHelper';
import { Style3D } from '../common/Style3D';
import {
  AbilityTag, AdviceLib, HonorCertificate, JobRequirement, MatchResult,
  ProjectExperience, SkillCertificate, SkillDict, Student
} from '../model/Entity';
import { honorRepo, jobRepo, matchRepo, profileRepo, studentRepo, tagRepo } from '../repository/Repositories';
import { MatchEngine } from '../service/MatchEngine';
import { SemanticItem, SemanticMatchService } from '../service/SemanticMatchService';
import { Card3D } from '../view/Card3D';
import { EmptyState } from '../view/EmptyState';

interface JobView {
  job: JobRequirement;
  result: MatchResult;
}

@Entry
@Component
struct JobListPage {
  @State studentId: number = 1;
  @State views: JobView[] = [];
  @State directionFilter: string = '';
  @State keyword: string = '';
  @State recentSearches: string[] = [];
  /** 匹配方式说明：本地规则分 / 已融合大模型语义分 / 降级原因 */
  @State aiHint: string = '';
  private readonly historySize: number = 5;
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    const params: Record<string, Object> = RouteHelper.params();
    if (params['studentId'] !== undefined) {
      this.studentId = Number(params['studentId']);
    }
    this.loadHistory();
    this.load();
  }

  private loadHistory(): void {
    PrefsHelper.getString(Constants.KEY_JOB_SEARCH, '').then((text: string) => {
      if (text.length === 0) {
        this.recentSearches = [];
        return;
      }
      try {
        this.recentSearches = JSON.parse(text) as string[];
      } catch (error) {
        this.recentSearches = [];
      }
    });
  }

  private submitSearch(value: string): void {
    this.keyword = value.trim();
    const history: string[] = JobFilter.pushHistory(this.recentSearches, this.keyword, this.historySize);
    this.recentSearches = history;
    PrefsHelper.put(Constants.KEY_JOB_SEARCH, JSON.stringify(history));
  }

  private clearHistory(): void {
    this.recentSearches = [];
    PrefsHelper.put(Constants.KEY_JOB_SEARCH, '');
  }

  private async load(): Promise<void> {
    try {
      const values: [Student | null, AbilityTag[], SkillCertificate[], ProjectExperience[],
        HonorCertificate[], JobRequirement[], AdviceLib, SkillDict] = await Promise.all([
        studentRepo.getById(this.studentId),
        tagRepo.listByStudent(this.studentId),
        profileRepo.listSkillCerts(this.studentId),
        profileRepo.listProjects(this.studentId),
        honorRepo.list(this.studentId, { keyword: '', honorType: '', level: '', yearFrom: 0, yearTo: 0, issuer: '' }, 200, 0),
        jobRepo.listActive(),
        ResourceHelper.loadAdviceLib(this.context),
        ResourceHelper.loadSkillDict(this.context)
      ]);
      const student: Student = values[0] as Student;
      const tags: AbilityTag[] = values[1] as AbilityTag[];
      const certs: SkillCertificate[] = values[2] as SkillCertificate[];
      const projects: ProjectExperience[] = values[3] as ProjectExperience[];
      const honors: HonorCertificate[] = values[4] as HonorCertificate[];
      const jobs: JobRequirement[] = values[5] as JobRequirement[];
      const advice: AdviceLib = values[6] as AdviceLib;
      const dict: SkillDict = values[7] as SkillDict;

      // 第一步：本地六维加权规则分（离线可用，作为基线）
      const baseViews: JobView[] = [];
      for (const job of jobs) {
        baseViews.push({ job: job, result: MatchEngine.compute(student, tags, certs, projects, honors, job, advice, dict) });
      }

      // 先展示规则分结果，避免等待大模型时白屏
      baseViews.sort((a: JobView, b: JobView) => b.result.totalScore - a.result.totalScore);
      this.views = baseViews;

      // 第二步：大模型语义增强（仅前 K 个，未配置或失败时自动沿用规则分）
      const items: SemanticItem[] = baseViews.map((view: JobView): SemanticItem => {
        return { studentId: this.studentId, job: view.job, result: view.result } as SemanticItem;
      });
      const enhanced: MatchResult[] = await SemanticMatchService.enhanceBatch(items, Constants.SEMANTIC_TOPK);
      const views: JobView[] = [];
      const tasks: Promise<number>[] = [];
      let semanticCount: number = 0;
      for (let i = 0; i < baseViews.length; i++) {
        const result: MatchResult = enhanced[i];
        if (result.semantic === true) {
          semanticCount++;
        }
        views.push({ job: baseViews[i].job, result: result });
        tasks.push(matchRepo.replaceToday({
          id: 0,
          studentId: this.studentId,
          jobId: baseViews[i].job.id,
          direction: 0,
          totalScore: result.totalScore,
          dimensionScores: result.dimensionScores,
          gapItems: result.gapItems,
          suggestions: result.suggestions,
          createTime: Date.now()
        }));
      }
      await Promise.all(tasks);
      views.sort((a: JobView, b: JobView) => b.result.totalScore - a.result.totalScore);
      this.views = views;
      await this.updateAiHint(semanticCount);
    } catch (error) {
      const message: string = error instanceof Error ? error.message : String(error);
      promptAction.showToast({ message: '匹配失败：' + message });
    }
  }

  private async updateAiHint(semanticCount: number): Promise<void> {
    if (semanticCount > 0) {
      this.aiHint = `已融合大模型语义评分：${semanticCount} 个岗位（本地六维 + LLM）`;
      return;
    }
    const enabled: boolean = await SemanticMatchService.isEnabled();
    if (enabled) {
      const reason: string = SemanticMatchService.getLastError();
      this.aiHint = reason.length > 0 ? `大模型调用失败，已用本地规则分：${reason}` : '大模型未返回有效结果，已用本地规则分';
    } else {
      this.aiHint = '当前为本地六维加权评分，配置大模型后自动叠加语义分';
    }
  }

  private directions(): string[] {
    const result: string[] = [];
    for (const view of this.views) {
      if (view.job.majorDirection.length > 0 && result.indexOf(view.job.majorDirection) < 0) {
        result.push(view.job.majorDirection);
      }
    }
    return result;
  }

  private filteredViews(): JobView[] {
    if (this.directionFilter.length === 0 && this.keyword.length === 0) {
      return this.views;
    }
    const jobs: JobRequirement[] = this.views.map((view: JobView) => view.job);
    const ids: number[] = JobFilter.matchIds(jobs, this.directionFilter, this.keyword);
    return this.views.filter((view: JobView) => ids.indexOf(view.job.id) >= 0);
  }

  build() {
    Column({ space: 12 }) {
      Column({ space: 6 }) {
        Text('岗位推荐').fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Text(this.aiHint.length > 0 ? this.aiHint : '已按匹配度排序，点开卡片看差距与建议')
          .fontSize(12).fontColor($r('app.color.text_secondary'))
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })
      .borderRadius(20)
      .linearGradient({ angle: 140, colors: [['#FFFFFF', 0], [$r('app.color.brand_soft'), 1]] })
      .border({ width: 1, color: Style3D.highlight })
      .shadow({ radius: 16, color: Style3D.shadowSoft, offsetX: 0, offsetY: 6 })

      Row({ space: 8 }) {
        TextInput({ placeholder: '搜索岗位 / 企业 / 技能', text: this.keyword })
          .id('job_keyword')
          .layoutWeight(1)
          .borderRadius(18)
          .enterKeyType(EnterKeyType.Search)
          .onChange((value: string) => { this.keyword = value; })
          .onSubmit(() => this.submitSearch(this.keyword))
        Button('搜索').fontSize(13).borderRadius(18)
          .linearGradient({ angle: 135, colors: [[Style3D.heroFace[0], 0], [Style3D.heroFace[1], 1]] })
          .border({ width: 1, color: Style3D.highlight })
          .fontColor($r('app.color.on_primary'))
          .shadow({ radius: 10, color: '#4D0A7C92', offsetX: 0, offsetY: 4 })
          .onClick(() => this.submitSearch(this.keyword))
      }
      .width('100%')

      if (this.recentSearches.length > 0) {
        Row() {
          Text('最近搜索').fontSize(11).fontColor($r('app.color.text_secondary'))
          Blank()
          Text('清空').fontSize(11).fontColor($r('app.color.brand_primary'))
            .onClick(() => this.clearHistory())
        }
        .width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.recentSearches, (item: string) => {
            Text(item).fontSize(11).fontColor($r('app.color.text_label'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .margin({ right: 6, bottom: 6 })
              .borderRadius(14)
              .backgroundColor(this.keyword === item ? $r('app.color.brand_primary') : $r('app.color.chip_background'))
              .fontColor(this.keyword === item ? $r('app.color.on_primary') : $r('app.color.text_label'))
              .onClick(() => this.submitSearch(item))
          }, (item: string) => item)
        }
        .width('100%')
      }

      if (this.directions().length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          Text('全部方向').fontSize(11)
            .fontColor(this.directionFilter.length === 0 ? $r('app.color.on_primary') : $r('app.color.text_label'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .margin({ right: 6, bottom: 6 })
            .borderRadius(14)
            .backgroundColor(this.directionFilter.length === 0 ?
              $r('app.color.brand_primary') : $r('app.color.chip_background'))
            .onClick(() => { this.directionFilter = ''; })
          ForEach(this.directions(), (direction: string) => {
            Text(direction).fontSize(11)
              .fontColor(this.directionFilter === direction ? $r('app.color.on_primary') : $r('app.color.text_label'))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .margin({ right: 6, bottom: 6 })
              .borderRadius(14)
              .backgroundColor(this.directionFilter === direction ?
                $r('app.color.brand_primary') : $r('app.color.chip_background'))
              .onClick(() => { this.directionFilter = direction; })
          }, (direction: string) => direction)
        }
        .width('100%')
      }

      if (this.filteredViews().length === 0) {
        EmptyState({ text: '暂无有效岗位' })
      } else {
        List({ space: 12 }) {
          ForEach(this.filteredViews(), (item: JobView, index: number) => {
            ListItem() {
              Card3D({
                faceColors: Style3D.whiteFace,
                depthColor: Style3D.whiteDepth,
                radius: 20,
                depth: 5,
                facePadding: 16,
                shadowRadius: 16,
                action: () => {
                  router.pushUrl({
                    url: 'pages/JobDetailPage',
                    params: { jobId: item.job.id, studentId: this.studentId, score: item.result.totalScore }
                  });
                }
              }) {
                Column({ space: 10 }) {
                  Row() {
                    Text(item.job.jobTitle).fontSize(17).fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary')).layoutWeight(1)
                    Column({ space: 2 }) {
                      Text(`${item.result.totalScore}`).fontSize(18).fontWeight(FontWeight.Bold)
                        .fontColor($r('app.color.on_primary'))
                      Text('匹配分').fontSize(10).fontColor('#E6FFFFFF')
                    }
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .borderRadius(16)
                    .linearGradient({ angle: 145, colors: [['#FFC7A3', 0], ['#FF8F5C', 1]] })
                    .border({ width: 1, color: '#66FFFFFF' })
                    .shadow({ radius: 8, color: '#40DE7440', offsetX: 0, offsetY: 4 })
                  }.width('100%')

                  Row({ space: 8 }) {
                    Text(item.job.companyName).fontSize(12).fontColor($r('app.color.text_secondary'))
                    if (item.job.majorDirection.length > 0) {
                      Text(item.job.majorDirection).fontSize(11)
                        .fontColor($r('app.color.brand_primary'))
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .borderRadius(10)
                        .backgroundColor($r('app.color.brand_soft'))
                    }
                    Text(item.job.educationReq || '学历不限').fontSize(11)
                      .fontColor($r('app.color.brand_primary'))
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .borderRadius(10)
                      .backgroundColor($r('app.color.chip_background'))
                    if (item.result.semantic === true) {
                      Text('AI 语义').fontSize(10).fontColor($r('app.color.on_primary'))
                        .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                        .borderRadius(10)
                        .linearGradient({ angle: 135, colors: [['#8E7CFF', 0], ['#5B45E0', 1]] })
                    }
                  }

                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(item.job.skillReq.length > 0 ? item.job.skillReq : ['不限'],
                      (skill: string) => {
                        Text(skill).fontSize(11).fontColor($r('app.color.text_label'))
                          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                          .margin({ right: 6, bottom: 4 })
                          .borderRadius(12)
                          .backgroundColor(index % 2 === 0 ? $r('app.color.surface_muted') : $r('app.color.accent_peach_soft'))
                      }, (skill: string) => skill)
                  }
                }
                .width('100%')
              }
            }
          }, (item: JobView) => String(item.job.id))
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding(18)
    .linearGradient({
      angle: 165,
      colors: [[$r('app.color.app_background'), 0], [$r('app.color.app_background_end'), 1]]
    })
  }
}
