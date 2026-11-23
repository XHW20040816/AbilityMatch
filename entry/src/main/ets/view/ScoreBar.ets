/** 立体进度条：凹槽轨道 + 渐变高光填充，达到 80% 时转为暖色 */
@Component
export struct ScoreBar {
  @Prop label: string = '';
  @Prop score: number = 0;

  private percent(): number {
    const value: number = Math.max(0, Math.min(1, this.score));
    return Math.round(value * 100);
  }

  private fillColors(): string[] {
    return this.score >= 0.8 ? ['#FFD9B8', '#FF9463'] : ['#3AD8DA', '#0FA3AE'];
  }

  build() {
    Column({ space: 6 }) {
      Row() {
        Text(this.label).fontSize(14).fontColor($r('app.color.text_label'))
        Blank()
        Text(`${this.percent()}%`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.score >= 0.8 ? $r('app.color.accent_peach') : $r('app.color.brand_primary'))
      }
      .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(12)
          .borderRadius(6)
          .backgroundColor($r('app.color.track_background'))
          .border({ width: 1, color: '#260E5C5C' })

        Row()
          .width(`${this.percent()}%`)
          .height(12)
          .borderRadius(6)
          .linearGradient({
            angle: 90,
            colors: [[this.fillColors()[0], 0], [this.fillColors()[1], 1]]
          })
          .border({ width: 1, color: '#4DFFFFFF' })
          .shadow({
            radius: 8,
            color: this.score >= 0.8 ? '#66FF9463' : '#660FA3AE',
            offsetX: 0,
            offsetY: 2
          })
      }
      .width('100%')
      .height(12)
      .accessibilityText(`${this.label}达成度 ${this.percent()}%`)
    }
    .width('100%')
    .margin({ bottom: 12 })
  }
}
