import React, { useState } from "react";
import type { ChangeEvent } from "react";
import "./DashboardPage.css";
import type {
  StatCardData,
  ChartBarData,
  AlertData,
  SmsRecord,
  DetectionRule,
  BlacklistedSender,
  SystemUser,
} from "../types/dashboard";
import type { AuthPage } from "../types/auth";
import { useTheme } from "../theme/ThemeContext";
import {
  ShieldAlert,
  ShieldCheck,
  MessageSquare,
  AlertTriangle,
  Users,
  Settings,
  Activity,
  Plus,
  Search,
  Trash2,
  Eye,
  CheckCircle2,
  XCircle,
  Lock,
  Unlock,
  Moon,
  Sun,
  LogOut,
  Radio,
  Sliders,
  UserPlus,
  Bell,
  X,
  ArrowUpRight,
  Terminal,
  Copy,
  Check,
} from "lucide-react";
import inAppIcon from "../assets/images/in_app_icon.png";

interface DashboardPageProps {
  onNavigate: (page: AuthPage) => void;
}

const mockStats: StatCardData[] = [
  {
    id: "1",
    title: "Total SMS Scanned",
    value: "14,890",
    change: "+12.5% this month",
    type: "positive",
    category: "total",
  },
  {
    id: "2",
    title: "Fraud & Scams Blocked",
    value: "2,840",
    change: "98.4% detection rate",
    type: "negative",
    category: "fraud",
  },
  {
    id: "3",
    title: "Safe Messages Verified",
    value: "11,760",
    change: "+8.2% clean traffic",
    type: "positive",
    category: "safe",
  },
  {
    id: "4",
    title: "Active Device Interceptors",
    value: "412",
    change: "Live monitoring active",
    type: "warning",
    category: "pending",
  },
];

const mockChart: ChartBarData[] = [
  { day: "Mon", percentage: 42 },
  { day: "Tue", percentage: 65 },
  { day: "Wed", percentage: 54 },
  { day: "Thu", percentage: 88 },
  { day: "Fri", percentage: 70 },
  { day: "Sat", percentage: 94 },
  { day: "Sun", percentage: 76 },
];

const mockAlerts: AlertData[] = [
  {
    id: "1",
    title: "Critical Phishing Spike Detected",
    description: "Fraud score 96% on impersonation domain scam-vodacom.co.tz",
    timeAgo: "3 mins ago",
    severity: "high",
  },
  {
    id: "2",
    title: "Bulk Sender Blacklisted",
    description: "+255 746 099 812 added to global threat registry",
    timeAgo: "15 mins ago",
    severity: "medium",
  },
  {
    id: "3",
    title: "Fake Mobile Money Scam Alert",
    description: "Fake M-Pesa receipt SMS intercepted across 45 devices",
    timeAgo: "30 mins ago",
    severity: "high",
  },
  {
    id: "4",
    title: "ML Model Weights Sync",
    description: "Engine updated with 120 new scam vector definitions",
    timeAgo: "1 hour ago",
    severity: "low",
  },
];

const initialSmsRecords: SmsRecord[] = [
  {
    id: "SMS-8910",
    sender: "+255 746 046 202",
    message: "Hongera! Umeshinda TZS 2,500,000 kutoka Vodacom. Bonyeza link http://voda-tuzo.com au piga 0746046202 kudai zawadi yako.",
    fraudType: "Phishing",
    riskScore: 96,
    date: "03 Sep 2026 14:22",
    status: "Fraud",
  },
  {
    id: "SMS-8909",
    sender: "+255 754 123 890",
    message: "Tuma zile pesa elfu 50 kwenye namba hii 0754123890 kwa jina la Juma Kabwe. Usipime namba ile nyingine imefungwa.",
    fraudType: "Impersonation",
    riskScore: 91,
    date: "03 Sep 2026 13:45",
    status: "Fraud",
  },
  {
    id: "SMS-8908",
    sender: "+255 713 456 789",
    message: "LOAN APPROVED! Mkopo wako wa TZS 500,000 umekubaliwa. Lipia ada ya usajili TZS 10,000 kupitia http://mkopo-fast.com",
    fraudType: "Loan Scam",
    riskScore: 88,
    date: "03 Sep 2026 12:10",
    status: "Fraud",
  },
  {
    id: "SMS-8907",
    sender: "+255 765 222 111",
    message: "Ndugu mteja, akaunti yako ya Benki imefungwa kwa muda. Tafadhali thibitisha taarifa zako sasa hivi hapa: http://crdb-verify.org",
    fraudType: "Phishing",
    riskScore: 94,
    date: "03 Sep 2026 11:05",
    status: "Fraud",
  },
  {
    id: "SMS-8906",
    sender: "+255 789 900 112",
    message: "Kaka hio hela ya kodi tuma kwenye hii namba badala ya ile ya mwanzo. Namba mpya ni 0789900112 Asante.",
    fraudType: "Impersonation",
    riskScore: 78,
    date: "03 Sep 2026 09:30",
    status: "Review",
  },
  {
    id: "SMS-8905",
    sender: "CRDB-BANK",
    message: "Taarifa: Umepokea TZS 150,000 kwenye akaunti yako ****4812. Salio lako jipya ni TZS 1,820,000.",
    fraudType: "Clean",
    riskScore: 5,
    date: "03 Sep 2026 08:15",
    status: "Safe",
  },
];

