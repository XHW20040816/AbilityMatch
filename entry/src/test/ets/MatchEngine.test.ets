import { describe, expect, it } from '@ohos/hypium';
import {
  AbilityTag, AdviceLib, HonorCertificate, JobRequirement, MatchResult, MatchWeights,
  ProjectExperience, SkillCertificate, SkillDict, Student
} from '../../main/ets/model/Entity';
import { HonorLevel, HonorType, TagCategory } from '../../main/ets/model/Enums';
import { MatchEngine } from '../../main/ets/service/MatchEngine';

const student: Student = {
  id: 1,
  studentNo: '20240001',
  name: '测试学生',
  school: '测试大学',
  schoolLevel: '其他',
  major: '计算机科学与技术',
  grade: '大三',
  education: '本科',
  direction: '软件开发',
  phone: '',
  email: ''
};

const weights: MatchWeights = {
  education: 0.15,
  skill: 0.30,
  certificate: 0.15,
  experience: 0.15,
  honor: 0.10,
  direction: 0.15
};

const job: JobRequirement = {
  id: 1,
  companyId: 1,
  companyName: '测试企业',
  jobTitle: 'HarmonyOS 开发',
  majorDirection: '软件开发',
  rawText: '',
  educationReq: '本科',
  skillReq: ['Java', 'HarmonyOS'],
  certReq: ['CET-6'],
  experienceYears: 1,
  experienceKeywords: ['项目经验'],
  weights: weights,
  status: 1
};

const advice: AdviceLib = {
  advice: [
    { key: 'CET-6', text: '建议备考六级' },
    { key: 'Java', text: '建议补充 Java 项目' }
  ],
  default: '建议补充相关经历'
};

const dict: SkillDict = {
  version: '2.0.0',
  skills: [
    { name: 'Java', aliases: ['JAVA', 'Java语言'], category: 'PROGRAMMING' },
    { name: 'HarmonyOS', aliases: ['鸿蒙'], category: 'PLATFORM' }
  ],
  certificates: [
    { name: 'CET-6', aliases: ['六级', '大学英语六级'], category: 'CERT' }
  ],
  educationRank: ['大专', '本科', '硕士', '博士']
};

function certificateTag(name: string): AbilityTag {
  return {
    id: 1, studentId: 1, tagName: name, category: TagCategory.CERTIFICATE,
    sourceType: 'SKILL_CERT', sourceId: 1, proficiency: 4, confidence: 1.0
  };
}

