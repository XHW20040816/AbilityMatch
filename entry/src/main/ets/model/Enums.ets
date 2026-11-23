export enum AppRole {
  STUDENT = 'student',
  COMPANY = 'company'
}

export enum VerifyStatus {
  PENDING = 'PENDING',
  VERIFIED = 'VERIFIED',
  REJECTED = 'REJECTED'
}

export function verifyStatusLabel(status: string): string {
  if (status === VerifyStatus.VERIFIED) {
    return '已核验';
  }
  if (status === VerifyStatus.REJECTED) {
    return '未通过';
  }
  return '待核验';
}

export enum HonorType {
  COMPETITION = 'COMPETITION',
  HONOR = 'HONOR',
  CERTIFICATE = 'CERTIFICATE'
}

export enum HonorLevel {
  NATIONAL = 'NATIONAL',
  PROVINCIAL = 'PROVINCIAL',
  UNIVERSITY = 'UNIVERSITY',
  COLLEGE = 'COLLEGE'
}

export enum TagCategory {
  SKILL = 'SKILL',
  CERTIFICATE = 'CERTIFICATE',
  HONOR = 'HONOR',
  PROJECT = 'PROJECT'
}

export enum TaskCategory {
  COURSE = 'COURSE',
  COMPETITION = 'COMPETITION',
  CERT = 'CERT',
  PROJECT = 'PROJECT'
}

export enum MatchDirection {
  STUDENT_TO_JOB = 0,
  COMPANY_TO_STUDENT = 1
}

export function honorTypeLabel(value: string): string {
  if (value === HonorType.COMPETITION) {
    return '竞赛获奖';
  }
  if (value === HonorType.HONOR) {
    return '荣誉称号';
  }
  if (value === HonorType.CERTIFICATE) {
    return '技能证书';
  }
  return value;
}

export function honorLevelLabel(value: string): string {
  if (value === HonorLevel.NATIONAL) {
    return '国家级';
  }
  if (value === HonorLevel.PROVINCIAL) {
    return '省级';
  }
  if (value === HonorLevel.UNIVERSITY) {
    return '校级';
  }
  if (value === HonorLevel.COLLEGE) {
    return '院级';
  }
  return value;
}
