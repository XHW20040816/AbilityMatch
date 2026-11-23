import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo, picker } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { FileHelper } from '../common/FileHelper';
import {
  AbilityTag, HonorCertificate, ProjectExperience, SkillCertificate, Student
} from '../model/Entity';
import { honorLevelLabel, honorTypeLabel } from '../model/Enums';

export class ExportService {
  exportCertificatesCsv(context: common.UIAbilityContext, certs: HonorCertificate[]): string {
    const fileName: string = `certificates_${Date.now()}.csv`;
    return FileHelper.exportFile(context, fileName, ExportService.certificatesCsv(certs));
  }

  exportPortraitJson(context: common.UIAbilityContext, student: Student, tags: AbilityTag[],
                     certs: HonorCertificate[], skillCerts: SkillCertificate[],
                     projects: ProjectExperience[]): string {
    const fileName: string = `portrait_${Date.now()}.json`;
    return FileHelper.exportFile(context, fileName,
      ExportService.portraitJson(student, tags, certs, skillCerts, projects));
  }

  async saveCertificatesCsv(context: common.UIAbilityContext, certs: HonorCertificate[]): Promise<boolean> {
    const content: string = ExportService.certificatesCsv(certs);
    return await ExportService.saveToUser(context, `certificates_${Date.now()}.csv`, content, 'CSV|csv');
  }

  async savePortraitJson(context: common.UIAbilityContext, student: Student, tags: AbilityTag[],
                        certs: HonorCertificate[], skillCerts: SkillCertificate[],
                        projects: ProjectExperience[]): Promise<boolean> {
    const content: string = ExportService.portraitJson(student, tags, certs, skillCerts, projects);
    return await ExportService.saveToUser(context, `portrait_${Date.now()}.json`, content, 'JSON|.json');
  }

  async savePortraitHtml(context: common.UIAbilityContext, student: Student, tags: AbilityTag[],
                         certs: HonorCertificate[], skillCerts: SkillCertificate[],
                         projects: ProjectExperience[]): Promise<boolean> {
    const content: string = await ExportService.portraitHtml(
      context, student, tags, certs, skillCerts, projects
    );
    return await ExportService.saveToUser(context, `portrait_${Date.now()}.html`, content, 'HTML|.html');
  }

