import { AbilityTag, SkillCertificate } from '../model/Entity';
import { HonorLevel, HonorType, TagCategory } from '../model/Enums';
import { SkillDict } from '../model/Entity';
import { TextMatcher } from '../common/TextMatcher';

export class TagExtractService {
  static fromHonor(studentId: number, sourceId: number, title: string,
                   honorType: HonorType, level: HonorLevel, dict: SkillDict): AbilityTag[] {
    const lower: string = title.toLowerCase();
    const tags: AbilityTag[] = [];
    const seen: string[] = [];

    for (const item of dict.skills) {
      if (TextMatcher.hit(lower, item) && seen.indexOf(item.name) < 0) {
        tags.push(TagExtractService.buildTag(studentId, item.name, TagCategory.SKILL, 'HONOR', sourceId, 0.9));
        seen.push(item.name);
      }
    }
    for (const item of dict.certificates) {
      if (TextMatcher.hit(lower, item) && seen.indexOf(item.name) < 0) {
        tags.push(TagExtractService.buildTag(studentId, item.name, TagCategory.CERTIFICATE, 'HONOR', sourceId, 0.9));
        seen.push(item.name);
      }
    }

    if (tags.length === 0) {
      let name: string = title;
      let proficiency: number = 3;
      if (level === HonorLevel.NATIONAL) {
        proficiency = 5;
      } else if (level === HonorLevel.PROVINCIAL) {
        proficiency = 4;
      }
      if (honorType === HonorType.CERTIFICATE) {
        name = title;
      }
      tags.push(TagExtractService.buildTag(
        studentId, name,
        honorType === HonorType.CERTIFICATE ? TagCategory.CERTIFICATE : TagCategory.HONOR,
        'HONOR', sourceId, 0.6, proficiency
      ));
    }
    return tags;
  }

  static fromSkillCert(studentId: number, sourceId: number, cert: SkillCertificate,
                       dict: SkillDict): AbilityTag[] {
    const tags: AbilityTag[] = [TagExtractService.buildTag(
      studentId, cert.certName, TagCategory.CERTIFICATE, 'SKILL_CERT', sourceId, 1.0, 4
    )];
    const lower: string = cert.certName.toLowerCase();
    for (const item of dict.skills) {
      if (TextMatcher.hit(lower, item)) {
        tags.push(TagExtractService.buildTag(
          studentId, item.name, TagCategory.SKILL, 'SKILL_CERT', sourceId, 0.8
        ));
      }
    }
    return tags;
  }

  static fromProject(studentId: number, sourceId: number, projectTags: string[]): AbilityTag[] {
    return projectTags.map((name: string): AbilityTag =>
      TagExtractService.buildTag(studentId, name, TagCategory.PROJECT, 'PROJECT', sourceId, 1.0)
    );
  }

  private static buildTag(studentId: number, name: string, category: TagCategory,
                          sourceType: string, sourceId: number, confidence: number,
                          proficiency: number = 3): AbilityTag {
    return {
      id: 0,
      studentId: studentId,
      tagName: name,
      category: category,
      sourceType: sourceType,
      sourceId: sourceId,
      proficiency: proficiency,
      confidence: confidence
    };
  }
}
