import { DimensionScores, MatchWeights } from '../model/Entity';

export class Constants {
  static readonly DB_NAME: string = 'AbilityMatch.db';
  static readonly PREF_NAME: string = 'AbilityMatchPrefs';

  static readonly T_STUDENT: string = 'student_info';
  static readonly T_GROWTH: string = 'growth_plan';
  static readonly T_HONOR: string = 'honor_certificate';
  static readonly T_HONOR_TOKEN: string = 'honor_search_token';
  static readonly T_TAG: string = 'ability_tag';
  static readonly T_COMPANY: string = 'company_info';
  static readonly T_JOB: string = 'job_requirement';
  static readonly T_MATCH: string = 'match_record';
  static readonly T_SKILL_CERT: string = 'skill_certificate';
  static readonly T_PROJECT: string = 'project_experience';
  static readonly T_ACCOUNT: string = 'user_account';
  static readonly T_META: string = 'app_meta';
  // 数据库结构版本：新增字段或索引时递增，便于迁移与论文说明版本演进
  static readonly DB_VERSION: number = 2;

  static readonly KEY_ROLE: string = 'current_role';
  static readonly KEY_STUDENT_ID: string = 'current_student_id';
  static readonly KEY_COMPANY_ID: string = 'current_company_id';
  static readonly KEY_ACCOUNT_ID: string = 'current_account_id';
  static readonly KEY_ACCOUNT_NAME: string = 'current_account_name';
  static readonly KEY_VERIFY_STATUS: string = 'current_verify_status';
  static readonly KEY_REMIND: string = 'remind_enabled';
  static readonly KEY_JOB_SEARCH: string = 'job_search_history';
  static readonly KEY_REMIND_ADVANCE: string = 'remind_advance_days';
  static readonly KEY_W_EDU: string = 'weight_education';
  static readonly KEY_W_SKILL: string = 'weight_skill';
  static readonly KEY_W_CERT: string = 'weight_cert';
  static readonly KEY_W_EXP: string = 'weight_experience';
  static readonly KEY_W_HONOR: string = 'weight_honor';
  static readonly KEY_W_DIRECTION: string = 'weight_direction';
  static readonly KEY_FILTER_CACHE: string = 'honor_filter_cache';
  static readonly KEY_DICT_VERSION: string = 'skill_dict_version';
  static readonly KEY_DB_VERSION: string = 'db_version';

  // ---- 大模型语义匹配（OpenAI 兼容的 chat/completions 接口） ----
  static readonly KEY_LLM_ENABLED: string = 'llm_enabled';
  static readonly KEY_LLM_BASE_URL: string = 'llm_base_url';
  static readonly KEY_LLM_API_KEY: string = 'llm_api_key';
  static readonly KEY_LLM_MODEL: string = 'llm_model';
  static readonly LLM_DEFAULT_BASE_URL: string = 'https://api.deepseek.com/v1';
  static readonly LLM_DEFAULT_MODEL: string = 'deepseek-chat';
  // 单次请求超时：太短会让弱网误降级，太长会拖慢首屏
  static readonly LLM_TIMEOUT_MS: number = 15000;
  // 语义融合系数 α：语义越擅长的维度占比越高；学历/荣誉属于客观事实，只做微调
  static readonly SEMANTIC_ALPHA: DimensionScores = {
    education: 0.2,
    skill: 0.45,
    certificate: 0.3,
    experience: 0.4,
    honor: 0.2,
    direction: 0.35
  };
  // 列表页只对规则分最高的前 K 个结果调用大模型，控制时延与调用成本
  static readonly SEMANTIC_TOPK: number = 8;
  static readonly SEMANTIC_CACHE_TTL: number = 10 * 60 * 1000;
  static readonly SEMANTIC_CACHE_LIMIT: number = 200;

