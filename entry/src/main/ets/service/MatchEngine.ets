import {
  AbilityTag, AdviceLib, DimensionScores, HonorCertificate, JobRequirement,
  MatchResult, ProjectExperience, SkillCertificate, SkillDict, SkillDictItem, Student
} from '../model/Entity';
import { HonorLevel, HonorType, TagCategory } from '../model/Enums';
import { Taxonomy } from '../common/Taxonomy';
import { TextMatcher } from '../common/TextMatcher';

export class MatchEngine {

  static compute(student: Student, tags: AbilityTag[], skillCerts: SkillCertificate[],
                 projects: ProjectExperience[], honors: HonorCertificate[],
                 job: JobRequirement, advice: AdviceLib, dict: SkillDict | null = null): MatchResult {
    const skillItems: SkillDictItem[] = dict === null ? [] : dict.skills;
    const certItems: SkillDictItem[] = dict === null ? [] : dict.certificates;
    const rawSkills: string[] = [];
    const rawCerts: string[] = [];

    for (const tag of tags) {
      if (tag.category === TagCategory.SKILL || tag.category === TagCategory.PROJECT) {
        rawSkills.push(tag.tagName);
      } else if (tag.category === TagCategory.CERTIFICATE) {
        rawCerts.push(tag.tagName);
      }
    }
    for (const cert of skillCerts) {
      rawCerts.push(cert.certName);
    }
    for (const project of projects) {
      for (const tag of project.tags) {
        rawSkills.push(tag);
      }
    }
    for (const honor of honors) {
      // 只有“技能证书”类荣誉进入证书集合；竞赛获奖与荣誉称号只参与荣誉维度
      if (honor.honorType === HonorType.CERTIFICATE) {
        rawCerts.push(honor.title);
      }
    }

    const studentSkills: string[] = TextMatcher.canonicalList(rawSkills, skillItems);
    const studentCerts: string[] = TextMatcher.canonicalList(rawCerts, certItems);
    const jobSkills: string[] = TextMatcher.canonicalList(job.skillReq, skillItems);
    const jobCerts: string[] = TextMatcher.canonicalList(job.certReq, certItems);

    const eduScore: number = MatchEngine.educationScore(student, job.educationReq);
    const skillScore: number = MatchEngine.ratio(jobSkills, studentSkills);
    const certScore: number = MatchEngine.ratio(jobCerts, studentCerts);
    const expScore: number = MatchEngine.experienceScore(student, projects, job.experienceYears);
    const honorScore: number = MatchEngine.honorScore(honors, projects, jobSkills, jobCerts);
    const directionScore: number = MatchEngine.directionScore(student, job.majorDirection);

    const scores: DimensionScores = {
      education: eduScore,
      skill: skillScore,
      certificate: certScore,
      experience: expScore,
      honor: honorScore,
      direction: directionScore
    };

    let total: number = job.weights.education + job.weights.skill + job.weights.certificate +
      job.weights.experience + job.weights.honor + job.weights.direction;
    if (total <= 0) {
      total = 1;
    }
    const weighted: number =
      (scores.education * job.weights.education +
        scores.skill * job.weights.skill +
        scores.certificate * job.weights.certificate +
        scores.experience * job.weights.experience +
        scores.honor * job.weights.honor +
        scores.direction * job.weights.direction) / total;

    const missingKeys: string[] = [];
    const gaps: string[] = [];
    if (eduScore < 0.8 && job.educationReq.length > 0) {
      gaps.push(`学历要求未满足：要求 ${job.educationReq}`);
      missingKeys.push(job.educationReq);
    }
    for (const skill of jobSkills) {
      if (studentSkills.indexOf(skill) < 0) {
        gaps.push(`缺少技能：${skill}`);
        missingKeys.push(skill);
      }
    }
    for (const cert of jobCerts) {
      if (studentCerts.indexOf(cert) < 0) {
        gaps.push(`缺少证书：${cert}`);
        missingKeys.push(cert);
      }
    }
    if (expScore < 1 && job.experienceYears > 0) {
      gaps.push(`经验年限不足：要求 ${job.experienceYears} 年`);
      missingKeys.push(job.experienceKeywords.length > 0 ? job.experienceKeywords[0] : '项目经验');
    }
    if (directionScore < 0.8 && job.majorDirection.length > 0) {
      gaps.push(`专业方向不匹配：岗位方向为 ${job.majorDirection}`);
    }

    const suggestions: string[] = [];
    for (const key of missingKeys) {
      suggestions.push(MatchEngine.findAdvice(key, advice));
    }
    if (directionScore < 0.8 && job.majorDirection.length > 0) {
      suggestions.push(`建议将求职方向调整为“${job.majorDirection}”，并在成长规划中补充同方向的项目与证书。`);
    }
    if (suggestions.length === 0) {
      suggestions.push('各项要求均已满足，建议补充高质量项目描述以突出竞争力。');
    }

    return {
      totalScore: Math.round(weighted * 1000) / 10,
      dimensionScores: scores,
      gapItems: gaps,
      suggestions: suggestions
    };
  }

