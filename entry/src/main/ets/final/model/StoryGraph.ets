/**
 * 迷雾档案 · 剧情数据表
 * 12 个事件节点 / 6 条线索 / 2 条推论 / 4 个场景。
 * 文案可整体替换，但节点 id、线索 id、推论 id 被引擎与测试引用，改动需同步。
 */
import { ChoiceDef, ClueDef, DeductionDef, FinalChoice, SceneDef, Stage, StoryNode } from './Types';

export const SCENE_LIBRARY: string = 's_library';
export const SCENE_LAB: string = 's_lab';
export const SCENE_STADIUM: string = 's_stadium';
export const SCENE_OFFICE: string = 's_office';

export const CLUE_LOG: string = 'c_log';
export const CLUE_DOOR: string = 'c_door';
export const CLUE_CARD: string = 'c_card';
export const CLUE_TAPE: string = 'c_tape';
export const CLUE_BURN: string = 'c_burn';
export const CLUE_NOTE: string = 'c_note';

export const DEDUCE_GAP: string = 'd_gap';
export const DEDUCE_WHO: string = 'd_who';

export const SCENES: SceneDef[] = [
  { id: SCENE_LIBRARY, name: '图书馆 B1', subtitle: '闭馆之后的第四层地下' },
  { id: SCENE_LAB, name: '实验楼 403', subtitle: '值班室与烧焦的排班表' },
  { id: SCENE_STADIUM, name: '体育场看台', subtitle: '唯一愿意开口的人' },
  { id: SCENE_OFFICE, name: '教务处', subtitle: '结论比证据先到的地方' }
];

export const CLUES: ClueDef[] = [
  {
    id: CLUE_LOG,
    name: '闭馆巡查记录',
    summary: '值班签名与登记人不一致',
    detail: '21:40 的巡查记录上签的是「周」，但当晚登记的值班人是「陈」。保安说周那天请了假。',
    sceneId: SCENE_LIBRARY
  },
  {
    id: CLUE_DOOR,
    name: 'B1 门禁记录',
    summary: '23:47 有过一次刷卡',
    detail: '门禁后台显示 23:47 有一次有效刷卡，卡号属于学生卡，但持卡人当晚 22:00 已离校。',
    sceneId: SCENE_LIBRARY
  },
  {
    id: CLUE_CARD,
    name: '还书车里的借阅卡',
    summary: '一张不该出现在 B1 的卡',
    detail: '借阅卡夹在还书车最底层，卡面贴着实验室编号。这张卡的主人，是当晚被反锁的学生。',
    sceneId: SCENE_LIBRARY
  },
  {
    id: CLUE_TAPE,
    name: '监控的八分钟',
    summary: '23:44 到 23:52 是空的',
    detail: 'B1 走廊监控在 23:44 到 23:52 之间没有任何画面，不是黑屏，是文件被剪掉了。',
    sceneId: SCENE_LIBRARY
  },
  {
    id: CLUE_BURN,
    name: '烧焦的排班表',
    summary: 'B1 值班被临时换过',
    detail: '403 废纸篓里的残页还能认出半行字：「B1 值班 陈→周（临时）」。剩下的部分烧得很干净。',
    sceneId: SCENE_LAB
  },
  {
    id: CLUE_NOTE,
    name: '37 号柜的纸条',
    summary: '有人要求目击者改口',
    detail: '纸条上只有两行：「你什么都没看见。」「你还要在这个学校待三年。」',
    sceneId: SCENE_STADIUM
  }
];

export const DEDUCTIONS: DeductionDef[] = [
  {
    id: DEDUCE_GAP,
    name: '八分钟的空档',
    clueA: CLUE_LOG,
    clueB: CLUE_DOOR,
    conclusion: '巡查记录上的签名与当晚实际值班人不是同一个，而 23:47 那次刷卡用的是别人的卡。有人先在记录上做了手脚，才有后面被剪掉的八分钟。'
  },
  {
    id: DEDUCE_WHO,
    name: '代签的人',
    clueA: CLUE_CARD,
    clueB: CLUE_BURN,
    conclusion: '排班表把 B1 值班临时换成了周，而借阅卡的主人当晚并不在馆内。是有人替别人完成了签退，再把门从外面锁上。'
  }
];