  // ---- 账号服务（AGC 云函数 / 本地 Node 骨架，统一 REST + JWT） ----
  static readonly KEY_AUTH_ENABLED: string = 'auth_remote_enabled';
  static readonly KEY_AUTH_BASE_URL: string = 'auth_base_url';
  static readonly KEY_AUTH_TOKEN: string = 'auth_access_token';
  static readonly KEY_AUTH_REFRESH_TOKEN: string = 'auth_refresh_token';
  static readonly KEY_AUTH_TOKEN_EXPIRE: string = 'auth_token_expire';
  // 模拟器访问宿主机用 10.0.2.2；真机用局域网 IP，均可在数据工具页修改
  static readonly AUTH_DEFAULT_BASE_URL: string = 'http://10.0.2.2:8080';
  static readonly AUTH_TIMEOUT_MS: number = 8000;
  // 本地镜像账号的占位哈希：表示该账号由云端托管，本机不可直接校验密码
  static readonly AUTH_REMOTE_ONLY_HASH: string = 'REMOTE_ONLY';

  static readonly DEFAULT_WEIGHTS: MatchWeights = {
    education: 0.15,
    skill: 0.30,
    certificate: 0.15,
    experience: 0.15,
    honor: 0.10,
    direction: 0.15
  };

  static readonly CREATE_SQLS: string[] = [
    `CREATE TABLE IF NOT EXISTS student_info (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_no TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      school TEXT DEFAULT '',
      school_level TEXT DEFAULT '',
      major TEXT,
      grade TEXT,
      education TEXT DEFAULT '本科',
      direction TEXT,
      phone TEXT,
      email TEXT,
      is_public INTEGER DEFAULT 1,
      create_time INTEGER NOT NULL,
      update_time INTEGER NOT NULL)`,
    `CREATE TABLE IF NOT EXISTS growth_plan (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL,
      major_direction TEXT NOT NULL,
      academic_stage TEXT NOT NULL,
      task_title TEXT NOT NULL,
      task_desc TEXT,
      category TEXT,
      due_date INTEGER,
      status INTEGER DEFAULT 0,
      remind_enabled INTEGER DEFAULT 0,
      remind_time INTEGER,
      reminder_id INTEGER DEFAULT 0,
      create_time INTEGER NOT NULL,
      update_time INTEGER NOT NULL,
      FOREIGN KEY (student_id) REFERENCES student_info(id) ON DELETE CASCADE)`,
    `CREATE INDEX IF NOT EXISTS idx_growth_student_stage ON growth_plan(student_id, academic_stage)`,
    `CREATE INDEX IF NOT EXISTS idx_growth_direction_stage ON growth_plan(student_id, major_direction, academic_stage)`,
    `CREATE INDEX IF NOT EXISTS idx_growth_due ON growth_plan(due_date)`,
    `CREATE TABLE IF NOT EXISTS honor_certificate (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      honor_type TEXT NOT NULL,
      level TEXT,
      award_year INTEGER,
      issuer TEXT,
      image_path TEXT,
      remark TEXT,
      search_text TEXT,
      create_time INTEGER NOT NULL,
      update_time INTEGER NOT NULL,
      FOREIGN KEY (student_id) REFERENCES student_info(id) ON DELETE CASCADE)`,
    `CREATE INDEX IF NOT EXISTS idx_honor_student ON honor_certificate(student_id)`,
    `CREATE INDEX IF NOT EXISTS idx_honor_filter ON honor_certificate(student_id, honor_type, level, award_year)`,
    `CREATE INDEX IF NOT EXISTS idx_honor_search ON honor_certificate(search_text)`,
    `CREATE TABLE IF NOT EXISTS honor_search_token (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL,
      honor_id INTEGER NOT NULL,
      token TEXT NOT NULL,
      FOREIGN KEY (honor_id) REFERENCES honor_certificate(id) ON DELETE CASCADE)`,
    `CREATE INDEX IF NOT EXISTS idx_honor_token_lookup ON honor_search_token(student_id, token)`,
    `CREATE INDEX IF NOT EXISTS idx_honor_token_honor ON honor_search_token(honor_id)`,
    `CREATE TABLE IF NOT EXISTS ability_tag (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL,
      tag_name TEXT NOT NULL,
      category TEXT NOT NULL,
      source_type TEXT,
      source_id INTEGER,
      proficiency INTEGER DEFAULT 3,
      confidence REAL DEFAULT 1.0,
      create_time INTEGER NOT NULL,
      FOREIGN KEY (student_id) REFERENCES student_info(id) ON DELETE CASCADE)`,
    `CREATE INDEX IF NOT EXISTS idx_tag_student ON ability_tag(student_id)`,
    `CREATE INDEX IF NOT EXISTS idx_tag_name ON ability_tag(tag_name)`,
    `CREATE TABLE IF NOT EXISTS company_info (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      company_name TEXT NOT NULL,
      industry TEXT,
      scale TEXT,
      contact_person TEXT,
      contact_phone TEXT,
      address TEXT,
      create_time INTEGER NOT NULL,
      update_time INTEGER NOT NULL)`,
    `CREATE TABLE IF NOT EXISTS job_requirement (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      company_id INTEGER NOT NULL,
      job_title TEXT NOT NULL,
      major_direction TEXT DEFAULT '',
      raw_text TEXT,
      education_req TEXT,
      skill_req TEXT,
      cert_req TEXT,
      experience_req TEXT,
      weight_education REAL DEFAULT 0.15,
      weight_skill REAL DEFAULT 0.30,
      weight_cert REAL DEFAULT 0.15,
      weight_experience REAL DEFAULT 0.15,
      weight_honor REAL DEFAULT 0.10,
      weight_direction REAL DEFAULT 0.15,
      status INTEGER DEFAULT 1,
      create_time INTEGER NOT NULL,
      update_time INTEGER NOT NULL,
      FOREIGN KEY (company_id) REFERENCES company_info(id) ON DELETE CASCADE)`,
    `CREATE INDEX IF NOT EXISTS idx_job_company ON job_requirement(company_id, status)`,
    `CREATE INDEX IF NOT EXISTS idx_job_direction ON job_requirement(major_direction, status)`,
    `CREATE TABLE IF NOT EXISTS match_record (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL,
      job_id INTEGER NOT NULL,
      direction INTEGER NOT NULL,
      total_score REAL NOT NULL,
      edu_score REAL,
      skill_score REAL,
      cert_score REAL,
      exp_score REAL,
      honor_score REAL,
      direction_score REAL,
      gap_items TEXT,
      suggestions TEXT,
      create_time INTEGER NOT NULL,
      FOREIGN KEY (student_id) REFERENCES student_info(id) ON DELETE CASCADE,
      FOREIGN KEY (job_id) REFERENCES job_requirement(id) ON DELETE CASCADE)`,
    `CREATE INDEX IF NOT EXISTS idx_match_student ON match_record(student_id, create_time)`,
    `CREATE INDEX IF NOT EXISTS idx_match_job ON match_record(job_id, create_time)`,
    `CREATE TABLE IF NOT EXISTS skill_certificate (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL,
      cert_name TEXT NOT NULL,
      issuer TEXT,
      obtain_year INTEGER,
      level TEXT,
      image_path TEXT,
      create_time INTEGER NOT NULL,
      FOREIGN KEY (student_id) REFERENCES student_info(id) ON DELETE CASCADE)`,
    `CREATE INDEX IF NOT EXISTS idx_skill_cert_student ON skill_certificate(student_id)`,
    `CREATE TABLE IF NOT EXISTS project_experience (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      student_id INTEGER NOT NULL,
      project_name TEXT NOT NULL,
      role TEXT,
      start_date INTEGER,
      end_date INTEGER,
      description TEXT,
      tags TEXT,
      create_time INTEGER NOT NULL,
      FOREIGN KEY (student_id) REFERENCES student_info(id) ON DELETE CASCADE)`,
    `CREATE INDEX IF NOT EXISTS idx_project_student ON project_experience(student_id)`,
    `CREATE TABLE IF NOT EXISTS user_account (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      role TEXT NOT NULL,
      account TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      display_name TEXT DEFAULT '',
      linked_id INTEGER DEFAULT 0,
      verify_image_path TEXT DEFAULT '',
      verify_status TEXT DEFAULT 'PENDING',
      create_time INTEGER NOT NULL,
      update_time INTEGER NOT NULL)`,
    `CREATE INDEX IF NOT EXISTS idx_account_role ON user_account(role)`
  ];
}
