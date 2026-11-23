import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { Constants } from '../common/Constants';
import { DbHelper } from '../common/DbHelper';
import { Logger } from '../common/Logger';
import { PrefsHelper } from '../common/PrefsHelper';
import { Company, Student, UserAccount } from '../model/Entity';
import { AppRole, VerifyStatus } from '../model/Enums';
import { accountRepo, companyRepo, studentRepo } from '../repository/Repositories';
import { AuthAccountDto, AuthApiError, AuthApiService, AuthConfig, AuthSessionDto } from './AuthApiService';

export interface StudentSignUpInput {
  name: string;
  studentNo: string;
  school: string;
  schoolLevel: string;
  major: string;
  education: string;
  grade: string;
  account: string;
  password: string;
  verifyImagePath: string;
}

/** 调用账号服务注册时的请求体 */
interface RemoteRegisterBody {
  role: string;
  account: string;
  password: string;
  displayName: string;
}

export interface CompanySignUpInput {
  companyName: string;
  industry: string;
  scale: string;
  contactPerson: string;
  address: string;
  account: string;
  password: string;
  verifyImagePath: string;
}

export class AuthService {
  async isAccountTaken(account: string): Promise<boolean> {
    const found: UserAccount | null = await accountRepo.findByAccount(this.normalize(account));
    return found !== null;
  }

  async registerStudent(input: StudentSignUpInput): Promise<UserAccount> {
    const account: string = this.normalize(input.account);
    await this.assertAccountAvailable(account);
    if (input.studentNo.trim().length === 0) {
      throw new Error('请填写学号');
    }
    const needsSchoolLevel: boolean = input.education === '本科' ||
      input.education === '硕士' || input.education === '博士及以上';
    if (needsSchoolLevel && input.schoolLevel.trim().length === 0) {
      throw new Error('请选择学校层级');
    }
    const studentNoCount: number = await DbHelper.count(
      `SELECT COUNT(*) AS cnt FROM ${Constants.T_STUDENT} WHERE student_no = ?`,
      [input.studentNo.trim()]
    );
    if (studentNoCount > 0) {
      throw new Error('该学号已注册，请直接登录');
    }

    // 账号服务启用时先注册云端账号；网络不可达会返回 false 并继续本地注册
    const remoteBody: RemoteRegisterBody = {
      role: AuthApiService.roleOf(AppRole.STUDENT),
      account: account,
      password: input.password,
      displayName: input.name.trim()
    };
    await this.tryRemoteRegister(JSON.stringify(remoteBody));

    const isEmail: boolean = account.includes('@');
    const student: Student = {
      id: 0,
      studentNo: input.studentNo.trim(),
      name: input.name.trim(),
      school: input.school.trim(),
      schoolLevel: input.schoolLevel.trim(),
      major: input.major.trim(),
      grade: input.grade.trim(),
      education: input.education,
      direction: '软件开发',
      phone: isEmail ? '' : account,
      email: isEmail ? account : ''
    };
    const studentId: number = await studentRepo.insert(student);
    let accountId: number = 0;
    try {
      accountId = await accountRepo.insert({
        id: 0,
        role: AppRole.STUDENT,
        account: account,
        passwordHash: await this.hashPassword(account, input.password),
        displayName: student.name,
        linkedId: studentId,
        verifyImagePath: input.verifyImagePath,
        verifyStatus: VerifyStatus.PENDING,
        createTime: Date.now()
      });
    } catch (error) {
      await DbHelper.remove(Constants.T_STUDENT, 'id = ?', [studentId]);
      const message: string = error instanceof Error ? error.message : '注册失败，请重试';
      throw new Error(message);
    }
    const created: UserAccount | null = await accountRepo.findById(accountId);
    if (created === null) {
      throw new Error('注册失败，请重试');
    }
    await this.saveSession(created);
    return created;
  }

  async registerCompany(input: CompanySignUpInput): Promise<UserAccount> {
    const account: string = this.normalize(input.account);
    await this.assertAccountAvailable(account);

    const remoteBody: RemoteRegisterBody = {
      role: AuthApiService.roleOf(AppRole.COMPANY),
      account: account,
      password: input.password,
      displayName: input.companyName.trim()
    };
    await this.tryRemoteRegister(JSON.stringify(remoteBody));

    const company: Company = {
      id: 0,
      companyName: input.companyName.trim(),
      industry: input.industry.trim(),
      scale: input.scale.trim(),
      contactPerson: input.contactPerson.trim(),
      contactPhone: account,
      address: input.address.trim()
    };
    const companyId: number = await companyRepo.insert(company);
    let accountId: number = 0;
    try {
      accountId = await accountRepo.insert({
        id: 0,
        role: AppRole.COMPANY,
        account: account,
        passwordHash: await this.hashPassword(account, input.password),
        displayName: company.companyName,
        linkedId: companyId,
        verifyImagePath: input.verifyImagePath,
        verifyStatus: VerifyStatus.PENDING,
        createTime: Date.now()
      });
    } catch (error) {
      await DbHelper.remove(Constants.T_COMPANY, 'id = ?', [companyId]);
      const message: string = error instanceof Error ? error.message : '注册失败，请重试';
      throw new Error(message);
    }
    const created: UserAccount | null = await accountRepo.findById(accountId);
    if (created === null) {
      throw new Error('注册失败，请重试');
    }
    await this.saveSession(created);
    return created;
  }