const initialRules: DetectionRule[] = [
  {
    id: "RULE-101",
    name: "Urgent Payment Redirect Keyword",
    type: "Keyword",
    pattern: "(tuma|tumia|lipia)\\s+.*(namba\\s+hii|kodi|pesa)",
    riskWeight: 85,
    enabled: true,
    matchesCount: 1420,
  },
  {
    id: "RULE-102",
    name: "Suspicious Domain / Phishing URL",
    type: "Link Analyzer",
    pattern: "http(s)?://(?!.*(vodacom|airtel|crdbbank|nmb)\\.co\\.tz)",
    riskWeight: 95,
    enabled: true,
    matchesCount: 2310,
  },
  {
    id: "RULE-103",
    name: "Unsolicited Lottery & Prize Claims",
    type: "Keyword",
    pattern: "(umeshinda|zawadi|bahati\\s+nasibu|tuzo)",
    riskWeight: 90,
    enabled: true,
    matchesCount: 890,
  },
  {
    id: "RULE-104",
    name: "Fake Account Suspension Alert",
    type: "Sender Spoofing",
    pattern: "(akaunti|account)\\s+.*(imefungwa|suspended|blocked)",
    riskWeight: 88,
    enabled: true,
    matchesCount: 650,
  },
];

const initialBlacklist: BlacklistedSender[] = [
  {
    id: "BLK-01",
    number: "+255 746 046 202",
    reason: "Repeated phishing link delivery (voda-tuzo.com)",
    addedBy: "Admin (Auto-Shield)",
    dateAdded: "02 Sep 2026",
  },
  {
    id: "BLK-02",
    number: "+255 754 123 890",
    reason: "Impersonation scam requesting money transfers",
    addedBy: "Admin",
    dateAdded: "01 Sep 2026",
  },
  {
    id: "BLK-03",
    number: "+255 765 222 111",
    reason: "Fake CRDB Bank credential harvesting",
    addedBy: "Admin (Auto-Shield)",
    dateAdded: "30 Aug 2026",
  },
];

const initialUsers: SystemUser[] = [
  {
    id: "USR-01",
    name: "System Administrator",
    email: "admin@smsfraud.com",
    phone: "+255 700 000 001",
    role: "ADMIN",
    isVerified: true,
    isLocked: false,
    lastActive: "Active Now",
  },
  {
    id: "USR-02",
    name: "Security Analyst",
    email: "analyst@smsfraud.com",
    phone: "+255 700 000 002",
    role: "ADMIN",
    isVerified: true,
    isLocked: false,
    lastActive: "10 mins ago",
  },
  {
    id: "USR-03",
    name: "Juma Hamisi",
    email: "juma.hamisi@gmail.com",
    phone: "+255 712 990 011",
    role: "USER",
    isVerified: true,
    isLocked: false,
    lastActive: "2 hours ago",
  },
  {
    id: "USR-04",
    name: "Amina Salum",
    email: "amina.salum@yahoo.com",
    phone: "+255 754 881 223",
    role: "USER",
    isVerified: false,
    isLocked: true,
    lastActive: "1 day ago",
  },
];

