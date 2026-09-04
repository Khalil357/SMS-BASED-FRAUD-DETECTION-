export interface StatCardData {
  id: string;
  title: string;
  value: string;
  change: string;
  type: 'positive' | 'negative' | 'warning';
  category: 'total' | 'fraud' | 'safe' | 'pending';
  icon: string;
}

export interface ChartBarData {
  day: string;
  percentage: number;
}

export interface AlertData {
  id: string;
  title: string;
  description: string;
  timeAgo: string;
  severity: 'high' | 'medium' | 'low';
  icon: string;
}

export interface SmsRecord {
  id: string;
  sender: string;
  message: string;
  fraudType: 'Phishing' | 'Impersonation' | 'Fake Promotion' | 'Loan Scam';
  riskScore: number;
  date: string;
  status: 'Fraud' | 'Review';
}