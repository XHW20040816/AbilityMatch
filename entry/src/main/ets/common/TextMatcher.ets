import { SkillDictItem } from '../model/Entity';

/**
 * 统一的关键字匹配与词典归一化工具。
 * - contains: 英文关键字按“词边界”匹配，避免 Java 命中 JavaScript
 * - canonical: 把任意写法（含别名）映射回词典中的标准名称
 */
export class TextMatcher {
  static contains(text: string, keyword: string): boolean {
    const lowerText: string = text.toLowerCase();
    const lower: string = keyword.toLowerCase().trim();
    if (lower.length === 0 || lowerText.length < lower.length) {
      return false;
    }
    let from: number = 0;
    while (from <= lowerText.length - lower.length) {
      const index: number = lowerText.indexOf(lower, from);
      if (index < 0) {
        return false;
      }
      const blockedBefore: boolean = TextMatcher.isAsciiLetter(lowerText, index - 1);
      const blockedAfter: boolean = TextMatcher.isAsciiLetter(lowerText, index + lower.length);
      if (!blockedBefore && !blockedAfter) {
        return true;
      }
      from = index + 1;
    }
    return false;
  }

  static hit(text: string, item: SkillDictItem): boolean {
    if (TextMatcher.contains(text, item.name)) {
      return true;
    }
    for (const alias of item.aliases) {
      if (TextMatcher.contains(text, alias)) {
        return true;
      }
    }
    return false;
  }

  static canonical(value: string, items: SkillDictItem[]): string {
    const trimmed: string = value.trim();
    const lower: string = trimmed.toLowerCase();
    if (lower.length === 0) {
      return '';
    }
    for (const item of items) {
      if (lower === item.name.toLowerCase()) {
        return item.name;
      }
      for (const alias of item.aliases) {
        if (lower === alias.toLowerCase()) {
          return item.name;
        }
      }
    }
    for (const item of items) {
      if (TextMatcher.hit(lower, item)) {
        return item.name;
      }
    }
    return trimmed;
  }

  static canonicalList(values: string[], items: SkillDictItem[]): string[] {
    const result: string[] = [];
    for (const value of values) {
      const canonical: string = TextMatcher.canonical(value, items);
      if (canonical.length > 0 && result.indexOf(canonical) < 0) {
        result.push(canonical);
      }
    }
    return result;
  }

  private static isAsciiLetter(text: string, index: number): boolean {
    if (index < 0 || index >= text.length) {
      return false;
    }
    const code: number = text.charCodeAt(index);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }
}
