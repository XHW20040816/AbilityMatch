import { ValuesBucket } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from '../common/DbHelper';
import { ExperienceRequirement, JobRequirement, MatchWeights } from '../model/Entity';
import { BaseRepository } from './BaseRepository';

export class JobRepository {
  async listActive(): Promise<JobRequirement[]> {
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT j.*, c.company_name AS company_name FROM ${Constants.T_JOB} j ` +
      `LEFT JOIN ${Constants.T_COMPANY} c ON j.company_id = c.id ` +
      `WHERE j.status = 1 ORDER BY j.id DESC`, []
    );
    return rows.map((row: ValuesBucket) => this.toEntity(row));
  }

  async listByCompany(companyId: number): Promise<JobRequirement[]> {
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT j.*, c.company_name AS company_name FROM ${Constants.T_JOB} j ` +
      `LEFT JOIN ${Constants.T_COMPANY} c ON j.company_id = c.id ` +
      `WHERE j.company_id = ? ORDER BY j.id DESC`, [companyId]
    );
    return rows.map((row: ValuesBucket) => this.toEntity(row));
  }

  async getById(id: number): Promise<JobRequirement | null> {
    const row: ValuesBucket | null = await DbHelper.queryOne(
      `SELECT j.*, c.company_name AS company_name FROM ${Constants.T_JOB} j ` +
      `LEFT JOIN ${Constants.T_COMPANY} c ON j.company_id = c.id WHERE j.id = ?`, [id]
    );
    return row === null ? null : this.toEntity(row);
  }

  async insert(job: JobRequirement): Promise<number> {
    const now: number = Date.now();
    return await DbHelper.insert(Constants.T_JOB, this.toBucket(job, now));
  }

  async update(job: JobRequirement): Promise<void> {
    await DbHelper.update(Constants.T_JOB, this.toBucket(job, Date.now()), 'id = ?', [job.id]);
  }

  async archive(id: number): Promise<void> {
    await DbHelper.update(Constants.T_JOB, { status: 0, update_time: Date.now() }, 'id = ?', [id]);
  }

  async activate(id: number): Promise<void> {
    await DbHelper.update(Constants.T_JOB, { status: 1, update_time: Date.now() }, 'id = ?', [id]);
  }

  async remove(id: number): Promise<void> {
    await DbHelper.remove(Constants.T_JOB, 'id = ?', [id]);
  }

  async countByCompany(companyId: number): Promise<number> {
    return await DbHelper.count(
      `SELECT COUNT(*) AS cnt FROM ${Constants.T_JOB} WHERE company_id = ?`, [companyId]
    );
  }

  async listDirections(): Promise<string[]> {
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT DISTINCT major_direction FROM ${Constants.T_JOB} ` +
      `WHERE status = 1 AND major_direction IS NOT NULL AND major_direction <> '' ` +
      `ORDER BY major_direction ASC`, []
    );
    return rows.map((row: ValuesBucket) => BaseRepository.str(row['major_direction']));
  }

  private toBucket(job: JobRequirement, now: number): ValuesBucket {
    const exp: ExperienceRequirement = {
      years: job.experienceYears,
      keywords: job.experienceKeywords
    };
    return {
      company_id: job.companyId,
      job_title: job.jobTitle,
      major_direction: job.majorDirection,
      raw_text: job.rawText,
      education_req: job.educationReq,
      skill_req: JSON.stringify(job.skillReq),
      cert_req: JSON.stringify(job.certReq),
      experience_req: JSON.stringify(exp),
      weight_education: job.weights.education,
      weight_skill: job.weights.skill,
      weight_cert: job.weights.certificate,
      weight_experience: job.weights.experience,
      weight_honor: job.weights.honor,
      weight_direction: job.weights.direction,
      status: job.status,
      create_time: now,
      update_time: now
    };
  }

  private toEntity(row: ValuesBucket): JobRequirement {
    const expText: string = BaseRepository.str(row['experience_req']);
    let years: number = 0;
    let keywords: string[] = [];
    if (expText.length > 0) {
      try {
        const exp: ExperienceRequirement = JSON.parse(expText) as ExperienceRequirement;
        years = exp.years;
        keywords = exp.keywords;
      } catch (error) {
        years = 0;
        keywords = [];
      }
    }
    const weights: MatchWeights = {
      education: BaseRepository.real(row['weight_education']),
      skill: BaseRepository.real(row['weight_skill']),
      certificate: BaseRepository.real(row['weight_cert']),
      experience: BaseRepository.real(row['weight_experience']),
      honor: BaseRepository.real(row['weight_honor']),
      direction: BaseRepository.real(row['weight_direction'])
    };
    return {
      id: BaseRepository.num(row['id']),
      companyId: BaseRepository.num(row['company_id']),
      companyName: BaseRepository.str(row['company_name']),
      jobTitle: BaseRepository.str(row['job_title']),
      majorDirection: BaseRepository.str(row['major_direction']),
      rawText: BaseRepository.str(row['raw_text']),
      educationReq: BaseRepository.str(row['education_req']),
      skillReq: BaseRepository.arr(row['skill_req']),
      certReq: BaseRepository.arr(row['cert_req']),
      experienceYears: years,
      experienceKeywords: keywords,
      weights: weights,
      status: BaseRepository.num(row['status'])
    };
  }
}
