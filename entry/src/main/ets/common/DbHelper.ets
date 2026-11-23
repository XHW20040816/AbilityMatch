import { common } from '@kit.AbilityKit';
import { relationalStore, ValuesBucket, ValueType } from '@kit.ArkData';
import { Constants } from './Constants';
import { Logger } from './Logger';
import { Taxonomy } from './Taxonomy';

class DbHelperClass {
  private store: relationalStore.RdbStore | null = null;
  private initialized: boolean = false;

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.initialized && this.store !== null) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: Constants.DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.store = await relationalStore.getRdbStore(context, config);
    for (const sql of Constants.CREATE_SQLS) {
      await this.store.executeSql(sql);
    }
    await this.migrate();
    await this.seedDefaults();
    this.initialized = true;
    Logger.info('RDB initialized: ' + Constants.DB_NAME);
  }

  getStore(): relationalStore.RdbStore {
    if (this.store === null) {
      throw new Error('Database has not been initialized');
    }
    return this.store;
  }

  async execute(sql: string, args: ValueType[] = []): Promise<void> {
    await this.getStore().executeSql(sql, args);
  }

  async runInTransaction<T>(work: () => Promise<T>): Promise<T> {
    this.getStore().beginTransaction();
    try {
      const result: T = await work();
      this.getStore().commit();
      return result;
    } catch (error) {
      this.getStore().rollBack();
      throw error as Error;
    }
  }

  // 仅清空业务表，不开启事务，由调用方决定事务边界
  async clearTables(): Promise<void> {
    const order: string[] = [
      Constants.T_ACCOUNT, Constants.T_MATCH, Constants.T_PROJECT,
      Constants.T_SKILL_CERT, Constants.T_TAG, Constants.T_HONOR_TOKEN,
      Constants.T_HONOR, Constants.T_GROWTH, Constants.T_JOB,
      Constants.T_COMPANY, Constants.T_STUDENT
    ];
    for (const table of order) {
      await this.execute(`DELETE FROM ${table}`);
    }
  }

  // 重置为初始演示数据，整体作为一个事务提交
  async clearAllData(): Promise<void> {
    await this.runInTransaction(async (): Promise<void> => {
      await this.clearTables();
      await this.seedDefaults();
    });
  }

  async insert(table: string, values: ValuesBucket): Promise<number> {
    return await this.getStore().insert(table, values);
  }

  async update(table: string, values: ValuesBucket, where: string, args: ValueType[]): Promise<number> {
    const sql: string = `UPDATE ${table} SET ${this.buildSetClause(values)} WHERE ${where}`;
    const bindArgs: ValueType[] = [];
    for (const key of Object.keys(values)) {
      const value: ValueType | Uint8Array | null = values[key];
      if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
        bindArgs.push(value);
      }
    }
    for (const arg of args) {
      bindArgs.push(arg);
    }
    await this.execute(sql, bindArgs);
    return 1;
  }

  async remove(table: string, where: string, args: ValueType[]): Promise<void> {
    const sql: string = `DELETE FROM ${table} WHERE ${where}`;
    await this.execute(sql, args);
  }

  async query(sql: string, args: ValueType[] = []): Promise<ValuesBucket[]> {
    const resultSet: relationalStore.ResultSet = await this.getStore().querySql(sql, args);
    const rows: ValuesBucket[] = [];
    try {
      const columns: string[] = resultSet.getColumnNames();
      while (resultSet.goToNextRow()) {
        const row: ValuesBucket = {};
        for (let i: number = 0; i < columns.length; i++) {
          row[columns[i]] = resultSet.getString(i);
        }
        rows.push(row);
      }
    } finally {
      resultSet.close();
    }
    return rows;
  }

  async queryOne(sql: string, args: ValueType[] = []): Promise<ValuesBucket | null> {
    const rows: ValuesBucket[] = await this.query(sql, args);
    return rows.length > 0 ? rows[0] : null;
  }

  async count(sql: string, args: ValueType[] = []): Promise<number> {
    const row: ValuesBucket | null = await this.queryOne(sql, args);
    if (row === null) {
      return 0;
    }
    return Number(row['cnt']);
  }

  private buildSetClause(values: ValuesBucket): string {
    const parts: string[] = [];
    for (const key of Object.keys(values)) {
      parts.push(`${key} = ?`);
    }
    return parts.join(', ');
  }

  private async migrate(): Promise<void> {
    await this.ensureMetaTable();
    const version: number = await this.readSchemaVersion();
    Logger.info(`schema version: ${version} -> ${Constants.DB_VERSION}`);
    try {
      await this.execute('ALTER TABLE growth_plan ADD COLUMN reminder_id INTEGER DEFAULT 0');
    } catch (error) {
      Logger.info('reminder_id column already exists or migration skipped');
    }
    try {
      await this.execute(`ALTER TABLE ${Constants.T_STUDENT} ADD COLUMN education TEXT DEFAULT '本科'`);
    } catch (error) {
      Logger.info('education column already exists or migration skipped');
    }
    try {
      await this.execute(`ALTER TABLE ${Constants.T_STUDENT} ADD COLUMN school TEXT DEFAULT ''`);
    } catch (error) {
      Logger.info('school column already exists or migration skipped');
    }
    try {
      await this.execute(`ALTER TABLE ${Constants.T_STUDENT} ADD COLUMN school_level TEXT DEFAULT ''`);
    } catch (error) {
      Logger.info('school_level column already exists or migration skipped');
    }
    try {
      await this.execute(`ALTER TABLE ${Constants.T_JOB} ADD COLUMN major_direction TEXT DEFAULT ''`);
      await this.execute(`UPDATE ${Constants.T_JOB} SET major_direction = '软件开发' WHERE major_direction IS NULL OR major_direction = ''`);
    } catch (error) {
      Logger.info('major_direction column already exists or migration skipped');
    }
    try {
      await this.execute(`ALTER TABLE ${Constants.T_JOB} ADD COLUMN weight_direction REAL DEFAULT 0.15`);
    } catch (error) {
      Logger.info('weight_direction column already exists or migration skipped');
    }
    try {
      await this.execute(`ALTER TABLE ${Constants.T_MATCH} ADD COLUMN direction_score REAL DEFAULT 0`);
    } catch (error) {
      Logger.info('direction_score column already exists or migration skipped');
    }
    try {
      await this.execute(`ALTER TABLE ${Constants.T_STUDENT} ADD COLUMN is_public INTEGER DEFAULT 1`);
    } catch (error) {
      Logger.info('is_public column already exists or migration skipped');
    }
    await this.ensureConstraints();
    if (version < Constants.DB_VERSION) {
      await this.writeSchemaVersion(Constants.DB_VERSION);
    }
  }

  private async ensureMetaTable(): Promise<void> {
    await this.execute(
      `CREATE TABLE IF NOT EXISTS ${Constants.T_META} (` +
      'meta_key TEXT PRIMARY KEY, meta_value TEXT)'
    );
  }

  private async readSchemaVersion(): Promise<number> {
    const row: ValuesBucket | null = await this.queryOne(
      `SELECT meta_value FROM ${Constants.T_META} WHERE meta_key = ?`, ['schema_version']
    );
    if (row === null) {
      return 0;
    }
    const parsed: number = Number(row['meta_value']);
    return Number.isNaN(parsed) ? 0 : parsed;
  }

  private async writeSchemaVersion(version: number): Promise<void> {
    await this.execute(
      `INSERT OR REPLACE INTO ${Constants.T_META} (meta_key, meta_value) VALUES (?, ?)`,
      ['schema_version', String(version)]
    );
  }

  // 生成演示学生（用于分页、方向筛选与匹配性能演示），已存在则跳过
  async seedDemoStudents(count: number): Promise<number> {
    const directions: string[] = Taxonomy.directionOptions;
    const grades: string[] = ['大一', '大二', '大三', '大四', '研一'];
    const levels: string[] = ['985', '211', '普通本科', '其他'];
    const now: number = Date.now();
    let created: number = 0;
    await this.runInTransaction(async (): Promise<void> => {
      for (let i = 0; i < count; i++) {
        const direction: string = directions[i % directions.length];
        const grade: string = grades[i % grades.length];
        const studentNo: string = `DEMO${1000 + i}`;
        const existed: ValuesBucket | null = await this.queryOne(
          'SELECT id FROM student_info WHERE student_no = ?', [studentNo]
        );
        if (existed !== null) {
          continue;
        }
        const id: number = await this.insert(Constants.T_STUDENT, {
          student_no: studentNo,
          name: `演示学生${i + 1}`,
          school: '示范大学',
          school_level: levels[i % levels.length],
          major: '计算机科学与技术',
          grade: grade,
          education: grade === '研一' ? '硕士' : '本科',
          direction: direction,
          phone: '',
          email: '',
          is_public: 1,
          create_time: now,
          update_time: now
        });
        if (id <= 0) {
          continue;
        }
        created += 1;
        const keywords: string[] = Taxonomy.directionKeywords(direction);
        const tagCount: number = Math.min(2, keywords.length);
        for (let k = 0; k < tagCount; k++) {
          await this.insert(Constants.T_TAG, {
            student_id: id,
            tag_name: keywords[k],
            category: 'SKILL',
            source_type: 'MANUAL',
            source_id: 0,
            proficiency: 3,
            confidence: 0.6,
            create_time: now
          });
        }
      }
    });
    return created;
  }

  private async ensureConstraints(): Promise<void> {
    await this.execute('PRAGMA foreign_keys = ON');
    try {
      await this.execute(
        `DELETE FROM ${Constants.T_TAG} WHERE id NOT IN (` +
        `SELECT MIN(id) FROM ${Constants.T_TAG} GROUP BY student_id, tag_name, category)`
      );
      await this.execute(
        `CREATE UNIQUE INDEX IF NOT EXISTS uk_tag_student_name ` +
        `ON ${Constants.T_TAG}(student_id, tag_name, category)`
      );
    } catch (error) {
      Logger.info('tag unique constraint skipped: ' + (error as Error).message);
    }
    try {
      await this.execute(
        `DELETE FROM ${Constants.T_HONOR_TOKEN} WHERE id NOT IN (` +
        `SELECT MIN(id) FROM ${Constants.T_HONOR_TOKEN} GROUP BY honor_id, token)`
      );
      await this.execute(
        `CREATE UNIQUE INDEX IF NOT EXISTS uk_honor_token ` +
        `ON ${Constants.T_HONOR_TOKEN}(honor_id, token)`
      );
    } catch (error) {
      Logger.info('token unique constraint skipped: ' + (error as Error).message);
    }
  }

  private async seedDefaults(): Promise<void> {
    const now: number = Date.now();
    const student: ValuesBucket | null = await this.queryOne(
      'SELECT id FROM student_info WHERE student_no = ?', ['20240001']
    );
    if (student === null) {
      await this.insert(Constants.T_STUDENT, {
        student_no: '20240001',
        name: '示例学生',
        school: '示例大学',
        school_level: '其他',
        major: '计算机科学与技术',
        grade: '大三',
        education: '本科',
        direction: '软件开发',
        phone: '',
        email: '',
        is_public: 1,
        create_time: now,
        update_time: now
      });
      await this.insert(Constants.T_STUDENT, {
        student_no: '20240002',
        name: '研究生同学',
        school: '示例大学',
        school_level: '其他',
        major: '软件工程',
        grade: '研一',
        education: '硕士',
        direction: '嵌入式',
        phone: '',
        email: '',
        is_public: 1,
        create_time: now,
        update_time: now
      });
    }

    const company: ValuesBucket | null = await this.queryOne(
      'SELECT id FROM company_info WHERE company_name = ?', ['示例科技有限公司']
    );
    if (company === null) {
      await this.insert(Constants.T_COMPANY, {
        company_name: '示例科技有限公司',
        industry: '软件与信息技术',
        scale: '100-500人',
        contact_person: '张经理',
        contact_phone: '',
        address: '',
        create_time: now,
        update_time: now
      });
    }

    const jobCount: number = await this.count('SELECT COUNT(*) AS cnt FROM job_requirement');
    if (jobCount === 0) {
      const sampleJobs: ValuesBucket[] = [
        {
          company_id: 1,
          job_title: 'HarmonyOS 应用开发工程师',
          major_direction: '软件开发',
          raw_text: '本科及以上学历，熟悉 ArkTS、HarmonyOS、数据库，CET-6 优先，1 年以上项目经验。',
          education_req: '本科',
          skill_req: JSON.stringify(['ArkTS', 'HarmonyOS', '数据库']),
          cert_req: JSON.stringify(['CET-6']),
          experience_req: JSON.stringify({ years: 1, keywords: ['项目经验'] }),
          weight_education: 0.15,
          weight_skill: 0.30,
          weight_cert: 0.15,
          weight_experience: 0.15,
          weight_honor: 0.10,
          weight_direction: 0.15,
          status: 1,
          create_time: now,
          update_time: now
        },
        {
          company_id: 1,
          job_title: 'Java 后端开发工程师',
          major_direction: '软件开发',
          raw_text: '本科及以上学历，掌握 Java、MySQL，有算法基础，计算机二级优先，2 年经验。',
          education_req: '本科',
          skill_req: JSON.stringify(['Java', 'MySQL', '算法']),
          cert_req: JSON.stringify(['计算机二级']),
          experience_req: JSON.stringify({ years: 2, keywords: ['实习'] }),
          weight_education: 0.15,
          weight_skill: 0.30,
          weight_cert: 0.15,
          weight_experience: 0.15,
          weight_honor: 0.10,
          weight_direction: 0.15,
          status: 1,
          create_time: now,
          update_time: now
        }
      ];
      for (const job of sampleJobs) {
        await this.insert(Constants.T_JOB, job);
      }
    }

    const honorCount: number = await this.count('SELECT COUNT(*) AS cnt FROM honor_certificate');
    if (honorCount === 0) {
      await this.insert(Constants.T_HONOR, {
        student_id: 1,
        title: '蓝桥杯软件类省赛二等奖',
        honor_type: 'COMPETITION',
        level: 'PROVINCIAL',
        award_year: 2025,
        issuer: '教育部高等学校计算机类专业教学指导委员会',
        image_path: '',
        remark: '算法竞赛经历',
        search_text: '蓝桥杯软件类省赛二等奖 教育部高等学校计算机类专业教学指导委员会 算法竞赛经历',
        create_time: now,
        update_time: now
      });
      await this.insert(Constants.T_HONOR, {
        student_id: 2,
        title: '软件设计师证书',
        honor_type: 'CERTIFICATE',
        level: 'NATIONAL',
        award_year: 2025,
        issuer: '工业和信息化部教育与考试中心',
        image_path: '',
        remark: '软考中级',
        search_text: '软件设计师证书 工业和信息化部教育与考试中心 软考中级',
        create_time: now,
        update_time: now
      });
    }

    const tagCount: number = await this.count('SELECT COUNT(*) AS cnt FROM ability_tag');
    if (tagCount === 0) {
      const tags: ValuesBucket[] = [
        { student_id: 1, tag_name: 'Java', category: 'SKILL', source_type: 'HONOR', source_id: 1, proficiency: 4, confidence: 0.9, create_time: now },
        { student_id: 1, tag_name: 'HarmonyOS', category: 'SKILL', source_type: 'PROJECT', source_id: 1, proficiency: 4, confidence: 0.8, create_time: now },
        { student_id: 1, tag_name: '算法', category: 'SKILL', source_type: 'HONOR', source_id: 1, proficiency: 4, confidence: 0.9, create_time: now },
        { student_id: 2, tag_name: 'HarmonyOS', category: 'SKILL', source_type: 'HONOR', source_id: 2, proficiency: 4, confidence: 0.8, create_time: now }
      ];
      for (const tag of tags) {
        await this.insert(Constants.T_TAG, tag);
      }
    }
  }
}

export const DbHelper: DbHelperClass = new DbHelperClass();
