import { http } from '@kit.NetworkKit';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { PrefsHelper } from '../common/PrefsHelper';
import { UserAccount } from '../model/Entity';
import { AppRole, VerifyStatus } from '../model/Enums';

/** 账号服务地址与开关，存在本机 Preferences，可在数据工具页修改 */
export interface AuthConfig {
  enabled: boolean;
  baseUrl: string;
}

/** 服务端返回的账号信息（不含密码哈希） */
export interface AuthAccountDto {
  id: number;
  role: string;
  account: string;
  displayName: string;
  verifyStatus: string;
}

/** 登录/注册成功后的会话 */
export interface AuthSessionDto {
  token: string;
  refreshToken: string;
  expiresIn: number;
  account: AuthAccountDto;
}

interface AuthEnvelope {
  ok: boolean;
  code?: string;
  message?: string;
  data?: AuthSessionDto;
}

interface AuthAccountEnvelope {
  ok: boolean;
  code?: string;
  message?: string;
  data?: AuthAccountDto;
}

interface LoginBody {
  role: string;
  account: string;
  password: string;
}

interface RefreshBody {
  refreshToken: string;
}

/** 账号服务错误：transport=true 表示网络/超时等可降级错误，false 表示服务端明确拒绝 */
export class AuthApiError extends Error {
  code: string;
  transport: boolean;

  constructor(code: string, message: string, transport: boolean) {
    super(message);
    this.name = 'AuthApiError';
    this.code = code;
    this.transport = transport;
  }
}

export class AuthApiService {
  static async loadConfig(): Promise<AuthConfig> {
    const enabled: boolean = await PrefsHelper.getBoolean(Constants.KEY_AUTH_ENABLED, false);
    const baseUrl: string = await PrefsHelper.getString(Constants.KEY_AUTH_BASE_URL, Constants.AUTH_DEFAULT_BASE_URL);
    return { enabled: enabled, baseUrl: AuthApiService.normalizeBase(baseUrl) };
  }

  static async saveConfig(config: AuthConfig): Promise<void> {
    await PrefsHelper.put(Constants.KEY_AUTH_ENABLED, config.enabled);
    await PrefsHelper.put(Constants.KEY_AUTH_BASE_URL, AuthApiService.normalizeBase(config.baseUrl));
  }

  /** 是否已启用账号服务：开关打开即可尝试，失败再降级 */
  static async isEnabled(): Promise<boolean> {
    const config: AuthConfig = await AuthApiService.loadConfig();
    return config.enabled && config.baseUrl.length > 0;
  }

  static async saveToken(session: AuthSessionDto): Promise<void> {
    await PrefsHelper.put(Constants.KEY_AUTH_TOKEN, session.token);
    await PrefsHelper.put(Constants.KEY_AUTH_REFRESH_TOKEN, session.refreshToken);
    await PrefsHelper.put(Constants.KEY_AUTH_TOKEN_EXPIRE, Date.now() + session.expiresIn * 1000);
  }

  static async clearToken(): Promise<void> {
    await PrefsHelper.put(Constants.KEY_AUTH_TOKEN, '');
    await PrefsHelper.put(Constants.KEY_AUTH_REFRESH_TOKEN, '');
    await PrefsHelper.put(Constants.KEY_AUTH_TOKEN_EXPIRE, 0);
  }

  static async getToken(): Promise<string> {
    const token: string = await PrefsHelper.getString(Constants.KEY_AUTH_TOKEN, '');
    if (token.length === 0) {
      return '';
    }
    const expire: number = await PrefsHelper.getNumber(Constants.KEY_AUTH_TOKEN_EXPIRE, 0);
    // 提前 60 秒视为过期，避免临界时刻请求被服务端拒绝
    if (expire > 0 && Date.now() > expire - 60000) {
      return AuthApiService.refreshToken();
    }
    return token;
  }

  /** 用 refreshToken 换取新 accessToken，失败返回空串交由调用方处理 */
  static async refreshToken(): Promise<string> {
    const refresh: string = await PrefsHelper.getString(Constants.KEY_AUTH_REFRESH_TOKEN, '');
    if (refresh.length === 0) {
      return '';
    }
    try {
      const body: RefreshBody = { refreshToken: refresh };
      const session: AuthSessionDto = await AuthApiService.postSession('/api/auth/refresh', JSON.stringify(body), '');
      await AuthApiService.saveToken(session);
      return session.token;
    } catch (error) {
      Logger.warn(`刷新 token 失败：${AuthApiService.messageOf(error)}`);
      return '';
    }
  }

  static async testConnection(): Promise<string> {
    const config: AuthConfig = await AuthApiService.loadConfig();
    const response: http.HttpResponse = await AuthApiService.request(
      config.baseUrl, '/api/health', http.RequestMethod.GET, '', '');
    const text: string = AuthApiService.textOf(response);
    if (response.responseCode !== http.ResponseCode.OK) {
      throw new AuthApiError('BAD_RESPONSE', `账号服务返回 ${response.responseCode}：${text}`, false);
    }
    return text.length > 80 ? text.substring(0, 80) : text;
  }

  /** 本地角色枚举（student/company）与服务端大写角色（STUDENT/COMPANY）之间的映射 */
  static roleOf(role: AppRole): string {
    return role === AppRole.COMPANY ? 'COMPANY' : 'STUDENT';
  }

