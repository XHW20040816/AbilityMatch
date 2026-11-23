import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { Constants } from '../common/Constants';
import { PrefsHelper } from '../common/PrefsHelper';
import { ResourceHelper } from '../common/ResourceHelper';
import { Company, JobRequirement, MatchWeights, ParsedRequirement, SkillDict } from '../model/Entity';
import { companyRepo, jobRepo } from '../repository/Repositories';
import { ResumeParseService } from '../service/ResumeParseService';
import { Taxonomy } from '../common/Taxonomy';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Entry
@Component
struct JobPublishPage {
  @State company: Company | null = null;
  @State jobTitle: string = '';
  @State majorDirection: string = '';
  @State rawText: string = '';
  @State parsed: ParsedRequirement | null = null;
  @State weights: MatchWeights = Constants.DEFAULT_WEIGHTS;
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private dict: SkillDict | null = null;

  aboutToAppear(): void {
    Promise.all([
      AppViewModel.load(),
      ResourceHelper.loadSkillDict(this.context),
      PrefsHelper.getNumber(Constants.KEY_W_EDU, Constants.DEFAULT_WEIGHTS.education),
      PrefsHelper.getNumber(Constants.KEY_W_SKILL, Constants.DEFAULT_WEIGHTS.skill),
      PrefsHelper.getNumber(Constants.KEY_W_CERT, Constants.DEFAULT_WEIGHTS.certificate),
      PrefsHelper.getNumber(Constants.KEY_W_EXP, Constants.DEFAULT_WEIGHTS.experience),
      PrefsHelper.getNumber(Constants.KEY_W_HONOR, Constants.DEFAULT_WEIGHTS.honor),
      PrefsHelper.getNumber(Constants.KEY_W_DIRECTION, Constants.DEFAULT_WEIGHTS.direction)
    ]).then(async (values: [void, SkillDict, number, number, number, number, number, number]) => {
      this.company = await companyRepo.getById(AppViewModel.companyId);
      this.dict = values[1];
      this.weights = {
        education: values[2],
        skill: values[3],
        certificate: values[4],
        experience: values[5],
        honor: values[6],
        direction: values[7]
      };
    }).catch((error: Error) => {
      promptAction.showToast({ message: '数据加载失败：' + error.message });
    });
  }

  private parse(): void {
    if (this.rawText.trim().length < 20) {
      promptAction.showToast({ message: '招聘简章至少 20 个字符' });
      return;
    }
    if (this.dict === null) {
      return;
    }
    this.parsed = ResumeParseService.parse(this.rawText, this.dict);
    promptAction.showToast({ message: '解析完成' });
  }

  private save(): void {
    if (this.jobTitle.trim().length === 0 || this.majorDirection.trim().length === 0 ||
      this.rawText.trim().length === 0 || this.company === null) {
      promptAction.showToast({ message: '请填写岗位名称、专业方向、简章，并确认企业资料' });
      return;
    }
    if (this.dict === null) {
      promptAction.showToast({ message: '词典加载中，请稍后再试' });
      return;
    }
    const result: ParsedRequirement = this.parsed === null
      ? ResumeParseService.parse(this.rawText, this.dict)
      : this.parsed as ParsedRequirement;
    const job: JobRequirement = {
      id: 0,
      companyId: this.company.id,
      companyName: this.company.companyName,
      jobTitle: this.jobTitle.trim(),
      majorDirection: this.majorDirection.trim(),
      rawText: this.rawText.trim(),
      educationReq: result.educationReq,
      skillReq: result.skillReq,
      certReq: result.certReq,
      experienceYears: result.experienceYears,
      experienceKeywords: result.experienceKeywords,
      weights: this.normalizedWeights(),
      status: 1
    };
    this.persistWeights().then(() => jobRepo.insert(job)).then(() => {
      promptAction.showToast({ message: '岗位已发布' });
      router.back();
    }).catch((error: Error) => {
      promptAction.showToast({ message: '发布失败：' + error.message });
    });
  }

  private normalizedWeights(): MatchWeights {
    const total: number = this.weights.education + this.weights.skill + this.weights.certificate +
      this.weights.experience + this.weights.honor + this.weights.direction;
    if (total <= 0) {
      return Constants.DEFAULT_WEIGHTS;
    }
    return {
      education: this.weights.education / total,
      skill: this.weights.skill / total,
      certificate: this.weights.certificate / total,
      experience: this.weights.experience / total,
      honor: this.weights.honor / total,
      direction: this.weights.direction / total
    };
  }

  private persistWeights(): Promise<void> {
    return Promise.all([
      PrefsHelper.put(Constants.KEY_W_EDU, this.weights.education),
      PrefsHelper.put(Constants.KEY_W_SKILL, this.weights.skill),
      PrefsHelper.put(Constants.KEY_W_CERT, this.weights.certificate),
      PrefsHelper.put(Constants.KEY_W_EXP, this.weights.experience),
      PrefsHelper.put(Constants.KEY_W_HONOR, this.weights.honor),
      PrefsHelper.put(Constants.KEY_W_DIRECTION, this.weights.direction)
    ]).then(() => {});
  }

