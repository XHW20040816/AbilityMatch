import { common } from '@kit.AbilityKit';
import { componentSnapshot, promptAction } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { DbHelper } from '../common/DbHelper';
import { FileHelper } from '../common/FileHelper';
import { ResourceHelper } from '../common/ResourceHelper';
import { RouteHelper } from '../common/RouteHelper';
import {
  AbilityTag, HonorCertificate, ProjectExperience, SkillCertificate, SkillDict, Student
} from '../model/Entity';
import { HonorLevel, TagCategory } from '../model/Enums';
import { honorRepo, profileRepo, studentRepo, tagRepo } from '../repository/Repositories';
import { ExportService } from '../service/ExportService';
import { TagExtractService } from '../service/TagExtractService';
import { EmptyState } from '../view/EmptyState';

@Entry
@Component
struct PortraitPage {
  @State studentId: number = 1;
  @State student: Student | null = null;
  @State tags: AbilityTag[] = [];
  @State honors: HonorCertificate[] = [];
  @State skillCerts: SkillCertificate[] = [];
  @State projects: ProjectExperience[] = [];
  @State certName: string = '';
  @State certIssuer: string = '';
  @State certYear: string = '';
  @State certLevel: string = '';
  @State editingCertId: number = 0;
  @State projectName: string = '';
  @State projectRole: string = '';
  @State projectStart: string = '';
  @State projectEnd: string = '';
  @State projectTags: string = '';
  @State projectDesc: string = '';
  @State editingProjectId: number = 0;
  @State editingTagId: number = 0;
  @State tagEditName: string = '';
  @State manualTagName: string = '';
  private exporter: ExportService = new ExportService();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private dict: SkillDict | null = null;
  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);
  private canvasReady: boolean = false;

  aboutToAppear(): void {
    const params: Record<string, Object> = RouteHelper.params();
    if (params['studentId'] !== undefined) {
      this.studentId = Number(params['studentId']);
    }
    ResourceHelper.loadSkillDict(this.context).then((dict: SkillDict) => {
      this.dict = dict;
      this.load();
    });
  }

  private load(): void {
    studentRepo.getById(this.studentId).then((student: Student | null) => {
      this.student = student;
      return tagRepo.listByStudent(this.studentId);
    }).then((tags: AbilityTag[]) => {
      this.tags = tags;
      return honorRepo.list(this.studentId, { keyword: '', honorType: '', level: '', yearFrom: 0, yearTo: 0, issuer: '' }, 200, 0);
    }).then((honors: HonorCertificate[]) => {
      this.honors = honors;
      const referenced: string[] = honors.map((honor: HonorCertificate) => honor.imagePath);
      FileHelper.cleanupOrphans(this.context, referenced);
      return profileRepo.listSkillCerts(this.studentId);
    }).then((certs: SkillCertificate[]) => {
      this.skillCerts = certs;
      return profileRepo.listProjects(this.studentId);
    }).then((projects: ProjectExperience[]) => {
      this.projects = projects;
      this.drawRadar();
    }).catch((error: Error) => {
      promptAction.showToast({ message: '加载失败：' + error.message });
    });
  }

  private resetCertForm(): void {
    this.certName = '';
    this.certIssuer = '';
    this.certYear = '';
    this.certLevel = '';
    this.editingCertId = 0;
  }

  private resetProjectForm(): void {
    this.projectName = '';
    this.projectRole = '';
    this.projectStart = '';
    this.projectEnd = '';
    this.projectTags = '';
    this.projectDesc = '';
    this.editingProjectId = 0;
  }

  private saveSkillCert(): void {
    if (this.certName.trim().length === 0 || this.dict === null) {
      promptAction.showToast({ message: '请输入证书名称' });
      return;
    }
    let imagePath: string = '';
    for (const item of this.skillCerts) {
      if (item.id === this.editingCertId) {
        imagePath = item.imagePath;
      }
    }
    const cert: SkillCertificate = {
      id: this.editingCertId,
      studentId: this.studentId,
      certName: this.certName.trim(),
      issuer: this.certIssuer.trim(),
      obtainYear: Number(this.certYear) > 0 ? Number(this.certYear) : new Date().getFullYear(),
      level: this.certLevel.trim(),
      imagePath: imagePath
    };
    DbHelper.runInTransaction(async (): Promise<void> => {
      const id: number = cert.id === 0
        ? await profileRepo.insertSkillCert(cert)
        : await profileRepo.updateSkillCert(cert).then((): number => cert.id);
      await tagRepo.deleteBySource(this.studentId, 'SKILL_CERT', id);
      const tags: AbilityTag[] = TagExtractService.fromSkillCert(
        this.studentId, id, cert, this.dict as SkillDict
      );
      for (const tag of tags) {
        await tagRepo.insert(tag);
      }
    }).then(() => {
      this.resetCertForm();
      this.load();
      promptAction.showToast({ message: '技能证书已保存' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '保存失败：' + error.message });
    });
  }

  private editSkillCert(cert: SkillCertificate): void {
    this.editingCertId = cert.id;
    this.certName = cert.certName;
    this.certIssuer = cert.issuer;
    this.certYear = cert.obtainYear > 0 ? String(cert.obtainYear) : '';
    this.certLevel = cert.level;
  }

  private removeSkillCert(cert: SkillCertificate): void {
    tagRepo.deleteBySource(this.studentId, 'SKILL_CERT', cert.id).then(() => {
      return profileRepo.removeSkillCert(cert.id);
    }).then(() => {
      if (this.editingCertId === cert.id) {
        this.resetCertForm();
      }
      this.load();
      promptAction.showToast({ message: '已删除' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '删除失败：' + error.message });
    });
  }

  private saveProject(): void {
    if (this.projectName.trim().length === 0) {
      promptAction.showToast({ message: '请输入项目名称' });
      return;
    }
    const list: string[] = this.projectTags.split(',')
      .map((value: string) => value.trim())
      .filter((value: string) => value.length > 0);
    const project: ProjectExperience = {
      id: this.editingProjectId,
      studentId: this.studentId,
      projectName: this.projectName.trim(),
      role: this.projectRole.trim().length > 0 ? this.projectRole.trim() : '成员',
      startDate: Number(this.projectStart) > 0 ? Number(this.projectStart) : 0,
      endDate: Number(this.projectEnd) > 0 ? Number(this.projectEnd) : 0,
      description: this.projectDesc.trim(),
      tags: list
    };
    DbHelper.runInTransaction(async (): Promise<void> => {
      const id: number = project.id === 0
        ? await profileRepo.insertProject(project)
        : await profileRepo.updateProject(project).then((): number => project.id);
      await tagRepo.deleteBySource(this.studentId, 'PROJECT', id);
      const tags: AbilityTag[] = TagExtractService.fromProject(this.studentId, id, list);
      for (const tag of tags) {
        await tagRepo.insert(tag);
      }
    }).then(() => {
      this.resetProjectForm();
      this.load();
      promptAction.showToast({ message: '项目经历已保存' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '保存失败：' + error.message });
    });
  }

  private editProject(project: ProjectExperience): void {
    this.editingProjectId = project.id;
    this.projectName = project.projectName;
    this.projectRole = project.role;
    this.projectStart = project.startDate > 0 ? String(project.startDate) : '';
    this.projectEnd = project.endDate > 0 ? String(project.endDate) : '';
    this.projectTags = project.tags.join(',');
    this.projectDesc = project.description;
  }

  private removeProject(project: ProjectExperience): void {
    tagRepo.deleteBySource(this.studentId, 'PROJECT', project.id).then(() => {
      return profileRepo.removeProject(project.id);
    }).then(() => {
      if (this.editingProjectId === project.id) {
        this.resetProjectForm();
      }
      this.load();
      promptAction.showToast({ message: '已删除' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '删除失败：' + error.message });
    });
  }

  private exportPortrait(): void {
    if (this.student === null) {
      return;
    }
    this.exporter.savePortraitJson(
      this.context, this.student, this.tags, this.honors, this.skillCerts, this.projects
    ).then((saved: boolean) => {
      promptAction.showToast({ message: saved ? '能力档案已保存到指定位置' : '已取消导出' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '导出失败：' + error.message });
    });
  }

  private exportPortraitHtml(): void {
    if (this.student === null) {
      return;
    }
    this.exporter.savePortraitHtml(
      this.context, this.student, this.tags, this.honors, this.skillCerts, this.projects
    ).then((saved: boolean) => {
      promptAction.showToast({ message: saved ? 'HTML 能力档案已保存' : '已取消导出' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '导出失败：' + error.message });
    });
  }

  private exportPortraitImage(): void {
    if (this.student === null) {
      return;
    }
    componentSnapshot.get('portrait_poster').then((pixelMap: image.PixelMap): Promise<boolean> => {
      return this.exporter.savePortraitImage(this.context, pixelMap);
    }).then((saved: boolean) => {
      promptAction.showToast({ message: saved ? '能力画像长图已保存' : '已取消导出' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '生成失败：' + error.message });
    });
  }

  @Builder
  posterCard() {
    Column({ space: 12 }) {
      Row() {
        Text(this.student === null ? '' : this.student.name)
          .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#1F2933')
        Blank()
        Text('能力画像').fontSize(13).fontColor('#5A6B7B')
      }
      .width('100%')

      Text(this.student === null ? '' :
        `${this.student.school} · ${this.student.major} · ${this.student.grade}`)
        .fontSize(12).fontColor('#5A6B7B').width('100%').maxLines(2)

      Divider().color('#E4E9EF')

      Text('核心能力标签').fontSize(11).fontColor('#8494A5').width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.tags.slice(0, 12), (tag: AbilityTag) => {
          Text(tag.tagName).fontSize(11).fontColor('#2F6BFF')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .margin({ right: 6, bottom: 6 })
            .borderRadius(12).backgroundColor('#EFF4FF')
        }, (tag: AbilityTag) => String(tag.id))
      }
      .width('100%')

      Row() {
        Column() {
          Text(String(this.honors.length)).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#1F2933')
          Text('荣誉奖项').fontSize(10).fontColor('#8494A5')
        }.layoutWeight(1)
        Column() {
          Text(String(this.skillCerts.length)).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#1F2933')
          Text('技能证书').fontSize(10).fontColor('#8494A5')
        }.layoutWeight(1)
        Column() {
          Text(String(this.projects.length)).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#1F2933')
          Text('项目经历').fontSize(10).fontColor('#8494A5')
        }.layoutWeight(1)
      }
      .width('100%').padding({ top: 8, bottom: 8 })
      .backgroundColor('#F7F9FC').borderRadius(12)

      Text(`生成于 ${new Date().toLocaleDateString()}｜能力画像与岗位匹配应用`)
        .fontSize(9).fontColor('#A9B6C4').width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
    .id('portrait_poster')
  }

  private startEditTag(tag: AbilityTag): void {
    this.editingTagId = tag.id;
    this.tagEditName = tag.tagName;
  }

  private saveTagName(tag: AbilityTag): void {
    const name: string = this.tagEditName.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '标签名称不能为空' });
      return;
    }
    tagRepo.renameAndMerge(this.studentId, tag.tagName, name).then(() => {
      this.editingTagId = 0;
      this.tagEditName = '';
      this.load();
      promptAction.showToast({ message: '标签已更新并合并重复项' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '更新失败：' + error.message });
    });
  }

  private removeTag(tag: AbilityTag): void {
    tagRepo.removeById(tag.id).then(() => {
      if (this.editingTagId === tag.id) {
        this.editingTagId = 0;
      }
      this.load();
      promptAction.showToast({ message: '标签已删除' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '删除失败：' + error.message });
    });
  }

  private addManualTag(): void {
    const name: string = this.manualTagName.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '请输入标签名称' });
      return;
    }
    tagRepo.addManual(this.studentId, name, TagCategory.SKILL).then(() => {
      this.manualTagName = '';
      this.load();
      promptAction.showToast({ message: '标签已加入画像' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '添加失败：' + error.message });
    });
  }

  private sourceLabel(source: string): string {
    if (source === 'HONOR') {
      return '荣誉证书';
    }
    if (source === 'SKILL_CERT') {
      return '技能证书';
    }
    if (source === 'PROJECT') {
      return '项目经历';
    }
    if (source === 'MANUAL') {
      return '手动添加';
    }
    return '其他来源';
  }

  private categoryLabel(category: TagCategory): string {
    if (category === TagCategory.SKILL) {
      return '技能';
    }
    if (category === TagCategory.CERTIFICATE) {
      return '证书';
    }
    if (category === TagCategory.HONOR) {
      return '荣誉';
    }
    return '项目';
  }

  private tagCount(category: TagCategory): number {
    return this.tags.filter((tag: AbilityTag) => tag.category === category).length;
  }

  private projectPeriod(project: ProjectExperience): string {
    if (project.startDate > 0 && project.endDate > 0) {
      return `${project.startDate}-${project.endDate}`;
    }
    if (project.startDate > 0) {
      return `${project.startDate} 至今`;
    }
    return '时间未填写';
  }

  private radarValues(): number[] {
    let skillCount: number = 0;
    let proficiencySum: number = 0;
    let proficiencyCount: number = 0;
    for (const tag of this.tags) {
      if (tag.category === TagCategory.SKILL) {
        skillCount++;
        proficiencySum += tag.proficiency;
        proficiencyCount++;
      } else if (tag.category === TagCategory.PROJECT) {
        skillCount++;
      }
    }
    const certCount: number = this.tagCount(TagCategory.CERTIFICATE);
    let honorPoints: number = 0;
    for (const honor of this.honors) {
      if (honor.level === HonorLevel.NATIONAL) {
        honorPoints += 1.0;
      } else if (honor.level === HonorLevel.PROVINCIAL) {
        honorPoints += 0.8;
      } else if (honor.level === HonorLevel.UNIVERSITY) {
        honorPoints += 0.6;
      } else {
        honorPoints += 0.4;
      }
    }
    const depth: number = proficiencyCount === 0 ? 0 : proficiencySum / proficiencyCount / 5;
    return [
      Math.min(skillCount / 8, 1),
      Math.min(certCount / 5, 1),
      Math.min(honorPoints / 3, 1),
      Math.min(this.projects.length / 4, 1),
      Math.min(depth, 1)
    ];
  }

  private drawRadar(): void {
    if (!this.canvasReady) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.canvasCtx;
    const canvasWidth: number = 300;
    const canvasHeight: number = 250;
    const cx: number = canvasWidth / 2;
    const cy: number = 118;
    const radius: number = 78;
    const labels: string[] = ['技能广度', '证书实力', '荣誉层次', '项目经验', '技能深度'];
    const values: number[] = this.radarValues();
    ctx.clearRect(0, 0, canvasWidth, canvasHeight);

    for (let level: number = 1; level <= 4; level++) {
      const ringRadius: number = radius * level / 4;
      ctx.beginPath();
      for (let i: number = 0; i < 5; i++) {
        const angle: number = -Math.PI / 2 + i * Math.PI * 2 / 5;
        const x: number = cx + Math.cos(angle) * ringRadius;
        const y: number = cy + Math.sin(angle) * ringRadius;
        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      ctx.closePath();
      ctx.strokeStyle = '#DCEEEC';
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    for (let i: number = 0; i < 5; i++) {
      const angle: number = -Math.PI / 2 + i * Math.PI * 2 / 5;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius);
      ctx.strokeStyle = '#DCEEEC';
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    ctx.beginPath();
    for (let i: number = 0; i < 5; i++) {
      const angle: number = -Math.PI / 2 + i * Math.PI * 2 / 5;
      const r: number = radius * values[i];
      const x: number = cx + Math.cos(angle) * r;
      const y: number = cy + Math.sin(angle) * r;
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.closePath();
    ctx.fillStyle = 'rgba(18, 174, 182, 0.22)';
    ctx.fill();
    ctx.strokeStyle = '#12AEB6';
    ctx.lineWidth = 2;
    ctx.stroke();

    ctx.font = '12vp sans-serif';
    ctx.fillStyle = '#5C7B80';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (let i: number = 0; i < 5; i++) {
      const angle: number = -Math.PI / 2 + i * Math.PI * 2 / 5;
      const x: number = cx + Math.cos(angle) * (radius + 20);
      const y: number = cy + Math.sin(angle) * (radius + 20);
      ctx.fillText(labels[i], x, y);
    }
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 6 }) {
          Text('我的能力画像').fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          Text(this.student === null ? '' : `${this.student.name} · ${this.student.major} · ${this.student.grade}`)
            .fontSize(13).fontColor($r('app.color.text_secondary'))
          Text('技能、证书与项目，都沉淀成你的能力标签')
            .fontSize(12).fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(18)
        .borderRadius({ topLeft: 28, topRight: 12, bottomLeft: 20, bottomRight: 20 })
        .linearGradient({ angle: 140, colors: [['#FFFFFF', 0], [$r('app.color.brand_soft'), 1]] })
        .border({ width: 1, color: '#80FFFFFF' })
        .shadow({ radius: 16, color: '#1F0E5C5C', offsetX: 0, offsetY: 6 })

        Row({ space: 8 }) {
          Column({ space: 4 }) {
            Text(String(this.tagCount(TagCategory.SKILL))).fontSize(22).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.brand_primary'))
            Text('技能').fontSize(11).fontColor($r('app.color.text_secondary'))
          }.layoutWeight(1).padding(10).borderRadius(16).border({ width: 1, color: '#8CFFFFFF' }).shadow({ radius: 10, color: '#1F0E5C5C', offsetX: 0, offsetY: 4 }).backgroundColor($r('app.color.chip_background'))
          Column({ space: 4 }) {
            Text(String(this.tagCount(TagCategory.CERTIFICATE))).fontSize(22).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.success'))
            Text('证书').fontSize(11).fontColor($r('app.color.text_secondary'))
          }.layoutWeight(1).padding(10).borderRadius(16).border({ width: 1, color: '#8CFFFFFF' }).shadow({ radius: 10, color: '#1F0E5C5C', offsetX: 0, offsetY: 4 }).backgroundColor($r('app.color.brand_soft'))
          Column({ space: 4 }) {
            Text(String(this.tagCount(TagCategory.HONOR))).fontSize(22).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.warning'))
            Text('荣誉').fontSize(11).fontColor($r('app.color.text_secondary'))
          }.layoutWeight(1).padding(10).borderRadius(16).border({ width: 1, color: '#8CFFFFFF' }).shadow({ radius: 10, color: '#1F0E5C5C', offsetX: 0, offsetY: 4 }).backgroundColor($r('app.color.accent_peach_soft'))
          Column({ space: 4 }) {
            Text(String(this.projects.length)).fontSize(22).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent_purple'))
            Text('项目').fontSize(11).fontColor($r('app.color.text_secondary'))
          }.layoutWeight(1).padding(10).borderRadius(16).border({ width: 1, color: '#8CFFFFFF' }).shadow({ radius: 10, color: '#1F0E5C5C', offsetX: 0, offsetY: 4 }).backgroundColor($r('app.color.surface_muted'))
        }
        .width('100%')

        Column({ space: 8 }) {
          Text('能力雷达').fontSize(16).fontWeight(FontWeight.Medium).width('100%')
          Canvas(this.canvasCtx)
            .id('portrait_radar')
            .width(300)
            .height(250)
            .onReady(() => {
              this.canvasReady = true;
              this.drawRadar();
            })
          Text('技能广度按标签数、证书实力按证书数、荣誉层次按级别、项目经验按项目数、技能深度按熟练度折算')
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .borderRadius(22)
        .linearGradient({ angle: 145, colors: [['#FFFFFF', 0], ['#F1FAF9', 1]] })
        .border({ width: 1, color: '#8CFFFFFF' })
        .shadow({ radius: 18, color: '#1F0E5C5C', offsetX: 0, offsetY: 6 })

        Text('能力标签').fontSize(16).fontWeight(FontWeight.Medium)
        Text('自动抽取的标签可改名合并、删除，也可手动补充，匹配时立即生效')
          .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
        Row({ space: 8 }) {
          TextInput({ placeholder: '补充技能标签，如 Python', text: this.manualTagName })
            .layoutWeight(1)
            .onChange((value: string) => { this.manualTagName = value; })
            .onSubmit(() => this.addManualTag())
          Button('添加')
            .fontSize(12)
            .height(36)
            .borderRadius(18)
            .linearGradient({ angle: 135, colors: [['#3AD8DA', 0], ['#0FA3AE', 1]] })
            .border({ width: 1, color: '#4DFFFFFF' })
            .shadow({ radius: 10, color: '#400A8089', offsetX: 0, offsetY: 4 })
            .fontColor($r('app.color.on_primary'))
            .onClick(() => this.addManualTag())
        }
        .width('100%')
        if (this.tags.length === 0) {
          EmptyState({ text: '暂无标签，请先录入证书或项目经历' })
        } else {
          Column({ space: 8 }) {
            ForEach(this.tags, (tag: AbilityTag) => {
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  Text(tag.tagName).fontSize(13).fontWeight(FontWeight.Medium).layoutWeight(1)
                  Text(this.categoryLabel(tag.category)).fontSize(10)
                    .fontColor($r('app.color.brand_primary'))
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .borderRadius(8)
                    .backgroundColor($r('app.color.chip_background'))
                }.width('100%')
                Text(`来源：${this.sourceLabel(tag.sourceType)} · 熟练度 ${tag.proficiency}/5 · 置信度 ${tag.confidence.toFixed(2)}`)
                  .fontSize(10).fontColor($r('app.color.text_secondary')).width('100%')
                if (this.editingTagId === tag.id) {
                  Row({ space: 6 }) {
                    TextInput({ text: this.tagEditName })
                      .layoutWeight(1).height(32).fontSize(12)
                      .onChange((value: string) => { this.tagEditName = value; })
                      .onSubmit(() => this.saveTagName(tag))
                    Button('保存').fontSize(11).height(28).borderRadius(14)
                      .backgroundColor($r('app.color.brand_primary'))
                      .fontColor($r('app.color.on_primary'))
                      .onClick(() => this.saveTagName(tag))
                    Button('取消').fontSize(11).height(28).borderRadius(14)
                      .backgroundColor($r('app.color.chip_background'))
                      .fontColor($r('app.color.text_label'))
                      .onClick(() => { this.editingTagId = 0; })
                  }.width('100%')
                } else {
                  Row({ space: 6 }) {
                    Button('改名/合并').fontSize(10).height(26).borderRadius(13)
                      .backgroundColor($r('app.color.chip_background')).fontColor($r('app.color.text_label'))
                      .onClick(() => this.startEditTag(tag))
                    Button('删除').fontSize(10).height(26).borderRadius(13)
                      .backgroundColor($r('app.color.accent_peach_soft')).fontColor($r('app.color.danger'))
                      .onClick(() => this.removeTag(tag))
                  }.width('100%').justifyContent(FlexAlign.End)
                }
              }
              .width('100%').alignItems(HorizontalAlign.Start).padding(10)
              .borderRadius(12).backgroundColor($r('app.color.card_background'))
            }, (tag: AbilityTag) => String(tag.id))
          }
          .width('100%')
        }

        Text('技能证书').fontSize(16).fontWeight(FontWeight.Medium)
        TextInput({ placeholder: '证书名称，如 CET-6 / 软件设计师', text: this.certName })
          .id('portrait_cert_name')
          .width('100%')
          .onChange((value: string) => { this.certName = value; })
        Row({ space: 8 }) {
          TextInput({ placeholder: '颁发单位', text: this.certIssuer })
            .layoutWeight(1)
            .onChange((value: string) => { this.certIssuer = value; })
          TextInput({ placeholder: '年份', text: this.certYear })
            .width(90)
            .type(InputType.Number)
            .onChange((value: string) => { this.certYear = value; })
        }.width('100%')
        TextInput({ placeholder: '级别，如 中级 / 高级 / 国家级', text: this.certLevel })
          .width('100%')
          .onChange((value: string) => { this.certLevel = value; })
        Button(this.editingCertId > 0 ? '保存证书修改' : '添加证书')
          .id('portrait_cert_save')
          .width('100%')
          .borderRadius(18)
          .backgroundColor($r('app.color.brand_primary'))
          .fontColor($r('app.color.on_primary'))
          .onClick(() => this.saveSkillCert())
        ForEach(this.skillCerts, (cert: SkillCertificate) => {
          Column({ space: 6 }) {
            Row() {
              Text(cert.certName).fontSize(14).fontWeight(FontWeight.Medium)
              Blank()
              Text(cert.obtainYear > 0 ? String(cert.obtainYear) : '年份未填')
                .fontSize(12).fontColor($r('app.color.text_secondary'))
            }.width('100%')
            Row() {
              Text(`${cert.issuer.length > 0 ? cert.issuer : '颁发单位未填'} · ${cert.level.length > 0 ? cert.level : '级别未填'}`)
                .fontSize(11).fontColor($r('app.color.text_secondary')).layoutWeight(1)
              Button('编辑').fontSize(11).height(26).borderRadius(13)
                .backgroundColor($r('app.color.chip_background')).fontColor($r('app.color.text_label'))
                .onClick(() => this.editSkillCert(cert))
              Button('删除').fontSize(11).height(26).borderRadius(13).margin({ left: 6 })
                .backgroundColor($r('app.color.accent_peach_soft')).fontColor($r('app.color.danger'))
                .onClick(() => this.removeSkillCert(cert))
            }.width('100%')
          }
          .width('100%').padding(10).backgroundColor($r('app.color.card_background')).borderRadius(8)
        }, (cert: SkillCertificate) => String(cert.id))

        Text('项目经历').fontSize(16).fontWeight(FontWeight.Medium)
        TextInput({ placeholder: '项目名称', text: this.projectName })
          .width('100%').onChange((value: string) => { this.projectName = value; })
        TextInput({ placeholder: '担任角色，如 组长 / 后端开发', text: this.projectRole })
          .width('100%').onChange((value: string) => { this.projectRole = value; })
        Row({ space: 8 }) {
          TextInput({ placeholder: '开始年份', text: this.projectStart })
            .layoutWeight(1).type(InputType.Number)
            .onChange((value: string) => { this.projectStart = value; })
          TextInput({ placeholder: '结束年份', text: this.projectEnd })
            .layoutWeight(1).type(InputType.Number)
            .onChange((value: string) => { this.projectEnd = value; })
        }.width('100%')
        TextInput({ placeholder: '技能标签，用逗号分隔', text: this.projectTags })
          .width('100%').onChange((value: string) => { this.projectTags = value; })
        TextInput({ placeholder: '项目描述', text: this.projectDesc })
          .width('100%').onChange((value: string) => { this.projectDesc = value; })
        Button(this.editingProjectId > 0 ? '保存项目修改' : '添加项目')
          .width('100%').borderRadius(20)
          .backgroundColor($r('app.color.accent_peach'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => this.saveProject())
        ForEach(this.projects, (project: ProjectExperience) => {
          Column({ space: 6 }) {
            Row() {
              Text(project.projectName).fontSize(14).fontWeight(FontWeight.Medium)
              Blank()
              Text(this.projectPeriod(project)).fontSize(11).fontColor($r('app.color.text_secondary'))
            }.width('100%')
            Text(`${project.role.length > 0 ? project.role : '角色未填'}`)
              .fontSize(11).fontColor($r('app.color.text_secondary'))
            if (project.description.length > 0) {
              Text(project.description).fontSize(12).fontColor($r('app.color.text_label'))
            }
            Row() {
              Text(project.tags.length > 0 ? project.tags.join('、') : '标签未填')
                .fontSize(11).fontColor($r('app.color.text_secondary')).layoutWeight(1)
              Button('编辑').fontSize(11).height(26).borderRadius(13)
                .backgroundColor($r('app.color.chip_background')).fontColor($r('app.color.text_label'))
                .onClick(() => this.editProject(project))
              Button('删除').fontSize(11).height(26).borderRadius(13).margin({ left: 6 })
                .backgroundColor($r('app.color.accent_peach_soft')).fontColor($r('app.color.danger'))
                .onClick(() => this.removeProject(project))
            }.width('100%')
          }
          .width('100%').alignItems(HorizontalAlign.Start).padding(10)
          .backgroundColor($r('app.color.card_background')).borderRadius(8)
        }, (project: ProjectExperience) => String(project.id))

        Text('分享海报预览').fontSize(13).fontColor($r('app.color.text_secondary'))
          .width('100%').margin({ top: 4 })
        this.posterCard()
        Button('导出可展示能力档案(HTML)').width('100%').borderRadius(20)
          .backgroundColor($r('app.color.brand_primary')).fontColor($r('app.color.on_primary'))
          .shadow({ radius: 10, color: $r('app.color.shadow'), offsetX: 0, offsetY: 4 })
          .onClick(() => this.exportPortraitHtml())
        Button('导出能力画像长图(JPG)').width('100%').borderRadius(20)
          .backgroundColor($r('app.color.brand_soft')).fontColor($r('app.color.brand_primary'))
          .onClick(() => this.exportPortraitImage())
        Button('导出能力档案(JSON)').width('100%').borderRadius(20)
          .backgroundColor($r('app.color.chip_background')).fontColor($r('app.color.text_label'))
          .onClick(() => this.exportPortrait())
      }
      .width('100%')
      .padding(20)
      .linearGradient({ angle: 165, colors: [[$r('app.color.app_background'), 0], [$r('app.color.app_background_end'), 1]] })
    }
    .width('100%')
    .height('100%')
    .id('portrait_scroll')
    .scrollBar(BarState.Off)
  }
}