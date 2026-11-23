import { HonorCertificate } from '../model/Entity';
import { honorLevelLabel, honorTypeLabel } from '../model/Enums';

@Component
export struct CertificateCard {
  @Prop cert: HonorCertificate;
  @Prop imageBasePath: string = '';
  onOpen: () => void = () => {};
  onEdit: () => void = () => {};
  onDelete: () => void = () => {};

  build() {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        if (this.cert.imagePath.length > 0) {
          Image(this.imageBasePath + '/' + this.cert.imagePath)
            .width(62)
            .height(62)
            .borderRadius(14)
            .objectFit(ImageFit.Cover)
        } else {
          Column() {
            Text('证').fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.on_primary'))
          }
          .width(62)
          .height(62)
          .borderRadius(14)
          .linearGradient({ angle: 150, colors: [['#3AD8DA', 0], ['#0FA3AE', 1]] })
          .border({ width: 1, color: '#4DFFFFFF' })
          .shadow({ radius: 10, color: '#590A8089', offsetX: 0, offsetY: 4 })
          .justifyContent(FlexAlign.Center)
        }

        Column({ space: 5 }) {
          Text(this.cert.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          Row({ space: 6 }) {
            Text(honorTypeLabel(this.cert.honorType)).fontSize(11).fontColor($r('app.color.brand_primary'))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 }).borderRadius(10)
              .backgroundColor($r('app.color.chip_background'))
            Text(honorLevelLabel(this.cert.level)).fontSize(11).fontColor($r('app.color.text_primary'))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 }).borderRadius(10)
              .backgroundColor($r('app.color.accent_peach_soft'))
            Text(String(this.cert.awardYear)).fontSize(11).fontColor($r('app.color.text_secondary'))
          }
          Text(this.cert.issuer).fontSize(11).fontColor($r('app.color.text_secondary'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Row({ space: 8 }) {
        Button('预览').fontSize(12).borderRadius(16).backgroundColor($r('app.color.brand_soft'))
          .fontColor($r('app.color.brand_primary')).onClick(() => this.onOpen())
        Button('编辑').fontSize(12).borderRadius(16).backgroundColor($r('app.color.surface_muted'))
          .fontColor($r('app.color.text_primary')).onClick(() => this.onEdit())
        Button('删除').fontSize(12).borderRadius(16).backgroundColor($r('app.color.danger'))
          .fontColor($r('app.color.on_primary')).onClick(() => this.onDelete())
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(20)
    .linearGradient({ angle: 145, colors: [['#FFFFFF', 0], ['#F1FAF9', 1]] })
    .border({ width: 1, color: '#66FFFFFF' })
    .shadow({ radius: 14, color: '#260E5C5C', offsetX: 0, offsetY: 6 })
    .margin({ bottom: 14 })
  }
}
