import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { FileHelper } from '../common/FileHelper';
import { ResourceHelper } from '../common/ResourceHelper';
import { RouteHelper } from '../common/RouteHelper';
import { HonorCertificate, HonorFilter, SkillDict } from '../model/Entity';
import { honorLevelLabel, honorTypeLabel } from '../model/Enums';
import { honorRepo } from '../repository/Repositories';
import { CertificateService } from '../service/CertificateService';
import { ExportService } from '../service/ExportService';
import { CertificateCard } from '../view/CertificateCard';
import { EmptyState } from '../view/EmptyState';

interface CertRouteParams {
  studentId: number;
  certId: number;
}

@Entry
@Component
struct CertificatePage {
  @State studentId: number = 1;
  @State keyword: string = '';
  @State honorType: string = '';
  @State level: string = '';
  @State honorTypeIndex: number = 0;
  @State levelIndex: number = 0;
  @State yearModeIndex: number = 0;
  @State yearFromText: string = '';
  @State yearToText: string = '';
  @State issuer: string = '';
  @State issuerIndex: number = 0;
  @State issuerOptions: string[] = [];
  @State certs: HonorCertificate[] = [];
  @State previewUrl: string = '';
  @State total: number = 0;
  @State nextOffset: number = 0;
  @State hasMore: boolean = true;
  @State loadingMore: boolean = false;
  private readonly pageSize: number = 20;
  private requestSeq: number = 0;
  private service: CertificateService = new CertificateService();
  private exporter: ExportService = new ExportService();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private dict: SkillDict | null = null;

  aboutToAppear(): void {
    const params: Record<string, Object> = RouteHelper.params();
    if (params['studentId'] !== undefined) {
      this.studentId = Number(params['studentId']);
    }
    ResourceHelper.loadSkillDict(this.context).then((dict: SkillDict) => {
      this.dict = dict;
      honorRepo.ensureSearchIndex(this.studentId).then(() => {
        this.load(true);
      }).catch(() => {
        this.load(true);
      });
    });
  }

  private filter(): HonorFilter {
    const currentYear: number = new Date().getFullYear();
    let from: number = Number(this.yearFromText) > 0 ? Number(this.yearFromText) : 0;
    let to: number = Number(this.yearToText) > 0 ? Number(this.yearToText) : 0;
    if (this.yearModeIndex === 1) {
      from = currentYear - 2;
      to = currentYear;
    } else if (this.yearModeIndex === 2) {
      from = currentYear - 4;
      to = currentYear;
    }
    return {
      keyword: this.keyword.trim(),
      honorType: this.honorType,
      level: this.level,
      yearFrom: from,
      yearTo: to,
      issuer: this.issuer.trim()
    };
  }

  private loadIssuers(): void {
    honorRepo.listIssuers(this.studentId).then((issuers: string[]) => {
      this.issuerOptions = issuers;
      if (this.issuerIndex > issuers.length) {
        this.issuerIndex = 0;
        this.issuer = '';
      }
    }).catch(() => {
      this.issuerOptions = [];
    });
  }

  private issuerSelectItems(): SelectOption[] {
    const items: SelectOption[] = [{ value: '全部颁发单位' }];
    for (const item of this.issuerOptions) {
      items.push({ value: item });
    }
    return items;
  }

  private load(reset: boolean): void {
    if (!reset && (!this.hasMore || this.loadingMore)) {
      return;
    }
    const seq: number = ++this.requestSeq;
    const offset: number = reset ? 0 : this.nextOffset;
    const filter: HonorFilter = this.filter();
    this.loadingMore = true;
    this.service.count(this.studentId, filter).then((total: number) => {
      if (seq === this.requestSeq) {
        this.total = total;
      }
      return this.service.list(this.studentId, filter, this.pageSize, offset);
    }).then((certs: HonorCertificate[]) => {
      if (seq !== this.requestSeq) {
        return;
      }
      this.certs = reset ? certs : this.certs.concat(certs);
      this.nextOffset = this.certs.length;
      this.hasMore = this.certs.length < this.total;
      this.loadingMore = false;
      if (reset) {
        this.loadIssuers();
      }
    }).catch((error: Error) => {
      if (seq === this.requestSeq) {
        this.loadingMore = false;
        promptAction.showToast({ message: '加载失败：' + error.message });
      }
    });
  }

  private loadMore(): void {
    if (this.hasMore && !this.loadingMore) {
      this.load(false);
    }
  }

  private edit(cert?: HonorCertificate): void {
    const params: CertRouteParams = {
      studentId: this.studentId,
      certId: cert === undefined ? 0 : cert.id
    };
    router.pushUrl({ url: 'pages/CertificateEditPage', params: params });
  }

  private remove(cert: HonorCertificate): void {
    this.service.remove(cert, this.context).then(() => {
      promptAction.showToast({ message: '已删除' });
      this.load(true);
    });
  }

  private exportCsv(): void {
    this.service.list(this.studentId, this.filter(), 5000, 0).then((all: HonorCertificate[]) => {
      return this.exporter.saveCertificatesCsv(this.context, all);
    }).then((saved: boolean) => {
      promptAction.showToast({ message: saved ? '证书记录已保存到指定位置' : '已取消导出' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '导出失败：' + error.message });
    });
  }

