export interface CampusEvent {
  title: string;
  time: string;
  place: string;
  summary: string;
  todoCount: number;
}

export const EVENTS: CampusEvent[] = [
  { title: '校园摄影采风', time: '周四 14:00', place: '图书馆南门',
    summary: '校园秋景拍摄', todoCount: 3 },
  { title: '鸿蒙应用工作坊', time: '周五 15:30', place: '软件实验室',
    summary: 'ArkTS交互页面实践', todoCount: 2 },
  { title: '校园夜跑', time: '周六 19:00', place: '体育场东入口',
    summary: '校园环线慢跑', todoCount: 1 }
];

export interface CardPayload {
  eventIndex: number;
  title: string;
  time: string;
  place: string;
  summary: string;
  todoCount: number;
  formId?: string;
  dimension?: number;
  revision?: number;
  refreshedAt?: string;
  refreshSource?: string;
}

export function eventData(index: number, count: number = EVENTS[index].todoCount): CardPayload {
  const item: CampusEvent = EVENTS[index];
  return { eventIndex: index, title: item.title, time: item.time, place: item.place,
    summary: item.summary, todoCount: count };
}
