import { router } from '@kit.ArkUI';

export class RouteHelper {
  static params(): Record<string, Object> {
    const raw: Object = router.getParams();
    if (raw === undefined || raw === null) {
      const empty: Record<string, Object> = {};
      return empty;
    }
    return raw as Record<string, Object>;
  }
}
