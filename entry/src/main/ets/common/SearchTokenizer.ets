export class SearchTokenizer {
  static normalize(text: string): string {
    return text.toLowerCase().replace(/[^\u4e00-\u9fa5a-z0-9]/g, '');
  }

  static tokens(text: string): string[] {
    const normalized: string = SearchTokenizer.normalize(text);
    const tokens: string[] = [];
    if (normalized.length === 0) {
      return tokens;
    }
    for (let i: number = 0; i < normalized.length; i++) {
      const single: string = normalized.substring(i, i + 1);
      if (tokens.indexOf(single) < 0) {
        tokens.push(single);
      }
      if (i + 2 <= normalized.length) {
        const pair: string = normalized.substring(i, i + 2);
        if (tokens.indexOf(pair) < 0) {
          tokens.push(pair);
        }
      }
    }
    return tokens;
  }
}
