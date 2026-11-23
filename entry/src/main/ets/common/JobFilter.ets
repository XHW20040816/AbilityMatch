import { JobRequirement } from '../model/Entity';
import { SearchTokenizer } from './SearchTokenizer';

/**
 * 岗位检索的纯函数集合：不依赖 RDB 与 UI，便于单元测试与复用。
 * 关键字匹配规则：先做整体子串匹配（中文友好），
 * 再退化为按空白/标点切分的多词 AND 匹配（如“鸿蒙 开发”）。
 */
export class JobFilter {
  static searchBlob(job: JobRequirement): string {
    const parts: string[] = [
      job.jobTitle,
      job.companyName,
      job.majorDirection,
      job.educationReq,
      job.skillReq.join(' '),
      job.certReq.join(' '),
      job.experienceKeywords.join(' '),
      job.rawText
    ];
    return SearchTokenizer.normalize(parts.join(' '));
  }

  static matchKeywords(keyword: string): string[] {
    const segments: string[] = keyword.split(/[\s,，、;；/]+/);
    const result: string[] = [];
    for (const segment of segments) {
      const normalized: string = SearchTokenizer.normalize(segment);
      if (normalized.length > 0 && result.indexOf(normalized) < 0) {
        result.push(normalized);
      }
    }
    return result;
  }

  static matches(job: JobRequirement, keyword: string): boolean {
    const key: string = SearchTokenizer.normalize(keyword);
    if (key.length === 0) {
      return true;
    }
    const blob: string = JobFilter.searchBlob(job);
    if (blob.length === 0) {
      return false;
    }
    if (blob.indexOf(key) >= 0) {
      return true;
    }
    const segments: string[] = JobFilter.matchKeywords(keyword);
    if (segments.length <= 1) {
      return false;
    }
    for (const segment of segments) {
      if (blob.indexOf(segment) < 0) {
        return false;
      }
    }
    return true;
  }

  static matchIds(jobs: JobRequirement[], direction: string, keyword: string): number[] {
    const ids: number[] = [];
    for (const job of jobs) {
      if (direction.length > 0 && job.majorDirection !== direction) {
        continue;
      }
      if (!JobFilter.matches(job, keyword)) {
        continue;
      }
      ids.push(job.id);
    }
    return ids;
  }

  static pushHistory(history: string[], keyword: string, maxSize: number): string[] {
    const trimmed: string = keyword.trim();
    if (trimmed.length === 0) {
      return history;
    }
    const result: string[] = [trimmed];
    for (const item of history) {
      if (item !== trimmed && result.length < maxSize) {
        result.push(item);
      }
    }
    return result;
  }
}