export default function matchEngineTest(): void {
  describe('MatchEngine', () => {
    it('should compute weighted score and gap items', 0, () => {
      const tags: AbilityTag[] = [
        {
          id: 1, studentId: 1, tagName: 'Java', category: TagCategory.SKILL,
          sourceType: 'HONOR', sourceId: 1, proficiency: 4, confidence: 1.0
        },
        {
          id: 2, studentId: 1, tagName: 'HarmonyOS', category: TagCategory.SKILL,
          sourceType: 'PROJECT', sourceId: 1, proficiency: 4, confidence: 1.0
        }
      ];
      const certs: SkillCertificate[] = [];
      const projects: ProjectExperience[] = [];
      const honors: HonorCertificate[] = [];
      const result: MatchResult = MatchEngine.compute(
        student, tags, certs, projects, honors, job, advice
      );
      expect(result.dimensionScores.skill).assertEqual(1);
      expect(result.dimensionScores.certificate).assertEqual(0);
      expect(result.dimensionScores.experience).assertEqual(1);
      expect(result.dimensionScores.education).assertEqual(0.92);
      expect(result.dimensionScores.direction).assertEqual(1);
      expect(result.totalScore).assertEqual(73.8);
      expect(result.gapItems.length).assertEqual(1);
      expect(result.suggestions[0]).assertEqual('建议备考六级');
    });

    it('should handle empty requirements', 0, () => {
      const emptyJob: JobRequirement = {
        id: 2, companyId: 1, companyName: '测试企业', jobTitle: '不限岗位',
        majorDirection: '软件开发',
        rawText: '', educationReq: '', skillReq: [], certReq: [],
        experienceYears: 0, experienceKeywords: [], weights: weights, status: 1
      };
      const result: MatchResult = MatchEngine.compute(
        student, [], [], [], [], emptyJob, advice
      );
      expect(result.totalScore).assertEqual(90);
    });

    it('should treat PhD student as highest education rank', 0, () => {
      const phd: Student = {
        id: 2, studentNo: '20240002', name: '博士学生', school: '测试大学', schoolLevel: '985',
        major: '计算机科学与技术', grade: '博士研究生', education: '博士', direction: '软件开发',
        phone: '', email: ''
      };
      const phdJob: JobRequirement = {
        id: 3, companyId: 1, companyName: '测试企业', jobTitle: '研究岗位',
        majorDirection: '软件开发',
        rawText: '', educationReq: '博士', skillReq: [], certReq: [],
        experienceYears: 0, experienceKeywords: [], weights: weights, status: 1
      };
      const result: MatchResult = MatchEngine.compute(
        phd, [], [], [], [], phdJob, advice
      );
      expect(result.dimensionScores.education).assertEqual(1);
    });

    it('should normalize certificate aliases with dictionary', 0, () => {
      const result: MatchResult = MatchEngine.compute(
        student, [certificateTag('六级')], [], [], [], job, advice, dict
      );
      expect(result.dimensionScores.certificate).assertEqual(1);
      expect(result.gapItems.length).assertEqual(2);
    });

    it('should ignore competition honors when matching certificates', 0, () => {
      const honors: HonorCertificate[] = [{
        id: 1, studentId: 1, title: 'CET-6', honorType: HonorType.COMPETITION,
        level: HonorLevel.NATIONAL, awardYear: 2025, issuer: '', imagePath: '',
        remark: '', searchText: 'cet-6', createTime: 0
      }];
      const result: MatchResult = MatchEngine.compute(
        student, [], [], [], honors, job, advice, dict
      );
      expect(result.dimensionScores.certificate).assertEqual(0);
    });

    it('should penalize mismatched major direction', 0, () => {
      const aiJob: JobRequirement = {
        id: 4, companyId: 1, companyName: '测试企业', jobTitle: '算法岗位',
        majorDirection: '人工智能',
        rawText: '', educationReq: '本科', skillReq: ['Java', 'HarmonyOS'], certReq: ['CET-6'],
        experienceYears: 1, experienceKeywords: [], weights: weights, status: 1
      };
      const tags: AbilityTag[] = [
        { id: 1, studentId: 1, tagName: 'Java', category: TagCategory.SKILL,
          sourceType: 'HONOR', sourceId: 1, proficiency: 4, confidence: 1 },
        { id: 2, studentId: 1, tagName: 'HarmonyOS', category: TagCategory.SKILL,
          sourceType: 'PROJECT', sourceId: 1, proficiency: 4, confidence: 1 }
      ];
      const result: MatchResult = MatchEngine.compute(
        student, tags, [], [], [], aiJob, advice
      );
      expect(result.dimensionScores.direction).assertEqual(0);
      expect(result.gapItems.length).assertEqual(2);
      expect(result.totalScore).assertEqual(58.8);
    });

    it('should treat adjacent directions as partial match', 0, () => {
      const javaStudent: Student = {
        id: 3, studentNo: '20240003', name: 'Java 学生', school: '测试大学', schoolLevel: '其他',
        major: '软件工程', grade: '大三', education: '本科', direction: 'Java 后端',
        phone: '', email: ''
      };
      const result: MatchResult = MatchEngine.compute(
        javaStudent, [], [], [], [], job, advice
      );
      expect(result.dimensionScores.direction).assertEqual(0.7);
    });

    it('should give 985 undergraduate full education score', 0, () => {
      const topStudent: Student = {
        id: 4, studentNo: '20240004', name: '985 学生', school: '测试大学', schoolLevel: '985',
        major: '计算机科学与技术', grade: '大三', education: '本科', direction: '软件开发',
        phone: '', email: ''
      };
      const result: MatchResult = MatchEngine.compute(
        topStudent, [], [], [], [], job, advice
      );
      expect(result.dimensionScores.education).assertEqual(1);
    });

    it('should be sensitive to direction weight', 0, () => {
      const lowDirection: MatchWeights = {
        education: 0.15, skill: 0.35, certificate: 0.15, experience: 0.2, honor: 0.15, direction: 0
      };
      const highDirection: MatchWeights = {
        education: 0.10, skill: 0.25, certificate: 0.10, experience: 0.15, honor: 0.10, direction: 0.30
      };
      const lowJob: JobRequirement = {
        id: 5, companyId: 1, companyName: '测试企业', jobTitle: '算法岗位',
        majorDirection: '人工智能', rawText: '', educationReq: '本科',
        skillReq: ['Java', 'HarmonyOS'], certReq: ['CET-6'], experienceYears: 1,
        experienceKeywords: [], weights: lowDirection, status: 1
      };
      const highJob: JobRequirement = {
        id: 6, companyId: 1, companyName: '测试企业', jobTitle: '算法岗位',
        majorDirection: '人工智能', rawText: '', educationReq: '本科',
        skillReq: ['Java', 'HarmonyOS'], certReq: ['CET-6'], experienceYears: 1,
        experienceKeywords: [], weights: highDirection, status: 1
      };
      const tags: AbilityTag[] = [
        { id: 1, studentId: 1, tagName: 'Java', category: TagCategory.SKILL,
          sourceType: 'HONOR', sourceId: 1, proficiency: 4, confidence: 1 },
        { id: 2, studentId: 1, tagName: 'HarmonyOS', category: TagCategory.SKILL,
          sourceType: 'PROJECT', sourceId: 1, proficiency: 4, confidence: 1 }
      ];
      const low: MatchResult = MatchEngine.compute(student, tags, [], [], [], lowJob, advice);
      const high: MatchResult = MatchEngine.compute(student, tags, [], [], [], highJob, advice);
      expect(high.totalScore < low.totalScore).assertTrue();
    });

    it('should compute 1000 candidates within budget', 0, () => {
      const tags: AbilityTag[] = [
        { id: 1, studentId: 1, tagName: 'Java', category: TagCategory.SKILL,
          sourceType: 'HONOR', sourceId: 1, proficiency: 4, confidence: 1 },
        { id: 2, studentId: 1, tagName: 'HarmonyOS', category: TagCategory.SKILL,
          sourceType: 'PROJECT', sourceId: 1, proficiency: 4, confidence: 1 }
      ];
      const start: number = Date.now();
      for (let i: number = 0; i < 1000; i++) {
        MatchEngine.compute(student, tags, [], [], [], job, advice);
      }
      const elapsed: number = Date.now() - start;
      console.info(`MatchEngine benchmark: 1000 candidates in ${elapsed}ms`);
      expect(elapsed < 5000).assertTrue();
    });
  });
}