  static async login(role: AppRole, account: string, password: string): Promise<AuthSessionDto> {
    const body: LoginBody = {
      role: AuthApiService.roleOf(role),
      account: account,
      password: password
    };
    return AuthApiService.postSession('/api/auth/login', JSON.stringify(body), '');
  }

  static async register(body: string): Promise<AuthSessionDto> {
    return AuthApiService.postSession('/api/auth/register', body, '');
  }

  static async me(): Promise<AuthAccountDto> {
    const config: AuthConfig = await AuthApiService.loadConfig();
    const token: string = await AuthApiService.getToken();
    const response: http.HttpResponse = await AuthApiService.request(
      config.baseUrl, '/api/auth/me', http.RequestMethod.GET, '', token);
    const text: string = AuthApiService.textOf(response);
    if (response.responseCode !== http.ResponseCode.OK) {
      throw AuthApiService.errorOf(text, response.responseCode, false);
    }
    const envelope: AuthAccountEnvelope = JSON.parse(text) as AuthAccountEnvelope;
    if (envelope.data === undefined) {
      throw new AuthApiError('BAD_RESPONSE', '账号服务返回格式异常', false);
    }
    return envelope.data;
  }

  static async logout(): Promise<void> {
    const config: AuthConfig = await AuthApiService.loadConfig();
    const token: string = await PrefsHelper.getString(Constants.KEY_AUTH_TOKEN, '');
    if (config.enabled && token.length > 0) {
      try {
        await AuthApiService.request(config.baseUrl, '/api/auth/logout', http.RequestMethod.POST, '{}', token);
      } catch (error) {
        Logger.warn(`通知账号服务下线失败：${AuthApiService.messageOf(error)}`);
      }
    }
    await AuthApiService.clearToken();
  }

  /** 把服务端账号 DTO 转成本地 UserAccount（linkedId 由调用方按本地镜像补） */
  static toLocalAccount(dto: AuthAccountDto, linkedId: number): UserAccount {
    return {
      id: 0,
      role: dto.role.toUpperCase() === 'COMPANY' ? AppRole.COMPANY : AppRole.STUDENT,
      account: dto.account,
      passwordHash: Constants.AUTH_REMOTE_ONLY_HASH,
      displayName: dto.displayName,
      linkedId: linkedId,
      verifyImagePath: '',
      verifyStatus: dto.verifyStatus.length > 0 ? dto.verifyStatus : VerifyStatus.PENDING,
      createTime: Date.now()
    };
  }

  private static async postSession(path: string, body: string, token: string): Promise<AuthSessionDto> {
    const config: AuthConfig = await AuthApiService.loadConfig();
    const response: http.HttpResponse = await AuthApiService.request(
      config.baseUrl, path, http.RequestMethod.POST, body, token);
    const text: string = AuthApiService.textOf(response);
    if (response.responseCode !== http.ResponseCode.OK) {
      if (response.responseCode >= 400 && response.responseCode < 500) {
        throw AuthApiService.errorOf(text, response.responseCode, false);
      }
      throw AuthApiService.errorOf(text, response.responseCode, true);
    }
    const envelope: AuthEnvelope = JSON.parse(text) as AuthEnvelope;
    if (envelope.data === undefined) {
      throw new AuthApiError('BAD_RESPONSE', '账号服务返回格式异常', false);
    }
    return envelope.data;
  }

  private static async request(baseUrl: string, path: string, method: http.RequestMethod,
    body: string, token: string): Promise<http.HttpResponse> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const header: Record<string, string> = { 'Content-Type': 'application/json' };
      if (token.length > 0) {
        header['Authorization'] = `Bearer ${token}`;
      }
      const response: http.HttpResponse = await request.request(`${baseUrl}${path}`, {
        method: method,
        header: header,
        extraData: body,
        connectTimeout: Constants.AUTH_TIMEOUT_MS,
        readTimeout: Constants.AUTH_TIMEOUT_MS,
        expectDataType: http.HttpDataType.STRING
      });
      return response;
    } catch (error) {
      const message: string = AuthApiService.messageOf(error);
      Logger.error(`账号服务请求失败（${path}）：${message}`);
      throw new AuthApiError('NETWORK', `无法连接账号服务：${message}`, true);
    } finally {
      request.destroy();
    }
  }

  private static textOf(response: http.HttpResponse): string {
    return typeof response.result === 'string' ? response.result as string : JSON.stringify(response.result);
  }

  private static errorOf(text: string, statusCode: number, transport: boolean): AuthApiError {
    try {
      const envelope: AuthEnvelope = JSON.parse(text) as AuthEnvelope;
      if (envelope.message !== undefined && envelope.message.length > 0) {
        return new AuthApiError(envelope.code ?? 'UNKNOWN', envelope.message, transport);
      }
    } catch (error) {
      // 非 JSON 响应，走兜底
    }
    return new AuthApiError('HTTP_' + statusCode, `账号服务返回 ${statusCode}`, transport);
  }

  private static messageOf(error: Object): string {
    return error instanceof Error ? error.message : String(error);
  }

  private static normalizeBase(baseUrl: string): string {
    let base: string = baseUrl.trim();
    if (base.length === 0) {
      return Constants.AUTH_DEFAULT_BASE_URL;
    }
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/api')) {
      base = base.substring(0, base.length - '/api'.length);
    }
    return base;
  }
}
