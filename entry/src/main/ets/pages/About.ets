// SPDX-License-Identifier: AGPL-3.0-only WITH limits-notice
// Copyright by 秋冥散雨_GenOuka
import { ArcList, ArcListItem } from '@ohos.arkui.ArcList';
import { bundleManager } from '@kit.AbilityKit';

@Entry
@Component
struct Volume {
  @State version: string = '';
  async aboutToAppear() {
    bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).then((bundleInfo)=>{
      this.version = bundleInfo.versionName;//App version name
      //let versionNo = bundleInfo.versionCode;//App version code
    }).catch((error: BusinessError )=>{
      console.error("get bundleInfo failed,error is "+error)
    })
  }
  build() {
    ArcList(){
      ArcListItem(){
        Column(){
          Image($r('app.media.foreground'))
            .width(100)
            .height(100)
          Text($r('app.string.app_name'))
            .fontSize(20)
          Text(this.version)
        }
      }
      ArcListItem(){
        Column(){
          Text($r("app.string.ByGenouka"))
        }.margin(15)
      }
      ArcListItem(){
        Column(){
          Text($r("app.string.Thanks"))
        }.margin(15)
      }
      ArcListItem(){
        Column(){
          Text($r("app.string.Bilibili"))
          QRCode('https://space.bilibili.com/3493116076100126')
            .width(100)
            .height(100)
        }
      }
      ArcListItem(){
        Column(){
          Text($r("app.string.QQGroup"))
          QRCode('https://qm.qq.com/q/j0ryXtvxDO')
            .width(100)
            .height(100)
        }
      }
    }
  }
}