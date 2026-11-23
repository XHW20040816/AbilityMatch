import { common } from '@kit.AbilityKit';
import { DbHelper } from '../common/DbHelper';
import { FileHelper } from '../common/FileHelper';
import { HonorCertificate, HonorFilter, SkillDict } from '../model/Entity';
import { honorRepo, tagRepo } from '../repository/Repositories';
import { TagExtractService } from './TagExtractService';

export class CertificateService {
  async save(cert: HonorCertificate, dict: SkillDict): Promise<number> {
    cert.searchText = `${cert.title} ${cert.issuer} ${cert.remark}`.toLowerCase();
    const id: number = await DbHelper.runInTransaction(async (): Promise<number> => {
      let certId: number = cert.id;
      if (certId === 0) {
        certId = await honorRepo.insert(cert);
      } else {
        await honorRepo.update(cert);
        await tagRepo.deleteBySource(cert.studentId, 'HONOR', certId);
      }
      const tags = TagExtractService.fromHonor(
        cert.studentId, certId, cert.title, cert.honorType, cert.level, dict
      );
      for (const tag of tags) {
        const exists: boolean = await tagRepo.exists(cert.studentId, tag.tagName, 'HONOR', certId);
        if (!exists) {
          await tagRepo.insert(tag);
        }
      }
      return certId;
    });
    return id;
  }

  async remove(cert: HonorCertificate, context: common.UIAbilityContext): Promise<void> {
    await DbHelper.runInTransaction(async (): Promise<void> => {
      await tagRepo.deleteBySource(cert.studentId, 'HONOR', cert.id);
      await honorRepo.remove(cert.id);
    });
    FileHelper.removeFile(context, cert.imagePath);
  }

  async list(studentId: number, filter: HonorFilter, limit: number, offset: number): Promise<HonorCertificate[]> {
    return await honorRepo.list(studentId, filter, limit, offset);
  }

  async count(studentId: number, filter: HonorFilter): Promise<number> {
    return await honorRepo.count(studentId, filter);
  }
}
