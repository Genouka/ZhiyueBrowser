// SPDX-License-Identifier: AGPL-3.0-only WITH limits-notice
// Copyright by 秋冥散雨_GenOuka
import {
  ArcList, ArcListItem, display, router
} from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { Favourite, store } from '../entry/Favourite';
import { preferences, relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { audio } from '@kit.AudioKit';
import { History, storeH } from '../entry/History';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { i18n } from '@kit.LocalizationKit';

const DOMAIN = 0x0000;
const TAG = '[INDEX]';
let audioManager = audio.getAudioManager();
let audioVolumeManager = audioManager.getVolumeManager();
let mediaVolumeMin = 0;
let mediaVolumeMax = 15;
let dataPreferences: preferences.Preferences | null = null;

@CustomDialog
struct qrDialog {
  controller: CustomDialogController;
  @Link text: string;

  build() {
    Column() {
      Text($r("app.string.Share"))
      QRCode(this.text).margin(10)
    }.justifyContent(FlexAlign.Center)
  }
}
//i18n.System.setAppPreferredLanguage("zh")//Test Only
console.log('LLLLL:'+i18n.System.getSystemLanguage())
let useEnglish = !i18n.System.getAppPreferredLanguage().startsWith('zh');
let agreeEula = false;
try {
  let options: preferences.Options = { name: 'myStore' };
  dataPreferences = preferences.getPreferencesSync(getContext(), options);
  agreeEula = dataPreferences.getSync('agreeEula', '0') === '1';
} catch (error) {
  hilog.error(0x0000, '[Index]', `dataPreferences Create Error: ${error}`)
}
@Entry
@Component
struct Index {
  @State allowJumpAppUser: boolean = false;
  @State volume: number = 100;
  @State mDarkmodeWeb: WebDarkMode = WebDarkMode.Auto;
  @State mForceDarkmodeWeb: boolean = false;
  @State zoomValueUser: number = 1;
  @State crownZoomUser: boolean = false;
  @State isMenuOpen: boolean = false;
  @State menuOffset: number = -100;
  @State initedWeb: boolean = false;
  @State initedWebOnce: boolean = false;
  @State topPaddingWeb: boolean = false;
  @State addPaddingWeb: boolean = false;
  @State metaViewportWeb: boolean = true;
  @State isStared: boolean = false;
  listVScroller: Scroller = new Scroller();
  liteHScroller: Scroller = new Scroller();
  webviewController: webview.WebviewController = new webview.WebviewController();
  @State qr_text: string = this.initedWeb ? this.webviewController.getUrl() : '';
  qrdialogController: CustomDialogController = new CustomDialogController({
    builder: qrDialog({
      text: this.qr_text
    }),
  })
  favourite = new Favourite(this.getUIContext().getHostContext());
  history = new History(this.getUIContext().getHostContext());
  hasHideOnce = false;

  getScrH(): number {
    return display.getDefaultDisplaySync().availableHeight
  }

  async aboutToAppear() {
    await this.favourite.initOrMerge();
    await this.history.initOrMerge();
    mediaVolumeMin = await audioManager.getMinVolume(audio.AudioVolumeType.MEDIA)
    mediaVolumeMax = await audioManager.getMaxVolume(audio.AudioVolumeType.MEDIA)
    try {
      audioVolumeManager.on('volumeChange', (e) => {
        if (e.volumeType == audio.AudioVolumeType.MEDIA) {
          this.volume = e.volume
          hilog.info(0x0000, '[Index]', `audio.AudioVolumeType.MEDIA volume=${e.volume}`)
        }
      })
      this.volume = await audioManager.getVolume(audio.AudioVolumeType.MEDIA)
    } catch (error) {
      hilog.error(0x0000, '[Index]', `Audio Hook Error: ${error}`)
    }

  }

  onPageShow(): void {
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>; // 获取传递过来的参数对象
    if (params) {
      const info: string = params.info as string; // 获取info属性的值
      try {
        this.webviewController.loadUrl(info)
      } catch (error) {
        // TODO: Implement error handling.
      }
    } else {
      if (this.hasHideOnce) {
        this.isMenuOpen = true;
        this.menuOffset = 0
        this.listVScroller.scrollTo({ xOffset: 0, yOffset: 0 })
      }
    }
    if (this.initedWeb) {
      this.starOp()
    }
  }

  onPageHide(): void {
    this.hasHideOnce = true
  }

  build() {
    Stack() {
      Column() {
        Button({ type: ButtonType.Capsule }) {
          SymbolGlyph($r('sys.symbol.menubar_rectangle'))
            .fontColor(['#ffffff'])
            .fontSize(12)
        }
        .width('100%')
        .height(this.getScrH() * 0.141 + 'px')
        .margin(0)
        .position({})
        .onClick((e) => {
          this.isMenuOpen = !this.isMenuOpen
        })
      }.width('100%').height('100%')

      // Web视图
      Web({ src: useEnglish?
        (agreeEula?$rawfile('homepage_en.html'):$rawfile('privacy_en.html')):
        (agreeEula?$rawfile('homepage.html'):$rawfile('privacy.html')),
        controller: this.webviewController })
        .focusable(true)
        .focusOnTouch(true)
        .defaultFocus(true)
        .groupDefaultFocus(true)
        .darkMode(this.mDarkmodeWeb)
        .forceDarkAccess(this.mForceDarkmodeWeb)
        .javaScriptProxy({
          object: {
            about: () => {
              this.getUIContext().getRouter().pushUrl({
                url: 'pages/About' // 目标url
              }, router.RouterMode.Standard, (err) => {
                if (err) {
                  hilog.error(0x0000, 'Router',
                    `Invoke pushUrl failed, code is ${err.code}, message is ${err.message}`);
                  return;
                }
                hilog.info(0x0000, 'Router', 'Invoke pushUrl succeeded.');
              });
            },
            agreeEula: () => {
              agreeEula = true;
              try {
                if(dataPreferences==null)
                  dataPreferences = preferences.getPreferencesSync(getContext(), { name: 'myStore' });
                  dataPreferences.putSync('agreeEula', '1');
                  dataPreferences.flushSync();
                this.webviewController.loadUrl(useEnglish?
                  (agreeEula?$rawfile('homepage_en.html'):$rawfile('privacy_en.html')):
                  (agreeEula?$rawfile('homepage.html'):$rawfile('privacy.html')))
              } catch (error) {
                hilog.error(0x0000, '[Index]', `dataPreferences Create Error: ${error}`)
              }

            },
            close: () => {
              let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
              context.terminateSelf();
            }
          },
          name: 'ZhiyueBrowser',
          methodList: ['about','agreeEula','close'],
          controller: this.webviewController
        })
        .onDigitalCrown((e: CrownEvent) => {
          if (this.crownZoomUser) {
            this.zoomValueUser = Math.max(0.01, Math.min(this.zoomValueUser - Math.floor(e.degree * 100) / 100, 2))
          } else {
            try {
              this.webviewController.scrollBy(0, -e.degree)
            } catch (error) {
              console.error('scrollByError', error)
            }
          }
        })
        .margin((() => {
          if (this.topPaddingWeb) {
            return {
              top: this.getScrH() * 0.141 + 'px'
            }
          }
          return this.addPaddingWeb ?
            this.getScrH() * 0.141 + 'px' :
            null
        })())
        .id('webView')
        .domStorageAccess(true)
        .metaViewport(this.metaViewportWeb)
        .onPageBegin((event) => {
          this.initedWeb = false;
        })
        .onAlert((event) => {
          if (event) {
            console.info('event.url:' + event.url);
            console.info('event.message:' + event.message);
            this.getUIContext().showAlertDialog({
              title: '来自网页 \"' + event.url + '\" 的提示',
              message: event.message,
              confirm: {
                value: '确认',
                action: () => {
                  console.info('Alert confirmed.');
                  event.result.handleConfirm();
                }
              },
              cancel: () => {
                event.result.handleCancel();
              }
            })
          }
          return true;
        })
        .onConfirm((event) => {
          if (event) {
            console.info('event.url:' + event.url);
            console.info('event.message:' + event.message);
            this.getUIContext().showAlertDialog({
              title: '来自网页 \"' + event.url + '\" 的提示',
              message: event.message,
              primaryButton: {
                value: '取消',
                action: () => {
                  event.result.handleCancel();
                }
              },
              secondaryButton: {
                value: '确认',
                action: () => {
                  event.result.handleConfirm();
                }
              },
              cancel: () => {
                event.result.handleCancel();
              }
            })
          }
          return true;
        })
        .onOverrideUrlLoading((r) => {
          let lurl = r.getRequestUrl().toLowerCase()
          if (lurl.startsWith('data:') ||
          lurl.startsWith('file:') ||
          lurl.startsWith('view-source:') ||
          lurl.startsWith('resource:') ||
          lurl.startsWith('http://') ||
          lurl.startsWith('https://')) {
            return false
          }
          if (this.allowJumpAppUser) {
            (this.getUIContext().getHostContext() as common.UIAbilityContext).openLink(r.getRequestUrl())
              .then(() => {
                hilog.info(DOMAIN, TAG, 'openLink success.');
              }).catch((err: BusinessError) => {
              hilog.error(DOMAIN, TAG, `openLink failed, err: ${JSON.stringify(err)}.`);
            });
            return true
          }
          return true
        })
        .onPageEnd((event) => {
          console.info('Page finished loading');
          if (!this.initedWeb) {
            this.webviewController.setCustomUserAgent('Mozilla/5.0 (Linux; Android 16; M040 Build/JOP40D) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36')
          }
          this.initedWeb = true;
          this.starOp()
          this.historyOp()
          setTimeout(() => {
            this.initedWebOnce = true;
          }, 200)
        })
        .onErrorReceive((event) => {
          console.error('Error loading page:', event.error);
        })

      if (!this.initedWebOnce) {
        Text($r("app.string.Loading"))
          .backgroundColor('#000000')
          .align(Alignment.Center)
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.asymmetric(
            undefined,
            TransitionEffect.OPACITY.animation({ duration: 1500, curve: Curve.EaseOut })))
      }
      // 上滑菜单
      ArcList({
        initialIndex: 1,
        scroller: this.listVScroller
      }) {
        ArcListItem() {
          Row() {
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.chevron_left'))
                .fontColor(['#ffffff'])
                .fontSize(22)
            }
            .width(40)
            .height(40)
            .enabled(this.initedWeb && this.webviewController.accessBackward())
            .onClick(() => {
              // 后退逻辑
              if (this.webviewController.accessBackward()) {
                this.webviewController.backward();
                this.starOp();
              }
            })

            Column() {
              if (!this.addPaddingWeb) {
                Row() {
                  Text($r("app.string.UpPadding"))
                  Toggle({ type: ToggleType.Switch, isOn: false })
                    .onChange((e) => {
                      this.topPaddingWeb = e
                    })
                }
              }

              if (!this.topPaddingWeb) {
                Row() {
                  Text($r("app.string.AllPadding"))
                  Toggle({ type: ToggleType.Switch, isOn: false })
                    .onChange((e) => {
                      this.addPaddingWeb = e
                    })
                }
              }
            }

            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontColor(['#ffffff'])
                .fontSize(22)
            }
            .width(40)
            .height(40)
            .enabled(this.initedWeb && this.webviewController.accessForward())
            .onClick(() => {
              // 前进逻辑
              if (this.webviewController.accessForward()) {
                this.webviewController.forward();
                this.starOp();
              }
            })
          }
          .justifyContent(FlexAlign.Center)
        }.margin({ top: 30, left: 30, right: 30 })

        ArcListItem() {
          Row() {
            Search({
              value: this.initedWeb ?
                (
                  () => {
                    let url = this.webviewController.getUrl()
                    const preSearchUrl = 'https://cn.bing.com/search?q='
                    if (url.startsWith(preSearchUrl)) {
                      url = url.substring(preSearchUrl.length)
                      let index = url.indexOf('&')
                      if (index > -1) {
                        url = url.substring(0, index)
                      }
                      url = decodeURI(url)
                      return url
                    }
                    if (url.startsWith('resource:')) {
                      return ''
                    }
                    return url
                  }
                )() :
                ''
            })
              .searchButton($r("app.string.searchButton"))
              .onSubmit((text) => {
                if (this.initedWeb) {
                  if (text.startsWith('data:') || (text.includes('.') || text.includes(':')) && !text.includes(' ')) {
                    this.webviewController.loadUrl(text);
                  } else {
                    this.webviewController.loadUrl('https://bing.com/?q=' + text);
                  }
                }
                this.isMenuOpen = false
              })
            // TextInput({ text: this.initedWeb ? this.webviewController.getUrl() : '' })
            //   .width('80%')
            // Button({ type: ButtonType.Circle }) {
            //   SymbolGlyph($r('sys.symbol.magnifyingglass'))
            //     .fontColor(['#ffffff'])
            //     .fontSize(22)
            //     .alignSelf(ItemAlign.Center)
            // }
            // .width('20%')
            // .padding(8)
            // .onClick(() => {
            //   // 搜索逻辑
            //   if (this.initedWeb) {
            //     this.webviewController.loadUrl(this.webviewController.getUrl());
            //   }
            // })
          }
          .width('100%')
        }.padding({ top: -10, bottom: -20 })

        ArcListItem() {
          Row() {
            Scroll(this.liteHScroller) {
              //收藏
              Row() {
                Button({ type: ButtonType.Circle }) {
                  SymbolGlyph(this.isStared ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
                    .fontColor(['#ffffff'])
                    .fontSize(24)
                }
                .width(40)
                .height(40)
                .margin(10)
                .onClick((e) => {
                  this.starOp(true, true);
                })

                // 添加主页的图标按钮
                Button({ type: ButtonType.Circle }) {
                  SymbolGlyph($r('sys.symbol.house'))
                    .fontColor(['#ffffff'])
                    .fontSize(24)
                }
                .width(40)
                .height(40)
                .margin(4)
                .onClick((e) => {
                  this.webviewController.loadUrl($rawfile('homepage.html'))
                  this.isMenuOpen = false
                })

                // 添加刷新的图标按钮
                Button({ type: ButtonType.Circle }) {
                  SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                    .fontColor(['#ffffff'])
                    .fontSize(24)
                }
                .width(40)
                .height(40)
                .margin(4)
                .onClick(() => {
                  this.webviewController.refresh();
                })

                // 添加分享的图标按钮
                Button({ type: ButtonType.Circle }) {
                  SymbolGlyph($r('sys.symbol.share'))
                    .fontColor(['#ffffff'])
                    .fontSize(24)
                }
                .width(40)
                .height(40)
                .margin(4)
                .onClick((e) => {
                  this.qrdialogController.open()
                })

                // 添加设置的图标按钮
                // Button({ type: ButtonType.Circle }) {
                //   SymbolGlyph($r('sys.symbol.gearshape'))
                //     .fontColor(['#ffffff'])
                //     .fontSize(24)
                // }
                // .width(40)
                // .height(40)
                // .margin(4)
                // .onClick((e) => {
                //   this.webviewController.clearHistory();
                //   this.webviewController.refresh();
                // })
              }
            }.scrollable(ScrollDirection.Horizontal)
          }
        }.width('100%')

        ArcListItem() {
          Column() {
            // Row() {
            //   Text('桌面版式')
            //
            // }
            Row() {
              Toggle({ type: ToggleType.Button, isOn: false }) {
                Text($r("app.string.WideViewport")).fontSize(14)
              }
              .onChange((e) => {
                this.metaViewportWeb = !e
              })

              Toggle({ type: ToggleType.Button, isOn: false }) {
                Text($r("app.string.PcUA")).fontSize(14)
              }
              .onChange((e) => {
                try {
                  if (e) {
                    this.webviewController.setCustomUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36')
                  } else {
                    this.webviewController.setCustomUserAgent('Mozilla/5.0 (Linux; Android 16; M040 Build/JOP40D) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36')
                  }
                  this.webviewController.refresh()
                } catch (error) {
                }
              })
            }

            Row() {
              Toggle({ type: ToggleType.Button, isOn: false }) {
                Text($r("app.string.AllowOpenDeepLink")).fontSize(14)
              }
              .onChange((e) => {
                this.allowJumpAppUser = e
              })
            }

            Row() {
              Toggle({ type: ToggleType.Button, isOn: false }) {
                Text($r("app.string.SmartFollowBan")).fontSize(14)
              }
              .onChange((e) => {
                try {
                  this.webviewController.enableIntelligentTrackingPrevention(e);
                  console.info('enableIntelligentTrackingPrevention: ' + e);
                } catch (error) {
                  console.error(
                    `ErrorCode: ${(error as BusinessError).code},  Message: ${(error as BusinessError).message}`);
                }
              })

            }

            Row() {
              Toggle({ type: ToggleType.Button, isOn: false }) {
                Text($r("app.string.Dark")).fontSize(14)
              }
              .onChange((e) => {
                try {
                  this.mDarkmodeWeb = e ? WebDarkMode.On : WebDarkMode.Off
                  this.webviewController.refresh()
                } catch (error) {
                }
              })

              if (this.mDarkmodeWeb === WebDarkMode.On) {
                Toggle({ type: ToggleType.Button, isOn: false }) {
                  Text($r("app.string.ForceDark")).fontSize(14)
                }
                .onChange((e) => {
                  try {
                    this.mForceDarkmodeWeb = e;
                    this.webviewController.refresh()
                  } catch (error) {
                  }
                })
              }
            }
          }
        }

        ArcListItem() {
          Row() {
            Button($r("app.string.EnteringStar")).fontSize(16).margin({right:10}).onClick((e) => {
              this.getUIContext().getRouter().pushUrl({
                url: 'pages/Star' // 目标url
              }, router.RouterMode.Standard, (err) => {
                if (err) {
                  hilog.error(0x0000, 'Router',
                    `Invoke pushUrl failed, code is ${err.code}, message is ${err.message}`);
                  return;
                }
                hilog.info(0x0000, 'Router', 'Invoke pushUrl succeeded.');
              });
            })
            Button($r("app.string.EnteringHistory")).fontSize(16).onClick((e) => {
              this.getUIContext().getRouter().pushUrl({
                url: 'pages/History' // 目标url
              }, router.RouterMode.Standard, (err) => {
                if (err) {
                  hilog.error(0x0000, 'Router',
                    `Invoke pushUrl failed, code is ${err.code}, message is ${err.message}`);
                  return;
                }
                hilog.info(0x0000, 'Router', 'Invoke pushUrl succeeded.');
              });
            })
          }
        }.margin(10)

        ArcListItem() {
          Column() {
            Row() {
              Text($r("app.string.WebScale"))
              Toggle({ type: ToggleType.Button, isOn: this.crownZoomUser }) {
                Text($r("app.string.WebScaleByCrown")).fontSize(12)
              }
              .onChange((e) => {
                this.crownZoomUser = e
              })
            }

            Row() {
              Slider({
                value: this.zoomValueUser,
                min: 0.01,
                max: 2,
                step: 0.01,
                style: SliderStyle.InSet
              })
                .showTips(true, Math.floor(this.zoomValueUser * 100) + '%')
                .onChange((value, mode) => {
                  this.zoomValueUser = value
                  this.webviewController.runJavaScript('document.body.style.zoom=' + value + ';')
                })
                .width('70%')
              Button({ type: ButtonType.Circle }) {
                SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                  .fontColor(['#ffffff'])
                  .fontSize(16)
              }
              .padding(8)
              .width('30%')
              .onClick((e) => {
                this.zoomValueUser = 0;
                this.zoomValueUser = 1;
                this.webviewController.runJavaScript('document.body.style.zoom=1;')
              })
            }
          }
        }

        ArcListItem() {
          Column() {
            Text($r("app.string.MediaVolumn"))
            Slider({
              value: this.volume,
              min: mediaVolumeMin,
              max: mediaVolumeMax,
              step: 1,
              style: SliderStyle.InSet
            })
              .showTips(true, this.volume + ' ')
              .onChange((value, mode) => {
                //this.volume = value
                audioManager.setVolume(audio.AudioVolumeType.MEDIA, value, (err) => {
                  if (err) {
                    hilog.error(0x0000, 'VMediaV',
                      `Invoke volumn failed, code is ${err.code}, message is ${err.message}`);
                  }
                })
              })
              .width('80%')
          }
        }

        ArcListItem() {
          Column() {
            Button($r("app.string.About")).fontSize(20).margin(10).onClick((e) => {
              this.getUIContext().getRouter().pushUrl({
                url: 'pages/About' // 目标url
              }, router.RouterMode.Standard, (err) => {
                if (err) {
                  hilog.error(0x0000, 'Router',
                    `Invoke pushUrl failed, code is ${err.code}, message is ${err.message}`);
                  return;
                }
                hilog.info(0x0000, 'Router', 'Invoke pushUrl succeeded.');
              });
            })
            Button($r("app.string.DrawPrivacy")).fontSize(20).margin(10).onClick((e) => {
              try {
                if(dataPreferences==null)
                  dataPreferences = preferences.getPreferencesSync(getContext(), { name: 'myStore' });
                dataPreferences.putSync('agreeEula', '0');
                dataPreferences.flushSync();
              } catch (error) {
                hilog.error(0x0000, '[Index]', `dataPreferences Create Error: ${error}`)
              }
              let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
              context.terminateSelf();
            })
            Button($r("app.string.Language")).fontSize(20).margin(10).onClick((e) => {
              try {
                i18n.System.setAppPreferredLanguage(useEnglish?"zh":"en")
                useEnglish=!useEnglish
                this.webviewController.loadUrl(useEnglish?
                  (agreeEula?$rawfile('homepage_en.html'):$rawfile('privacy_en.html')):
                  (agreeEula?$rawfile('homepage.html'):$rawfile('privacy.html')))
              } catch (error) {
                hilog.error(0x0000, '[Index]', `setAppPreferredLanguage Error: ${error}`)
              }
            })
            Text($r("app.string.ClickCloseMenu"))
          }
        }.width('100%').margin({ bottom: 60 })

        // ArcListItem() {
        //
        // }.width('100%').margin({ bottom: 60 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 10, right: 10 })
      .background('#ee111111')
      .shadow(ShadowStyle.OUTER_DEFAULT_MD)
      .position({ y: this.isMenuOpen ? this.menuOffset + '%' : '-100%' })
      .animation({ duration: 300, curve: Curve.EaseOut })
      .onClick((event: ClickEvent) => {
        this.isMenuOpen = false
      })
    }
    .parallelGesture(
      PanGesture({
        fingers: 1,
        direction: PanDirection.Down,
        distance: 120,
      })
        .onActionStart((Event: GestureEvent) => {
          if(!agreeEula) return;
          if (!this.isMenuOpen) {
            this.listVScroller.scrollTo({
              xOffset: 0,
              yOffset: 0,
            })
          }
          if (this.webviewController.getScrollOffset().y < 50) {
            this.isMenuOpen = true
          }
        })
        .onActionUpdate((event: GestureEvent) => {
          this.menuOffset =
            Math.floor((Math.max(0, Math.min(event.offsetY + 160, this.getScrH()))) * 100.0 / this.getScrH()) - 100
        })
        .onActionEnd((event: GestureEvent) => {
          if (Number(this.menuOffset) > -50) {
            this.menuOffset = 0;
          } else {
            this.isMenuOpen = false
          }
        })
    )
    .parallelGesture(
      PanGesture({
        fingers: 1,
        direction: PanDirection.Up,
        distance: 20,
      })
        .onActionEnd((event: GestureEvent) => {
          if (this.listVScroller.isAtEnd()) {
            this.isMenuOpen = false;
          }
        })
    )
    .height('100%')
    .width('100%')
  }

  private starOp(insert: boolean = false, remove: boolean = false, icon: boolean = true,
    url_override: string | undefined = undefined, title_override: string | undefined = undefined) {
    let predicates2 = new relationalStore.RdbPredicates(this.favourite.tableName);
    let url = url_override || this.webviewController.getOriginalUrl();
    let title = title_override || this.webviewController.getTitle();
    predicates2.equalTo('URL', url);
    store?.query(predicates2, (err, data) => {
      if (err) {
        hilog.error(0x0000, 'rdbDataPersistence',
          `Failed to query data. Code:${err.code}, message:${err.message}`);
        return;
      }
      if (!data.goToNextRow()) {
        //没有
        data.close();
        if (insert) {
          hilog.info(0x0000, 'rdbDataPersistence', 'insert new star');
          store?.insert(this.favourite.tableName, {
            URL: url,
            TITLE: title
          }).then(() => {
            if (icon) {
              this.isStared = true;
            }
          }).catch((err1: BusinessError) => {
            hilog.error(0x0000, 'rdbDataPersistence',
              `Failed to insert data. Code:${err1.code}, message:${err1.message}`);
          });
        } else {
          if (icon) {
            this.isStared = false;
          }
        }
      } else {
        // 有
        data.close();
        if (remove) {
          hilog.info(0x0000, 'rdbDataPersistence', 'remove star');
          store?.delete(predicates2).then(() => {
            if (icon) {
              this.isStared = false;
            }
          }).catch((err1: BusinessError) => {
            hilog.error(0x0000, 'rdbDataPersistence',
              `Failed to delete data. Code:${err1.code}, message:${err1.message}`);
          });
        } else {
          if (icon) {
            this.isStared = true;
          }
        }
        hilog.info(0x0000, 'rdbDataPersistence', 'insert new star not happened');
      }

    });
  }

  private historyOp() {
    let predicates2 = new relationalStore.RdbPredicates(this.history.tableName);
    let url = this.webviewController.getOriginalUrl();
    let title = this.webviewController.getTitle();
    hilog.info(0x0000, 'historyOp',
      `url: ${url}, title: ${title}, hN: ${this.history.tableName}`);
    predicates2.equalTo('URL', url);
    storeH?.query(predicates2, (err, data) => {
      if (err) {
        hilog.error(0x0000, 'rdbDataPersistence',
          `Failed to query history data. Code:${err.code}, message:${err.message}`);
        return;
      }
      if (!data.goToNextRow()) {
        data.close();
        hilog.info(0x0000, 'rdbDataPersistence', 'insert new history');
        storeH?.insert(this.history.tableName, {
          URL: url,
          TITLE: title
        }).catch((err1: BusinessError) => {
          hilog.error(0x0000, 'rdbDataPersistence',
            `Failed to insert history data. Code:${err1.code}, message:${err1.message}`);
        });
      }
    })
  }
}