  // 能力画像长图：把组件快照压缩为 JPEG 后交给系统文件选择器保存
  async savePortraitImage(context: common.UIAbilityContext, pixelMap: image.PixelMap): Promise<boolean> {
    const packer: image.ImagePacker = image.createImagePacker();
    let data: ArrayBuffer;
    try {
      data = await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 90 });
    } finally {
      await packer.release();
    }
    const options: picker.DocumentSaveOptions = {
      newFileNames: [`portrait_${Date.now()}.jpg`],
      fileSuffixChoices: ['图片|.jpg']
    };
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    const uris: string[] = await documentPicker.save(options);
    if (uris.length === 0) {
      return false;
    }
    const file: fileIo.File = await fileIo.open(uris[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      await fileIo.write(file.fd, data);
    } finally {
      await fileIo.close(file.fd);
    }
    return true;
  }

  private static async portraitHtml(context: common.UIAbilityContext, student: Student,
                                    tags: AbilityTag[], certs: HonorCertificate[],
                                    skillCerts: SkillCertificate[],
                                    projects: ProjectExperience[]): Promise<string> {
    const tagHtml: string = tags.length === 0 ? '<span class="muted">暂无标签</span>' :
      tags.map((tag: AbilityTag): string =>
        `<span class="tag">${ExportService.htmlEscape(tag.tagName)}<em>${tag.proficiency}/5</em></span>`
      ).join('');

    let certRows: string = '';
    for (const cert of skillCerts) {
      certRows += `<tr><td>${ExportService.htmlEscape(cert.certName)}</td>` +
        `<td>${ExportService.htmlEscape(cert.issuer)}</td>` +
        `<td>${cert.obtainYear > 0 ? cert.obtainYear : ''}</td>` +
        `<td>${ExportService.htmlEscape(cert.level)}</td></tr>`;
    }
    if (certRows.length === 0) {
      certRows = '<tr><td colspan="4" class="muted">暂无技能证书</td></tr>';
    }

    let honorHtml: string = '';
    for (const honor of certs) {
      let image: string = '';
      if (honor.imagePath.length > 0) {
        image = await ExportService.imageDataUri(context, honor.imagePath);
      }
      honorHtml += `<div class="card honor">` +
        `<div class="honor-head"><strong>${ExportService.htmlEscape(honor.title)}</strong>` +
        `<span class="badge">${ExportService.htmlEscape(honorLevelLabel(honor.level))}</span></div>` +
        `<div class="muted">${ExportService.htmlEscape(honorTypeLabel(honor.honorType))} · ` +
        `${honor.awardYear > 0 ? honor.awardYear : '年份未填'} · ` +
        `${ExportService.htmlEscape(honor.issuer.length > 0 ? honor.issuer : '颁发单位未填')}</div>` +
        (honor.remark.length > 0 ? `<p>${ExportService.htmlEscape(honor.remark)}</p>` : '') +
        (image.length > 0 ? `<img class="thumb" src="${image}" alt="证书图片"/>` : '') +
        `</div>`;
    }
    if (honorHtml.length === 0) {
      honorHtml = '<p class="muted">暂无荣誉证书</p>';
    }

    let projectHtml: string = '';
    for (const project of projects) {
      projectHtml += `<div class="card"><strong>${ExportService.htmlEscape(project.projectName)}</strong>` +
        `<div class="muted">${ExportService.htmlEscape(project.role)} · ` +
        `${project.startDate > 0 ? project.startDate : '?'}-${project.endDate > 0 ? project.endDate : '至今'}</div>` +
        (project.description.length > 0 ? `<p>${ExportService.htmlEscape(project.description)}</p>` : '') +
        `<div class="muted">标签：${ExportService.htmlEscape(project.tags.join('、'))}</div></div>`;
    }
    if (projectHtml.length === 0) {
      projectHtml = '<p class="muted">暂无项目经历</p>';
    }

    const school: string = student.school + (student.schoolLevel.length > 0 ? ` · ${student.schoolLevel}` : '');
    return `<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>${ExportService.htmlEscape(student.name)}的能力档案</title>
<style>
body{margin:0;background:#F4F8F8;color:#1F3A3D;font-family:-apple-system,"PingFang SC","Microsoft YaHei",sans-serif}
.wrap{max-width:900px;margin:0 auto;padding:32px 22px 48px}
.hero{background:linear-gradient(135deg,#12AEB6,#0B7F86);color:#fff;border-radius:24px;padding:28px}
.hero h1{margin:0 0 8px;font-size:30px}.hero p{margin:4px 0;opacity:.92}
h2{margin:30px 0 12px;font-size:19px;color:#0B7F86}
.card{background:#fff;border-radius:14px;padding:14px 16px;margin-bottom:10px;box-shadow:0 4px 14px rgba(18,60,66,.06)}
.tag{display:inline-block;background:#E4F5F4;color:#0B7F86;border-radius:999px;padding:6px 12px;margin:0 8px 8px 0;font-size:13px}
.tag em{font-style:normal;opacity:.65;margin-left:6px;font-size:11px}
table{width:100%;border-collapse:collapse;background:#fff;border-radius:14px;overflow:hidden}
th,td{text-align:left;padding:10px 12px;border-bottom:1px solid #EAF1F1;font-size:13px}
th{background:#E4F5F4;color:#0B7F86}
.muted{color:#6B8589;font-size:12px}.badge{background:#FFF0E4;color:#B36A2E;border-radius:8px;padding:2px 8px;font-size:11px;margin-left:8px}
.honor-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:6px}
.thumb{max-width:100%;max-height:260px;border-radius:10px;margin-top:10px;object-fit:contain}
.footer{margin-top:28px;text-align:center;color:#8AA1A4;font-size:11px}
</style></head><body><div class="wrap">
<div class="hero"><h1>${ExportService.htmlEscape(student.name)}</h1>
<p>${ExportService.htmlEscape(student.major)} · ${ExportService.htmlEscape(student.grade)} · ${ExportService.htmlEscape(student.education)}</p>
<p>${ExportService.htmlEscape(school)} · 求职方向：${ExportService.htmlEscape(student.direction.length > 0 ? student.direction : '未填写')}</p>
<p>${ExportService.htmlEscape(student.email)} ${ExportService.htmlEscape(student.phone)}</p></div>
<h2>能力标签</h2><div>${tagHtml}</div>
<h2>技能证书</h2><table><thead><tr><th>证书</th><th>颁发单位</th><th>年份</th><th>级别</th></tr></thead><tbody>${certRows}</tbody></table>
<h2>荣誉证书</h2>${honorHtml}
<h2>项目经历</h2>${projectHtml}
<div class="footer">由 AbilityMatch 本地生成 · ${new Date().toLocaleDateString()}</div>
</div></body></html>`;
  }

  private static async imageDataUri(context: common.UIAbilityContext, relativePath: string): Promise<string> {
    try {
      const path: string = FileHelper.thumbnailPath(context, relativePath);
      if (!fileIo.accessSync(path)) {
        return '';
      }
      const stat: fileIo.Stat = fileIo.statSync(path);
      if (stat.size <= 0 || stat.size > 5 * 1024 * 1024) {
        return '';
      }
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      let read: number = 0;
      try {
        read = fileIo.readSync(file.fd, buffer);
      } finally {
        fileIo.closeSync(file.fd);
      }
      if (read <= 0) {
        return '';
      }
      const base64: string = new util.Base64Helper().encodeToStringSync(new Uint8Array(buffer.slice(0, read)));
      const mime: string = relativePath.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      return `data:${mime};base64,${base64}`;
    } catch (error) {
      return '';
    }
  }

  private static htmlEscape(value: string): string {
    return value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  private static certificatesCsv(certs: HonorCertificate[]): string {
    const lines: string[] = ['标题,荣誉类型,级别,获奖年份,颁发单位,备注'];
    for (const cert of certs) {
      lines.push([
        cert.title, honorTypeLabel(cert.honorType), honorLevelLabel(cert.level),
        String(cert.awardYear), cert.issuer, cert.remark
      ].map((value: string): string => ExportService.escape(value)).join(','));
    }
    // 前置 UTF-8 BOM，确保 Windows Excel 双击打开时中文不乱码
    return '\uFEFF' + lines.join('\r\n');
  }

  private static portraitJson(student: Student, tags: AbilityTag[], certs: HonorCertificate[],
                              skillCerts: SkillCertificate[], projects: ProjectExperience[]): string {
    return JSON.stringify({
      student: student,
      tags: tags,
      honors: certs,
      skillCertificates: skillCerts,
      projects: projects,
      exportedAt: Date.now()
    }, null, 2);
  }

  private static async saveToUser(context: common.UIAbilityContext, fileName: string,
                                  content: string, suffix: string): Promise<boolean> {
    const options: picker.DocumentSaveOptions = {
      newFileNames: [fileName],
      fileSuffixChoices: [suffix]
    };
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    const uris: string[] = await documentPicker.save(options);
    if (uris.length === 0) {
      return false;
    }
    const file: fileIo.File = await fileIo.open(uris[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      await fileIo.write(file.fd, content);
    } finally {
      await fileIo.close(file.fd);
    }
    return true;
  }

  private static escape(value: string): string {
    if (value.includes(',') || value.includes('"') || value.includes('\n') || value.includes('\r')) {
      return `"${value.replace(/"/g, '""')}"`;
    }
    return value;
  }
}
