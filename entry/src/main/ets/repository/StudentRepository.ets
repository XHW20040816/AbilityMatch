import { ValueType, ValuesBucket } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from '../common/DbHelper';
import { Taxonomy } from '../common/Taxonomy';
import { Student } from '../model/Entity';
import { BaseRepository } from './BaseRepository';

export class StudentRepository {
  async getById(id: number): Promise<Student | null> {
    const row: ValuesBucket | null = await DbHelper.queryOne(
      `SELECT * FROM ${Constants.T_STUDENT} WHERE id = ?`, [id]
    );
    return row === null ? null : this.toEntity(row);
  }

  async getDefault(): Promise<Student | null> {
    const row: ValuesBucket | null = await DbHelper.queryOne(
      `SELECT * FROM ${Constants.T_STUDENT} ORDER BY id ASC LIMIT 1`, []
    );
    return row === null ? null : this.toEntity(row);
  }

  async listAll(): Promise<Student[]> {
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT * FROM ${Constants.T_STUDENT} ORDER BY id ASC`, []
    );
    return rows.map((row: ValuesBucket) => this.toEntity(row));
  }

  async listPage(limit: number, offset: number, direction: string): Promise<Student[]> {
    let sql: string = `SELECT * FROM ${Constants.T_STUDENT} WHERE is_public = 1`;
    const args: ValueType[] = [];
    const keywords: string[] = Taxonomy.directionKeywords(direction);
    if (keywords.length > 0) {
      sql += ' AND (';
      for (let i: number = 0; i < keywords.length; i++) {
        sql += (i === 0 ? 'direction LIKE ?' : ' OR direction LIKE ?');
        args.push(`%${keywords[i]}%`);
      }
      sql += ')';
    }
    sql += ' ORDER BY id ASC LIMIT ? OFFSET ?';
    args.push(limit, offset);
    const rows: ValuesBucket[] = await DbHelper.query(sql, args);
    return rows.map((row: ValuesBucket) => this.toEntity(row));
  }

  async countByDirection(direction: string): Promise<number> {
    let sql: string = `SELECT COUNT(*) AS cnt FROM ${Constants.T_STUDENT} WHERE is_public = 1`;
    const args: ValueType[] = [];
    const keywords: string[] = Taxonomy.directionKeywords(direction);
    if (keywords.length > 0) {
      sql += ' AND (';
      for (let i: number = 0; i < keywords.length; i++) {
        sql += (i === 0 ? 'direction LIKE ?' : ' OR direction LIKE ?');
        args.push(`%${keywords[i]}%`);
      }
      sql += ')';
    }
    return await DbHelper.count(sql, args);
  }

  async insert(student: Student): Promise<number> {
    const now: number = Date.now();
    return await DbHelper.insert(Constants.T_STUDENT, {
      student_no: student.studentNo,
      name: student.name,
      school: student.school,
      school_level: student.schoolLevel,
      major: student.major,
      grade: student.grade,
      education: student.education,
      direction: student.direction,
      phone: student.phone,
      email: student.email,
      is_public: student.isPublic === false ? 0 : 1,
      create_time: now,
      update_time: now
    });
  }

  async save(student: Student): Promise<void> {
    await DbHelper.update(Constants.T_STUDENT, {
      student_no: student.studentNo,
      name: student.name,
      school: student.school,
      school_level: student.schoolLevel,
      major: student.major,
      grade: student.grade,
      education: student.education,
      direction: student.direction,
      phone: student.phone,
      email: student.email,
      is_public: student.isPublic === false ? 0 : 1,
      update_time: Date.now()
    }, 'id = ?', [student.id]);
  }

  private toEntity(row: ValuesBucket): Student {
    return {
      id: BaseRepository.num(row['id']),
      studentNo: BaseRepository.str(row['student_no']),
      name: BaseRepository.str(row['name']),
      school: BaseRepository.str(row['school']),
      schoolLevel: BaseRepository.str(row['school_level']),
      major: BaseRepository.str(row['major']),
      grade: BaseRepository.str(row['grade']),
      education: BaseRepository.str(row['education']),
      direction: BaseRepository.str(row['direction']),
      phone: BaseRepository.str(row['phone']),
      email: BaseRepository.str(row['email']),
      isPublic: BaseRepository.num(row['is_public']) !== 0
    };
  }
}
