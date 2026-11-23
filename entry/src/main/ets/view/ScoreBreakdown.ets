import { MatchResult, MatchWeights } from '../model/Entity';

interface ScoreRow {
  label: string;
  raw: number;
  weight: number;
  contribution: number;
  hint: string;
}

/**
 * 匹配得分的可解释明细：展示每个维度的原始得分、权重与加权贡献，
 * 使总分可被逐项核验（论文算法章节与答辩演示均可直接引用）。
 */
@Component
export struct ScoreBreakdown {
  result: MatchResult = {
    totalScore: 0,
    dimensionScores: { education: 0, skill: 0, certificate: 0, experience: 0, honor: 0, direction: 0 },
    gapItems: [],
    suggestions: []
  };
  @Prop weights: MatchWeights = {
    education: 0.15, skill: 0.30, certificate: 0.15, experience: 0.15, honor: 0.10, direction: 0.15
  };
  @Prop expanded: boolean = true;

  private totalWeight(): number {
    return this.weights.education + this.weights.skill + this.weights.certificate +
      this.weights.experience + this.weights.honor + this.weights.direction;
  }

  private contribution(score: number, weight: number): number {
    const total: number = this.totalWeight();
    if (total <= 0) {
      return 0;
    }
    return score * weight * 100 / total;
  }

  private hintOf(label: string, raw: number): string {
    if (raw >= 0.85) {
      return '满足要求';
    }
    if (raw >= 0.6) {
      return '基本满足，可提升';
    }
    return label === '方向' ? '方向不完全一致' : '未满足，需补齐';
  }

  private rows(): ScoreRow[] {
    const scores = this.result.dimensionScores;
    return [
      {
        label: '学历',
        raw: scores.education,
        weight: this.weights.education,
        contribution: this.contribution(scores.education, this.weights.education),
        hint: this.hintOf('学历', scores.education)
      },
      {
        label: '技能',
        raw: scores.skill,
        weight: this.weights.skill,
        contribution: this.contribution(scores.skill, this.weights.skill),
        hint: this.hintOf('技能', scores.skill)
      },
      {
        label: '证书',
        raw: scores.certificate,
        weight: this.weights.certificate,
        contribution: this.contribution(scores.certificate, this.weights.certificate),
        hint: this.hintOf('证书', scores.certificate)
      },
      {
        label: '经验',
        raw: scores.experience,
        weight: this.weights.experience,
        contribution: this.contribution(scores.experience, this.weights.experience),
        hint: this.hintOf('经验', scores.experience)
      },
      {
        label: '荣誉/项目',
        raw: scores.honor,
        weight: this.weights.honor,
        contribution: this.contribution(scores.honor, this.weights.honor),
        hint: this.hintOf('荣誉/项目', scores.honor)
      },
      {
        label: '方向',
        raw: scores.direction,
        weight: this.weights.direction,
        contribution: this.contribution(scores.direction, this.weights.direction),
        hint: this.hintOf('方向', scores.direction)
      }
    ];
  }

  private rawColor(raw: number): ResourceColor {
    if (raw >= 0.85) {
      return $r('app.color.success');
    }
    if (raw >= 0.6) {
      return $r('app.color.brand_primary');
    }
    return $r('app.color.danger');
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text('得分明细').fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1)
        Text(`总分 ${this.result.totalScore}`).fontSize(13)
          .fontColor($r('app.color.brand_primary'))
        Text(this.expanded ? '收起' : '展开').fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 8 })
          .onClick(() => { this.expanded = !this.expanded; })
      }
      .width('100%')

      if (this.expanded) {
        Row() {
          Text('维度').fontSize(10).fontColor($r('app.color.text_secondary')).width('22%')
          Text('达成度').fontSize(10).fontColor($r('app.color.text_secondary')).width('20%')
          Text('权重').fontSize(10).fontColor($r('app.color.text_secondary')).width('16%')
          Text('贡献分').fontSize(10).fontColor($r('app.color.text_secondary')).width('18%')
          Text('说明').fontSize(10).fontColor($r('app.color.text_secondary')).layoutWeight(1)
        }
        .width('100%')

        ForEach(this.rows(), (row: ScoreRow) => {
          Row() {
            Text(row.label).fontSize(12).width('22%')
            Text(`${Math.round(row.raw * 100)}%`).fontSize(12)
              .fontColor(this.rawColor(row.raw)).width('20%')
            Text(`${Math.round(row.weight * 100)}%`).fontSize(12)
              .fontColor($r('app.color.text_secondary')).width('16%')
            Text(`${Math.round(row.contribution * 10) / 10}`).fontSize(12)
              .fontColor($r('app.color.brand_primary')).width('18%')
            Text(row.hint).fontSize(10)
              .fontColor($r('app.color.text_label')).layoutWeight(1).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%').padding({ top: 4, bottom: 4 })
        }, (row: ScoreRow) => row.label)

        Text('总分 = Σ(达成度 × 权重占比) × 100，权重占比按六维权重归一化')
          .fontSize(10).fontColor($r('app.color.text_secondary')).width('100%')
      }
    }
    .width('100%').padding(14).borderRadius(16)
    .backgroundColor($r('app.color.card_background'))
    .alignItems(HorizontalAlign.Start)
  }
}