  private setWeight(key: keyof MatchWeights, value: number): void {
    const updated: MatchWeights = {
      education: this.weights.education,
      skill: this.weights.skill,
      certificate: this.weights.certificate,
      experience: this.weights.experience,
      honor: this.weights.honor,
      direction: this.weights.direction
    };
    if (key === 'education') { updated.education = value; }
    if (key === 'skill') { updated.skill = value; }
    if (key === 'certificate') { updated.certificate = value; }
    if (key === 'experience') { updated.experience = value; }
    if (key === 'honor') { updated.honor = value; }
    if (key === 'direction') { updated.direction = value; }
    this.weights = updated;
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text('招聘简章录入').fontSize(20).fontWeight(FontWeight.Bold)

        Column({ space: 4 }) {
          Text('发布企业').fontSize(12).fontColor($r('app.color.text_secondary'))
          Text(this.company === null ? '企业资料加载中' : this.company.companyName)
            .fontSize(15).fontWeight(FontWeight.Medium)
            .width('100%')
            .padding(12)
            .borderRadius(12)
            .backgroundColor($r('app.color.brand_soft'))
        }.width('100%')

        TextInput({ placeholder: '岗位名称' }).width('100%').onChange((value: string) => { this.jobTitle = value; })
        Column({ space: 4 }) {
          Text('专业方向（企业招聘设定）').fontSize(12).fontColor($r('app.color.text_secondary'))
          TextInput({ placeholder: '如：软件开发、嵌入式、人工智能', text: this.majorDirection })
            .width('100%')
            .onChange((value: string) => { this.majorDirection = value; })
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(Taxonomy.directionOptions, (direction: string) => {
              Text(direction).fontSize(11)
                .fontColor(this.majorDirection === direction ? $r('app.color.on_primary') : $r('app.color.text_label'))
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .margin({ right: 6, bottom: 6 })
                .borderRadius(12)
                .backgroundColor(this.majorDirection === direction ?
                  $r('app.color.brand_primary') : $r('app.color.chip_background'))
                .onClick(() => { this.majorDirection = direction; })
            }, (direction: string) => direction)
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        TextArea({ placeholder: '粘贴招聘简章文本', text: this.rawText })
          .width('100%').height(140)
          .onChange((value: string) => { this.rawText = value; })
        Button('解析岗位要求').width('100%').onClick(() => this.parse())

        if (this.parsed !== null) {
          Column({ space: 6 }) {
            Text('解析结果').fontSize(16).fontWeight(FontWeight.Medium)
            Text(`学历：${this.parsed.educationReq || '未识别'}`).fontSize(13)
            Text(`技能：${this.parsed.skillReq.join('、') || '未识别'}`).fontSize(13)
            Text(`证书：${this.parsed.certReq.join('、') || '未识别'}`).fontSize(13)
            Text(`经验：${this.parsed.experienceYears} 年`).fontSize(13)
          }
          .width('100%').alignItems(HorizontalAlign.Start)
          .padding(14).borderRadius(12).backgroundColor($r('app.color.card_background'))
        }

        Text('匹配权重').fontSize(16).fontWeight(FontWeight.Medium)
        Row() { Text('学历').fontSize(12).width(60); Slider({ value: this.weights.education, min: 0, max: 1, step: 0.05 }).layoutWeight(1).onChange((v: number, mode: SliderChangeMode) => { if (mode === SliderChangeMode.End) { this.setWeight('education', v); } }) }
        Row() { Text('技能').fontSize(12).width(60); Slider({ value: this.weights.skill, min: 0, max: 1, step: 0.05 }).layoutWeight(1).onChange((v: number, mode: SliderChangeMode) => { if (mode === SliderChangeMode.End) { this.setWeight('skill', v); } }) }
        Row() { Text('证书').fontSize(12).width(60); Slider({ value: this.weights.certificate, min: 0, max: 1, step: 0.05 }).layoutWeight(1).onChange((v: number, mode: SliderChangeMode) => { if (mode === SliderChangeMode.End) { this.setWeight('certificate', v); } }) }
        Row() { Text('经验').fontSize(12).width(60); Slider({ value: this.weights.experience, min: 0, max: 1, step: 0.05 }).layoutWeight(1).onChange((v: number, mode: SliderChangeMode) => { if (mode === SliderChangeMode.End) { this.setWeight('experience', v); } }) }
        Row() { Text('荣誉').fontSize(12).width(60); Slider({ value: this.weights.honor, min: 0, max: 1, step: 0.05 }).layoutWeight(1).onChange((v: number, mode: SliderChangeMode) => { if (mode === SliderChangeMode.End) { this.setWeight('honor', v); } }) }
        Row() { Text('方向').fontSize(12).width(60); Slider({ value: this.weights.direction, min: 0, max: 1, step: 0.05 }).layoutWeight(1).onChange((v: number, mode: SliderChangeMode) => { if (mode === SliderChangeMode.End) { this.setWeight('direction', v); } }) }

        Button('发布岗位').width('100%').backgroundColor($r('app.color.success')).onClick(() => this.save())
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
