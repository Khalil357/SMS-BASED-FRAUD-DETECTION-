export interface StatCardData {
  id: string;
  title: string;
  value: string;
  change: string;
  type: 'positive' | 'negative' | 'warning';
  category: 'total' | 'fraud' | 'safe' | 'pending';
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
}

export interface SmsRecord {
  id: string;
  sender: string;
  message: string;
  fraudType: 'Phishing' | 'Impersonation' | 'Fake Promotion' | 'Loan Scam' | 'Clean';
  riskScore: number;
  date: string;
  status: 'Fraud' | 'Review' | 'Safe';
  reportedByUser: boolean;
}

export interface BlacklistedSender {
  id: string;
  number: string;
  reason: string;
  addedBy: string;
  dateAdded: string;
}
