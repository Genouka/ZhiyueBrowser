// SPDX-License-Identifier: AGPL-3.0-only WITH limits-notice
// Copyright by 秋冥散雨_GenOuka
import {
  ArcAlphabetIndexer,
  ArcList,
  ArcListItem,
  BorderRadiusMode,
  ComponentContent,
  LengthMetrics
} from '@kit.ArkUI';
import { BasicDataSource, LinkItem } from '../entry/BaseDataSource';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { store } from '../entry/Favourite';
import { relationalStore } from '@kit.ArkData';

const TAG = '[Star]';
const DOMAIN = 0xF811;

class InitialDataSource extends BasicDataSource {
  private dataArray: LinkItem[] = [];

  public totalCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): LinkItem {
    return this.dataArray[index];
  }

  public indexOf(item: LinkItem): number {
    return this.dataArray.indexOf(item);
  }

  public removeData(data: LinkItem): void {
    let predicates2 = new relationalStore.RdbPredicates('FAVOURITE');
    predicates2.equalTo('ID', data.id)
    store?.delete(predicates2, (err) => {
      if (err) {
        hilog.error(DOMAIN, TAG,
          `Failed to remove data. Code:${err.code}, message:${err.message}`);
        return;
      }
      let index = this.dataArray.indexOf(data);
      this.dataArray.splice(index, 1);
      this.notifyDataDelete(index);
    })
  }

  // public pushData(data: LinkItem): void {
  //   this.dataArray.push(data);
  //   this.notifyDataAdd(this.dataArray.length - 1);
  // }

  public initAllData(callback: CallableFunction | undefined = undefined): void {
    // TODO: Add offset+limit data support
    let predicates2 = new relationalStore.RdbPredicates('FAVOURITE');
    //predicates2.offsetAs()
    //predicates2.limitAs(100)
    store?.query(predicates2, (err, data) => {
      if (err) {
        hilog.error(DOMAIN, TAG,
          `Failed to query data. Code:${err.code}, message:${err.message}`);
        return;
      }
      try {
        while (data.goToNextRow()) {
          let item: LinkItem = {
            id: data.getLong(data.getColumnIndex('ID')),
            url: data.getString(data.getColumnIndex('URL')),
            title: data.getString(data.getColumnIndex('TITLE'))
          };
          this.dataArray.push(item);
        }
        data.close()
      } catch (error) {
        hilog.error(DOMAIN, TAG,
          `Query data error. Code:${error}`);
      }
      this.notifyDataReload();
      if (callback) {
        callback()
      }

    })
  }
}

@Builder
function starHeader() {
  Column() {
    Text($r("app.string.Star"))
      .fontColor('#FFFFFFFF')
      .fontSize('19fp')
  }
}

@Entry
@Component
struct Star {
  @State empty: boolean = true;
  data: InitialDataSource = new InitialDataSource();
  arcListScroller: Scroller = new Scroller();
  indexerIndex: number = 0;
  context: UIContext = this.getUIContext();
  starHeader: ComponentContent<Object> = new ComponentContent(this.context, wrapBuilder(starHeader));

  aboutToAppear(): void {
    this.data.initAllData(() => {
      if (this.data.totalCount() == 0) {
        this.empty = true;
      } else {
        this.empty = false;
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.End }) {
      if(this.empty){
        Text($r("app.string.EmptyStar"))
          .align(Alignment.Center)
          .width('100%')
          .height('100%')
          .padding(30)
          .onClick(()=>{
            this.getUIContext().getRouter().back();
          })
      }else {
        ArcList({ initialIndex: 0, header: this.starHeader, scroller: this.arcListScroller }) {
          LazyForEach(this.data, (item: LinkItem) => {
            ArcListItem() {
              Column() {
                Text(item.title)
                  .fontSize(20)
                  .maxLines(1)
                  .textOverflow({
                    overflow: TextOverflow.MARQUEE
                  })
                  .onAppear(() => {
                    //hilog.info(DOMAIN, TAG, `appear t: ${item}`);
                  })
                Text(item.url)
                  .fontSize(12)
                  .maxLines(1)
                  .textOverflow({
                    overflow: TextOverflow.Ellipsis
                  })
                  .onAppear(() => {
                    //hilog.info(DOMAIN, TAG, `appear u: ${item}`);
                  })
              }.margin({
                left: 10,
                right: 10
              })
            }
            .borderRadius('65px')
            .width('414px')
            .height('129px')
            .backgroundColor('#26FFFFFF')
            .onClick((e) => {
              this.getUIContext().getRouter().back({
                url: 'pages/Index',
                params: {
                  info: item.url
                }
              });
            })
            .swipeAction({
              end: {
                // index为该ArcListItem在ArcList中的索引值。
                builder: () => {
                  this.itemEnd(item);
                },
              }
            })

          }, (item: string) => item)
        }
        .cachedCount(3)
        .space(LengthMetrics.px(10))
        // 设置弧形列表支持获焦
        .focusable(true)
        // 设置弧形列表支持点击获焦
        .focusOnTouch(true)
        // 设置弧形列表为所在页面上的默认焦点
        .defaultFocus(true)
      }
    }
  }

  @Builder
  itemEnd(item: LinkItem) {
    // 构建尾端滑出组件
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.trash'))
        .fontColor(['#ff0000'])
        .fontSize(24)
    }
    .width(40)
    .height(40)
    .margin(10)
    .backgroundColor(Color.Black)
    .onClick(() => {
      this.getUIContext()?.animateTo({
        duration: 1000,
        curve: Curve.Smooth,
        iterations: 1,
        playMode: PlayMode.Normal,
      }, () => {
        // this.contacts为列表数据源，可根据实际场景构造，indexOf方法可获取将被删除数据在数据源中的索引
        if (this.data.totalCount() <= 1) {
          //FIXME:可能失败
          this.empty = true;
        } else {
          this.empty = false;
        }
        this.data.removeData(item);
      })
    })
  }
}