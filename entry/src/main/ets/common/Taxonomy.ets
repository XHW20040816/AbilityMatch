export class Taxonomy {
  static readonly educationOptions: string[] = [
    '高中学历及以下', '专科', '专升本', '本科', '硕士', '博士及以上'
  ];

  static readonly schoolLevelOptions: string[] = ['985', '211', '双一流', '留学', '其他'];

  static readonly directionOptions: string[] = [
    '软件开发', '人工智能', '嵌入式', '网络安全', '数据分析', '软件测试',
    '产品运营', '数字媒体', '云计算', '集成电路'
  ];

  static readonly directionGroups: string[][] = [
    ['软件开发', '后端开发', '前端开发', '移动开发', '全栈开发', 'Java', 'Web', 'HarmonyOS', 'ArkTS'],
    ['人工智能', '机器学习', '深度学习', '算法', '数据科学', '大模型', '计算机视觉', '自然语言处理'],
    ['嵌入式', '物联网', '单片机', '硬件', '驱动开发', '电子信息'],
    ['网络安全', '信息安全', '渗透测试', '密码学'],
    ['数据分析', '大数据', '数据挖掘', '商业分析', 'BI'],
    ['软件测试', '测试开发', '自动化测试', '质量保障'],
    ['产品运营', '产品经理', '运营', '用户研究', '交互设计'],
    ['数字媒体', '前端设计', 'UI', '视觉设计', '多媒体'],
    ['云计算', '云原生', '运维', 'DevOps', '容器'],
    ['集成电路', '芯片', '微电子', '半导体', 'FPGA']
  ];

  static educationRank(value: string): number {
    const text: string = value.trim();
    if (text.includes('博士')) {
      return 5;
    }
    if (text.includes('硕士') || text.includes('研究生')) {
      return 4;
    }
    if (text.includes('本科') || text.includes('专升本')) {
      return 3;
    }
    if (text.includes('专科') || text.includes('大专')) {
      return 2;
    }
    if (text.includes('高中') || text.includes('中专')) {
      return 1;
    }
    return 0;
  }

  static normalizeEducation(value: string): string {
    const text: string = value.trim();
    if (text === '大专') {
      return '专科';
    }
    if (text === '博士') {
      return '博士及以上';
    }
    if (text === '高中' || text === '中专') {
      return '高中学历及以下';
    }
    if (text.includes('研究生') || text === '硕士') {
      return '硕士';
    }
    return text;
  }

  static directionKeywords(direction: string): string[] {
    const target: string = direction.trim();
    if (target.length === 0) {
      return [];
    }
    const result: string[] = [target];
    for (const group of Taxonomy.directionGroups) {
      let targetInGroup: boolean = false;
      for (const item of group) {
        if (target.toLowerCase().includes(item.toLowerCase())) {
          targetInGroup = true;
          break;
        }
      }
      if (targetInGroup) {
        for (const item of group) {
          if (result.indexOf(item) < 0) {
            result.push(item);
          }
        }
        break;
      }
    }
    return result;
  }

  static directionScore(ownDirection: string, requiredDirection: string): number {
    const own: string = ownDirection.trim().toLowerCase();
    const required: string = requiredDirection.trim().toLowerCase();
    if (required.length === 0) {
      return 1;
    }
    if (own.length === 0) {
      return 0.4;
    }
    if (own.includes(required) || required.includes(own)) {
      return 1;
    }
    for (const group of Taxonomy.directionGroups) {
      let ownHit: boolean = false;
      let requiredHit: boolean = false;
      for (const item of group) {
        const keyword: string = item.toLowerCase();
        if (own.includes(keyword)) {
          ownHit = true;
        }
        if (required.includes(keyword)) {
          requiredHit = true;
        }
      }
      if (ownHit && requiredHit) {
        return 0.7;
      }
    }
    return 0;
  }
}
