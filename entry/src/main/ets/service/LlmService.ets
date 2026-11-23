import { http } from '@kit.NetworkKit';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { PrefsHelper } from '../common/PrefsHelper';

/**
 * 大模型配置：采用 OpenAI 兼容的 chat/completions 协议，
 * 因此 DeepSeek / 通义千问 / 智谱 / Moonshot / Ollama 等只要给出 baseUrl 与 model 即可复用。
 */
export interface LlmConfig {
  enabled: boolean;
  baseUrl: string;
  apiKey: string;
  model: string;
}

interface ChatMessage {
  role: string;
  content: string;
}

interface ChatRequestBody {
  model: string;
  messages: ChatMessage[];
  temperature: number;
  stream: boolean;
}

interface ChatChoice {
  message: ChatMessage;
}

interface ChatResponse {
  choices: ChatChoice[];
}

export class LlmService {
  static async loadConfig(): Promise<LlmConfig> {
    const enabled: boolean = await PrefsHelper.getBoolean(Constants.KEY_LLM_ENABLED, false);
    const baseUrl: string = await PrefsHelper.getString(Constants.KEY_LLM_BASE_URL, Constants.LLM_DEFAULT_BASE_URL);
    const apiKey: string = await PrefsHelper.getString(Constants.KEY_LLM_API_KEY, '');
    const model: string = await PrefsHelper.getString(Constants.KEY_LLM_MODEL, Constants.LLM_DEFAULT_MODEL);
    return {
      enabled: enabled,
      baseUrl: LlmService.normalizeBase(baseUrl),
      apiKey: apiKey,
      model: model.length > 0 ? model : Constants.LLM_DEFAULT_MODEL
    };
  }

  static async saveConfig(config: LlmConfig): Promise<void> {
    await PrefsHelper.put(Constants.KEY_LLM_ENABLED, config.enabled);
    await PrefsHelper.put(Constants.KEY_LLM_BASE_URL, config.baseUrl);
    await PrefsHelper.put(Constants.KEY_LLM_API_KEY, config.apiKey);
    await PrefsHelper.put(Constants.KEY_LLM_MODEL, config.model);
  }

  /** 去掉末尾斜杠：用户可能直接粘贴 https://api.deepseek.com/v1/ 甚至完整 .../chat/completions */
  private static normalizeBase(baseUrl: string): string {
    let base: string = baseUrl.trim();
    if (base.length === 0) {
      return Constants.LLM_DEFAULT_BASE_URL;
    }
    if (base.endsWith('/chat/completions')) {
      base = base.substring(0, base.length - '/chat/completions'.length);
    }
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  static isReady(config: LlmConfig): boolean {
    return config.enabled && config.apiKey.trim().length > 0 && config.baseUrl.length > 0;
  }

  /** 判断当前是否需要走大模型：开关打开且密钥已填 */
  static async isAvailable(): Promise<boolean> {
    const config: LlmConfig = await LlmService.loadConfig();
    return LlmService.isReady(config);
  }

  /**
   * 发起一次对话补全。失败时抛出带中文说明的错误，由调用方决定是否降级到本地算法。
   */
  static async chat(system: string, user: string): Promise<string> {
    const config: LlmConfig = await LlmService.loadConfig();
    if (!LlmService.isReady(config)) {
      throw new Error('未配置大模型服务');
    }
    const body: ChatRequestBody = {
      model: config.model,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user }
      ],
      // 语义评分需要稳定可复现，温度取低值
      temperature: 0.1,
      stream: false
    };
    const content: string = await LlmService.post(config, JSON.stringify(body));
    Logger.info(`LLM 语义匹配返回 ${content.length} 字符，model=${config.model}`);
    return content;
  }

  private static async post(config: LlmConfig, payload: string): Promise<string> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(`${config.baseUrl}/chat/completions`, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${config.apiKey}`
        },
        extraData: payload,
        connectTimeout: Constants.LLM_TIMEOUT_MS,
        readTimeout: Constants.LLM_TIMEOUT_MS,
        expectDataType: http.HttpDataType.STRING
      });
      const text: string = typeof response.result === 'string' ?
        response.result as string : JSON.stringify(response.result);
      if (response.responseCode !== http.ResponseCode.OK) {
        throw new Error(`大模型接口返回 ${response.responseCode}：${LlmService.briefError(text)}`);
      }
      const parsed: ChatResponse = JSON.parse(text) as ChatResponse;
      if (parsed.choices === undefined || parsed.choices.length === 0) {
        throw new Error('大模型返回内容为空');
      }
      return parsed.choices[0].message.content;
    } catch (error) {
      const message: string = error instanceof Error ? error.message : String(error);
      Logger.error(`大模型请求失败：${message}`);
      throw new Error(message);
    } finally {
      request.destroy();
    }
  }

  private static briefError(text: string): string {
    const body: string = text.length > 120 ? text.substring(0, 120) : text;
    return body.length > 0 ? body : '空响应';
  }

  /** 配置页的“测试连接”：发一句极短请求，验证地址、密钥与模型是否可用 */
  static async testConnection(): Promise<string> {
    const reply: string = await LlmService.chat('你是连通性测试助手，请只回复 OK。', '请回复 OK');
    const trimmed: string = reply.trim();
    return trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed;
  }
}
