import { AppRole, HonorLevel, HonorType, TagCategory, TaskCategory } from './Enums';

export interface SelectItem {
  value: string;
}

export interface Student {
  id: number;
  studentNo: string;
  name: string;
  school: string;
  schoolLevel: string;
  major: string;
  grade: string;
  education: string;
  direction: string;
  phone: string;
  email: string;
  isPublic?: boolean;
}

export interface UserAccount {
  id: number;
  role: AppRole;
  account: string;
  passwordHash: string;
  displayName: string;
  linkedId: number;
  verifyImagePath: string;
  verifyStatus: string;
  createTime: number;
}

export interface GrowthTask {
  id: number;
  studentId: number;
  majorDirection: string;
  academicStage: string;
  taskTitle: string;
  taskDesc: string;
  category: TaskCategory;
  dueDate: number;
  status: number;
  remindEnabled: boolean;
  remindTime: number;
  reminderId?: number;
}

export interface HonorCertificate {
  id: number;
  studentId: number;
  title: string;
  honorType: HonorType;
  level: HonorLevel;
  awardYear: number;
  issuer: string;
  imagePath: string;
  remark: string;
  searchText: string;
  createTime: number;
}

export interface SkillCertificate {
  id: number;
  studentId: number;
  certName: string;
  issuer: string;
  obtainYear: number;
  level: string;
  imagePath: string;
}

export interface ProjectExperience {
  id: number;
  studentId: number;
  projectName: string;
  role: string;
  startDate: number;
  endDate: number;
  description: string;
  tags: string[];
}

export interface AbilityTag {
  id: number;
  studentId: number;
  tagName: string;
  category: TagCategory;
  sourceType: string;
  sourceId: number;
  proficiency: number;
  confidence: number;
}

export interface Company {
  id: number;
  companyName: string;
  industry: string;
  scale: string;
  contactPerson: string;
  contactPhone: string;
  address: string;
}

export interface MatchWeights {
  education: number;
  skill: number;
  certificate: number;
  experience: number;
  honor: number;
  direction: number;
}

export interface JobRequirement {
  id: number;
  companyId: number;
  companyName: string;
  jobTitle: string;
  majorDirection: string;
  rawText: string;
  educationReq: string;
  skillReq: string[];
  certReq: string[];
  experienceYears: number;
  experienceKeywords: string[];
  weights: MatchWeights;
  status: number;
}

export interface DimensionScores {
  education: number;
  skill: number;
  certificate: number;
  experience: number;
  honor: number;
  direction: number;
}

/** 大模型语义评分：与六个规则维度一一对应，取值 0~1 */
export interface SemanticScores {
  education: number;
  skill: number;
  certificate: number;
  experience: number;
  honor: number;
  direction: number;
}

/** 一次大模型语义评估的完整结果（含可解释依据） */
export interface SemanticResult {
  scores: SemanticScores;
  /** 模型给出的综合契合度 0~1 */
  overall: number;
  /** 一句话总评 */
  reason: string;
  strengths: string[];
  gaps: string[];
  /** 实际调用的模型名，便于演示时说明来源 */
  model: string;
  createTime: number;
}

export interface MatchResult {
  totalScore: number;
  dimensionScores: DimensionScores;
  gapItems: string[];
  suggestions: string[];
  /** 是否融合了大模型语义评分（false/未定义表示纯本地规则分） */
  semantic?: boolean;
  /** 融合前的大模型原始评分，用于得分明细对照 */
  semanticScores?: SemanticScores;
  semanticOverall?: number;
  semanticReason?: string;
  semanticModel?: string;
}

export interface MatchRecord {
  id: number;
  studentId: number;
  jobId: number;
  direction: number;
  totalScore: number;
  dimensionScores: DimensionScores;
  gapItems: string[];
  suggestions: string[];
  createTime: number;
}

export interface HonorFilter {
  keyword: string;
  honorType: string;
  level: string;
  yearFrom: number;
  yearTo: number;
  issuer: string;
}

export interface ParsedRequirement {
  educationReq: string;
  skillReq: string[];
  certReq: string[];
  experienceYears: number;
  experienceKeywords: string[];
}

export interface ExperienceRequirement {
  years: number;
  keywords: string[];
}

export interface SkillDictItem {
  name: string;
  aliases: string[];
  category: string;
}

export interface SkillDict {
  version: string;
  skills: SkillDictItem[];
  certificates: SkillDictItem[];
  educationRank: string[];
}

export interface GrowthTemplate {
  direction: string;
  stage: string;
  tasks: GrowthTemplateTask[];
}

export interface GrowthTemplateTask {
  title: string;
  desc: string;
  category: TaskCategory;
  offsetDays: number;
}

export interface GrowthTemplateLib {
  templates: GrowthTemplate[];
}

export interface AdviceItem {
  key: string;
  text: string;
}

export interface AdviceLib {
  advice: AdviceItem[];
  default: string;
}
