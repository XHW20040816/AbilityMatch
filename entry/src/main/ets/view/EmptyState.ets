@Component
export struct EmptyState {
  @Prop text: string = '暂无数据';

  build() {
    Column({ space: 14 }) {
      Image($r('app.media.hero_rest'))
        .width(150)
        .height(150)
        .objectFit(ImageFit.Contain)
      Text(this.text)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .padding({ top: 36, bottom: 36 })
  }
}
