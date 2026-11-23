import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';
import {
  AbilityTag, HonorCertificate, JobRequirement, MatchResult, ProjectExperience,
  SemanticResult, SemanticScores, SkillCertificate, Student
} from '../model/Entity';
import { TagCategory } from '../model/Enums';
import { honorRepo, profileRepo, studentRepo, tagRepo } from '../repository/Repositories';
import { LlmService } from './LlmService';
import { MatchEngine } from './MatchEngine';

/** 待语义评估的一组「学生-岗位」匹配（result 为本地规则分） */
export interface SemanticItem {
  studentId: number;
  job: JobRequirement;
  result: MatchResult;
}

interface RawSemantic {
  education?: number | string;
  skill?: number | string;
  certificate?: number | string;
  experience?: number | string;
  honor?: number | string;
  direction?: number | string;
  overall?: number | string;
  reason?: string;
  strengths?: string[];
  gaps?: string[];
}

interface CacheEntry {
  value: SemanticResult;
  createTime: number;
}

const SYSTEM_PROMPT: string =
  '你是校园招聘的岗位匹配专家，需要基于学生画像与岗位要求做语义层面的契合度判断。' +
  '要求：1) 只输出一个 JSON 对象，不要输出 Markdown、代码块或任何解释文字；' +
  '2) 六个维度与 overall 的取值都是 0 到 1 的小数，保留两位；' +
  '3) 语义相近即可给分（例如「鸿蒙应用开发」与「HarmonyOS 开发」应视为高度匹配，' +
  '「数据结构与算法」可支撑「后端开发」的技能要求）；' +
  '4) 信息缺失时按「可能满足」的中性分（0.5~0.6）估计，不要直接给 0；' +
  '5) reason 不超过 60 字，strengths 与 gaps 各不超过 3 条，每条不超过 20 字。' +
  '输出示例：{"education":0.9,"skill":0.8,"certificate":0.5,"experience":0.6,"honor":0.4,' +
  '"direction":0.85,"overall":0.75,"reason":"技能与方向高度吻合，证书与项目深度略有欠缺",' +
  '"strengths":["鸿蒙项目经验","方向一致"],"gaps":["缺少六级证书"]}';

/**
 * 大模型语义匹配服务：
 * 在本地六维加权规则分之上，额外请求大模型给出七项语义评分（六维 + 综合），
 * 再按维度融合系数交给 MatchEngine 合成最终得分。
 * 任何失败（未配置、超时、返回格式异常）都自动降级为纯本地规则分，保证离线可用。
 */
export class SemanticMatchService {
  private static cache: Map<string, CacheEntry> = new Map<string, CacheEntry>();
  private static profileCache: Map<number, string> = new Map<number, string>();
  private static lastError: string = '';

  static getLastError(): string {
    return SemanticMatchService.lastError;
  }

  static clearCache(): void {
    SemanticMatchService.cache.clear();
    SemanticMatchService.profileCache.clear();
  }

  /** 是否已启用语义匹配（配置齐全且开关打开） */
  static async isEnabled(): Promise<boolean> {
    return LlmService.isAvailable();
  }

  /** 单个「学生-岗位」语义增强；失败时原样返回本地规则分 */
  static async enhance(studentId: number, job: JobRequirement, base: MatchResult): Promise<MatchResult> {
    const results: MatchResult[] = await SemanticMatchService.enhanceBatch(
      [{ studentId: studentId, job: job, result: base }], 1);
    return results[0];
  }

  /**
   * 批量语义增强：只对规则分最高的前 topK 个结果调用大模型（控制时延与费用），
   * 其余结果保留本地分数。返回值与原数组顺序一致。
   */
  static async enhanceBatch(items: SemanticItem[], topK: number): Promise<MatchResult[]> {
    const results: MatchResult[] = items.map((item: SemanticItem) => item.result);
    SemanticMatchService.lastError = '';
    if (items.length === 0) {
      return results;
    }
    const enabled: boolean = await LlmService.isAvailable();
    if (!enabled) {
      return results;
    }

    const order: number[] = items.map((item: SemanticItem, index: number) => index)
      .sort((a: number, b: number) => items[b].result.totalScore - items[a].result.totalScore);
    const limit: number = topK > 0 ? Math.min(topK, order.length) : order.length;
    const targets: number[] = order.slice(0, limit);

    // 并发度控制在 3：兼顾时延与接口限流
    const batchSize: number = 3;
    for (let start = 0; start < targets.length; start += batchSize) {
      const slice: number[] = targets.slice(start, start + batchSize);
      const tasks: Promise<number>[] = slice.map((index: number) => SemanticMatchService.enhanceOne(items[index])
        .then((merged: MatchResult | null) => {
          if (merged !== null) {
            results[index] = merged;
          }
          return index;
        }));
      await Promise.all(tasks);
    }
    return results;
  }

