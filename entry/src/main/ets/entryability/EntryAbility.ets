import { UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

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
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) { console.error(`[CARDLAB] LOAD_ERROR ${error.code}`); }
    });
  }
}