export const DashboardPage: React.FC<DashboardPageProps> = ({ onNavigate }) => {
  const { isDark, toggleTheme } = useTheme();

  // State
  const [activeTab, setActiveTab] = useState<string>("Overview");
  const [searchQuery, setSearchQuery] = useState<string>("");
  const [filterType, setFilterType] = useState<string>("All");
  const [smsList, setSmsList] = useState<SmsRecord[]>(initialSmsRecords);
  const [rulesList, setRulesList] = useState<DetectionRule[]>(initialRules);
  const [blacklist, setBlacklist] = useState<BlacklistedSender[]>(initialBlacklist);
  const [usersList, setUsersList] = useState<SystemUser[]>(initialUsers);

  // Modals & Popovers
  const [selectedSms, setSelectedSms] = useState<SmsRecord | null>(null);
  const [isAddRuleOpen, setIsAddRuleOpen] = useState(false);
  const [isAddBlacklistOpen, setIsAddBlacklistOpen] = useState(false);
  const [isNotificationsOpen, setIsNotificationsOpen] = useState(false);
  const [copiedCommandId, setCopiedCommandId] = useState<string | null>(null);

  const handleCopyCommand = (id: string, text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedCommandId(id);
    setTimeout(() => setCopiedCommandId(null), 2000);
  };

  // Form states
  const [newRuleName, setNewRuleName] = useState("");
  const [newRulePattern, setNewRulePattern] = useState("");
  const [newRuleType, setNewRuleType] = useState<DetectionRule["type"]>("Keyword");
  const [newRuleWeight, setNewRuleWeight] = useState(85);

  const [newBlacklistNumber, setNewBlacklistNumber] = useState("");
  const [newBlacklistReason, setNewBlacklistReason] = useState("");

  // Filtering
  const filteredSms = smsList.filter((item) => {
    const matchesSearch =
      item.sender.toLowerCase().includes(searchQuery.toLowerCase()) ||
      item.message.toLowerCase().includes(searchQuery.toLowerCase()) ||
      item.fraudType.toLowerCase().includes(searchQuery.toLowerCase()) ||
      item.id.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesFilter = filterType === "All" || item.status === filterType;
    return matchesSearch && matchesFilter;
  });

  // Action handlers
  const handleToggleRule = (id: string) => {
    setRulesList((prev) =>
      prev.map((r) => (r.id === id ? { ...r, enabled: !r.enabled } : r))
    );
  };

  const handleAddRule = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newRuleName.trim() || !newRulePattern.trim()) return;

    const newRule: DetectionRule = {
      id: `RULE-${Math.floor(100 + Math.random() * 900)}`,
      name: newRuleName.trim(),
      type: newRuleType,
      pattern: newRulePattern.trim(),
      riskWeight: newRuleWeight,
      enabled: true,
      matchesCount: 0,
    };

    setRulesList([newRule, ...rulesList]);
    setNewRuleName("");
    setNewRulePattern("");
    setIsAddRuleOpen(false);
  };

  const handleAddBlacklist = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newBlacklistNumber.trim()) return;

    const newEntry: BlacklistedSender = {
      id: `BLK-0${blacklist.length + 1}`,
      number: newBlacklistNumber.trim(),
      reason: newBlacklistReason.trim() || "Manual admin blacklist entry",
      addedBy: "Admin",
      dateAdded: "Today",
    };

    setBlacklist([newEntry, ...blacklist]);
    setNewBlacklistNumber("");
    setNewBlacklistReason("");
    setIsAddBlacklistOpen(false);
  };

  const handleRemoveBlacklist = (id: string) => {
    setBlacklist((prev) => prev.filter((item) => item.id !== id));
  };

  const handleToggleUserLock = (id: string) => {
    setUsersList((prev) =>
      prev.map((u) => (u.id === id ? { ...u, isLocked: !u.isLocked } : u))
    );
  };

  const handleMarkSafe = (smsId: string) => {
    setSmsList((prev) =>
      prev.map((s) => (s.id === smsId ? { ...s, status: "Safe", fraudType: "Clean", riskScore: 5 } : s))
    );
    setSelectedSms(null);
  };

  const handleBlacklistFromModal = (sms: SmsRecord) => {
    if (!blacklist.some((b) => b.number === sms.sender)) {
      setBlacklist([
        {
          id: `BLK-0${blacklist.length + 1}`,
          number: sms.sender,
          reason: `Flagged from SMS ${sms.id} (${sms.fraudType})`,
          addedBy: "Admin (Shield)",
          dateAdded: "Just now",
        },
        ...blacklist,
      ]);
    }
    setSmsList((prev) =>
      prev.map((s) => (s.id === sms.id ? { ...s, status: "Fraud", riskScore: 99 } : s))
    );
    setSelectedSms(null);
  };

  const getBadgeClass = (type: SmsRecord["fraudType"]): string => {
    switch (type) {
      case "Phishing":
        return "phishing";
      case "Impersonation":
        return "impersonation";
      case "Fake Promotion":
        return "promotion";
      case "Loan Scam":
        return "loan";
      default:
        return "safe";
    }
  };

  return (
    <div className="admin-portal-container">
      {/* SIDEBAR */}
      <aside className="admin-sidebar">
        <div className="sidebar-brand">
          <div className="brand-icon-wrapper">
            <img src={inAppIcon} alt="Argus Logo" className="brand-logo-img" />
          </div>
          <div className="brand-text">
            <h2>Argus</h2>
            <span>Admin Console</span>
          </div>
        </div>

        <nav className="sidebar-menu">
          {[
            { name: "Overview", icon: Activity },
            { name: "SMS Ingestion Logs", icon: MessageSquare, badge: smsList.filter((s) => s.status === "Fraud").length },
            { name: "Rules & Threat Engine", icon: Sliders },
            { name: "Blacklist Management", icon: ShieldAlert, badge: blacklist.length },
            { name: "Users & Devices", icon: Users },
            { name: "System Settings", icon: Settings },
          ].map((item) => {
            const Icon = item.icon;
            const isActive = activeTab === item.name;
            return (
              <button
                key={item.name}
                type="button"
                className={`sidebar-link ${isActive ? "active" : ""}`}
                onClick={() => setActiveTab(item.name)}
              >
                <Icon size={18} className="sidebar-link-icon" />
                <span>{item.name}</span>
                {item.badge !== undefined && item.badge > 0 && (
                  <span className={`menu-badge ${item.name === "Blacklist Management" ? "dark" : "danger"}`}>
                    {item.badge}
                  </span>
                )}
              </button>
            );
          })}
        </nav>

        <div className="sidebar-footer">
          <button type="button" className="theme-toggle-btn" onClick={toggleTheme}>
            {isDark ? <Sun size={18} /> : <Moon size={18} />}
            <span>{isDark ? "Light Mode" : "Dark Mode"}</span>
          </button>

          <div className="system-health-card">
            <span className="pulse-indicator"></span>
            <div>
              <strong>Gateway Connected</strong>
              <small>Gmail SMTP • PostgreSQL Active</small>
            </div>
          </div>

          <button type="button" className="logout-btn" onClick={() => onNavigate("login")}>
            <LogOut size={18} />
            <span>Logout</span>
          </button>
        </div>
      </aside>

      {/* MAIN CONTENT AREA */}
      <main className="admin-main">
        {/* TOPBAR HEADER */}
        <header className="admin-topbar">
          <div className="topbar-title">
            <h1>{activeTab}</h1>
            <p>Argus SMS Fraud Interception Platform</p>
          </div>

          <div className="topbar-actions">
            {/* SEARCH */}
            <div className="global-search-input">
              <Search size={16} className="search-icon" />
              <input
                type="text"
                placeholder="Search SMS, senders, rules..."
                value={searchQuery}
                onChange={(e: ChangeEvent<HTMLInputElement>) => setSearchQuery(e.target.value)}
              />
              {searchQuery && (
                <button type="button" className="clear-search" onClick={() => setSearchQuery("")}>
                  <X size={14} />
                </button>
              )}
            </div>

            {/* NOTIFICATION BELL */}
            <div className="notification-wrapper">
              <button
                type="button"
                className="icon-btn-circle"
                onClick={() => setIsNotificationsOpen(!isNotificationsOpen)}
              >
                <Bell size={18} />
                <span className="bell-badge">4</span>
              </button>

              {isNotificationsOpen && (
                <div className="notifications-popover">
                  <div className="popover-header">
                    <h4>Recent Security Alerts</h4>
                    <span className="popover-count">4 New</span>
                  </div>
                  <div className="popover-body">
                    {mockAlerts.map((alt) => (
                      <div key={alt.id} className={`popover-item ${alt.severity}`}>
                        <AlertTriangle size={16} className="alert-item-icon" />
                        <div>
                          <strong>{alt.title}</strong>
                          <p>{alt.description}</p>
                          <small>{alt.timeAgo}</small>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>

            {/* ADMIN PROFILE PILL */}
            <div className="admin-profile-pill">
              <div className="admin-avatar">AD</div>
              <div className="admin-info">
                <strong>System Admin</strong>
                <small>ADMINISTRATOR</small>
              </div>
            </div>
          </div>
        </header>

        {/* TAB 1: OVERVIEW */}
        {activeTab === "Overview" && (
          <div className="tab-content fade-slide">
            {/* STATS GRID */}
            <section className="stats-cards-grid">
              {mockStats.map((stat) => (
                <div key={stat.id} className="stat-card-box">
                  <div className="stat-header">
                    <span className="stat-title">{stat.title}</span>
                    <div className={`stat-icon-badge ${stat.category}`}>
                      {stat.category === "total" && <MessageSquare size={18} />}
                      {stat.category === "fraud" && <ShieldAlert size={18} />}
                      {stat.category === "safe" && <ShieldCheck size={18} />}
                      {stat.category === "pending" && <Radio size={18} />}
                    </div>
                  </div>
                  <h2 className="stat-number">{stat.value}</h2>
                  <div className="stat-footer">
                    <span className={`change-indicator ${stat.type}`}>{stat.change}</span>
                  </div>
                </div>
              ))}
            </section>

            {/* MIDDLE PANELS GRID */}
            <section className="middle-dashboard-grid">
              {/* CHART PANEL */}
              <div className="admin-panel chart-panel">
                <div className="panel-top">
                  <div>
                    <h3>Fraud Detection Velocity</h3>
                    <p>Daily intercepted scam payloads</p>
                  </div>
                  <div className="panel-badge-pill">
                    <Activity size={14} /> Live Stream
                  </div>
                </div>

                <div className="chart-wrapper">
                  <div className="chart-bars-container">
                    {mockChart.map((bar) => (
                      <div key={bar.day} className="chart-bar-column">
                        <div className="bar-value">{bar.percentage}%</div>
                        <div className="bar-track">
                          <div className="bar-fill" style={{ height: `${bar.percentage}%` }} />
                        </div>
                        <span className="bar-label">{bar.day}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              {/* THREAT ALERTS FEED */}
              <div className="admin-panel alerts-panel">
                <div className="panel-top">
                  <div>
                    <h3>Real-Time Threat Alerts</h3>
                    <p>Highest severity intercepts</p>
                  </div>
                  <button type="button" className="text-btn" onClick={() => setActiveTab("SMS Ingestion Logs")}>
                    View Logs <ArrowUpRight size={14} />
                  </button>
                </div>

                <div className="alerts-feed-list">
                  {mockAlerts.map((alt) => (
                    <div key={alt.id} className={`feed-alert-card ${alt.severity}`}>
                      <div className="feed-alert-icon">
                        {alt.severity === "high" ? <ShieldAlert size={18} /> : <AlertTriangle size={18} />}
                      </div>
                      <div className="feed-alert-content">
                        <strong>{alt.title}</strong>
                        <p>{alt.description}</p>
                        <small>{alt.timeAgo}</small>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </section>

            {/* RECENT INTERCEPTED SMS TABLE */}
            <section className="admin-panel sms-table-panel">
              <div className="panel-top">
                <div>
                  <h3>Live SMS Interception Stream</h3>
                  <p>Recent incoming messages scanned by ML & rule engine</p>
                </div>
                <button type="button" className="btn-primary" onClick={() => setActiveTab("SMS Ingestion Logs")}>
                  Full Log Inspection
                </button>
              </div>

              <div className="table-wrapper">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>Sender</th>
                      <th>Message Body</th>
                      <th>Classification</th>
                      <th>Risk Score</th>
                      <th>Date / Time</th>
                      <th>Status</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredSms.slice(0, 5).map((sms) => (
                      <tr key={sms.id}>
                        <td><code className="code-tag">{sms.id}</code></td>
                        <td className="font-semibold">{sms.sender}</td>
                        <td className="message-cell">{sms.message}</td>
                        <td>
                          <span className={`type-tag ${getBadgeClass(sms.fraudType)}`}>
                            {sms.fraudType}
                          </span>
                        </td>
                        <td>
                          <div className="risk-meter">
                            <span className="risk-val">{sms.riskScore}%</span>
                            <div className="meter-track">
                              <div
                                className={`meter-fill ${sms.riskScore > 80 ? "high" : sms.riskScore > 50 ? "medium" : "low"}`}
                                style={{ width: `${sms.riskScore}%` }}
                              />
                            </div>
                          </div>
                        </td>
                        <td className="subtle-text">{sms.date}</td>
                        <td>
                          <span className={`status-pill ${sms.status.toLowerCase()}`}>
                            {sms.status}
                          </span>
                        </td>
                        <td>
                          <button
                            type="button"
                            className="icon-action-btn"
                            onClick={() => setSelectedSms(sms)}
                            title="Inspect Details"
                          >
                            <Eye size={16} />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>

            {/* SYSTEM COMMANDS CONSOLE INSPECTOR */}
            <section className="admin-panel command-console-panel">
              <div className="panel-top">
                <div className="flex-align">
                  <Terminal size={22} style={{ color: "var(--primary)" }} />
                  <div>
                    <h3>System Command Console Inspector</h3>
                    <p>Copy & execute core backend, mobile listener, and dev server commands</p>
                  </div>
                </div>
                <span className="status-pill safe">Live Terminal Sync</span>
              </div>

              <div className="command-cards-grid">
                {[
                  {
                    id: "cmd-backend",
                    label: "Spring Boot Backend (Gmail SMTP)",
                    cmd: ".\\mvnw.cmd spring-boot:run",
                    dir: "backend/",
                    desc: "Launches Java API server on port 8080 with Gmail SMTP OTP delivery",
                  },
                  {
                    id: "cmd-dev-web",
                    label: "React Web Client (Admin Console)",
                    cmd: "cmd.exe /c \"npm run dev\"",
                    dir: "web-client/",
                    desc: "Launches React 19 Vite dev server on http://localhost:5173",
                  },
                  {
                    id: "cmd-adb-reverse",
                    label: "ADB Reverse Gateway Forwarding",
                    cmd: "adb reverse tcp:8080 tcp:8080",
                    dir: "android/",
                    desc: "Forwards localhost:8080 traffic to connected Android phone/emulator",
                  },
                  {
                    id: "cmd-flutter-app",
                    label: "Argus Flutter Mobile App",
                    cmd: "flutter run -d 45141JEKB13899",
                    dir: "frontend/",
                    desc: "Runs mobile client with live SMS interception background service",
                  },
                ].map((item) => (
                  <div key={item.id} className="command-card-box">
                    <div className="command-card-header">
                      <strong>{item.label}</strong>
                      <span className="dir-tag">{item.dir}</span>
                    </div>
                    <p className="command-desc">{item.desc}</p>
                    <div className="command-code-row">
                      <code>{item.cmd}</code>
                      <button
                        type="button"
                        className="copy-cmd-btn"
                        onClick={() => handleCopyCommand(item.id, item.cmd)}
                      >
                        {copiedCommandId === item.id ? (
                          <>
                            <Check size={14} style={{ color: "var(--emerald)" }} />
                            <span style={{ color: "var(--emerald)" }}>Copied!</span>
                          </>
                        ) : (
                          <>
                            <Copy size={14} />
                            <span>Copy</span>
                          </>
                        )}
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          </div>
        )}

        {/* TAB 2: SMS INGESTION LOGS */}
        {activeTab === "SMS Ingestion Logs" && (
          <div className="tab-content fade-slide">
            <div className="admin-panel">
              <div className="panel-top flex-wrap">
                <div>
                  <h3>SMS Ingestion Audit Logs</h3>
                  <p>Filter, search, and verify all intercepted messages</p>
                </div>

                <div className="filter-button-group">
                  {["All", "Fraud", "Review", "Safe"].map((t) => (
                    <button
                      key={t}
                      type="button"
                      className={`filter-btn ${filterType === t ? "active" : ""}`}
                      onClick={() => setFilterType(t)}
                    >
                      {t}
                    </button>
                  ))}
                </div>
              </div>

              <div className="table-wrapper">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Record ID</th>
                      <th>Sender</th>
                      <th>Message Body</th>
                      <th>Fraud Category</th>
                      <th>Risk Score</th>
                      <th>Intercept Time</th>
                      <th>Status</th>
                      <th>Inspect & Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredSms.map((sms) => (
                      <tr key={sms.id}>
                        <td><code className="code-tag">{sms.id}</code></td>
                        <td className="font-semibold">{sms.sender}</td>
                        <td className="message-cell">{sms.message}</td>
                        <td>
                          <span className={`type-tag ${getBadgeClass(sms.fraudType)}`}>
                            {sms.fraudType}
                          </span>
                        </td>
                        <td>
                          <div className="risk-meter">
                            <span className="risk-val">{sms.riskScore}%</span>
                            <div className="meter-track">
                              <div
                                className={`meter-fill ${sms.riskScore > 80 ? "high" : sms.riskScore > 50 ? "medium" : "low"}`}
                                style={{ width: `${sms.riskScore}%` }}
                              />
                            </div>
                          </div>
                        </td>
                        <td className="subtle-text">{sms.date}</td>
                        <td>
                          <span className={`status-pill ${sms.status.toLowerCase()}`}>
                            {sms.status}
                          </span>
                        </td>
                        <td>
                          <div className="action-buttons-row">
                            <button
                              type="button"
                              className="icon-action-btn"
                              onClick={() => setSelectedSms(sms)}
                              title="Inspect SMS"
                            >
                              <Eye size={16} />
                            </button>
                            {sms.status !== "Safe" && (
                              <button
                                type="button"
                                className="icon-action-btn success"
                                onClick={() => handleMarkSafe(sms.id)}
                                title="Mark Safe"
                              >
                                <CheckCircle2 size={16} />
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* TAB 3: RULES & THREAT ENGINE */}
        {activeTab === "Rules & Threat Engine" && (
          <div className="tab-content fade-slide">
            <div className="admin-panel">
              <div className="panel-top">
                <div>
                  <h3>Rule-Based Fraud Detection Engine</h3>
                  <p>Active heuristic algorithms and pattern matching definitions</p>
                </div>
                <button type="button" className="btn-primary" onClick={() => setIsAddRuleOpen(true)}>
                  <Plus size={16} /> Create Detection Rule
                </button>
              </div>

              <div className="table-wrapper">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Rule ID</th>
                      <th>Rule Name</th>
                      <th>Type</th>
                      <th>Pattern Definition</th>
                      <th>Weight</th>
                      <th>Detections</th>
                      <th>Status</th>
                      <th>Toggle</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rulesList.map((rule) => (
                      <tr key={rule.id}>
                        <td><code className="code-tag">{rule.id}</code></td>
                        <td className="font-semibold">{rule.name}</td>
                        <td>
                          <span className="type-tag blue">{rule.type}</span>
                        </td>
                        <td><code className="regex-code">{rule.pattern}</code></td>
                        <td>
                          <strong style={{ color: "var(--primary)" }}>{rule.riskWeight}%</strong>
                        </td>
                        <td>{rule.matchesCount.toLocaleString()}</td>
                        <td>
                          <span className={`status-pill ${rule.enabled ? "safe" : "review"}`}>
                            {rule.enabled ? "Active" : "Disabled"}
                          </span>
                        </td>
                        <td>
                          <label className="switch-toggle">
                            <input
                              type="checkbox"
                              checked={rule.enabled}
                              onChange={() => handleToggleRule(rule.id)}
                            />
                            <span className="slider round" />
                          </label>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* TAB 4: BLACKLIST MANAGEMENT */}
        {activeTab === "Blacklist Management" && (
          <div className="tab-content fade-slide">
            <div className="admin-panel">
              <div className="panel-top">
                <div>
                  <h3>Global Blacklisted Senders</h3>
                  <p>Phone numbers and shortcodes blocked from reaching end-users</p>
                </div>
                <button type="button" className="btn-primary" onClick={() => setIsAddBlacklistOpen(true)}>
                  <Plus size={16} /> Blacklist Number
                </button>
              </div>

              <div className="table-wrapper">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>Blocked Sender Number</th>
                      <th>Reason for Blacklisting</th>
                      <th>Added By</th>
                      <th>Date Added</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {blacklist.map((item) => (
                      <tr key={item.id}>
                        <td><code className="code-tag">{item.id}</code></td>
                        <td className="font-semibold">{item.number}</td>
                        <td>{item.reason}</td>
                        <td><span className="type-tag dark">{item.addedBy}</span></td>
                        <td className="subtle-text">{item.dateAdded}</td>
                        <td>
                          <button
                            type="button"
                            className="icon-action-btn danger"
                            onClick={() => handleRemoveBlacklist(item.id)}
                            title="Remove from Blacklist"
                          >
                            <Trash2 size={16} />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* TAB 5: USERS & DEVICES */}
        {activeTab === "Users & Devices" && (
          <div className="tab-content fade-slide">
            <div className="admin-panel">
              <div className="panel-top">
                <div>
                  <h3>User & Device Registry</h3>
                  <p>Registered users, device authorization, and account security</p>
                </div>
                <button type="button" className="btn-primary" onClick={() => alert("Creating user...")}>
                  <UserPlus size={16} /> Add User
                </button>
              </div>

              <div className="table-wrapper">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>User ID</th>
                      <th>Full Name</th>
                      <th>Email / Contact</th>
                      <th>Role</th>
                      <th>Email Verified</th>
                      <th>Status</th>
                      <th>Last Active</th>
                      <th>Account Lock</th>
                    </tr>
                  </thead>
                  <tbody>
                    {usersList.map((user) => (
                      <tr key={user.id}>
                        <td><code className="code-tag">{user.id}</code></td>
                        <td className="font-semibold">{user.name}</td>
                        <td>
                          <div>{user.email}</div>
                          <small className="subtle-text">{user.phone}</small>
                        </td>
                        <td>
                          <span className={`type-tag ${user.role === "ADMIN" ? "impersonation" : "blue"}`}>
                            {user.role}
                          </span>
                        </td>
                        <td>
                          {user.isVerified ? (
                            <span className="badge-inline green"><CheckCircle2 size={14} /> Verified</span>
                          ) : (
                            <span className="badge-inline amber"><XCircle size={14} /> Pending</span>
                          )}
                        </td>
                        <td>
                          <span className={`status-pill ${user.isLocked ? "danger" : "safe"}`}>
                            {user.isLocked ? "Locked" : "Active"}
                          </span>
                        </td>
                        <td className="subtle-text">{user.lastActive}</td>
                        <td>
                          <button
                            type="button"
                            className={`icon-action-btn ${user.isLocked ? "success" : "danger"}`}
                            onClick={() => handleToggleUserLock(user.id)}
                            title={user.isLocked ? "Unlock Account" : "Lock Account"}
                          >
                            {user.isLocked ? <Unlock size={16} /> : <Lock size={16} />}
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* TAB 6: SYSTEM SETTINGS */}
        {activeTab === "System Settings" && (
          <div className="tab-content fade-slide">
            <div className="settings-grid">
              <div className="admin-panel">
                <div className="panel-top">
                  <div>
                    <h3>SMTP Email Configuration</h3>
                    <p>Active OTP delivery channel via Gmail SMTP</p>
                  </div>
                  <span className="status-pill safe">Active</span>
                </div>

                <div className="settings-form">
                  <div className="setting-item">
                    <label>SMTP Host</label>
                    <input type="text" value="smtp.gmail.com" readOnly className="readonly-input" />
                  </div>
                  <div className="setting-item">
                    <label>SMTP Port</label>
                    <input type="text" value="587 (STARTTLS)" readOnly className="readonly-input" />
                  </div>
                  <div className="setting-item">
                    <label>Sending Email Address</label>
                    <input type="text" value="smsfraud.noreply@gmail.com" readOnly className="readonly-input" />
                  </div>
                  <div className="setting-item">
                    <label>App Password Status</label>
                    <input type="text" value="•••••••••••• (Configured via ${MAIL_APP_PASSWORD})" readOnly className="readonly-input" />
                  </div>
                </div>
              </div>

              <div className="admin-panel">
                <div className="panel-top">
                  <div>
                    <h3>SMS Interception Gateway</h3>
                    <p>Android device listener & backend sync status</p>
                  </div>
                  <span className="status-pill safe">Online</span>
                </div>

                <div className="settings-form">
                  <div className="setting-item">
                    <label>Interception Mode</label>
                    <input type="text" value="Automatic Background Ingestion" readOnly className="readonly-input" />
                  </div>
                  <div className="setting-item">
                    <label>Default Threat Alert Threshold</label>
                    <input type="text" value="80% Risk Index" readOnly className="readonly-input" />
                  </div>
                  <div className="setting-item">
                    <label>PostgreSQL Database</label>
                    <input type="text" value="jdbc:postgresql://localhost:5432/sms_fraud" readOnly className="readonly-input" />
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* INSPECT SMS MODAL */}
      {selectedSms && (
        <div className="modal-backdrop" onClick={() => setSelectedSms(null)}>
          <div className="modal-card fade-slide" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <div className="flex-align">
                <ShieldAlert size={22} style={{ color: "var(--primary)" }} />
                <h3>SMS Payload Inspection</h3>
              </div>
              <button type="button" className="close-btn" onClick={() => setSelectedSms(null)}>
                <X size={18} />
              </button>
            </div>

            <div className="modal-body">
              <div className="modal-info-row">
                <div>
                  <small>RECORD ID</small>
                  <strong>{selectedSms.id}</strong>
                </div>
                <div>
                  <small>SENDER NUMBER</small>
                  <strong>{selectedSms.sender}</strong>
                </div>
                <div>
                  <small>DATE / TIME</small>
                  <strong>{selectedSms.date}</strong>
                </div>
              </div>

              <div className="modal-field">
                <label>INTERCEPTED MESSAGE BODY</label>
                <div className="message-box">{selectedSms.message}</div>
              </div>

              <div className="modal-info-row margin-top">
                <div>
                  <small>CLASSIFICATION</small>
                  <span className={`type-tag ${getBadgeClass(selectedSms.fraudType)}`}>
                    {selectedSms.fraudType}
                  </span>
                </div>
                <div>
                  <small>CALCULATED THREAT SCORE</small>
                  <div className="risk-meter">
                    <strong style={{ color: selectedSms.riskScore > 80 ? "var(--primary)" : "var(--amber)" }}>
                      {selectedSms.riskScore}%
                    </strong>
                  </div>
                </div>
              </div>
            </div>

            <div className="modal-footer">
              <button type="button" className="btn-secondary" onClick={() => handleMarkSafe(selectedSms.id)}>
                <CheckCircle2 size={16} /> Mark as Safe
              </button>
              <button type="button" className="btn-primary danger" onClick={() => handleBlacklistFromModal(selectedSms)}>
                <ShieldAlert size={16} /> Confirm Fraud & Blacklist Sender
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ADD RULE MODAL */}
      {isAddRuleOpen && (
        <div className="modal-backdrop" onClick={() => setIsAddRuleOpen(false)}>
          <div className="modal-card fade-slide" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Add Detection Rule</h3>
              <button type="button" className="close-btn" onClick={() => setIsAddRuleOpen(false)}>
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleAddRule}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Rule Name</label>
                  <input
                    type="text"
                    placeholder="e.g. Fake Bank Account Closure"
                    value={newRuleName}
                    onChange={(e) => setNewRuleName(e.target.value)}
                    required
                  />
                </div>

                <div className="form-group">
                  <label>Rule Type</label>
                  <select
                    value={newRuleType}
                    onChange={(e) => setNewRuleType(e.target.value as DetectionRule["type"])}
                  >
                    <option value="Keyword">Keyword Match</option>
                    <option value="Regex Pattern">Regex Pattern</option>
                    <option value="Link Analyzer">Link Analyzer Domain</option>
                    <option value="Sender Spoofing">Sender Spoofing</option>
                  </select>
                </div>

                <div className="form-group">
                  <label>Pattern Definition (Regex or String)</label>
                  <input
                    type="text"
                    placeholder="e.g. (tuma|lipia)\s+.*(namba)"
                    value={newRulePattern}
                    onChange={(e) => setNewRulePattern(e.target.value)}
                    required
                  />
                </div>

                <div className="form-group">
                  <label>Threat Weight Index ({newRuleWeight}%)</label>
                  <input
                    type="range"
                    min="10"
                    max="100"
                    value={newRuleWeight}
                    onChange={(e) => setNewRuleWeight(Number(e.target.value))}
                  />
                </div>
              </div>

              <div className="modal-footer">
                <button type="button" className="btn-secondary" onClick={() => setIsAddRuleOpen(false)}>
                  Cancel
                </button>
                <button type="submit" className="btn-primary">
                  Save Rule
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ADD BLACKLIST MODAL */}
      {isAddBlacklistOpen && (
        <div className="modal-backdrop" onClick={() => setIsAddBlacklistOpen(false)}>
          <div className="modal-card fade-slide" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Blacklist Sender Number</h3>
              <button type="button" className="close-btn" onClick={() => setIsAddBlacklistOpen(false)}>
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleAddBlacklist}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Phone Number or Sender ID</label>
                  <input
                    type="text"
                    placeholder="e.g. +255 712 345 678"
                    value={newBlacklistNumber}
                    onChange={(e) => setNewBlacklistNumber(e.target.value)}
                    required
                  />
                </div>

                <div className="form-group">
                  <label>Reason for Blacklisting</label>
                  <textarea
                    placeholder="e.g. Repeated phishing attempt with scam URL"
                    value={newBlacklistReason}
                    onChange={(e) => setNewBlacklistReason(e.target.value)}
                    rows={3}
                  />
                </div>
              </div>

              <div className="modal-footer">
                <button type="button" className="btn-secondary" onClick={() => setIsAddBlacklistOpen(false)}>
                  Cancel
                </button>
                <button type="submit" className="btn-primary danger">
                  Add to Blacklist
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default DashboardPage;