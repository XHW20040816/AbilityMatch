import { describe, expect, it } from '@ohos/hypium';
import { SkillDict } from '../../main/ets/model/Entity';
import { ResumeParseService } from '../../main/ets/service/ResumeParseService';

const dict: SkillDict = {
  version: '1.0.0',
  skills: [
    { name: 'Java', aliases: ['JAVA', 'Java语言'], category: 'PROGRAMMING' },
    { name: 'HarmonyOS', aliases: ['鸿蒙', 'ArkTS'], category: 'PLATFORM' }
  ],
  certificates: [
    { name: 'CET-6', aliases: ['大学英语六级', '六级'], category: 'CERTIFICATE' }
  ],
  educationRank: ['大专', '本科', '硕士', '博士']
};

export default function resumeParseServiceTest(): void {
  describe('ResumeParseService', () => {
    it('should extract education, skills, certificate and years', 0, () => {
      const result = ResumeParseService.parse(
        '岗位要求：本科及以上学历，熟悉 Java、HarmonyOS，大学英语六级优先，1 年以上项目经验。',
        dict
      );
      expect(result.educationReq).assertEqual('本科');
      expect(result.skillReq.length).assertEqual(2);
      expect(result.skillReq[0]).assertEqual('Java');
      expect(result.certReq[0]).assertEqual('CET-6');
      expect(result.experienceYears).assertEqual(1);
    });

    it('should return empty arrays when nothing matched', 0, () => {
      const result = ResumeParseService.parse('岗位职责：参与日常开发与文档编写。', dict);
      expect(result.educationReq).assertEqual('');
      expect(result.skillReq.length).assertEqual(0);
      expect(result.certReq.length).assertEqual(0);
      expect(result.experienceYears).assertEqual(0);
    });

    it('should ignore graduation year and extract experience years', 0, () => {
      const result = ResumeParseService.parse(
        '2024年毕业于XX大学，熟悉 Java，1年以上项目经验。', dict
      );
      expect(result.experienceYears).assertEqual(1);
    });

    it('should parse chinese numeral experience years', 0, () => {
      const result = ResumeParseService.parse('要求三年以上相关工作经验。', dict);
      expect(result.experienceYears).assertEqual(3);
    });

    it('should match certificate and skill aliases', 0, () => {
      const result = ResumeParseService.parse('熟悉鸿蒙与 ArkTS，通过大学英语六级。', dict);
      expect(result.skillReq[0]).assertEqual('HarmonyOS');
      expect(result.certReq[0]).assertEqual('CET-6');
    });

    it('should ignore negated skills and certificates', 0, () => {
      const result = ResumeParseService.parse('无需 Java，不要求大学英语六级，熟悉鸿蒙。', dict);
      expect(result.skillReq.length).assertEqual(1);
      expect(result.skillReq[0]).assertEqual('HarmonyOS');
      expect(result.certReq.length).assertEqual(0);
    });

    it('should keep a skill when positive and negative mentions coexist', 0, () => {
      const result = ResumeParseService.parse('无 Java 经验也可，但需要熟悉 Java 开发。', dict);
      expect(result.skillReq.length).assertEqual(1);
      expect(result.skillReq[0]).assertEqual('Java');
    });
  });
}
