import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo, picker } from '@kit.CoreFileKit';
import { ValuesBucket } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from '../common/DbHelper';
import { FileHelper } from '../common/FileHelper';
import { Logger } from '../common/Logger';

interface SnapshotTable {
  table: string;
  rows?: ValuesBucket[];
}

interface Snapshot {
  version?: number;
  exportedAt?: number;
  tables?: SnapshotTable[];
}

class BackupServiceClass {
  // 导入顺序：父表在前，保证外键约束可满足
  private readonly INSERT_ORDER: string[] = [
    Constants.T_STUDENT, Constants.T_COMPANY, Constants.T_JOB, Constants.T_GROWTH,
    Constants.T_HONOR, Constants.T_HONOR_TOKEN, Constants.T_TAG, Constants.T_SKILL_CERT,
    Constants.T_PROJECT, Constants.T_MATCH, Constants.T_ACCOUNT
  ];

  async exportSnapshot(context: common.UIAbilityContext): Promise<boolean> {
    const tables: SnapshotTable[] = [];
    for (const table of this.INSERT_ORDER) {
      const rows: ValuesBucket[] = await DbHelper.query(`SELECT * FROM ${table}`);
      tables.push({ table: table, rows: rows });
    }
    const snapshot: Snapshot = { version: 1, exportedAt: Date.now(), tables: tables };
    const fileName: string = `abilitymatch_backup_${Date.now()}.json`;
    return await this.saveToUser(context, fileName, JSON.stringify(snapshot));
  }

  // 返回导入行数；用户取消选择时返回 -1
  async restoreSnapshot(context: common.UIAbilityContext): Promise<number> {
    const text: string = await this.pickAndRead(context);
    if (text.length === 0) {
      return -1;
    }
    let snapshot: Snapshot;
    try {
      snapshot = JSON.parse(text) as Snapshot;
    } catch (error) {
      throw new Error('备份文件不是有效的 JSON');
    }
    if (snapshot === null || snapshot.tables === undefined || snapshot.tables === null) {
      throw new Error('备份文件缺少 tables 字段，可能不是本应用导出的备份');
    }
    const pending: Map<string, ValuesBucket[]> = new Map<string, ValuesBucket[]>();
    let total: number = 0;
    for (const entry of snapshot.tables) {
      if (this.INSERT_ORDER.indexOf(entry.table) < 0) {
        continue;
      }
      const rows: ValuesBucket[] = entry.rows === undefined ? [] : entry.rows;
      pending.set(entry.table, rows);
      total += rows.length;
    }
    if (total === 0) {
      throw new Error('备份文件中没有可导入的数据');
    }
    await DbHelper.runInTransaction(async (): Promise<void> => {
      await DbHelper.clearTables();
      for (const table of this.INSERT_ORDER) {
        const rows: ValuesBucket[] | undefined = pending.get(table);
        if (rows === undefined) {
          continue;
        }
        for (const row of rows) {
          await DbHelper.insert(table, row);
        }
      }
    });
    await this.cleanupImages(context);
    Logger.info(`Snapshot restored: ${total} rows`);
    return total;
  }

  // 恢复后按新数据引用关系清理不再被引用的证书图片
  private async cleanupImages(context: common.UIAbilityContext): Promise<void> {
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT image_path FROM ${Constants.T_HONOR} WHERE image_path IS NOT NULL AND image_path <> '' ` +
      `UNION SELECT image_path FROM ${Constants.T_SKILL_CERT} WHERE image_path IS NOT NULL AND image_path <> ''`
    );
    const referenced: string[] = [];
    for (const row of rows) {
      const path: string = row['image_path'] === undefined || row['image_path'] === null
        ? '' : String(row['image_path']);
      if (path.length > 0) {
        referenced.push(path);
      }
    }
    await FileHelper.cleanupOrphans(context, referenced);
  }

  private async pickAndRead(context: common.UIAbilityContext): Promise<string> {
    const options: picker.DocumentSelectOptions = {
      maxSelectNumber: 1,
      fileSuffixFilters: ['JSON 备份|.json']
    };
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    const uris: string[] = await documentPicker.select(options);
    if (uris.length === 0) {
      return '';
    }
    const stat: fileIo.Stat = fileIo.statSync(uris[0]);
    if (stat.size <= 0) {
      throw new Error('备份文件为空');
    }
    if (stat.size > 20 * 1024 * 1024) {
      throw new Error('备份文件超过 20MB，暂不支持恢复');
    }
    const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
    const file: fileIo.File = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
    let read: number = 0;
    try {
      read = fileIo.readSync(file.fd, buffer);
    } finally {
      fileIo.closeSync(file.fd);
    }
    if (read <= 0) {
      return '';
    }
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(new Uint8Array(buffer.slice(0, read)));
  }

  private async saveToUser(context: common.UIAbilityContext, fileName: string,
                           content: string): Promise<boolean> {
    const options: picker.DocumentSaveOptions = {
      newFileNames: [fileName],
      fileSuffixChoices: ['JSON 备份|.json']
    };
    const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    const uris: string[] = await documentPicker.save(options);
    if (uris.length === 0) {
      return false;
    }
    const file: fileIo.File = await fileIo.open(uris[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      await fileIo.write(file.fd, content);
    } finally {
      await fileIo.close(file.fd);
    }
    return true;
  }
}

export const BackupService: BackupServiceClass = new BackupServiceClass();
