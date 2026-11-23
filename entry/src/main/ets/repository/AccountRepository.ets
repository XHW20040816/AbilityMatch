import { ValuesBucket } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from '../common/DbHelper';
import { UserAccount } from '../model/Entity';
import { AppRole } from '../model/Enums';
import { BaseRepository } from './BaseRepository';

export class AccountRepository {
  async findByAccount(account: string): Promise<UserAccount | null> {
    const row: ValuesBucket | null = await DbHelper.queryOne(
      `SELECT * FROM ${Constants.T_ACCOUNT} WHERE account = ?`, [account]
    );
    return row === null ? null : this.toEntity(row);
  }

  async findById(id: number): Promise<UserAccount | null> {
    const row: ValuesBucket | null = await DbHelper.queryOne(
      `SELECT * FROM ${Constants.T_ACCOUNT} WHERE id = ?`, [id]
    );
    return row === null ? null : this.toEntity(row);
  }

  async insert(account: UserAccount): Promise<number> {
    const now: number = Date.now();
    return await DbHelper.insert(Constants.T_ACCOUNT, {
      role: account.role,
      account: account.account,
      password_hash: account.passwordHash,
      display_name: account.displayName,
      linked_id: account.linkedId,
      verify_image_path: account.verifyImagePath,
      verify_status: account.verifyStatus,
      create_time: now,
      update_time: now
    });
  }

  async updateLinkedId(id: number, linkedId: number): Promise<void> {
    await DbHelper.update(Constants.T_ACCOUNT, {
      linked_id: linkedId,
      update_time: Date.now()
    }, 'id = ?', [id]);
  }

  async updateVerify(id: number, imagePath: string, status: string): Promise<void> {
    await DbHelper.update(Constants.T_ACCOUNT, {
      verify_image_path: imagePath,
      verify_status: status,
      update_time: Date.now()
    }, 'id = ?', [id]);
  }

  async setVerifyStatus(id: number, status: string): Promise<void> {
    await DbHelper.update(Constants.T_ACCOUNT, {
      verify_status: status,
      update_time: Date.now()
    }, 'id = ?', [id]);
  }

  async remove(id: number): Promise<void> {
    await DbHelper.remove(Constants.T_ACCOUNT, 'id = ?', [id]);
  }

  private toEntity(row: ValuesBucket): UserAccount {
    return {
      id: BaseRepository.num(row['id']),
      role: BaseRepository.str(row['role']) as AppRole,
      account: BaseRepository.str(row['account']),
      passwordHash: BaseRepository.str(row['password_hash']),
      displayName: BaseRepository.str(row['display_name']),
      linkedId: BaseRepository.num(row['linked_id']),
      verifyImagePath: BaseRepository.str(row['verify_image_path']),
      verifyStatus: BaseRepository.str(row['verify_status']),
      createTime: BaseRepository.num(row['create_time'])
    };
  }
}
