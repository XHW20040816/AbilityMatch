import { describe, expect, it } from '@ohos/hypium';
import { JobFilter } from '../../main/ets/common/JobFilter';
import { JobRequirement, MatchWeights } from '../../main/ets/model/Entity';

const weights: MatchWeights = {
  education: 20, skill: 30, certificate: 15, experience: 15, honor: 10, direction: 10
};

function makeJob(id: number, title: string, company: string, direction: string,
                  education: string, skills: string[]): JobRequirement {
  return {
    id: id,
    companyId: 1,
    companyName: company,
    jobTitle: title,
    majorDirection: direction,
    rawText: `${title} ${company} ${skills.join(' ')}`,
    educationReq: education,
    skillReq: skills,
    certReq: [],
    experienceYears: 1,
    experienceKeywords: [],
    weights: weights,
    status: 1
  };
}

const jobs: JobRequirement[] = [
  makeJob(1, 'HarmonyOS 应用开发工程师', '示例科技有限公司', '软件开发', '本科', ['ArkTS', 'ArkUI']),
  makeJob(2, 'Java 后端开发工程师', '云帆数据', '软件开发', '本科', ['Java', 'Spring Boot']),
  makeJob(3, '算法工程师', '智研科技', '人工智能', '硕士', ['Python', 'PyTorch'])
];

export default function jobFilterTest() {
  describe('JobFilter', () => {
    it('空关键字返回全部岗位', 0, () => {
      expect(JobFilter.matchIds(jobs, '', '').length).assertEqual(3);
    });

    it('标题关键字命中', 0, () => {
      const ids: number[] = JobFilter.matchIds(jobs, '', 'HarmonyOS');
      expect(ids.length).assertEqual(1);
      expect(ids[0]).assertEqual(1);
    });

    it('企业名称与技能关键字均可命中', 0, () => {
      expect(JobFilter.matchIds(jobs, '', '云帆').length).assertEqual(1);
      expect(JobFilter.matchIds(jobs, '', 'PyTorch')[0]).assertEqual(3);
    });

    it('多词 AND 匹配', 0, () => {
      expect(JobFilter.matchIds(jobs, '', 'Java 后端').length).assertEqual(1);
      expect(JobFilter.matchIds(jobs, '', 'Java ArkTS').length).assertEqual(0);
    });

    it('方向筛选与关键字叠加', 0, () => {
      expect(JobFilter.matchIds(jobs, '软件开发', '').length).assertEqual(2);
      expect(JobFilter.matchIds(jobs, '人工智能', 'Java').length).assertEqual(0);
      expect(JobFilter.matchIds(jobs, '人工智能', '算法')[0]).assertEqual(3);
    });

    it('大小写与符号不影响匹配', 0, () => {
      expect(JobFilter.matchIds(jobs, '', 'arkts').length).assertEqual(1);
      expect(JobFilter.matchIds(jobs, '', 'Spring-Boot').length).assertEqual(1);
    });

    it('搜索历史去重且限制数量', 0, () => {
      let history: string[] = [];
      history = JobFilter.pushHistory(history, 'Java', 3);
      history = JobFilter.pushHistory(history, 'ArkTS', 3);
      history = JobFilter.pushHistory(history, 'Java', 3);
      expect(history.length).assertEqual(2);
      expect(history[0]).assertEqual('Java');
      history = JobFilter.pushHistory(history, '算法', 3);
      history = JobFilter.pushHistory(history, '后端', 3);
      expect(history.length).assertEqual(3);
      expect(history[0]).assertEqual('后端');
      expect(JobFilter.pushHistory(history, '   ', 3).length).assertEqual(3);
    });
  });
}