  async ensureMockAccounts(): Promise<void> {
    await this.ensureMockStudent();
    await this.ensureMockCompany();
  }

  private async ensureMockStudent(): Promise<void> {
    const account: string = '111111';
    if (await this.isAccountTaken(account)) {
      return;
    }
    const row = await DbHelper.queryOne(
      `SELECT id FROM ${Constants.T_STUDENT} WHERE student_no = ?`, ['20240001']
    );
    let studentId: number = row === null ? 0 : Number(row['id']);
    if (studentId === 0) {
      studentId = await studentRepo.insert({
        id: 0,
        studentNo: '20240001',
        name: '示例学生',
        school: '示例大学',
        schoolLevel: '其他',
        major: '计算机科学与技术',
        grade: '大三',
        education: '本科',
        direction: '软件开发',
        phone: '',
        email: ''
      });
    }
    await accountRepo.insert({
      id: 0,
      role: AppRole.STUDENT,
      account: account,
      passwordHash: await this.hashPassword(account, account),
      displayName: '示例学生',
      linkedId: studentId,
      verifyImagePath: '',
      verifyStatus: VerifyStatus.VERIFIED,
      createTime: Date.now()
    });
  }

  private async ensureMockCompany(): Promise<void> {
    const account: string = '222222';
    if (await this.isAccountTaken(account)) {
      return;
    }
    const row = await DbHelper.queryOne(
      `SELECT id FROM ${Constants.T_COMPANY} WHERE company_name = ?`, ['示例科技有限公司']
    );
    let companyId: number = row === null ? 0 : Number(row['id']);
    if (companyId === 0) {
      companyId = await companyRepo.insert({
        id: 0,
        companyName: '示例科技有限公司',
        industry: '软件与信息技术',
        scale: '100-500人',
        contactPerson: '张经理',
        contactPhone: '222222',
        address: '示例市高新区软件园'
      });
    }
    await accountRepo.insert({
      id: 0,
      role: AppRole.COMPANY,
      account: account,
      passwordHash: await this.hashPassword(account, account),
      displayName: '示例科技有限公司',
      linkedId: companyId,
      verifyImagePath: '',
      verifyStatus: VerifyStatus.VERIFIED,
      createTime: Date.now()
    });
  }

  async login(role: AppRole, accountInput: string, password: string): Promise<UserAccount> {
    const account: string = this.normalize(accountInput);
    const remote: AuthConfig = await AuthApiService.loadConfig();
    if (remote.enabled) {
      try {
        const session: AuthSessionDto = await AuthApiService.login(role, account, password);
        return await this.acceptRemoteLogin(session);
      } catch (error) {
        // 服务端明确拒绝（密码错误、角色不符）直接抛出，不再本地兜底
        if (error instanceof AuthApiError && !error.transport) {
          throw new Error(error.message);
        }
        Logger.warn(`账号服务不可用，降级本地校验：${AuthService.messageOf(error)}`);
      }
    }
    const found: UserAccount | null = await accountRepo.findByAccount(account);
    if (found === null) {
      throw new Error(remote.enabled ? '当前离线，且本机无该账号缓存，请联网后重试' : '账号不存在，请先注册');
    }
    if (found.role !== role) {
      throw new Error(role === AppRole.STUDENT ? '该账号是企业账号，请切换到企业端' : '该账号是学生账号，请切换到学生端');
    }
    if (found.passwordHash === Constants.AUTH_REMOTE_ONLY_HASH) {
      throw new Error('该账号由云端托管，当前离线无法校验密码，请联网后重试');
    }
    const passwordHash: string = await this.hashPassword(account, password);
    if (passwordHash !== found.passwordHash) {
      throw new Error('密码错误，请重新输入');
    }
    await this.saveSession(found);
    return found;
  }

  /** 云端登录成功：落地本地镜像账号，保证其余页面仍按本地 linkedId 取数据 */
  private async acceptRemoteLogin(session: AuthSessionDto): Promise<UserAccount> {
    await AuthApiService.saveToken(session);
    const dto: AuthAccountDto = session.account;
    const account: string = this.normalize(dto.account);
    let local: UserAccount | null = await accountRepo.findByAccount(account);
    if (local === null) {
      const linkedId: number = await this.ensureLocalProfile(dto);
      const id: number = await accountRepo.insert(AuthApiService.toLocalAccount(dto, linkedId));
      local = await accountRepo.findById(id);
    } else if (dto.verifyStatus.length > 0 && dto.verifyStatus !== local.verifyStatus) {
      await accountRepo.setVerifyStatus(local.id, dto.verifyStatus);
    }
    if (local === null) {
      throw new Error('登录失败，请重试');
    }
    await this.saveSession(local);
    return local;
  }

