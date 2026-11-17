import { UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { START_PAGE } from '../final/BootConfig';

export default class EntryAbility extends UIAbility {
  private serial: number = 0;

  private acceptRoute(want: Want, lifecycle: string): void {
    let id: string = '';
    const raw = want.parameters?.params;
    if (typeof raw === 'string') {
      try {
        const params: Record<string, string> = JSON.parse(raw) as Record<string, string>;
        if (params.target === 'detail' && typeof params.formId === 'string') { id = params.formId; }
      } catch (error) { console.error(`[CARDLAB] ROUTE_ERROR ${(error as Error).message}`); }
    }
    AppStorage.setOrCreate<string>('activeFormId', id);
    AppStorage.setOrCreate<string>('entrySource', id.length > 0 ? 'card' : 'app');
    AppStorage.setOrCreate<number>('routeSerial', ++this.serial);
    console.info(`[CARDLAB] ROUTE lifecycle=${lifecycle} id=${id}`);
  }

  onCreate(want: Want): void { this.acceptRoute(want, 'create'); }

  onNewWant(want: Want): void { this.acceptRoute(want, 'newWant'); }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 首页由 final/BootConfig.ets 的 START_PAGE 决定：
    // 做大作业时指向 final/pages/FinalIndex；要回到实验入口（pages/Index），
    // 只改那一个常量即可，这里与 Index.ets 都不需要改动。
    windowStage.loadContent(START_PAGE, (error) => {
      if (error.code) { console.error(`[CARDLAB] LOAD_ERROR ${error.code}`); }
    });

    // 只有启动页在 final/ 下时才把系统状态栏改成深色，避免深色界面顶部出现白条。
    // 切回 pages/Index 做实验时会保持系统默认外观，实验页面视觉不受影响。
    if (START_PAGE.indexOf('final/') === 0) {
      windowStage.getMainWindow((error, mainWindow) => {
        if (error.code) { return; }
        mainWindow.setWindowSystemBarProperties({
          statusBarColor: '#0B0C0F',
          statusBarContentColor: '#FFFFFF',
          navigationBarColor: '#0B0C0F',
          navigationBarContentColor: '#FFFFFF'
        });
      });
    }
  }
}
