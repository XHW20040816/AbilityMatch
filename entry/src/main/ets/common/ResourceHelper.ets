import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { AdviceLib, GrowthTemplateLib, SkillDict } from '../model/Entity';

export class ResourceHelper {
  private static readonly decoder: util.TextDecoder = new util.TextDecoder('utf-8');
  private static dictCache: SkillDict | null = null;
  private static templateCache: GrowthTemplateLib | null = null;
  private static adviceCache: AdviceLib | null = null;

  private static async read(context: common.UIAbilityContext, name: string): Promise<string> {
    const data: Uint8Array = await context.resourceManager.getRawFileContent(name);
    return ResourceHelper.decoder.decode(data);
  }

  static async loadSkillDict(context: common.UIAbilityContext): Promise<SkillDict> {
    if (ResourceHelper.dictCache === null) {
      const text: string = await ResourceHelper.read(context, 'skill_dict.json');
      ResourceHelper.dictCache = JSON.parse(text) as SkillDict;
    }
    return ResourceHelper.dictCache;
  }

  static async loadGrowthTemplates(context: common.UIAbilityContext): Promise<GrowthTemplateLib> {
    if (ResourceHelper.templateCache === null) {
      const text: string = await ResourceHelper.read(context, 'growth_templates.json');
      ResourceHelper.templateCache = JSON.parse(text) as GrowthTemplateLib;
    }
    return ResourceHelper.templateCache;
  }

  static async loadAdviceLib(context: common.UIAbilityContext): Promise<AdviceLib> {
    if (ResourceHelper.adviceCache === null) {
      const text: string = await ResourceHelper.read(context, 'advice_lib.json');
      ResourceHelper.adviceCache = JSON.parse(text) as AdviceLib;
    }
    return ResourceHelper.adviceCache;
  }
}
