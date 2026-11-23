@Component
export struct TagChip {
  @Prop text: string = '';
  @Prop color: Resource = $r('app.color.brand_primary');

  build() {
    Text(this.text)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.color)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(18)
      .border({ width: 1, color: this.color })
      .linearGradient({ angle: 145, colors: [['#FFFFFF', 0], [$r('app.color.chip_background'), 1]] })
      .shadow({ radius: 6, color: '#1A0E5C5C', offsetX: 0, offsetY: 3 })
      .margin({ right: 8, bottom: 8 })
  }
}
