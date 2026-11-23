import { SearchTokenizer } from './SearchTokenizer';
import { HonorFilter } from '../model/Entity';

export interface HonorQueryFragment {
  clause: string;
  args: (string | number)[];
}

/**
 * 荣誉检索条件的纯函数构造：把“关键字倒排 + 类型 + 级别 + 年份区间 + 颁发单位”
 * 归一为 SQL 片段与参数，Repository 只负责执行，便于单元测试覆盖筛选逻辑。
 */
export class HonorQuery {
  static build(studentId: number, filter: HonorFilter): HonorQueryFragment {
    let clause: string = '';
    const args: (string | number)[] = [studentId];

    const tokens: string[] = SearchTokenizer.tokens(filter.keyword);
    if (tokens.length > 0) {
      let marks: string = '';
      for (let i: number = 0; i < tokens.length; i++) {
        marks += i === 0 ? '?' : ', ?';
      }
      clause += ` AND id IN (SELECT honor_id FROM honor_search_token ` +
        `WHERE student_id = ? AND token IN (${marks}) GROUP BY honor_id HAVING COUNT(DISTINCT token) = ?)`;
      clause += ' AND search_text LIKE ?';
      args.push(studentId);
      for (const token of tokens) {
        args.push(token);
      }
      args.push(tokens.length);
      args.push(`%${SearchTokenizer.normalize(filter.keyword)}%`);
    }

    if (filter.honorType.length > 0) {
      clause += ' AND honor_type = ?';
      args.push(filter.honorType);
    }
    if (filter.level.length > 0) {
      clause += ' AND level = ?';
      args.push(filter.level);
    }
    if (filter.yearFrom > 0) {
      clause += ' AND award_year >= ?';
      args.push(filter.yearFrom);
    }
    if (filter.yearTo > 0) {
      clause += ' AND award_year <= ?';
      args.push(filter.yearTo);
    }
    const issuer: string = filter.issuer.trim();
    if (issuer.length > 0) {
      clause += ' AND issuer LIKE ?';
      args.push(`%${issuer}%`);
    }
    return { clause: clause, args: args };
  }
}