  /** 云端账号首次在本机登录时，按账号匹配已有档案；匹配不到则建占位档案 */
  private async ensureLocalProfile(dto: AuthAccountDto): Promise<number> {
    const account: string = this.normalize(dto.account);
    if (dto.role === AppRole.COMPANY) {
      const row = await DbHelper.queryOne(
        `SELECT id FROM ${Constants.T_COMPANY} WHERE contact_phone = ?`, [account]
      );
      if (row !== null) {
        return Number(row['id']);
      }
      return await companyRepo.insert({
        id: 0,
        companyName: dto.displayName.length > 0 ? dto.displayName : account,
        industry: '',
        scale: '',
        contactPerson: dto.displayName,
        contactPhone: account,
        address: ''
      });
    }
    const row = await DbHelper.queryOne(
      `SELECT id FROM ${Constants.T_STUDENT} WHERE phone = ? OR email = ?`, [account, account]
    );
    if (row !== null) {
      return Number(row['id']);
    }
    const isEmail: boolean = account.includes('@');
    return await studentRepo.insert({
      id: 0,
      studentNo: `CLOUD-${account}`,
      name: dto.displayName.length > 0 ? dto.displayName : account,
      school: '',
      schoolLevel: '其他',
      major: '',
      grade: '',
      education: '本科',
      direction: '软件开发',
      phone: isEmail ? '' : account,
      email: isEmail ? account : ''
    });
  }

  /** 远端失败但属网络问题时返回 false，表示可以继续走本地注册 */
  private async tryRemoteRegister(body: string): Promise<boolean> {
    const remote: AuthConfig = await AuthApiService.loadConfig();
    if (!remote.enabled) {
      return false;
    }
    try {
      const session: AuthSessionDto = await AuthApiService.register(body);
      await AuthApiService.saveToken(session);
      return true;
    } catch (error) {
      if (error instanceof AuthApiError && !error.transport) {
        throw new Error(error.message);
      }
      Logger.warn(`账号服务不可用，改为本地注册：${AuthService.messageOf(error)}`);
      return false;
    }
  }

  async logout(): Promise<void> {
    await AuthApiService.logout();
    await PrefsHelper.put(Constants.KEY_ACCOUNT_ID, 0);
    await PrefsHelper.put(Constants.KEY_ACCOUNT_NAME, '');
    await PrefsHelper.put(Constants.KEY_VERIFY_STATUS, '');
    await PrefsHelper.put(Constants.KEY_STUDENT_ID, 0);
    await PrefsHelper.put(Constants.KEY_COMPANY_ID, 0);
    await PrefsHelper.put(Constants.KEY_ROLE, AppRole.STUDENT);
  }

  private async saveSession(account: UserAccount): Promise<void> {
    await PrefsHelper.put(Constants.KEY_ACCOUNT_ID, account.id);
    await PrefsHelper.put(Constants.KEY_ACCOUNT_NAME, account.account);
    await PrefsHelper.put(Constants.KEY_VERIFY_STATUS, account.verifyStatus);
    await PrefsHelper.put(Constants.KEY_ROLE, account.role);
    if (account.role === AppRole.STUDENT) {
      await PrefsHelper.put(Constants.KEY_STUDENT_ID, account.linkedId);
      await PrefsHelper.put(Constants.KEY_COMPANY_ID, 0);
    } else {
      await PrefsHelper.put(Constants.KEY_STUDENT_ID, 0);
      await PrefsHelper.put(Constants.KEY_COMPANY_ID, account.linkedId);
    }
  }

  private async assertAccountAvailable(account: string): Promise<void> {
    if (account.length < 4) {
      throw new Error('登录账号至少 4 个字符');
    }
    if (await this.isAccountTaken(account)) {
      throw new Error('该账号已注册，请直接登录');
    }
  }

  private normalize(account: string): string {
    return account.trim().toLowerCase();
  }

  private static messageOf(error: Object): string {
    return error instanceof Error ? error.message : String(error);
  }

  private async hashPassword(account: string, password: string): Promise<string> {
    const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
    const encoder: util.TextEncoder = new util.TextEncoder();
    const bytes: Uint8Array = encoder.encodeInto(`boss-zhpin:${account}:${password}`);
    await md.update({ data: bytes });
    const digest: cryptoFramework.DataBlob = await md.digest();
    let hex: string = '';
    for (let i: number = 0; i < digest.data.length; i++) {
      hex += digest.data[i].toString(16).padStart(2, '0');
    }
    return hex;
  }
}

export const authService: AuthService = new AuthService();