function choice(id: string, label: string, hint: string, nextNodeId: string, cost: number): ChoiceDef {
  return {
    id: id, label: label, hint: hint, nextNodeId: nextNodeId, cost: cost,
    requireClues: [], requireDeductions: [], requireFlags: [],
    grantClues: [], setFlags: [], finalChoice: FinalChoice.NONE
  };
}

export const NODES: StoryNode[] = [
  {
    id: 'n_accept',
    sceneId: SCENE_OFFICE,
    title: '记者站 · 傍晚',
    text: '打印机卡了三次纸。站长把一份处分通知推到你面前：凌晨四点，图书馆 B1 书库，一名学生被反锁。「校方的结论是违规滞留。」她顿了顿，「门禁是他自己刷开的。你信吗。」',
    stage: Stage.ACCEPT,
    requireClues: [], requireDeductions: [], requireFlags: [], isEnding: false,
    choices: [
      choice('ch_accept', '接下这桩调查', '从闭馆记录开始', 'n_gate', 10),
      choice('ch_notice', '先把处分通知读完', '多花五分钟，少走一段弯路', 'n_gate', 5)
    ]
  },
  {
    id: 'n_gate',
    sceneId: SCENE_LIBRARY,
    title: '图书馆门厅 · 21:40',
    text: '闭馆广播刚结束，门厅只剩一盏应急灯。保安室的窗台上摞着一沓巡查记录，最后一页的签名歪得厉害。',
    stage: Stage.SURVEY,
    requireClues: [], requireDeductions: [], requireFlags: [], isEnding: false,
    choices: [
      {
        id: 'ch_gate_log', label: '调出闭馆巡查记录', hint: '需要翻到最后一页', nextNodeId: 'n_b1_door', cost: 30,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [CLUE_LOG], setFlags: ['saw_log'], finalChoice: FinalChoice.NONE
      },
      {
        id: 'ch_gate_guard', label: '直接问值班保安', hint: '省时间，但拿不到纸质记录', nextNodeId: 'n_b1_door', cost: 10,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [], setFlags: ['guard_talk'], finalChoice: FinalChoice.NONE
      }
    ]
  },
  {
    id: 'n_b1_door',
    sceneId: SCENE_LIBRARY,
    title: 'B1 铁门 · 22:20',
    text: '铁门上贴着「书库重地」。读卡器亮着红灯，像在等一张特定的卡。保安在你身后说：那晚的门，是有人从外面锁的。',
    stage: Stage.SURVEY,
    requireClues: [], requireDeductions: [], requireFlags: [], isEnding: false,
    choices: [
      {
        id: 'ch_door_force', label: '要求调门禁后台记录', hint: '需要值班记录做依据', nextNodeId: 'n_b1_shelf', cost: 20,
        requireClues: [CLUE_LOG], requireDeductions: [], requireFlags: [],
        grantClues: [CLUE_DOOR], setFlags: [], finalChoice: FinalChoice.NONE
      },
      {
        id: 'ch_door_guess', label: '按保安口述记下时间', hint: '没有记录，只能凭记忆', nextNodeId: 'n_b1_shelf', cost: 15,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [], setFlags: ['door_guess'], finalChoice: FinalChoice.NONE
      }
    ]
  },
  {
    id: 'n_b1_shelf',
    sceneId: SCENE_LIBRARY,
    title: 'B1 书架 · 22:50',
    text: '空气里有灰和旧纸的味道。还书车停在过道中间，轮子歪着，像被人撞过。第三排书架上有一道新鲜的划痕。',
    stage: Stage.SURVEY,
    requireClues: [], requireDeductions: [], requireFlags: [], isEnding: false,
    choices: [
      {
        id: 'ch_shelf_search', label: '逐排翻查还书车', hint: '要花点时间', nextNodeId: 'n_b1_tape', cost: 20,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [CLUE_CARD], setFlags: [], finalChoice: FinalChoice.NONE
      },
      {
        id: 'ch_shelf_quick', label: '只看借阅登记本', hint: '快，但会漏东西', nextNodeId: 'n_b1_tape', cost: 8,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [], setFlags: ['shelf_quick'], finalChoice: FinalChoice.NONE
      }
    ]
  },
  {
    id: 'n_b1_tape',
    sceneId: SCENE_LIBRARY,
    title: 'B1 监控回放 · 23:10',
    text: '回放列表里有一段时间是没有缩略图的。你把进度条拖过去，画面直接跳了一格——不是黑屏，是文件被剪掉了。',
    stage: Stage.SURVEY,
    requireClues: [CLUE_DOOR], requireDeductions: [], requireFlags: [], isEnding: false,
    choices: [
      {
        id: 'ch_tape_full', label: '把缺口前后对齐看一遍', hint: '需要先想明白门禁时间的矛盾', nextNodeId: 'n_lab_corridor', cost: 25,
        requireClues: [], requireDeductions: [DEDUCE_GAP], requireFlags: [],
        grantClues: [CLUE_TAPE], setFlags: [], finalChoice: FinalChoice.NONE
      },
      {
        id: 'ch_tape_skip', label: '只抄下时间码就走', hint: '缺口成了没有证据的疑点', nextNodeId: 'n_lab_corridor', cost: 8,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [], setFlags: ['tape_skipped'], finalChoice: FinalChoice.NONE
      }
    ]
  },
  {
    id: 'n_lab_corridor',
    sceneId: SCENE_LAB,
    title: '实验楼 403 · 走廊',
    text: '走廊尽头亮着一间值班室。值班教师正在收拾东西，看见你手里的档案袋，动作慢了半拍。',
    stage: Stage.VERIFY,
    requireClues: [], requireDeductions: [], requireFlags: [], isEnding: false,
    choices: [
      {
        id: 'ch_teacher_ask', label: '直接问那晚谁值班', hint: '把话挑明', nextNodeId: 'n_lab_room', cost: 20,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [], setFlags: ['teacher_trust'], finalChoice: FinalChoice.NONE
      },
      {
        id: 'ch_teacher_soft', label: '先聊排班表的事', hint: '绕一圈问', nextNodeId: 'n_lab_room', cost: 12,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [], setFlags: ['teacher_guard'], finalChoice: FinalChoice.NONE
      }
    ]
  },
  {
    id: 'n_lab_room',
    sceneId: SCENE_LAB,
    title: '403 值班室 · 23:40',
    text: '废纸篓里有一小片没烧干净的纸，边缘还是热的。上面能认出半行字：「B1 值班 陈→周（临时）」。',
    stage: Stage.VERIFY,
    requireClues: [], requireDeductions: [], requireFlags: [], isEnding: false,
    choices: [
      {
        id: 'ch_burn_take', label: '把残页收进档案袋', hint: '带走原件', nextNodeId: 'n_stadium_stand', cost: 20,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [CLUE_BURN], setFlags: ['burn_original'], finalChoice: FinalChoice.NONE
      },
      {
        id: 'ch_burn_photo', label: '只拍一张照片', hint: '原件留在现场', nextNodeId: 'n_stadium_stand', cost: 12,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [CLUE_BURN], setFlags: ['burn_photo'], finalChoice: FinalChoice.NONE
      }
    ]
  },
  {
    id: 'n_stadium_stand',
    sceneId: SCENE_STADIUM,
    title: '体育场看台 · 次日 12:10',
    text: '目击者坐在看台最高一排，手里捏着一瓶没开的水。他看见你走近，第一句话是：「我昨天说的，你别当真。」',
    stage: Stage.VERIFY,
    requireClues: [], requireDeductions: [], requireFlags: [], isEnding: false,
    choices: [
      {
        id: 'ch_witness_press', label: '追问为什么改口', hint: '逼他把话说完', nextNodeId: 'n_stadium_locker', cost: 20,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [], setFlags: ['witness_flip'], finalChoice: FinalChoice.NONE
      },
      {
        id: 'ch_witness_calm', label: '先陪他坐一会儿', hint: '慢，但他会自己开口', nextNodeId: 'n_stadium_locker', cost: 15,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [], setFlags: ['witness_calm'], finalChoice: FinalChoice.NONE
      }
    ]
  },
  {
    id: 'n_stadium_locker',
    sceneId: SCENE_STADIUM,
    title: '看台下 · 储物间',
    text: '37 号柜的锁是坏的。他站在门口没进来，只说：「那柜子不是我的。」',
    stage: Stage.VERIFY,
    requireClues: [], requireDeductions: [], requireFlags: [], isEnding: false,
    choices: [
      {
        id: 'ch_locker_open', label: '用借阅卡试开 37 号柜', hint: '需要借阅卡，且他已经松口', nextNodeId: 'n_confront', cost: 20,
        requireClues: [CLUE_CARD], requireDeductions: [], requireFlags: ['witness_flip'],
        grantClues: [CLUE_NOTE], setFlags: [], finalChoice: FinalChoice.NONE
      },
      {
        id: 'ch_locker_leave', label: '不碰私人物品，先回教务处', hint: '守住底线，也放弃一条线索', nextNodeId: 'n_confront', cost: 5,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [], setFlags: ['locker_left'], finalChoice: FinalChoice.NONE
      }
    ]
  },
  {
    id: 'n_confront',
    sceneId: SCENE_OFFICE,
    title: '教务处 · 16:30',
    text: '桌上摊着那份处分决定，签字栏已经空了三天。主任抬头看你：「记者站也要讲证据。」',
    stage: Stage.VERDICT,
    requireClues: [], requireDeductions: [], requireFlags: [], isEnding: false,
    choices: [
      choice('ch_confront_enter', '把档案袋放到桌上', '接下来就是最终判断', 'n_final_choose', 20)
    ]
  },
  {
    id: 'n_final_choose',
    sceneId: SCENE_OFFICE,
    title: '教务处 · 最终判断',
    text: '你可以把整条证据链摊开，也可以只交一份「人情」。窗外天已经黑透了，走廊里有人在等结果。',
    stage: Stage.VERDICT,
    requireClues: [], requireDeductions: [], requireFlags: [], isEnding: false,
    choices: [
      {
        id: 'ch_final_submit', label: '提交完整证据链', hint: '需要两条推论与至少五条线索', nextNodeId: 'n_epilogue', cost: 10,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [], setFlags: [], finalChoice: FinalChoice.SUBMIT
      },
      {
        id: 'ch_final_quiet', label: '只交人情，不交证据', hint: '事情会安静地结束', nextNodeId: 'n_epilogue', cost: 10,
        requireClues: [], requireDeductions: [], requireFlags: [],
        grantClues: [], setFlags: [], finalChoice: FinalChoice.KEEP_QUIET
      }
    ]
  },
  {
    id: 'n_epilogue',
    sceneId: SCENE_OFFICE,
    title: '档案封存',
    text: '档案袋被放回铁柜，锁扣合上的声音很轻。',
    stage: Stage.ENDING,
    requireClues: [], requireDeductions: [], requireFlags: [], isEnding: true,
    choices: []
  }
];

export function nodeById(id: string): StoryNode | undefined {
  return NODES.find((item: StoryNode) => item.id === id);
}

export function clueById(id: string): ClueDef | undefined {
  return CLUES.find((item: ClueDef) => item.id === id);
}

export function deductionById(id: string): DeductionDef | undefined {
  return DEDUCTIONS.find((item: DeductionDef) => item.id === id);
}

export function sceneById(id: string): SceneDef | undefined {
  return SCENES.find((item: SceneDef) => item.id === id);
}

export function nodesOfScene(sceneId: string): StoryNode[] {
  return NODES.filter((item: StoryNode) => item.sceneId === sceneId);
}

export function choiceById(node: StoryNode, choiceId: string): ChoiceDef | undefined {
  return node.choices.find((item: ChoiceDef) => item.id === choiceId);
}

export function clueName(id: string): string {
  const clue: ClueDef | undefined = clueById(id);
  return clue === undefined ? id : clue.name;
}

export function deductionName(id: string): string {
  const deduction: DeductionDef | undefined = deductionById(id);
  return deduction === undefined ? id : deduction.name;
}
