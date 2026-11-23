import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { ResourceHelper } from '../common/ResourceHelper';
import { RouteHelper } from '../common/RouteHelper';
import { Style3D } from '../common/Style3D';
import {
  AbilityTag, AdviceLib, HonorCertificate, JobRequirement, MatchResult,
  ProjectExperience, SkillCertificate, SkillDict, Student
} from '../model/Entity';
import { honorRepo, jobRepo, profileRepo, studentRepo, tagRepo } from '../repository/Repositories';
import { MatchEngine } from '../service/MatchEngine';
import { SemanticMatchService } from '../service/SemanticMatchService';
import { Card3D } from '../view/Card3D';
import { ScoreBar } from '../view/ScoreBar';
import { ScoreBreakdown } from '../view/ScoreBreakdown';

@Entry
@Component
struct JobDetailPage {
  @State jobId: number = 0;
  @State studentId: number = 1;
  @State job: JobRequirement | null = null;
  @State result: MatchResult | null = null;
  @State aiLoading: boolean = false;
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    const params: Record<string, Object> = RouteHelper.params();
    if (params['jobId'] !== undefined) {
      this.jobId = Number(params['jobId']);
    }
    if (params['studentId'] !== undefined) {
      this.studentId = Number(params['studentId']);
    }
    this.load();
  }

  private async load(): Promise<void> {
    try {
      const values: [JobRequirement | null, Student | null, AbilityTag[], SkillCertificate[],
        ProjectExperience[], HonorCertificate[], AdviceLib, SkillDict] = await Promise.all([
        jobRepo.getById(this.jobId),
        studentRepo.getById(this.studentId),
        tagRepo.listByStudent(this.studentId),
        profileRepo.listSkillCerts(this.studentId),
        profileRepo.listProjects(this.studentId),
        honorRepo.list(this.studentId, { keyword: '', honorType: '', level: '', yearFrom: 0, yearTo: 0, issuer: '' }, 200, 0),
        ResourceHelper.loadAdviceLib(this.context),
        ResourceHelper.loadSkillDict(this.context)
      ]);
      const job: JobRequirement = values[0] as JobRequirement;
      const student: Student = values[1] as Student;
      const tags: AbilityTag[] = values[2] as AbilityTag[];
      const certs: SkillCertificate[] = values[3] as SkillCertificate[];
      const projects: ProjectExperience[] = values[4] as ProjectExperience[];
      const honors: HonorCertificate[] = values[5] as HonorCertificate[];
      const advice: AdviceLib = values[6] as AdviceLib;
      const dict: SkillDict = values[7] as SkillDict;
      this.job = job;
      // 先给出本地规则分，页面立刻可用；随后异步叠加语义分，拿到后再刷新
      const base: MatchResult = MatchEngine.compute(student, tags, certs, projects, honors, job, advice, dict);
      this.result = base;
      const enabled: boolean = await SemanticMatchService.isEnabled();
      if (!enabled) {
        return;
      }
      this.aiLoading = true;
      this.result = await SemanticMatchService.enhance(this.studentId, job, base);
      this.aiLoading = false;
    } catch (error) {
      const message: string = error instanceof Error ? error.message : String(error);
      promptAction.showToast({ message: '加载失败：' + message });
    }
  }

  private openGrowthPlan(): void {
    const job: JobRequirement | null = this.job;
    if (job === null) {
      return;
    }
    router.pushUrl({
      url: 'pages/GrowthGuidePage',
      params: { studentId: this.studentId, majorDirection: job.majorDirection }
    }).catch((error: Error) => {
      promptAction.showToast({ message: '打开成长规划失败：' + error.message });
    });
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text('岗位匹配详情').fontSize(20).fontWeight(FontWeight.Bold)
        if (this.job !== null) {
          Card3D({
            faceColors: Style3D.whiteFace,
            depthColor: Style3D.whiteDepth,
            radius: 22,
            depth: 6,
            facePadding: 16,
            shadowRadius: 18
          }) {
            Column({ space: 10 }) {
              Row() {
                Column({ space: 4 }) {
                  Text(this.job.jobTitle).fontSize(19).fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.job.companyName)
                    .fontSize(12).fontColor($r('app.color.text_secondary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`学历：${this.job.educationReq || '不限'} · 经验：${this.job.experienceYears} 年`)
                    .fontSize(12).fontColor($r('app.color.text_tertiary'))
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text(this.job.majorDirection || '通用')
                  .fontSize(11)
                  .fontColor($r('app.color.on_primary'))
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .borderRadius(12)
                  .linearGradient({ angle: 145, colors: [['#3AD8DA', 0], ['#0FA3AE', 1]] })
                  .border({ width: 1, color: '#4DFFFFFF' })
                  .shadow({ radius: 8, color: '#400A8089', offsetX: 0, offsetY: 3 })
              }
              .width('100%')

              Divider().color('#1A0E5C5C')

              Text('技能要求：' + (this.job.skillReq.join('、') || '不限')).fontSize(13)
              Text('证书要求：' + (this.job.certReq.join('、') || '不限')).fontSize(13)

              if (this.job.majorDirection.length > 0) {
                Button('按此方向制定成长规划')
                  .fontSize(13)
                  .height(38)
                  .borderRadius(19)
                  .linearGradient({ angle: 135, colors: [['#3AD8DA', 0], ['#0FA3AE', 1]] })
                  .border({ width: 1, color: '#4DFFFFFF' })
                  .shadow({ radius: 10, color: '#400A8089', offsetX: 0, offsetY: 4 })
                  .fontColor($r('app.color.on_primary'))
                  .onClick(() => this.openGrowthPlan())
              }
            }
            .width('100%')
          }

          Text('招聘简章原文').fontSize(14).fontWeight(FontWeight.Medium).margin({ top: 8 })
          Text(this.job.rawText).fontSize(12).fontColor($r('app.color.text_tertiary'))
            .width('100%')
            .padding(14)
            .borderRadius(14)
            .linearGradient({ angle: 145, colors: [['#FFFFFF', 0], ['#F1FAF9', 1]] })
            .border({ width: 1, color: '#8CFFFFFF' })
            .shadow({ radius: 12, color: '#1A0E5C5C', offsetX: 0, offsetY: 5 })
        }

        if (this.result !== null) {
          Card3D({
            faceColors: Style3D.whiteFace,
            depthColor: Style3D.whiteDepth,
            radius: 22,
            depth: 6,
            facePadding: 16,
            shadowRadius: 18
          }) {
            Column({ space: 12 }) {
              Row() {
                Text('综合匹配度').fontSize(14).fontColor($r('app.color.text_secondary'))
                Blank()
                Text(`${this.result.totalScore}`)
                  .fontSize(30)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.brand_primary'))
                Text(' 分').fontSize(12).fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .alignItems(VerticalAlign.Bottom)

              Row({ space: 8 }) {
                if (this.aiLoading) {
                  Text('AI 语义分析中…').fontSize(10).fontColor('#7C63FF')
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(10)
                    .backgroundColor('#148E7CFF')
                } else if (this.result.semantic === true) {
                  Text(`AI 语义已融合${this.result.semanticModel !== undefined ?
                    ' · ' + this.result.semanticModel : ''}`)
                    .fontSize(10).fontColor($r('app.color.on_primary'))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(10)
                    .linearGradient({ angle: 135, colors: [['#8E7CFF', 0], ['#5B45E0', 1]] })
                } else {
                  Text('本地六维规则评分').fontSize(10).fontColor($r('app.color.text_tertiary'))
                }
              }
              .width('100%')
              .justifyContent(FlexAlign.Start)

              ScoreBar({ label: '学历', score: this.result.dimensionScores.education })
              ScoreBar({ label: '技能', score: this.result.dimensionScores.skill })
              ScoreBar({ label: '证书', score: this.result.dimensionScores.certificate })
              ScoreBar({ label: '经验', score: this.result.dimensionScores.experience })
              ScoreBar({ label: '荣誉/项目', score: this.result.dimensionScores.honor })
              ScoreBar({ label: '专业方向', score: this.result.dimensionScores.direction })
            }
            .width('100%')
          }

          ScoreBreakdown({
            result: this.result,
            weights: (this.job as JobRequirement).weights
          })

          Text('差距项').fontSize(16).fontWeight(FontWeight.Medium)
          ForEach(this.result.gapItems, (gap: string) => {
            Row() {
              Text('• ' + gap).fontSize(13).fontColor($r('app.color.danger'))
            }.width('100%').padding(8).backgroundColor($r('app.color.card_background')).borderRadius(8)
          }, (gap: string) => gap)

          Text('补齐建议').fontSize(16).fontWeight(FontWeight.Medium)
          ForEach(this.result.suggestions, (suggestion: string) => {
            Row() {
              Text('• ' + suggestion).fontSize(13).fontColor($r('app.color.success'))
            }.width('100%').padding(8).backgroundColor($r('app.color.card_background')).borderRadius(8)
          }, (suggestion: string) => suggestion)
        }
      }
      .width('100%')
      .padding(20)
      .linearGradient({ angle: 165, colors: [[$r('app.color.app_background'), 0], [$r('app.color.app_background_end'), 1]] })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
