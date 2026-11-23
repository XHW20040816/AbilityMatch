import { ValuesBucket } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from '../common/DbHelper';
import { ProjectExperience, SkillCertificate } from '../model/Entity';
import { BaseRepository } from './BaseRepository';

export class ProfileRepository {
  async listSkillCerts(studentId: number): Promise<SkillCertificate[]> {
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT * FROM ${Constants.T_SKILL_CERT} WHERE student_id = ? ORDER BY obtain_year DESC`,
      [studentId]
    );
    return rows.map((row: ValuesBucket): SkillCertificate => ({
      id: BaseRepository.num(row['id']),
      studentId: BaseRepository.num(row['student_id']),
      certName: BaseRepository.str(row['cert_name']),
      issuer: BaseRepository.str(row['issuer']),
      obtainYear: BaseRepository.num(row['obtain_year']),
      level: BaseRepository.str(row['level']),
      imagePath: BaseRepository.str(row['image_path'])
    }));
  }

  async insertSkillCert(cert: SkillCertificate): Promise<number> {
    return await DbHelper.insert(Constants.T_SKILL_CERT, {
      student_id: cert.studentId,
      cert_name: cert.certName,
      issuer: cert.issuer,
      obtain_year: cert.obtainYear,
      level: cert.level,
      image_path: cert.imagePath,
      create_time: Date.now()
    });
  }

  async updateSkillCert(cert: SkillCertificate): Promise<void> {
    await DbHelper.update(Constants.T_SKILL_CERT, {
      cert_name: cert.certName,
      issuer: cert.issuer,
      obtain_year: cert.obtainYear,
      level: cert.level,
      image_path: cert.imagePath
    }, 'id = ?', [cert.id]);
  }

  async removeSkillCert(id: number): Promise<void> {
    await DbHelper.remove(Constants.T_SKILL_CERT, 'id = ?', [id]);
  }

  async listProjects(studentId: number): Promise<ProjectExperience[]> {
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT * FROM ${Constants.T_PROJECT} WHERE student_id = ? ORDER BY id DESC`,
      [studentId]
    );
    return rows.map((row: ValuesBucket): ProjectExperience => ({
      id: BaseRepository.num(row['id']),
      studentId: BaseRepository.num(row['student_id']),
      projectName: BaseRepository.str(row['project_name']),
      role: BaseRepository.str(row['role']),
      startDate: BaseRepository.num(row['start_date']),
      endDate: BaseRepository.num(row['end_date']),
      description: BaseRepository.str(row['description']),
      tags: BaseRepository.arr(row['tags'])
    }));
  }

  async insertProject(project: ProjectExperience): Promise<number> {
    return await DbHelper.insert(Constants.T_PROJECT, {
      student_id: project.studentId,
      project_name: project.projectName,
      role: project.role,
      start_date: project.startDate,
      end_date: project.endDate,
      description: project.description,
      tags: JSON.stringify(project.tags),
      create_time: Date.now()
    });
  }

  async updateProject(project: ProjectExperience): Promise<void> {
    await DbHelper.update(Constants.T_PROJECT, {
      project_name: project.projectName,
      role: project.role,
      start_date: project.startDate,
      end_date: project.endDate,
      description: project.description,
      tags: JSON.stringify(project.tags)
    }, 'id = ?', [project.id]);
  }

  async removeProject(id: number): Promise<void> {
    await DbHelper.remove(Constants.T_PROJECT, 'id = ?', [id]);
  }
}
