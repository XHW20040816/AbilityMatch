import { common } from '@kit.AbilityKit';
import { Constants } from '../common/Constants';
import { PrefsHelper } from '../common/PrefsHelper';
import { AppRole, VerifyStatus } from '../model/Enums';
import { companyRepo, studentRepo } from '../repository/Repositories';

class AppViewModelClass {
  role: AppRole = AppRole.STUDENT;
  accountId: number = 0;
  accountName: string = '';
  verifyStatus: string = VerifyStatus.PENDING;
  loggedIn: boolean = false;
  studentId: number = 0;
  studentName: string = '';
  studentGrade: string = '';
  companyId: number = 0;
  companyName: string = '';

  async load(): Promise<void> {
    this.accountId = await PrefsHelper.getNumber(Constants.KEY_ACCOUNT_ID, 0);
    this.accountName = await PrefsHelper.getString(Constants.KEY_ACCOUNT_NAME, '');
    this.verifyStatus = await PrefsHelper.getString(Constants.KEY_VERIFY_STATUS, VerifyStatus.PENDING);
    const roleText: string = await PrefsHelper.getString(Constants.KEY_ROLE, AppRole.STUDENT);
    this.role = roleText === AppRole.COMPANY ? AppRole.COMPANY : AppRole.STUDENT;
    this.studentId = await PrefsHelper.getNumber(Constants.KEY_STUDENT_ID, 0);
    this.companyId = await PrefsHelper.getNumber(Constants.KEY_COMPANY_ID, 0);
    this.loggedIn = this.accountId > 0;

    if (!this.loggedIn) {
      return;
    }
    if (this.role === AppRole.STUDENT) {
      const student = await studentRepo.getById(this.studentId);
      this.studentName = student === null ? '' : student.name;
      this.studentGrade = student === null ? '' : student.grade;
    } else {
      const company = await companyRepo.getById(this.companyId);
      this.companyName = company === null ? '' : company.companyName;
    }
  }

  async logout(): Promise<void> {
    await PrefsHelper.put(Constants.KEY_ACCOUNT_ID, 0);
    await PrefsHelper.put(Constants.KEY_ACCOUNT_NAME, '');
    await PrefsHelper.put(Constants.KEY_VERIFY_STATUS, '');
    await PrefsHelper.put(Constants.KEY_STUDENT_ID, 0);
    await PrefsHelper.put(Constants.KEY_COMPANY_ID, 0);
    await PrefsHelper.put(Constants.KEY_ROLE, AppRole.STUDENT);
    this.loggedIn = false;
    this.accountId = 0;
    this.accountName = '';
    this.studentId = 0;
    this.companyId = 0;
  }

  context(page: Object): common.UIAbilityContext {
    return getContext(page) as common.UIAbilityContext;
  }
}

export const AppViewModel: AppViewModelClass = new AppViewModelClass();