  build() {
    Stack() {
      Column({ space: 10 }) {
        Column({ space: 6 }) {
          Text('荣誉证书归档').fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          Text('把每一份荣誉，收进成长档案')
            .fontSize(12).fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 18, right: 18, top: 16, bottom: 14 })
        .borderRadius(20)
        .backgroundColor($r('app.color.brand_soft'))

        Row({ space: 8 }) {
          TextInput({ placeholder: '关键字检索', text: this.keyword })
            .id('cert_keyword')
            .layoutWeight(1)
            .borderRadius(18)
            .onChange((value: string) => { this.keyword = value; this.load(true); })
          Button('新增').borderRadius(18).backgroundColor($r('app.color.brand_primary'))
            .fontColor($r('app.color.on_primary')).onClick(() => this.edit())
        }
        .width('100%')

        Row({ space: 8 }) {
          Select([{ value: '全部类型' }, { value: honorTypeLabel('COMPETITION') },
            { value: honorTypeLabel('HONOR') }, { value: honorTypeLabel('CERTIFICATE') }])
            .width(0)
            .selected(this.honorTypeIndex)
            .layoutWeight(1)
            .onSelect((index: number) => {
              this.honorTypeIndex = index;
              this.honorType = index === 0 ? '' : ['COMPETITION', 'HONOR', 'CERTIFICATE'][index - 1];
              this.load(true);
            })
          Select([{ value: '全部级别' }, { value: honorLevelLabel('NATIONAL') },
            { value: honorLevelLabel('PROVINCIAL') }, { value: honorLevelLabel('UNIVERSITY') },
            { value: honorLevelLabel('COLLEGE') }])
            .width(0)
            .selected(this.levelIndex)
            .layoutWeight(1)
            .onSelect((index: number) => {
              this.levelIndex = index;
              this.level = index === 0 ? '' : ['NATIONAL', 'PROVINCIAL', 'UNIVERSITY', 'COLLEGE'][index - 1];
              this.load(true);
            })
        }
        .width('100%')

        Row({ space: 8 }) {
          Select([{ value: '全部年份' }, { value: '近三年' }, { value: '近五年' }])
            .width(0)
            .selected(this.yearModeIndex)
            .layoutWeight(1)
            .onSelect((index: number) => {
              this.yearModeIndex = index;
              this.load(true);
            })
          TextInput({ placeholder: '起始年', text: this.yearFromText })
            .width(80)
            .type(InputType.Number)
            .onChange((value: string) => { this.yearFromText = value; this.load(true); })
          TextInput({ placeholder: '结束年', text: this.yearToText })
            .width(80)
            .type(InputType.Number)
            .onChange((value: string) => { this.yearToText = value; this.load(true); })
        }
        .width('100%')

        Row({ space: 8 }) {
          Select(this.issuerSelectItems())
            .id('cert_issuer_select')
            .width(0)
            .selected(this.issuerIndex)
            .layoutWeight(1)
            .onSelect((index: number) => {
              this.issuerIndex = index;
              this.issuer = index === 0 ? '' : this.issuerOptions[index - 1];
              this.load(true);
            })
          TextInput({ placeholder: '颁发单位筛选', text: this.issuer })
            .id('cert_issuer_input')
            .width(0)
            .layoutWeight(1)
            .borderRadius(18)
            .onChange((value: string) => {
              this.issuer = value;
              this.issuerIndex = 0;
              this.load(true);
            })
        }
        .width('100%')
        .accessibilityText('按颁发单位筛选荣誉证书')

        Row() {
          Text(`共 ${this.total} 条记录，已加载 ${this.certs.length} 条`).fontSize(12).fontColor($r('app.color.text_secondary'))
          Blank()
          Button('导出CSV').fontSize(12).borderRadius(16)
            .backgroundColor($r('app.color.accent_peach_soft'))
            .fontColor($r('app.color.text_primary')).onClick(() => this.exportCsv())
        }
        .width('100%')

        if (this.certs.length === 0) {
          EmptyState({ text: '暂无证书记录，点击“新增”开始录入' })
        } else {
          List({ space: 8 }) {
            ForEach(this.certs, (cert: HonorCertificate) => {
              ListItem() {
                CertificateCard({
                  cert: cert,
                  imageBasePath: this.context.filesDir,
                  onOpen: () => {
                    if (cert.imagePath.length > 0) {
                      this.previewUrl = FileHelper.thumbnailPath(this.context, cert.imagePath);
                    } else {
                      promptAction.showToast({ message: '该记录暂无图片' });
                    }
                  },
                  onEdit: () => this.edit(cert),
                  onDelete: () => this.remove(cert)
                })
              }
            }, (cert: HonorCertificate) => String(cert.id))
            ListItem() {
              Row() {
                if (this.loadingMore) {
                  LoadingProgress().width(18).height(18).color($r('app.color.brand_primary'))
                  Text('加载中…').fontSize(12).fontColor($r('app.color.text_secondary')).margin({ left: 6 })
                } else if (this.hasMore) {
                  Text('上拉加载更多').fontSize(12).fontColor($r('app.color.text_secondary'))
                } else {
                  Text(`已加载全部 ${this.total} 条`).fontSize(12).fontColor($r('app.color.text_tertiary'))
                }
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding(10)
            }
          }
          .layoutWeight(1)
          .width('100%')
          .onReachEnd(() => this.loadMore())
        }
      }
      .width('100%')
      .height('100%')
      .padding(20)
      .linearGradient({ angle: 165, colors: [[$r('app.color.app_background'), 0], [$r('app.color.app_background_end'), 1]] })

      if (this.previewUrl.length > 0) {
        Column() {
          Image(this.previewUrl)
            .width('90%')
            .height('70%')
            .objectFit(ImageFit.Contain)
            .backgroundColor($r('app.color.card_background'))
          Button('关闭').margin({ top: 20 }).onClick(() => { this.previewUrl = ''; })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.overlay'))
        .onClick(() => { this.previewUrl = ''; })
      }
    }
    .width('100%')
    .height('100%')
  }
}
