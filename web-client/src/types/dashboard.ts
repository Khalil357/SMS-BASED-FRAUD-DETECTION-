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
}

export interface DetectionRule {
  id: string;
  name: string;
  type: 'Keyword' | 'Regex Pattern' | 'Link Analyzer' | 'Sender Spoofing';
  pattern: string;
  riskWeight: number;
  enabled: boolean;
  matchesCount: number;
}

export interface BlacklistedSender {
  id: string;
  number: string;
  reason: string;
  addedBy: string;
  dateAdded: string;
}

export interface SystemUser {
  id: string;
  name: string;
  email: string;
  phone: string;
  role: 'ADMIN' | 'USER';
  isVerified: boolean;
  isLocked: boolean;
  lastActive: string;
}