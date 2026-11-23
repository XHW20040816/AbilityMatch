import { AbilityConstant, common, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { Constants } from '../common/Constants';
import { DbHelper } from '../common/DbHelper';
import { PrefsHelper } from '../common/PrefsHelper';
import { authService } from '../service/AuthService';

const DOMAIN = 0x0000;
const TAG = 'AbilityMatch';

export default class EntryAbility extends UIAbility {
  private initPromise: Promise<void> = Promise.resolve();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
    const context: common.UIAbilityContext = this.context as common.UIAbilityContext;
    this.initPromise = DbHelper.init(context)
      .then(() => PrefsHelper.init(context))
      .then(() => PrefsHelper.put(Constants.KEY_DB_VERSION, 3))
      .then(() => authService.ensureMockAccounts().catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Mock account seed failed: %{public}s', error.message);
      }));
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');
    this.initPromise.then(async () => {
      hilog.info(DOMAIN, TAG, 'Local storage ready');
      const accountId: number = await PrefsHelper.getNumber(Constants.KEY_ACCOUNT_ID, 0);
      this.loadContent(windowStage, accountId > 0 ? 'pages/Index' : 'pages/AuthPage');
    }).catch((error: Error) => {
      hilog.error(DOMAIN, TAG, 'Storage init failed: %{public}s', error.message);
      this.loadContent(windowStage, 'pages/AuthPage');
    });
  }

  private loadContent(windowStage: window.WindowStage, page: string): void {
    windowStage.loadContent(page, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}
