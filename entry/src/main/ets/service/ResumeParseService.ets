import { ParsedRequirement, SkillDict, SkillDictItem } from '../model/Entity';

export class ResumeParseService {
  static parse(text: string, dict: SkillDict): ParsedRequirement {
    const lower: string = text.toLowerCase();
    let education: string = '';
    for (let i: number = dict.educationRank.length - 1; i >= 0; i--) {
      const rank: string = dict.educationRank[i];
      if (text.includes(rank)) {
        education = rank;
        break;
      }
    }

    const skills: string[] = [];
    for (const item of dict.skills) {
      if (ResumeParseService.hitPositive(lower, item)) {
        skills.push(item.name);
      }
    }

    const certificates: string[] = [];
    for (const item of dict.certificates) {
      if (ResumeParseService.hitPositive(lower, item)) {
        certificates.push(item.name);
      }
    }

    const years: number = ResumeParseService.extractYears(text.replace(/\s+/g, ''));

    const keywords: string[] = [];
    const keywordList: string[] = ['实习', '项目经验', '工作经验', '应届生'];
    for (const keyword of keywordList) {
      if (text.includes(keyword)) {
        keywords.push(keyword);
      }
    }

    return {
      educationReq: education,
      skillReq: skills,
      certReq: certificates,
      experienceYears: years,
      experienceKeywords: keywords
    };
  }

  private static hitPositive(lower: string, item: SkillDictItem): boolean {
    const aliases: string[] = [item.name].concat(item.aliases);
    for (const alias of aliases) {
      const word: string = alias.toLowerCase();
      if (word.length === 0) {
        continue;
      }
      let from: number = 0;
      let index: number = lower.indexOf(word, from);
      while (index >= 0) {
        const raw: string = lower.substring(Math.max(0, index - 20), index);
        const cuts: number[] = [
          raw.lastIndexOf('，'), raw.lastIndexOf('。'), raw.lastIndexOf('；'),
          raw.lastIndexOf(','), raw.lastIndexOf(';'), raw.lastIndexOf('、')
        ];
        let cut: number = -1;
        for (const value of cuts) {
          cut = Math.max(cut, value);
        }
        const prefix: string = cut >= 0 ? raw.substring(cut + 1) : raw;
        if (!/(无需|不需要|不要求|不熟悉|不必须|不强制|非|无)/.test(prefix)) {
          return true;
        }
        from = index + word.length;
        index = lower.indexOf(word, from);
      }
    }
    return false;
  }

  private static extractYears(text: string): number {
    const patterns: RegExp[] = [
      /(\d{1,2})年(?:以上|及以上)?(?:工作|开发|项目|相关|从业){0,2}经验/,
      /(?:工作|开发|项目|相关|从业)经验(?:要求)?(?:至少|不少于)?(\d{1,2})年/,
      /(?:至少|不少于|拥有|具备)(\d{1,2})年(?:以上|及以上)?(?:工作|开发|项目|相关|从业){0,2}经验/
    ];
    for (const pattern of patterns) {
      const matched: RegExpMatchArray | null = text.match(pattern);
      if (matched !== null && matched.length > 1) {
        const value: number = Number(matched[1]);
        if (value > 0 && value < 50) {
          return value;
        }
      }
    }
    const chinese: RegExpMatchArray | null =
      text.match(/([一二两三四五六七八九十]{1,3})年(?:以上|及以上)?(?:工作|开发|项目|相关|从业){0,2}经验/);
    if (chinese !== null && chinese.length > 1) {
      const value: number = ResumeParseService.chineseNumber(chinese[1]);
      if (value > 0 && value < 50) {
        return value;
      }
    }
    return 0;
  }

  private static chineseNumber(value: string): number {
    const digits: string[] = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    if (value === '两') {
      return 2;
    }
    if (value === '十') {
      return 10;
    }
    const index: number = value.indexOf('十');
    if (index > 0) {
      const tens: number = digits.indexOf(value.substring(0, 1));
      const rest: string = value.substring(index + 1);
      const ones: number = rest.length > 0 ? digits.indexOf(rest) : 0;
      if (tens > 0 && ones >= 0) {
        return tens * 10 + ones;
      }
    }
    if (index === 0) {
      const ones: number = digits.indexOf(value.substring(1));
      if (ones > 0) {
        return 10 + ones;
      }
    }
    const single: number = digits.indexOf(value);
    return single > 0 ? single : 0;
  }
}
