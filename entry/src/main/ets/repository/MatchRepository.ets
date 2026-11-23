import { ValuesBucket } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from '../common/DbHelper';
import { DimensionScores, MatchRecord } from '../model/Entity';
import { BaseRepository } from './BaseRepository';

export class MatchRepository {
  async insert(record: MatchRecord): Promise<number> {
    return await DbHelper.insert(Constants.T_MATCH, {
      student_id: record.studentId,
      job_id: record.jobId,
      direction: record.direction,
      total_score: record.totalScore,
      edu_score: record.dimensionScores.education,
      skill_score: record.dimensionScores.skill,
      cert_score: record.dimensionScores.certificate,
      exp_score: record.dimensionScores.experience,
      honor_score: record.dimensionScores.honor,
      direction_score: record.dimensionScores.direction,
      gap_items: JSON.stringify(record.gapItems),
      suggestions: JSON.stringify(record.suggestions),
      create_time: Date.now()
    });
  }

  async listByStudent(studentId: number): Promise<MatchRecord[]> {
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT * FROM ${Constants.T_MATCH} WHERE student_id = ? ORDER BY create_time DESC LIMIT 100`,
      [studentId]
    );
    return rows.map((row: ValuesBucket) => this.toEntity(row));
  }

  async listByJob(jobId: number): Promise<MatchRecord[]> {
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT * FROM ${Constants.T_MATCH} WHERE job_id = ? ORDER BY total_score DESC LIMIT 100`,
      [jobId]
    );
    return rows.map((row: ValuesBucket) => this.toEntity(row));
  }

  /**
   * 覆盖当日匹配记录：仅删除同一学生/岗位/方向在今天 00:00 之后的记录再插入，
   * 保留跨天历史，避免每次进入页面都清空历史分数。
   */
  async replaceToday(record: MatchRecord): Promise<number> {
    const now: Date = new Date();
    const startOfDay: number = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    await DbHelper.remove(Constants.T_MATCH,
      'student_id = ? AND job_id = ? AND direction = ? AND create_time >= ?',
      [record.studentId, record.jobId, record.direction, startOfDay]);
    return await this.insert(record);
  }

  async clearStudentRecords(studentId: number): Promise<void> {
    await DbHelper.remove(Constants.T_MATCH, 'student_id = ?', [studentId]);
  }

  async removeByJob(jobId: number): Promise<void> {
    await DbHelper.remove(Constants.T_MATCH, 'job_id = ?', [jobId]);
  }

  private toEntity(row: ValuesBucket): MatchRecord {
    const scores: DimensionScores = {
      education: BaseRepository.real(row['edu_score']),
      skill: BaseRepository.real(row['skill_score']),
      certificate: BaseRepository.real(row['cert_score']),
      experience: BaseRepository.real(row['exp_score']),
      honor: BaseRepository.real(row['honor_score']),
      direction: BaseRepository.real(row['direction_score'])
    };
    return {
      id: BaseRepository.num(row['id']),
      studentId: BaseRepository.num(row['student_id']),
      jobId: BaseRepository.num(row['job_id']),
      direction: BaseRepository.num(row['direction']),
      totalScore: BaseRepository.real(row['total_score']),
      dimensionScores: scores,
      gapItems: BaseRepository.arr(row['gap_items']),
      suggestions: BaseRepository.arr(row['suggestions']),
      createTime: BaseRepository.num(row['create_time'])
    };
  }
}
