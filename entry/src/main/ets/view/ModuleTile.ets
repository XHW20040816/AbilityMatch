import { Style3D } from '../common/Style3D';
import { Card3D } from './Card3D';

/** 首页功能入口：3D 渐变徽章 + 立体卡片 */
@Component
export struct ModuleTile {
  title: string = '';
  desc: string = '';
  colorIndex: number = 0;
  action: () => void = () => {};

  build() {
    Card3D({
      faceColors: Style3D.whiteFace,
      depthColor: Style3D.whiteDepth,
      radius: 20,
      depth: 5,
      facePadding: 14,
      shadowRadius: 16,
      action: this.action
    }) {
      Row({ space: 14 }) {
        Column() {
          Text(Style3D.badgeText(this.title))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.on_primary'))
        }
        .width(46)
        .height(46)
        .justifyContent(FlexAlign.Center)
        .borderRadius(15)
        .linearGradient({
          angle: 150,
          colors: [[Style3D.faceAt(this.colorIndex)[0], 0], [Style3D.faceAt(this.colorIndex)[1], 1]]
        })
        .border({ width: 1, color: Style3D.highlight })
        .shadow({
          radius: 10,
          color: Style3D.depthAt(this.colorIndex),
          offsetX: 0,
          offsetY: 4
        })

        Column({ space: 4 }) {
          Text(this.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(this.desc)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('›')
          .fontSize(24)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
    }
  }
}
