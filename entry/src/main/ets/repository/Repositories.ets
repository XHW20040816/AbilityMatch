import { AccountRepository } from './AccountRepository';
import { CompanyRepository } from './CompanyRepository';
import { GrowthRepository } from './GrowthRepository';
import { HonorRepository } from './HonorRepository';
import { JobRepository } from './JobRepository';
import { MatchRepository } from './MatchRepository';
import { ProfileRepository } from './ProfileRepository';
import { StudentRepository } from './StudentRepository';
import { TagRepository } from './TagRepository';

export const studentRepo: StudentRepository = new StudentRepository();
export const growthRepo: GrowthRepository = new GrowthRepository();
export const honorRepo: HonorRepository = new HonorRepository();
export const tagRepo: TagRepository = new TagRepository();
export const companyRepo: CompanyRepository = new CompanyRepository();
export const jobRepo: JobRepository = new JobRepository();
export const matchRepo: MatchRepository = new MatchRepository();
export const profileRepo: ProfileRepository = new ProfileRepository();
export const accountRepo: AccountRepository = new AccountRepository();
