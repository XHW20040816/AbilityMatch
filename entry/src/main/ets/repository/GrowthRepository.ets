import { ValuesBucket } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from '../common/DbHelper';
import { GrowthTask } from '../model/Entity';
import { TaskCategory } from '../model/Enums';
import { BaseRepository } from './BaseRepository';

export class GrowthRepository {
  async listByStudent(studentId: number): Promise<GrowthTask[]> {
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT * FROM ${Constants.T_GROWTH} WHERE student_id = ? ORDER BY due_date ASC, id ASC`,
      [studentId]
    );
    return rows.map((row: ValuesBucket) => this.toEntity(row));
  }

  async listByStage(studentId: number, stage: string): Promise<GrowthTask[]> {
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT * FROM ${Constants.T_GROWTH} WHERE student_id = ? AND academic_stage = ? ORDER BY id ASC`,
      [studentId, stage]
    );
    return rows.map((row: ValuesBucket) => this.toEntity(row));
  }

  async insert(task: GrowthTask): Promise<number> {
    const now: number = Date.now();
    return await DbHelper.insert(Constants.T_GROWTH, {
      student_id: task.studentId,
      major_direction: task.majorDirection,
      academic_stage: task.academicStage,
      task_title: task.taskTitle,
      task_desc: task.taskDesc,
      category: task.category,
      due_date: task.dueDate,
      status: task.status,
      remind_enabled: task.remindEnabled ? 1 : 0,
      remind_time: task.remindTime,
      reminder_id: task.reminderId !== undefined ? task.reminderId : 0,
      create_time: now,
      update_time: now
    });
  }

  async updateStatus(id: number, status: number): Promise<void> {
    await DbHelper.update(Constants.T_GROWTH, { status: status, update_time: Date.now() }, 'id = ?', [id]);
  }

  async setReminder(id: number, enabled: boolean, remindTime: number, reminderId: number): Promise<void> {
    const values: ValuesBucket = {
      remind_enabled: enabled ? 1 : 0,
      remind_time: remindTime,
      reminder_id: reminderId,
      update_time: Date.now()
    };
    await DbHelper.update(Constants.T_GROWTH, values, 'id = ?', [id]);
  }

  async remove(id: number): Promise<void> {
    await DbHelper.remove(Constants.T_GROWTH, 'id = ?', [id]);
  }

  async countByDirectionStage(studentId: number, direction: string, stage: string): Promise<number> {
    return await DbHelper.count(
      `SELECT COUNT(*) AS cnt FROM ${Constants.T_GROWTH} WHERE student_id = ? AND major_direction = ? AND academic_stage = ?`,
      [studentId, direction, stage]
    );
  }

  private toEntity(row: ValuesBucket): GrowthTask {
    return {
      id: BaseRepository.num(row['id']),
      studentId: BaseRepository.num(row['student_id']),
      majorDirection: BaseRepository.str(row['major_direction']),
      academicStage: BaseRepository.str(row['academic_stage']),
      taskTitle: BaseRepository.str(row['task_title']),
      taskDesc: BaseRepository.str(row['task_desc']),
      category: BaseRepository.str(row['category']) as TaskCategory,
      dueDate: BaseRepository.num(row['due_date']),
      status: BaseRepository.num(row['status']),
      remindEnabled: BaseRepository.bool(row['remind_enabled']),
      remindTime: BaseRepository.num(row['remind_time']),
      reminderId: BaseRepository.num(row['reminder_id'])
    };
  }
}
