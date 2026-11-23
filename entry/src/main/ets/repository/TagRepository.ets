import { ValuesBucket } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from '../common/DbHelper';
import { AbilityTag } from '../model/Entity';
import { TagCategory } from '../model/Enums';
import { BaseRepository } from './BaseRepository';

export class TagRepository {
  async listByStudent(studentId: number): Promise<AbilityTag[]> {
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT * FROM ${Constants.T_TAG} WHERE student_id = ? ORDER BY proficiency DESC, id ASC`,
      [studentId]
    );
    return rows.map((row: ValuesBucket) => this.toEntity(row));
  }

  async insert(tag: AbilityTag): Promise<number> {
    return await DbHelper.insert(Constants.T_TAG, {
      student_id: tag.studentId,
      tag_name: tag.tagName,
      category: tag.category,
      source_type: tag.sourceType,
      source_id: tag.sourceId,
      proficiency: tag.proficiency,
      confidence: tag.confidence,
      create_time: Date.now()
    });
  }

  async deleteBySource(studentId: number, sourceType: string, sourceId: number): Promise<void> {
    await DbHelper.remove(
      Constants.T_TAG,
      'student_id = ? AND source_type = ? AND source_id = ?',
      [studentId, sourceType, sourceId]
    );
  }

  async exists(studentId: number, tagName: string, sourceType: string, sourceId: number): Promise<boolean> {
    const row: ValuesBucket | null = await DbHelper.queryOne(
      `SELECT id FROM ${Constants.T_TAG} WHERE student_id = ? AND tag_name = ? AND source_type = ? AND source_id = ?`,
      [studentId, tagName, sourceType, sourceId]
    );
    return row !== null;
  }

  async renameAndMerge(studentId: number, oldName: string, newName: string): Promise<void> {
    await DbHelper.execute(
      `UPDATE ${Constants.T_TAG} SET tag_name = ? WHERE student_id = ? AND tag_name = ?`,
      [newName, studentId, oldName]
    );
    await DbHelper.execute(
      `DELETE FROM ${Constants.T_TAG} WHERE student_id = ? AND tag_name = ? AND id NOT IN (` +
        `SELECT MIN(id) FROM ${Constants.T_TAG} WHERE student_id = ? AND tag_name = ? GROUP BY category)`,
      [studentId, newName, studentId, newName]
    );
  }

  async removeById(id: number): Promise<void> {
    await DbHelper.remove(Constants.T_TAG, 'id = ?', [id]);
  }

  async addManual(studentId: number, tagName: string, category: TagCategory): Promise<void> {
    const name: string = tagName.trim();
    if (name.length === 0) {
      return;
    }
    const row: ValuesBucket | null = await DbHelper.queryOne(
      `SELECT id, proficiency FROM ${Constants.T_TAG} ` +
      `WHERE student_id = ? AND tag_name = ? AND category = ? ORDER BY id ASC LIMIT 1`,
      [studentId, name, category]
    );
    if (row !== null) {
      const proficiency: number = Math.min(BaseRepository.num(row['proficiency']) + 1, 5);
      await DbHelper.update(Constants.T_TAG, {
        proficiency: proficiency,
        confidence: 1.0
      }, 'id = ?', [BaseRepository.num(row['id'])]);
      return;
    }
    await this.insert({
      id: 0,
      studentId: studentId,
      tagName: name,
      category: category,
      sourceType: 'MANUAL',
      sourceId: 0,
      proficiency: 3,
      confidence: 1.0
    });
  }

  private toEntity(row: ValuesBucket): AbilityTag {
    return {
      id: BaseRepository.num(row['id']),
      studentId: BaseRepository.num(row['student_id']),
      tagName: BaseRepository.str(row['tag_name']),
      category: BaseRepository.str(row['category']) as TagCategory,
      sourceType: BaseRepository.str(row['source_type']),
      sourceId: BaseRepository.num(row['source_id']),
      proficiency: BaseRepository.num(row['proficiency']),
      confidence: BaseRepository.real(row['confidence'])
    };
  }
}
