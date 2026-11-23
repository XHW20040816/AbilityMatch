import { describe, expect, it } from '@ohos/hypium';
import { HonorQuery, HonorQueryFragment } from '../../main/ets/common/HonorQuery';
import { HonorFilter } from '../../main/ets/model/Entity';
import { SearchTokenizer } from '../../main/ets/common/SearchTokenizer';

function makeFilter(): HonorFilter {
  return { keyword: '', honorType: '', level: '', yearFrom: 0, yearTo: 0, issuer: '' };
}

export default function honorQueryTest() {
  describe('HonorQuery', () => {
    it('空筛选只保留学生条件', 0, () => {
      const fragment: HonorQueryFragment = HonorQuery.build(7, makeFilter());
      expect(fragment.clause).assertEqual('');
      expect(fragment.args.length).assertEqual(1);
      expect(fragment.args[0]).assertEqual(7);
    });

    it('颁发单位使用模糊匹配', 0, () => {
      const filter: HonorFilter = makeFilter();
      filter.issuer = ' 教育部 ';
      const fragment: HonorQueryFragment = HonorQuery.build(1, filter);
      expect(fragment.clause).assertContain('issuer LIKE');
      expect(fragment.args[fragment.args.length - 1]).assertEqual('%教育部%');
    });

    it('类型/级别/年份区间按顺序拼接参数', 0, () => {
      const filter: HonorFilter = makeFilter();
      filter.honorType = '学科竞赛';
      filter.level = '国家级';
      filter.yearFrom = 2022;
      filter.yearTo = 2024;
      const fragment: HonorQueryFragment = HonorQuery.build(3, filter);
      expect(fragment.clause).assertContain('honor_type = ?');
      expect(fragment.clause).assertContain('level = ?');
      expect(fragment.clause).assertContain('award_year >= ?');
      expect(fragment.clause).assertContain('award_year <= ?');
      expect(fragment.args.length).assertEqual(5);
      expect(fragment.args[1]).assertEqual('学科竞赛');
      expect(fragment.args[2]).assertEqual('国家级');
      expect(fragment.args[3]).assertEqual(2022);
      expect(fragment.args[4]).assertEqual(2024);
    });

    it('关键字生成倒排索引子查询与模糊兜底', 0, () => {
      const filter: HonorFilter = makeFilter();
      filter.keyword = '蓝桥杯';
      const fragment: HonorQueryFragment = HonorQuery.build(1, filter);
      expect(fragment.clause).assertContain('honor_search_token');
      expect(fragment.clause).assertContain('search_text LIKE ?');
      const tokenCount: number = SearchTokenizer.tokens('蓝桥杯').length;
      expect(fragment.args.length).assertEqual(1 + 1 + tokenCount + 1 + 1);
    });

    it('全部条件组合时参数数量与占位符一致', 0, () => {
      const filter: HonorFilter = makeFilter();
      filter.keyword = '数学建模';
      filter.honorType = '学科竞赛';
      filter.level = '省级';
      filter.yearFrom = 2023;
      filter.issuer = '教育厅';
      const fragment: HonorQueryFragment = HonorQuery.build(2, filter);
      const placeholders: number = fragment.clause.split('?').length - 1;
      expect(fragment.args.length).assertEqual(placeholders + 1);
    });
  });
}
