import { abilityDelegatorRegistry, Component, Driver, ON, On } from '@kit.TestKit';
import { Want } from '@kit.AbilityKit';
import { beforeAll, describe, expect, it } from '@ohos/hypium';

const BUNDLE_NAME: string = 'com.example.abilitymatch';
const MODULE_NAME: string = 'entry';
const ENTRY_ABILITY: string = 'EntryAbility';
const HOME_TITLE: string = '能力画像与岗位匹配';

const driver: Driver = Driver.create();
const delegator: abilityDelegatorRegistry.AbilityDelegator =
  abilityDelegatorRegistry.getAbilityDelegator();

/** 轮询查找组件，出现则返回，超时返回 null */
async function waitFor(on: On, timeoutMs: number): Promise<Component | null> {
  const deadline: number = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const node: Component | null | undefined = await driver.findComponent(on);
    if (node !== null && node !== undefined) {
      return node;
    }
    await driver.delayMs(200);
  }
  return null;
}

/** 判断组件当前是否存在（未命中时框架返回 null） */
async function isPresent(on: On): Promise<boolean> {
  const node: Component | null | undefined = await driver.findComponent(on);
  return node !== null && node !== undefined;
}

/** 等待组件消失，用于确认页面已真正退出 */
async function waitGone(on: On, timeoutMs: number): Promise<boolean> {
  const deadline: number = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (!(await isPresent(on))) {
      return true;
    }
    await driver.delayMs(200);
  }
  return false;
}

/** 保证当前在首页：不在首页则按返回键回退，最多尝试 3 次 */
async function ensureHome(): Promise<boolean> {
  for (let attempt: number = 0; attempt < 3; attempt++) {
    if (await isPresent(ON.text(HOME_TITLE))) {
      return true;
    }
    await driver.pressBack();
    await driver.delayMs(800);
  }
  return await isPresent(ON.text(HOME_TITLE));
}

/**
 * G-10 自动化 UI 测试：覆盖三条主流程
 * 1. 首页角色切换（企业端 / 学生端）与企业信息页进入、返回
 * 2. 能力画像页与五维能力雷达组件
 * 3. 荣誉证书关键字检索（含输入法输入）
 *
 * 说明：Driver.waitForComponent 超时后返回 undefined 而不抛错，无法作为断言依据，
 * 因此这里统一使用轮询查找 + 显式断言，并在返回首页后确认旧页面已退出，
 * 避免点击落在路由栈中尚未销毁的隐藏页面上。
 */
export default function abilityMatchUiTest() {
  describe('AbilityMatchUiTest', () => {
    beforeAll(async () => {
      const want: Want = {
        bundleName: BUNDLE_NAME,
        moduleName: MODULE_NAME,
        abilityName: ENTRY_ABILITY
      };
      try {
        await delegator.startAbility(want);
      } catch (error) {
        console.error('AbilityMatchUiTest: failed to start EntryAbility');
      }
      await driver.delayMs(2500);
      const home: Component | null = await waitFor(ON.text(HOME_TITLE), 10000);
      expect(home !== null).assertTrue();
    });

    it('ui_01_home_role_switch_and_company_entry', 0, async () => {
      // 切换到企业端，出现“招聘方工作台”即证明角色切换生效
      const companyRole: Component | null = await waitFor(ON.id('role_company'), 5000);
      expect(companyRole !== null).assertTrue();
      if (companyRole !== null) {
        await companyRole.click();
      }
      const companyConsole: Component | null = await waitFor(ON.text('招聘方工作台'), 5000);
      expect(companyConsole !== null).assertTrue();

      // 进入企业信息页
      const companyModule: Component | null = await waitFor(ON.text('企业信息'), 5000);
      expect(companyModule !== null).assertTrue();
      if (companyModule !== null) {
        await companyModule.click();
      }
      const companyPage: Component | null = await waitFor(ON.text('新增企业'), 8000);
      expect(companyPage !== null).assertTrue();

      // 返回首页：先确认企业信息页已退出，避免点击落在过渡中的隐藏页面
      await driver.pressBack();
      expect(await waitGone(ON.text('新增企业'), 6000)).assertTrue();
      const home: Component | null = await waitFor(ON.text(HOME_TITLE), 5000);
      expect(home !== null).assertTrue();

      // 切回学生端
      const studentRole: Component | null = await waitFor(ON.id('role_student'), 5000);
      expect(studentRole !== null).assertTrue();
      if (studentRole !== null) {
        await studentRole.click();
      }
      const studentConsole: Component | null = await waitFor(ON.text('当前学生'), 5000);
      expect(studentConsole !== null).assertTrue();
    });

    it('ui_02_portrait_radar_visible', 0, async () => {
      expect(await ensureHome()).assertTrue();

      let portraitModule: Component | null = await waitFor(ON.text('能力画像'), 5000);
      if (portraitModule === null) {
        const homeList: Component | null = await waitFor(ON.id('home_module_list'), 3000);
        if (homeList !== null) {
          portraitModule = await homeList.scrollSearch(ON.text('能力画像'));
        }
      }
      expect(portraitModule !== null).assertTrue();
      if (portraitModule !== null) {
        await portraitModule.click();
      }

      expect((await waitFor(ON.text('我的能力画像'), 8000)) !== null).assertTrue();
      expect((await waitFor(ON.text('能力雷达'), 5000)) !== null).assertTrue();
      expect((await waitFor(ON.id('portrait_radar'), 5000)) !== null).assertTrue();

      // 导出入口位于页面下方，需要滚动后确认可见
      let exportButton: Component | null = await waitFor(ON.text('导出能力档案(JSON)'), 2000);
      if (exportButton === null) {
        const pageScroll: Component | null = await waitFor(ON.id('portrait_scroll'), 3000);
        if (pageScroll !== null) {
          exportButton = await pageScroll.scrollSearch(ON.text('导出能力档案(JSON)'));
        }
      }
      expect(exportButton !== null).assertTrue();

      await driver.pressBack();
      expect(await waitGone(ON.text('我的能力画像'), 6000)).assertTrue();
    });

    it('ui_03_certificate_keyword_search', 0, async () => {
      expect(await ensureHome()).assertTrue();

      const certificateModule: Component | null = await waitFor(ON.text('荣誉证书'), 5000);
      expect(certificateModule !== null).assertTrue();
      if (certificateModule !== null) {
        await certificateModule.click();
      }
      expect((await waitFor(ON.text('荣誉证书归档'), 8000)) !== null).assertTrue();

      const keyword: Component | null = await waitFor(ON.id('cert_keyword'), 5000);
      expect(keyword !== null).assertTrue();
      if (keyword !== null) {
        await keyword.click();
        await driver.delayMs(300);
        await keyword.inputText('蓝桥杯');
      }
      expect((await waitFor(ON.text('共 1 条记录，已加载 1 条'), 8000)) !== null).assertTrue();
    });
  });
}
