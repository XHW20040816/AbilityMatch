import { ValueType, ValuesBucket } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from '../common/DbHelper';
import { HonorQuery, HonorQueryFragment } from '../common/HonorQuery';
import { SearchTokenizer } from '../common/SearchTokenizer';
import { HonorCertificate, HonorFilter } from '../model/Entity';
import { HonorLevel, HonorType } from '../model/Enums';
import { BaseRepository } from './BaseRepository';

export class HonorRepository {
  async getById(id: number): Promise<HonorCertificate | null> {
    const row: ValuesBucket | null = await DbHelper.queryOne(
      `SELECT * FROM ${Constants.T_HONOR} WHERE id = ?`, [id]
    );
    return row === null ? null : this.toEntity(row);
  }

  async insert(cert: HonorCertificate): Promise<number> {
    const now: number = Date.now();
    const id: number = await DbHelper.insert(Constants.T_HONOR, {
      student_id: cert.studentId,
      title: cert.title,
      honor_type: cert.honorType,
      level: cert.level,
      award_year: cert.awardYear,
      issuer: cert.issuer,
      image_path: cert.imagePath,
      remark: cert.remark,
      search_text: cert.searchText,
      create_time: now,
      update_time: now
    });
    await this.indexHonor(id, cert.studentId, cert.searchText);
    return id;
  }

  async update(cert: HonorCertificate): Promise<void> {
    await DbHelper.update(Constants.T_HONOR, {
      title: cert.title,
      honor_type: cert.honorType,
      level: cert.level,
      award_year: cert.awardYear,
      issuer: cert.issuer,
      image_path: cert.imagePath,
      remark: cert.remark,
      search_text: cert.searchText,
      update_time: Date.now()
    }, 'id = ?', [cert.id]);
    await this.indexHonor(cert.id, cert.studentId, cert.searchText);
  }

  async remove(id: number): Promise<void> {
    await DbHelper.remove(Constants.T_HONOR_TOKEN, 'honor_id = ?', [id]);
    await DbHelper.remove(Constants.T_HONOR, 'id = ?', [id]);
  }

  async ensureSearchIndex(studentId: number): Promise<void> {
    const honors: number = await DbHelper.count(
      `SELECT COUNT(*) AS cnt FROM ${Constants.T_HONOR} WHERE student_id = ?`, [studentId]
    );
    if (honors === 0) {
      return;
    }
    const indexed: number = await DbHelper.count(
      `SELECT COUNT(DISTINCT honor_id) AS cnt FROM ${Constants.T_HONOR_TOKEN} WHERE student_id = ?`,
      [studentId]
    );
    if (indexed >= honors) {
      return;
    }
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT id, student_id, search_text FROM ${Constants.T_HONOR} WHERE student_id = ?`, [studentId]
    );
    for (const row of rows) {
      await this.indexHonor(BaseRepository.num(row['id']), BaseRepository.num(row['student_id']),
        BaseRepository.str(row['search_text']));
    }
  }

  private async indexHonor(honorId: number, studentId: number, searchText: string): Promise<void> {
    await DbHelper.remove(Constants.T_HONOR_TOKEN, 'honor_id = ?', [honorId]);
    const tokens: string[] = SearchTokenizer.tokens(searchText);
    const chunkSize: number = 60;
    for (let start: number = 0; start < tokens.length; start += chunkSize) {
      const chunk: string[] = tokens.slice(start, start + chunkSize);
      let sql: string = `INSERT INTO ${Constants.T_HONOR_TOKEN} (student_id, honor_id, token) VALUES `;
      const args: ValueType[] = [];
      for (let i: number = 0; i < chunk.length; i++) {
        sql += (i === 0 ? '(?, ?, ?)' : ', (?, ?, ?)');
        args.push(studentId, honorId, chunk[i]);
      }
      await DbHelper.execute(sql, args);
    }
  }

  async list(studentId: number, filter: HonorFilter, limit: number, offset: number): Promise<HonorCertificate[]> {
    const fragment: HonorQueryFragment = HonorQuery.build(studentId, filter);
    const args: ValueType[] = fragment.args as ValueType[];
    args.push(limit, offset);
    const querySql: string = `SELECT * FROM ${Constants.T_HONOR} WHERE student_id = ?${fragment.clause} ` +
      `ORDER BY award_year DESC, id DESC LIMIT ? OFFSET ?`;
    const rows: ValuesBucket[] = await DbHelper.query(querySql, args);
    return rows.map((row: ValuesBucket) => this.toEntity(row));
  }

  async count(studentId: number, filter: HonorFilter): Promise<number> {
    const fragment: HonorQueryFragment = HonorQuery.build(studentId, filter);
    return await DbHelper.count(
      `SELECT COUNT(*) AS cnt FROM ${Constants.T_HONOR} WHERE student_id = ?${fragment.clause}`,
      fragment.args as ValueType[]
    );
  }

  async listIssuers(studentId: number): Promise<string[]> {
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT DISTINCT issuer FROM ${Constants.T_HONOR} ` +
        `WHERE student_id = ? AND issuer <> '' ORDER BY issuer ASC`, [studentId]
    );
    return rows.map((row: ValuesBucket) => BaseRepository.str(row['issuer']));
  }

  private toEntity(row: ValuesBucket): HonorCertificate {
    return {
      id: BaseRepository.num(row['id']),
      studentId: BaseRepository.num(row['student_id']),
      title: BaseRepository.str(row['title']),
      honorType: BaseRepository.str(row['honor_type']) as HonorType,
      level: BaseRepository.str(row['level']) as HonorLevel,
      awardYear: BaseRepository.num(row['award_year']),
      issuer: BaseRepository.str(row['issuer']),
      imagePath: BaseRepository.str(row['image_path']),
      remark: BaseRepository.str(row['remark']),
      searchText: BaseRepository.str(row['search_text']),
      createTime: BaseRepository.num(row['create_time'])
    };
  }
}
