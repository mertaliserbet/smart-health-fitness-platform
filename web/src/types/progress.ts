export interface WeightRecordResponse {
  id: string;
  weightKg: number;
  recordedAt: string;
}

export interface BodyMeasurementResponse {
  id: string;
  chestCm: number | null;
  waistCm: number | null;
  hipCm: number | null;
  armCm: number | null;
  thighCm: number | null;
  bodyFatPercentage: number | null;
  recordedAt: string;
}

export type BodyMetric = Exclude<keyof BodyMeasurementResponse, 'id' | 'recordedAt'>;
export type ProgressPeriod = '30' | '90' | '365' | 'all';
export interface ProgressPoint {
  id: string;
  recordedAt: string;
  value: number | null;
}
