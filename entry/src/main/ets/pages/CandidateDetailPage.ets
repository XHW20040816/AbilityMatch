import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { ResourceHelper } from '../common/ResourceHelper';
import { RouteHelper } from '../common/RouteHelper';
import {
  AbilityTag, AdviceLib, HonorCertificate, JobRequirement, MatchResult,
  ProjectExperience, SkillCertificate, SkillDict, Student
} from '../model/Entity';
import { honorRepo, jobRepo, profileRepo, studentRepo, tagRepo } from '../repository/Repositories';
import { MatchEngine } from '../service/MatchEngine';
import { ScoreBar } from '../view/ScoreBar';
import { TagChip } from '../view/TagChip';

@Entry
@Component
struct CandidateDetailPage {
  @State jobId: number = 0;
  @State studentId: number = 1;
  @State student: Student | null = null;
  @State job: JobRequirement | null = null;
  @State tags: AbilityTag[] = [];
  @State result: MatchResult | null = null;
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

  private load(): void {
    Promise.all([
      studentRepo.getById(this.studentId),
      jobRepo.getById(this.jobId),
      tagRepo.listByStudent(this.studentId),
      profileRepo.listSkillCerts(this.studentId),
      profileRepo.listProjects(this.studentId),
      honorRepo.list(this.studentId, { keyword: '', honorType: '', level: '', yearFrom: 0, yearTo: 0, issuer: '' }, 200, 0),
      ResourceHelper.loadAdviceLib(this.context),
      ResourceHelper.loadSkillDict(this.context)
    ]).then((values: [Student | null, JobRequirement | null, AbilityTag[], SkillCertificate[],
      ProjectExperience[], HonorCertificate[], AdviceLib, SkillDict]) => {
      const student: Student | null = values[0] as Student | null;
      const job: JobRequirement | null = values[1] as JobRequirement | null;
      if (student === null || job === null) {
        promptAction.showToast({ message: '候选人数据不存在' });
        return;
      }
      const tags: AbilityTag[] = values[2] as AbilityTag[];
      this.student = student;
      this.job = job;
      this.tags = tags;
      this.result = MatchEngine.compute(
        student, tags, values[3] as SkillCertificate[], values[4] as ProjectExperience[],
        values[5] as HonorCertificate[], job, values[6] as AdviceLib, values[7] as SkillDict
      );
    }).catch((error: Error) => {
      promptAction.showToast({ message: '加载失败：' + error.message });
    });
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text('候选人详情').fontSize(20).fontWeight(FontWeight.Bold)

        if (this.student !== null) {
          Column({ space: 6 }) {
            Text(this.student.name).fontSize(20).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text(this.student.school + ' · ' + this.student.major + ' · ' + this.student.grade + ' · ' +
              this.student.education + (this.student.schoolLevel.length > 0 ? ' · ' + this.student.schoolLevel : ''))
              .fontSize(12).fontColor($r('app.color.text_secondary'))
            Text(`学号：${this.student.studentNo}`).fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
            if (this.student.phone.length > 0) {
              Text(`联系方式：${this.student.phone}`).fontSize(12)
                .fontColor($r('app.color.text_tertiary'))
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .borderRadius(18)
          .backgroundColor($r('app.color.brand_soft'))
        }

        if (this.job !== null) {
          Column({ space: 4 }) {
            Text(this.job.jobTitle).fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text(`${this.job.companyName} · 学历：${this.job.educationReq || '不限'} · 经验：${this.job.experienceYears} 年`)
              .fontSize(12).fontColor($r('app.color.text_secondary'))
            Text('专业方向：' + (this.job.majorDirection || '未设置')).fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
            Text('技能要求：' + (this.job.skillReq.join('、') || '不限')).fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
            Text('证书要求：' + (this.job.certReq.join('、') || '不限')).fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .borderRadius(16)
          .backgroundColor($r('app.color.card_background'))
        }

        if (this.result !== null) {
          Text(`综合匹配度：${this.result.totalScore} 分`).fontSize(20)
            .fontColor($r('app.color.brand_primary')).fontWeight(FontWeight.Bold)
          ScoreBar({ label: '学历', score: this.result.dimensionScores.education })
          ScoreBar({ label: '技能', score: this.result.dimensionScores.skill })
          ScoreBar({ label: '证书', score: this.result.dimensionScores.certificate })
          ScoreBar({ label: '经验', score: this.result.dimensionScores.experience })
          ScoreBar({ label: '荣誉/项目', score: this.result.dimensionScores.honor })
          ScoreBar({ label: '方向', score: this.result.dimensionScores.direction })
          Text('评分已包含学历层级、方向匹配与荣誉相关性，各维度按岗位权重加权。')
            .fontSize(11).fontColor($r('app.color.text_secondary')).width('100%')

          Text('差距项').fontSize(16).fontWeight(FontWeight.Medium)
          if (this.result.gapItems.length === 0) {
            Text('暂无明显差距').fontSize(13).fontColor($r('app.color.success'))
          } else {
            ForEach(this.result.gapItems, (gap: string) => {
              Row() {
                Text('• ' + gap).fontSize(13).fontColor($r('app.color.danger'))
              }.width('100%').padding(8).backgroundColor($r('app.color.card_background')).borderRadius(8)
            }, (gap: string) => gap)
          }

          Text('补齐建议').fontSize(16).fontWeight(FontWeight.Medium)
          ForEach(this.result.suggestions, (suggestion: string) => {
            Row() {
              Text('• ' + suggestion).fontSize(13).fontColor($r('app.color.success'))
            }.width('100%').padding(8).backgroundColor($r('app.color.card_background')).borderRadius(8)
          }, (suggestion: string) => suggestion)

          Text('能力标签').fontSize(16).fontWeight(FontWeight.Medium)
          if (this.tags.length === 0) {
            Text('该候选人暂无能力标签').fontSize(13).fontColor($r('app.color.text_secondary'))
          } else {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.tags, (tag: AbilityTag) => {
                TagChip({ text: tag.tagName, color: $r('app.color.brand_primary') })
              }, (tag: AbilityTag) => String(tag.id))
            }
            .width('100%')
            .padding(12)
            .borderRadius(12)
            .backgroundColor($r('app.color.card_background'))
          }
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
