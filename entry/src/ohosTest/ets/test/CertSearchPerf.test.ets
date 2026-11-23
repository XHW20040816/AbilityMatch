import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { beforeAll, describe, expect, it } from '@ohos/hypium';
import { Constants } from '../../../main/ets/common/Constants';
import { DbHelper } from '../../../main/ets/common/DbHelper';
import { FileHelper } from '../../../main/ets/common/FileHelper';
import { HonorFilter } from '../../../main/ets/model/Entity';
import { honorRepo } from '../../../main/ets/repository/Repositories';
import { testAbilityContext } from '../testability/TestAbility';

const PERF_TAG: number = 0x0001;
const PERF_DOMAIN: string = 'PerfTest';
const ROW_COUNT: number = 1000;
const ROUNDS: number = 20;

interface TimingSummary {
  min: number;
  max: number;
  avg: number;
  p95: number;
  samples: number[];
}

interface PerfReport {
  scenario: string;
  rowCount: number;
  rounds: number;
  limit: number;
  keywordSearchMs: TimingSummary;
  countQueryMs: TimingSummary;
  noHitSearchMs: TimingSummary;
  measuredAt: string;
}

function summarize(times: number[]): TimingSummary {
  const sorted: number[] = times.slice().sort((a: number, b: number): number => a - b);
  const sum: number = times.reduce((acc: number, v: number): number => acc + v, 0);
  const p95Index: number = Math.min(sorted.length - 1, Math.floor(sorted.length * 0.95));
  return {
    min: sorted[0],
    max: sorted[sorted.length - 1],
    avg: Math.round((sum / times.length) * 100) / 100,
    p95: sorted[p95Index],
    samples: times
  };
}

/**
 * G-10 性能证据：1000 条证书数据下的关键字检索耗时。
 * 在临时学生下写入 1000 条荣誉证书，重复执行关键字检索与计数，输出 JSON 报告。
 */
export default function certSearchPerfTest() {
  describe('CertSearchPerfTest', () => {
    let filesDir: string = '';
    let tempStudentId: number = 0;

    beforeAll(async () => {
      const context: common.UIAbilityContext | null = testAbilityContext;
      expect(context !== null).assertTrue();
      if (context === null) {
        throw new Error('testAbilityContext is null');
      }
      filesDir = context.filesDir;
      await DbHelper.init(context);
      hilog.info(PERF_TAG, PERF_DOMAIN, 'PerfTest ready, filesDir=%{public}s', filesDir);
    });

    it('perf_01_keyword_search_under_1000_rows', 0, async () => {
      const now: number = Date.now();
      tempStudentId = await DbHelper.insert(Constants.T_STUDENT, {
        student_no: 'PERF_TEMP_001',
        name: '性能测试学生',
        major: '计算机科学与技术',
        grade: '大三',
        education: '本科',
        direction: '软件开发',
        phone: '',
        email: '',
        create_time: now,
        update_time: now
      });
      expect(tempStudentId > 0).assertTrue();

      // 事务批量写入 1000 条记录（executeSql 不支持 BEGIN/COMMIT，使用事务 API）
      const store = DbHelper.getStore();
      store.beginTransaction();
      try {
        for (let i: number = 0; i < ROW_COUNT; i++) {
          await DbHelper.insert(Constants.T_HONOR, {
            student_id: tempStudentId,
            title: `性能测试证书-${i}`,
            honor_type: i % 2 === 0 ? 'COMPETITION' : 'CERTIFICATE',
            level: 'NATIONAL',
            award_year: 2020 + (i % 6),
            issuer: '测试颁发单位',
            image_path: '',
            remark: `remark ${i}`,
            search_text: `性能测试证书-${i} 测试颁发单位 remark ${i}`,
            create_time: now,
            update_time: now
          });
        }
        store.commit();
      } catch (error) {
        store.rollBack();
        throw new Error('failed to seed perf data');
      }

      const filter: HonorFilter = {
        keyword: '证书', honorType: '', level: '', yearFrom: 0, yearTo: 0, issuer: ''
      };
      const noHitFilter: HonorFilter = {
        keyword: '不存在的关键字xyz', honorType: '', level: '', yearFrom: 0, yearTo: 0, issuer: ''
      };

      const total: number = await honorRepo.count(tempStudentId, filter);
      expect(total).assertEqual(ROW_COUNT);

      // 预热
      await honorRepo.list(tempStudentId, filter, 100, 0);

      const searchTimes: number[] = [];
      const countTimes: number[] = [];
      const noHitTimes: number[] = [];
      for (let round: number = 0; round < ROUNDS; round++) {
        let t0: number = Date.now();
        const rows = await honorRepo.list(tempStudentId, filter, 100, 0);
        searchTimes.push(Date.now() - t0);
        expect(rows.length).assertEqual(100);

        t0 = Date.now();
        await honorRepo.count(tempStudentId, filter);
        countTimes.push(Date.now() - t0);

        t0 = Date.now();
        const noHitRows = await honorRepo.list(tempStudentId, noHitFilter, 100, 0);
        noHitTimes.push(Date.now() - t0);
        expect(noHitRows.length).assertEqual(0);
      }

      const kw: TimingSummary = summarize(searchTimes);
      const report: PerfReport = {
        scenario: 'honor_certificate keyword search under 1000 rows',
        rowCount: ROW_COUNT,
        rounds: ROUNDS,
        limit: 100,
        keywordSearchMs: kw,
        countQueryMs: summarize(countTimes),
        noHitSearchMs: summarize(noHitTimes),
        measuredAt: new Date().toISOString()
      };
      const reportPath: string = `${filesDir}/perf_cert_search.json`;
      FileHelper.writeTextFile(reportPath, JSON.stringify(report, null, 2));
      hilog.info(PERF_TAG, PERF_DOMAIN,
        'PerfTest report saved to %{public}s', reportPath);
      hilog.info(PERF_TAG, PERF_DOMAIN,
        'keywordSearch avg=%{public}sms min=%{public}s max=%{public}s p95=%{public}s',
        String(kw.avg), String(kw.min), String(kw.max), String(kw.p95));
    });

    it('perf_02_cleanup_temp_data', 0, async () => {
      if (tempStudentId > 0) {
        await DbHelper.execute(
          `DELETE FROM ${Constants.T_HONOR} WHERE student_id = ?`, [tempStudentId]
        );
        await DbHelper.execute(
          `DELETE FROM ${Constants.T_STUDENT} WHERE id = ?`, [tempStudentId]
        );
      }
      const remaining: number = await DbHelper.count(
        `SELECT COUNT(*) AS cnt FROM ${Constants.T_HONOR} WHERE student_id = ?`,
        [tempStudentId]
      );
      expect(remaining).assertEqual(0);
    });
  });
}
