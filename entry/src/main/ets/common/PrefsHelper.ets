import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Constants } from './Constants';

class PrefsHelperClass {
  private prefs: preferences.Preferences | null = null;

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.prefs === null) {
      this.prefs = await preferences.getPreferences(context, Constants.PREF_NAME);
    }
  }

  private store(): preferences.Preferences {
    if (this.prefs === null) {
      throw new Error('Preferences has not been initialized');
    }
    return this.prefs;
  }

  async getString(key: string, defaultValue: string): Promise<string> {
    const value: preferences.ValueType = await this.store().get(key, defaultValue);
    return typeof value === 'string' ? value : defaultValue;
  }

  async getNumber(key: string, defaultValue: number): Promise<number> {
    const value: preferences.ValueType = await this.store().get(key, defaultValue);
    return typeof value === 'number' ? value : defaultValue;
  }

  async getBoolean(key: string, defaultValue: boolean): Promise<boolean> {
    const value: preferences.ValueType = await this.store().get(key, defaultValue);
    return typeof value === 'boolean' ? value : defaultValue;
  }

  async put(key: string, value: preferences.ValueType): Promise<void> {
    await this.store().put(key, value);
    await this.store().flush();
  }
}

export const PrefsHelper: PrefsHelperClass = new PrefsHelperClass();
