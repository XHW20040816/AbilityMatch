import { describe, expect, it } from '@ohos/hypium';
import {
  AbilityTag, AdviceLib, JobRequirement, MatchResult, MatchWeights, SemanticResult, Student
} from '../../main/ets/model/Entity';
import { TagCategory } from '../../main/ets/model/Enums';
import { MatchEngine } from '../../main/ets/service/MatchEngine';
import { SemanticMatchService } from '../../main/ets/service/SemanticMatchService';

const student: Student = {
  id: 1, studentNo: '20240001', name: '测试学生', school: '测试大学', schoolLevel: '其他',
  major: '计算机科学与技术', grade: '大三', education: '本科', direction: '软件开发',
  phone: '', email: ''
};

const weights: MatchWeights = {
  education: 0.15, skill: 0.30, certificate: 0.15, experience: 0.15, honor: 0.10, direction: 0.15
};

const job: JobRequirement = {
  id: 1, companyId: 1, companyName: '测试企业', jobTitle: 'HarmonyOS 开发',
  majorDirection: '软件开发', rawText: '', educationReq: '本科',
  skillReq: ['Java', 'HarmonyOS'], certReq: ['CET-6'], experienceYears: 1,
  experienceKeywords: [], weights: weights, status: 1
};

const advice: AdviceLib = {
  advice: [{ key: 'CET-6', text: '建议备考六级' }],
  default: '建议补充相关经历'
};

const semantic: SemanticResult = {
  scores: { education: 0.8, skill: 1, certificate: 1, experience: 0.9, honor: 0.7, direction: 0.9 },
  overall: 0.88,
  reason: '技能与方向高度匹配',
  strengths: ['鸿蒙项目经验'],
  gaps: ['缺少大厂实习'],
  model: 'deepseek-chat',
  createTime: 0
};

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

export default function semanticMatchTest(): void {
  describe('SemanticMatch', () => {
    it('should blend rule and semantic scores by alpha', 0, () => {
      const tags: AbilityTag[] = [
        { id: 1, studentId: 1, tagName: 'Java', category: TagCategory.SKILL,
          sourceType: 'HONOR', sourceId: 1, proficiency: 4, confidence: 1 }
      ];
      const base: MatchResult = MatchEngine.compute(student, tags, [], [], [], job, advice);
      const merged: MatchResult = MatchEngine.mergeSemantic(base, weights, semantic);
      // 技能 α = 0.45：0.5(规则) × 0.55 + 1(语义) × 0.45
      expect(merged.dimensionScores.skill).assertEqual(round2(base.dimensionScores.skill * 0.55 + 0.45));
      // 学历 α = 0.2
      expect(merged.dimensionScores.education)
        .assertEqual(round2(base.dimensionScores.education * 0.8 + 0.8 * 0.2));
    });

    it('should mark semantic flag and merge reason into suggestions', 0, () => {
      const base: MatchResult = MatchEngine.compute(student, [], [], [], [], job, advice);
      const merged: MatchResult = MatchEngine.mergeSemantic(base, weights, semantic);
      expect(merged.semantic).assertTrue();
      expect(merged.semanticModel).assertEqual('deepseek-chat');
      expect(merged.semanticOverall).assertEqual(0.88);
      expect(merged.suggestions.some((item: string) => item.indexOf('AI 语义评价') >= 0)).assertTrue();
      expect(merged.gapItems.some((item: string) => item.indexOf('语义差距：缺少大厂实习') >= 0)).assertTrue();
    });

    it('should keep total score within 0-100 after merging', 0, () => {
      const base: MatchResult = MatchEngine.compute(student, [], [], [], [], job, advice);
      const merged: MatchResult = MatchEngine.mergeSemantic(base, weights, semantic);
      expect(merged.totalScore >= 0 && merged.totalScore <= 100).assertTrue();
      // 语义分全面高于规则分时，总分应不低于规则分
      expect(merged.totalScore >= base.totalScore).assertTrue();
    });

    it('should parse plain json returned by model', 0, () => {
      const text: string = '{"education":0.9,"skill":0.8,"certificate":0.5,"experience":0.6,' +
        '"honor":0.4,"direction":0.85,"overall":0.75,"reason":"匹配良好",' +
        '"strengths":["技能吻合"],"gaps":["证书不足"]}';
      const parsed: SemanticResult | null = SemanticMatchService.parseSemantic(text, 'deepseek-chat');
      expect(parsed !== null).assertTrue();
      if (parsed !== null) {
        expect(parsed.scores.skill).assertEqual(0.8);
        expect(parsed.overall).assertEqual(0.75);
        expect(parsed.reason).assertEqual('匹配良好');
        expect(parsed.gaps.length).assertEqual(1);
      }
    });

    it('should parse json wrapped in markdown fence and string numbers', 0, () => {
      const text: string = '```json\n{"skill":"0.8","direction":"0.6","overall":"0.7",' +
        '"reason":"ok","strengths":[],"gaps":[]}\n```';
      const parsed: SemanticResult | null = SemanticMatchService.parseSemantic(text, 'qwen-plus');
      expect(parsed !== null).assertTrue();
      if (parsed !== null) {
        expect(parsed.scores.skill).assertEqual(0.8);
        expect(parsed.scores.direction).assertEqual(0.6);
        // 缺省维度按中性分兜底，不会因个别字段缺失整条作废
        expect(parsed.scores.certificate).assertEqual(0.6);
        expect(parsed.scores.honor).assertEqual(0.5);
        expect(parsed.model).assertEqual('qwen-plus');
      }
    });

    it('should clamp out-of-range values and reject garbage', 0, () => {
      const parsed: SemanticResult | null = SemanticMatchService.parseSemantic(
        '{"skill":1.8,"direction":-0.2,"overall":2}', 'test-model');
      expect(parsed !== null).assertTrue();
      if (parsed !== null) {
        expect(parsed.scores.skill).assertEqual(1);
        expect(parsed.scores.direction).assertEqual(0);
        expect(parsed.overall).assertEqual(1);
      }
      expect(SemanticMatchService.parseSemantic('抱歉，我无法评分', 'test-model') === null).assertTrue();
    });
  });
}
