import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { media } from '@kit.MediaKit'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
const DEMO_VIDEO: string = 'demo_video.mp4'
@Entry
@Component
struct MediaPreview {
  @State imageUri: string = ''
  @State imageSourceText: string = '内置示例图'
  @State playerState: string = 'idle'
  @State playerTip: string = '尚未初始化播放器'
  @State currentTime: number = 0
  @State duration: number = 0
  @State logs: string[] = ['1. 页面已加载：内置图片和视频均可直接演示']
  private avPlayer?: media.AVPlayer
  private xComponentController: XComponentController = new XComponentController()
  private surfaceId: string = ''
  private logIndex: number = 1
  private isPreparing: boolean = false
  private rawFdOpened: boolean = false

  private appendLog(message: string): void {
    this.logIndex++
    this.logs = [`${this.logIndex}. ${message}`, ...this.logs].slice(0, 6)
  }

  private getUIAbilityContext(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  async chooseImage(): Promise<void> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker()
      const option = new photoAccessHelper.PhotoSelectOptions()
      option.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      option.maxSelectNumber = 1
      const result = await picker.select(option)
      if (result.photoUris.length > 0) {
        this.imageUri = result.photoUris[0]
        this.imageSourceText = '系统相册 URI'
        console.info(`selected uri: ${this.imageUri}`)
      }
    } catch (error) {
      const err = error as BusinessError
      console.error(`chooseImage failed: ${err.code}, ${err.message}`)
    }
  }

  private bindPlayerEvents(player: media.AVPlayer): void {
    player.on('stateChange', (state: string) => {
      this.playerState = state
      this.appendLog(`AVPlayer 状态：${state}`)
      switch (state) {
        case 'initialized':
          this.playerTip = '数据源已设置，等待绑定 Surface 并 prepare()'
          void this.prepareWhenReady()
          break
        case 'prepared':
          this.duration = player.duration
          this.currentTime = 0
          this.playerTip = '媒体已准备完成，可以播放'
          break
        case 'playing':
          this.playerTip = '正在解码并渲染视频画面'
          break
        case 'paused':
          this.playerTip = '播放已暂停'
          break
        case 'completed':
          this.playerTip = '播放完成'
          break
        case 'released':
          this.playerTip = '播放器资源已释放'
          break
        default:
          break
      }
    })
    player.on('timeUpdate', (time: number) => {
      this.currentTime = time
    })
    player.on('error', (err: BusinessError) => {
      this.playerState = 'error'
      this.playerTip = `播放器错误：${err.code}`
      this.appendLog(`AVPlayer error：${err.code} ${err.message}`)
    })
  }

  private async prepareWhenReady(): Promise<void> {
    if (!this.avPlayer ||
        this.playerState !== 'initialized' ||
        this.surfaceId === '' ||
        this.isPreparing) {
      return
    }
    this.isPreparing = true
    try {
      this.avPlayer.surfaceId = this.surfaceId
      this.appendLog('已把 XComponent SurfaceId 绑定给 AVPlayer')
      await this.avPlayer.prepare()
    } catch (error) {
      const err = error as BusinessError
      this.playerState = 'error'
      this.playerTip = `prepare() 失败：${err.code}`
    } finally {
      this.isPreparing = false
    }
  }

  async initDemoPlayer(): Promise<void> {
    try {
      await this.releasePlayer(false)
      this.playerState = 'idle'
      this.playerTip = '正在创建 AVPlayer…'
      this.currentTime = 0
      this.duration = 0
      const player = await media.createAVPlayer()
      this.avPlayer = player
      this.bindPlayerEvents(player)
      this.appendLog('createAVPlayer() 完成')
      const context = this.getUIAbilityContext()
      const rawFd = await context.resourceManager.getRawFd(DEMO_VIDEO)
      this.rawFdOpened = true
      player.fdSrc = {
        fd: rawFd.fd,
        offset: rawFd.offset,
        length: rawFd.length
      }
      this.appendLog('通过 getRawFd() 设置内置 MP4 数据源')
    } catch (error) {
      const err = error as BusinessError
      this.playerState = 'error'
      this.playerTip = `初始化失败：${err.code}`
    }
  }

  async releasePlayer(updateUi: boolean = true): Promise<void> {
    if (this.avPlayer) {
      try {
        this.avPlayer.off('timeUpdate')
        this.avPlayer.off('stateChange')
        this.avPlayer.off('error')
        await this.avPlayer.release()
      } catch (error) {
        const err = error as BusinessError
        console.error(`release failed: ${err.code}, ${err.message}`)
      }
      this.avPlayer = undefined
    }
    if (this.rawFdOpened) {
      try {
        const context = this.getUIAbilityContext()
        await context.resourceManager.closeRawFd(DEMO_VIDEO)
      } catch (error) {
        const err = error as BusinessError
        console.error(`closeRawFd failed: ${err.code}, ${err.message}`)
      }
      this.rawFdOpened = false
    }
    this.isPreparing = false
    if (updateUi) {
      this.playerState = 'released'
      this.playerTip = '播放器和 rawfile 文件描述符均已释放'
      this.currentTime = 0
      this.duration = 0
      this.appendLog('release() + closeRawFd() 完成')
    }
  }

  async play(): Promise<void> {
    if (!this.avPlayer) {
      console.info('请先初始化播放器')
      return
    }
    if (this.playerState === 'prepared' || this.playerState === 'paused') {
      await this.avPlayer.play()
    } else {
      console.info(`当前状态 ${this.playerState} 不能直接 play()`)
    }
  }

  async pause(): Promise<void> {
    if (this.avPlayer && this.playerState === 'playing') {
      await this.avPlayer.pause()
    } else {
      console.info(`当前状态 ${this.playerState} 不需要 pause()`)
    }
  }

  aboutToDisappear(): void {
    void this.releasePlayer(false)
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text('Media Lab')
          .fontSize(12)
          .fontColor('#0A59F7')
          .fontWeight(FontWeight.Bold)
        Text('多媒体应用实战')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
        Text('01 图片选择与预览')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        if (this.imageUri !== '') {
          Image(this.imageUri)
            .width('100%')
            .height(220)
            .objectFit(ImageFit.Cover)
            .borderRadius(14)
        } else {
          Image($r('app.media.demo_photo'))
            .width('100%')
            .height(220)
            .objectFit(ImageFit.Cover)
            .borderRadius(14)
        }
        Text(`当前图片来源：${this.imageSourceText}`)
          .fontSize(13)
          .fontColor('#667085')
        Row({ space: 10 }) {
          Button('选择相册图片')
            .layoutWeight(1)
            .onClick(() => {
              void this.chooseImage()
            })
          Button('恢复内置图片')
            .layoutWeight(1)
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .onClick(() => {
              this.imageUri = ''
              this.imageSourceText = '内置示例图'
            })
        }
        .width('100%')
        Text('02  AVPlayer 状态机与视频播放')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        XComponent({
          id: 'videoSurface',
          type: XComponentType.SURFACE,
          controller: this.xComponentController
        })
          .width('100%')
          .height(210)
          .backgroundColor('#101828')
          .borderRadius(14)
          .onLoad(() => {
            this.surfaceId = this.xComponentController.getXComponentSurfaceId()
            this.appendLog('XComponent Surface 创建完成')
          })
        Text(`播放器状态：${this.playerState}`)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Text(this.playerTip)
          .fontSize(13)
          .fontColor('#667085')
        Progress({
          value: this.currentTime,
          total: this.duration > 0 ? this.duration : 1
        })
          .width('100%')
        Button('初始化示例视频')
          .width('100%')
          .onClick(() => {
            void this.initDemoPlayer()
          })
        Row({ space: 10 }) {
          Button('播放')
            .layoutWeight(1)
            .enabled(this.playerState === 'prepared' || this.playerState === 'paused')
            .onClick(() => {
              void this.play()
            })
          Button('暂停')
            .layoutWeight(1)
            .enabled(this.playerState === 'playing')
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .onClick(() => {
              void this.pause()
            })
        }
        .width('100%')
        Button('释放播放器资源')
          .width('100%')
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .onClick(() => {
            void this.releasePlayer(true)
          })
        Text('03  操作日志')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        ForEach(this.logs, (item: string) => {
          Text(item)
            .width('100%')
            .fontSize(12)
            .fontColor('#475467')
            .padding(10)
            .backgroundColor('#F8FAFC')
            .borderRadius(8)
        }, (item: string) => item)
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
  }
}