  private static async enhanceOne(item: SemanticItem): Promise<MatchResult | null> {
    try {
      const semantic: SemanticResult | null = await SemanticMatchService.scoreFor(item.studentId, item.job);
      if (semantic === null) {
        return null;
      }
      return MatchEngine.mergeSemantic(item.result, item.job.weights, semantic);
    } catch (error) {
      const message: string = error instanceof Error ? error.message : String(error);
      SemanticMatchService.lastError = message;
      Logger.error(`语义匹配降级为本地算法：${message}`);
      return null;
    }
  }

  private static async scoreFor(studentId: number, job: JobRequirement): Promise<SemanticResult | null> {
    const key: string = SemanticMatchService.cacheKey(studentId, job);
    const hit: CacheEntry | undefined = SemanticMatchService.cache.get(key);
    if (hit !== undefined && Date.now() - hit.createTime < Constants.SEMANTIC_CACHE_TTL) {
      return hit.value;
    }
    const profile: string = await SemanticMatchService.profileText(studentId);
    if (profile.length === 0) {
      return null;
    }
    const config = await LlmService.loadConfig();
    const content: string = await LlmService.chat(SYSTEM_PROMPT,
      SemanticMatchService.userPrompt(profile, job));
    const semantic: SemanticResult | null = SemanticMatchService.parseSemantic(content, config.model);
    if (semantic === null) {
      Logger.warn('语义匹配返回内容无法解析，已降级');
      return null;
    }
    SemanticMatchService.cache.set(key, { value: semantic, createTime: Date.now() });
    SemanticMatchService.trimCache();
    return semantic;
  }

  private static trimCache(): void {
    if (SemanticMatchService.cache.size <= Constants.SEMANTIC_CACHE_LIMIT) {
      return;
    }
    const keys: string[] = Array.from(SemanticMatchService.cache.keys());
    const drop: number = keys.length - Constants.SEMANTIC_CACHE_LIMIT;
    for (let i = 0; i < drop; i++) {
      SemanticMatchService.cache.delete(keys[i]);
    }
  }

  private static cacheKey(studentId: number, job: JobRequirement): string {
    return `${studentId}|${job.id}|${job.jobTitle}|${job.skillReq.join(',')}|${job.rawText.length}`;
  }

  /** 把学生画像压成一段紧凑文本，既省 token 又保留语义判断所需信息 */
  private static async profileText(studentId: number): Promise<string> {
    const cached: string | undefined = SemanticMatchService.profileCache.get(studentId);
    if (cached !== undefined) {
      return cached;
    }
    const student: Student | null = await studentRepo.getById(studentId);
    if (student === null) {
      return '';
    }
    const tags: AbilityTag[] = await tagRepo.listByStudent(studentId);
    const certs: SkillCertificate[] = await profileRepo.listSkillCerts(studentId);
    const projects: ProjectExperience[] = await profileRepo.listProjects(studentId);
    const honors: HonorCertificate[] = await honorRepo.list(studentId,
      { keyword: '', honorType: '', level: '', yearFrom: 0, yearTo: 0, issuer: '' }, 50, 0);

    const skillNames: string[] = [];
    const certNames: string[] = [];
    for (const tag of tags) {
      if (tag.category === TagCategory.CERTIFICATE) {
        certNames.push(tag.tagName);
      } else {
        skillNames.push(tag.tagName);
      }
    }
    for (const cert of certs) {
      certNames.push(cert.certName);
    }
    for (const project of projects) {
      for (const tag of project.tags) {
        skillNames.push(tag);
      }
    }
    const honorNames: string[] = honors.map((honor: HonorCertificate) => `${honor.title}(${honor.level})`);

    const lines: string[] = [];
    lines.push(`学校：${student.school}（${student.schoolLevel}） 专业：${student.major} ${student.education} ${student.grade}`);
    lines.push(`求职方向：${student.direction.length > 0 ? student.direction : '未填写'}`);
    lines.push(`技能：${SemanticMatchService.unique(skillNames).slice(0, 20).join('、') || '无'}`);
    lines.push(`证书：${SemanticMatchService.unique(certNames).slice(0, 10).join('、') || '无'}`);
    const projectTexts: string[] = projects.slice(0, 5)
      .map((item: ProjectExperience) => `${item.projectName}[${item.tags.slice(0, 4).join('/')}]`);
    lines.push(`项目：${projectTexts.join('；') || '无'}`);
    lines.push(`荣誉：${honorNames.slice(0, 6).join('、') || '无'}`);
    const text: string = lines.join('\n');
    SemanticMatchService.profileCache.set(studentId, text);
    return text;
  }

