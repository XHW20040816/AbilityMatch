/**
 * 3D 视觉令牌：渐变面色、侧面厚度色、投影与高光。
 * 卡片统一采用「面板 + 厚度底座」两层结构，按下时面板下沉，形成实体按压反馈。
 */
export class Style3D {
  /** 主视觉（首页头部、登录页头图） */
  static readonly heroFace: string[] = ['#2ACBD2', '#0A7C92'];
  static readonly heroDepth: string = '#06596B';

  /** 浅色面板 */
  static readonly whiteFace: string[] = ['#FFFFFF', '#F1FAF9'];
  static readonly whiteDepth: string = '#C9E3E0';

  /** 模块徽章 / 卡片面色，6 套主题，按序循环 */
  static readonly tileFaces: string[][] = [
    ['#3AD8DA', '#0FA3AE'],
    ['#9BA8FA', '#5F6FE0'],
    ['#FFC7A3', '#FF9463'],
    ['#6FDDB0', '#2FAE7C'],
    ['#C0A6F5', '#8A76D8'],
    ['#7FD3F7', '#2B9CDE']
  ];
  static readonly tileDepths: string[] = ['#0A8089', '#4453C4', '#DE7440', '#1D8A5F', '#67539F', '#1B78AE'];

  static readonly shadowSoft: string = '#1A0E5C5C';
  static readonly shadowDeep: string = '#330E5C5C';
  static readonly highlight: string = '#66FFFFFF';

  static faceAt(index: number): string[] {
    return Style3D.tileFaces[index % Style3D.tileFaces.length];
  }

  static depthAt(index: number): string {
    return Style3D.tileDepths[index % Style3D.tileDepths.length];
  }

  /** 徽章字符：取标题首字，保证无图片也有立体图标 */
  static badgeText(title: string): string {
    return title.length > 0 ? title.substring(0, 1) : '·';
  }
}