  private static educationScore(student: Student, required: string): number {
    if (required.length === 0) {
      return 1;
    }
    const education: string = student.education.length > 0 ? student.education : student.grade;
    const studentRank: number = Taxonomy.educationRank(education);
    const requiredRank: number = Taxonomy.educationRank(required);
    if (requiredRank <= 0) {
      return 1;
    }
    if (studentRank >= requiredRank) {
      return 0.8 + 0.2 * MatchEngine.schoolLevelScore(student.schoolLevel);
    }
    return studentRank === requiredRank - 1 ? 0.6 : 0;
  }

  private static schoolLevelScore(value: string): number {
    if (value.includes('985')) {
      return 1;
    }
    if (value.includes('211')) {
      return 0.9;
    }
    if (value.includes('双一流')) {
      return 0.8;
    }
    if (value.includes('留学')) {
      return 0.7;
    }
    return 0.6;
  }

  private static directionScore(student: Student, required: string): number {
    return Taxonomy.directionScore(student.direction, required);
  }

  private static ratio(required: string[], owned: string[]): number {
    if (required.length === 0) {
      return 1;
    }
    let hit: number = 0;
    for (const item of required) {
      if (owned.indexOf(item) >= 0) {
        hit++;
      }
    }
    return hit / required.length;
  }

  private static experienceScore(student: Student, projects: ProjectExperience[], requiredYears: number): number {
    if (requiredYears <= 0) {
      return 1;
    }
    let years: number = 0;
    if (student.grade.includes('大三')) {
      years = 1;
    } else if (student.grade.includes('大四') || student.grade.includes('研究生')) {
      years = 2;
    }
    years += projects.length * 0.5;
    return Math.min(years / requiredYears, 1);
  }

  private static honorScore(honors: HonorCertificate[], projects: ProjectExperience[],
                            jobSkills: string[], jobCerts: string[]): number {
    let points: number = 0;
    for (const honor of honors) {
      let base: number = 0.4;
      if (honor.level === HonorLevel.NATIONAL) {
        base = 1.0;
      } else if (honor.level === HonorLevel.PROVINCIAL) {
        base = 0.8;
      } else if (honor.level === HonorLevel.UNIVERSITY) {
        base = 0.6;
      }
      const relevant: boolean = MatchEngine.isRelevant(honor.title, jobSkills, jobCerts);
      points += relevant ? base : base * 0.35;
    }
    for (const project of projects) {
      const relevant: boolean = MatchEngine.isRelevant(project.projectName + ' ' + project.tags.join(' '),
        jobSkills, jobCerts);
      points += relevant ? 0.2 : 0.07;
    }
    return Math.min(points / 2, 1);
  }

  private static isRelevant(text: string, jobSkills: string[], jobCerts: string[]): boolean {
    if (jobSkills.length === 0 && jobCerts.length === 0) {
      return true;
    }
    for (const item of jobSkills.concat(jobCerts)) {
      if (TextMatcher.contains(text, item) || TextMatcher.contains(item, text)) {
        return true;
      }
    }
    return false;
  }

  private static findAdvice(key: string, advice: AdviceLib): string {
    const lower: string = key.toLowerCase();
    for (const item of advice.advice) {
      if (lower.includes(item.key.toLowerCase()) || item.key.toLowerCase().includes(lower)) {
        return item.text;
      }
    }
    return advice.default;
  }
}
