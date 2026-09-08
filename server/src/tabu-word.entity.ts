export interface TabuWordEntity {
  id: string;
  word: string;
  category: string;
  difficulty: 'kolay' | 'normal' | 'zor';
  enabled: boolean;
  createdAt: Date;
}

export interface TabuForbiddenWordEntity {
  id: string;
  tabuWordId: string;
  word: string;
}