  private static unique(values: string[]): string[] {
    const result: string[] = [];
    for (const value of values) {
      if (value.length > 0 && result.indexOf(value) < 0) {
        result.push(value);
      }
    }
    return result;
  }

  private static userPrompt(profile: string, job: JobRequirement): string {
    const desc: string = job.rawText.length > 600 ? `${job.rawText.substring(0, 600)}…` : job.rawText;
    return [
      '【学生画像】',
      profile,
      '',
      '【岗位信息】',
      `岗位：${job.jobTitle}（${job.companyName}）`,
      `方向：${job.majorDirection.length > 0 ? job.majorDirection : '不限'}`,
      `学历要求：${job.educationReq.length > 0 ? job.educationReq : '不限'}`,
      `技能要求：${job.skillReq.join('、') || '不限'}`,
      `证书要求：${job.certReq.join('、') || '不限'}`,
      `经验要求：${job.experienceYears} 年`,
      `岗位描述：${desc.length > 0 ? desc : '无'}`,
      '',
      '请输出 JSON：六维评分（education/skill/certificate/experience/honor/direction）、' +
        'overall、reason、strengths、gaps。'
    ].join('\n');
  }

  /**
   * 解析模型输出。为兼容不同模型的“健壮性”，
   * 会先剥掉 ```json 代码块等多余内容，再截取第一个合法 JSON 对象。
   */
  static parseSemantic(content: string, model: string): SemanticResult | null {
    const json: string = SemanticMatchService.extractJson(content);
    if (json.length === 0) {
      return null;
    }
    try {
      const raw: RawSemantic = JSON.parse(json) as RawSemantic;
      const education: number | null = SemanticMatchService.asNum(raw.education);
      const skill: number | null = SemanticMatchService.asNum(raw.skill);
      const certificate: number | null = SemanticMatchService.asNum(raw.certificate);
      const experience: number | null = SemanticMatchService.asNum(raw.experience);
      const honor: number | null = SemanticMatchService.asNum(raw.honor);
      const direction: number | null = SemanticMatchService.asNum(raw.direction);
      if (skill === null || direction === null) {
        return null;
      }
      const scores: SemanticScores = {
        education: education === null ? 0.6 : education,
        skill: skill,
        certificate: certificate === null ? 0.6 : certificate,
        experience: experience === null ? 0.6 : experience,
        honor: honor === null ? 0.5 : honor,
        direction: direction
      };
      const overallValue: number | null = SemanticMatchService.asNum(raw.overall);
      const overall: number = overallValue === null ?
        Math.round((scores.education + scores.skill + scores.certificate + scores.experience +
          scores.honor + scores.direction) / 6 * 100) / 100 : overallValue;
      return {
        scores: scores,
        overall: overall,
        reason: typeof raw.reason === 'string' ? raw.reason.trim() : '',
        strengths: SemanticMatchService.cleanList(raw.strengths),
        gaps: SemanticMatchService.cleanList(raw.gaps),
        model: model,
        createTime: Date.now()
      };
    } catch (error) {
      Logger.warn('语义评分 JSON 解析失败');
      return null;
    }
  }

  private static cleanList(values: string[] | undefined): string[] {
    if (values === undefined || values === null) {
      return [];
    }
    const result: string[] = [];
    for (const value of values) {
      if (typeof value === 'string' && value.trim().length > 0) {
        result.push(value.trim());
      }
    }
    return result.slice(0, 3);
  }

  private static asNum(value: number | string | undefined): number | null {
    if (value === undefined || value === null) {
      return null;
    }
    const parsed: number = typeof value === 'number' ? value : Number(value as string);
    if (isNaN(parsed) || !isFinite(parsed)) {
      return null;
    }
    const clamped: number = Math.max(0, Math.min(1, parsed));
    return Math.round(clamped * 100) / 100;
  }

  private static extractJson(content: string): string {
    const start: number = content.indexOf('{');
    const end: number = content.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return '';
    }
    return content.substring(start, end + 1);
  }
}
