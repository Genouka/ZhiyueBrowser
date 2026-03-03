// SPDX-License-Identifier: AGPL-3.0-only WITH limits-notice
// Copyright by 秋冥散雨_GenOuka
import { relationalStore } from '@kit.ArkData'; // 导入模块
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0033;

export let store: relationalStore.RdbStore | undefined = undefined;

let tokenType = relationalStore.Tokenizer.ICU_TOKENIZER;
let tokenTypeSupported = relationalStore.isTokenizerSupported(tokenType);
if (!tokenTypeSupported) {
  tokenType = relationalStore.Tokenizer.NONE_TOKENIZER;
  hilog.error(DOMAIN, 'rdbDataPersistence', `ICU_TOKENIZER is not supported on this platform.`);
}
const STORE_CONFIG: relationalStore.StoreConfig = {
  // 数据库文件名
  name: 'Favourite.db',
  // 数据库安全级别
  securityLevel: relationalStore.SecurityLevel.S3,
  // 可选参数，指定数据库是否加密，默认不加密
  encrypt: false,
  // 可选参数，数据库自定义路径。默认在本应用沙箱目录下创建RdbStore实例。
  customDir: 'data/entries',
  // 可选参数，指定数据库是否以只读方式打开。默认为false，表示数据库可读可写。为true时，只允许从数据库读取数据，不允许对数据库进行写操作，否则会返回错误码801。
  isReadOnly: false,
  // 可选参数，指定用户在全文搜索场景(FTS)下使用哪种分词器。默认在FTS下仅支持英文分词，不支持其他语言分词。
  tokenizer: tokenType,
};

export class Favourite {
  context: Context;
  tableName: string = 'FAVOURITE';

  constructor(context: Context | undefined,tableName: string|undefined = undefined) {
    if (context === undefined) {
      throw Error();
    }
    this.context = context;
    if(tableName) this.tableName = tableName;
  }

  async initOrMerge() {
    const SQL_CREATE_TABLE =
      'CREATE TABLE IF NOT EXISTS FAVOURITE (ID INTEGER PRIMARY KEY AUTOINCREMENT,URL TEXT NOT NULL,TITLE TEXT)';
    if (store === undefined) {
      try {
        store = await relationalStore.getRdbStore(this.context, STORE_CONFIG);
      } catch (e) {
        const err = e as BusinessError;
        hilog.error(DOMAIN, 'rdbDataPersistence', `Failed to get RdbStore. Code:${err.code}, message:${err.message}`);
        return
      }
    }
    hilog.info(DOMAIN, 'rdbDataPersistence', 'Succeeded in getting RdbStore.');
    if (store !== undefined) {
      let transaction = await store.createTransaction({});
      let storeVersion = await transaction.execute('PRAGMA user_version');;
      // 示例应用升级流程较短，所以使用单个事务。如果实际业务中升级逻辑较多，建议拆分多个独立事务串行执行。
      if (storeVersion === 0) {
        try {
          await transaction.execute(SQL_CREATE_TABLE); // 创建数据表，以便后续调用insert接口插入数据
          storeVersion = 1;
          hilog.info(DOMAIN, 'rdbDataPersistence', 'Upgrade store version from 0 to 1 success.');
        } catch (e) {
          const err = e as BusinessError;
          await transaction.rollback();
          hilog.error(DOMAIN, 'rdbDataPersistence', `Failed to execute sql. Code:${err.code}, message:${err.message}`);
          return;
        }
      }
      if (storeVersion === 1) {
        try {
          storeVersion = 2;
          hilog.info(DOMAIN, 'rdbDataPersistence', 'Upgrade store version from 1 to 2 success.');
          // 设置数据库的版本，入参为大于0的整数
          await transaction.execute('PRAGMA user_version = 2');
        } catch (e) {
          const err = e as BusinessError;
          await transaction.rollback();
          hilog.error(DOMAIN, 'rdbDataPersistence', `Failed to execute sql. Code:${err.code}, message:${err.message}`);
          return;
        }
      }
      await transaction.commit()
    }
    hilog.info(DOMAIN, 'rdbDataPersistence', 'Succeeded run transaction.');
  }
}
