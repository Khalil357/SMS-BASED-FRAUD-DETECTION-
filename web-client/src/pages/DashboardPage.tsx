import React, { useState } from "react";
import type { ChangeEvent } from "react";
import "./DashboardPage.css";
import type {
  StatCardData,
  ChartBarData,
  AlertData,
  SmsRecord,
} from "../types/dashboard";
import type { AuthPage } from "../types/auth";
import { useTheme } from "../theme/ThemeContext";

interface DashboardPageProps {
  onNavigate: (page: AuthPage) => void;
}

const mockStats: StatCardData[] = [
  {
    id: "1",
    title: "Total SMS",
    value: "12,450",
    change: "12.5% this month",
    type: "positive",
    category: "total",
    icon: "fa-solid fa-message",
  },
  {
    id: "2",
    title: "Fraud Detected",
    value: "2,340",
    change: "8.2% this month",
    type: "negative",
    category: "fraud",
    icon: "fa-solid fa-triangle-exclamation",
  },
  {
    id: "3",
    title: "Safe SMS",
    value: "9,820",
    change: "5.4% this month",
    type: "positive",
    category: "safe",
    icon: "fa-solid fa-shield-halved",
  },
  {
    id: "4",
    title: "Pending Review",
    value: "290",
    change: "Requires attention",
    type: "warning",
    category: "pending",
    icon: "fa-solid fa-clock",
  },
];

const mockChart: ChartBarData[] = [
  { day: "Mon", percentage: 45 },
  { day: "Tue", percentage: 62 },
  { day: "Wed", percentage: 52 },
  { day: "Thu", percentage: 78 },
  { day: "Fri", percentage: 65 },
  { day: "Sat", percentage: 90 },
  { day: "Sun", percentage: 72 },
];

const mockAlerts: AlertData[] = [
  {
    id: "1",
    title: "High Risk SMS Detected",
    description: "Fraud score: 94%",
    timeAgo: "5 minutes ago",
    severity: "high",
    icon: "fa-solid fa-triangle-exclamation",
  },
  {
    id: "2",
    title: "Suspicious Sender",
    description: "+255 712 XXX XXX",
    timeAgo: "18 minutes ago",
    severity: "medium",
    icon: "fa-solid fa-shield",
  },
  {
    id: "3",
    title: "Phishing Attempt",
    description: "Fake mobile money message",
    timeAgo: "32 minutes ago",
    severity: "high",
    icon: "fa-solid fa-bug",
  },
  {
    id: "4",
    title: "System Scan Completed",
    description: "1,240 messages scanned",
    timeAgo: "1 hour ago",
    severity: "low",
    icon: "fa-solid fa-circle-check",
  },
];

const mockSms: SmsRecord[] = [
  {
    id: "1",
    sender: "+255 712 345 678",
    message: "Congratulations! You have won a cash prize...",
    fraudType: "Phishing",
    riskScore: 94,
    date: "27 Aug 2026",
    status: "Fraud",
  },
  {
    id: "2",
    sender: "+255 754 123 890",
    message: "Your mobile account has been suspended...",
    fraudType: "Impersonation",
    riskScore: 89,
    date: "27 Aug 2026",
    status: "Fraud",
  },
  {
    id: "3",
    sender: "+255 713 456 789",
    message: "You have been selected for a special promotion...",
    fraudType: "Fake Promotion",
    riskScore: 82,
    date: "26 Aug 2026",
    status: "Fraud",
  },
  {
    id: "4",
    sender: "+255 765 222 111",
    message: "Your loan application has been approved...",
    fraudType: "Loan Scam",
    riskScore: 76,
    date: "26 Aug 2026",
    status: "Review",
  },
];

export const DashboardPage: React.FC<DashboardPageProps> = ({ onNavigate }) => {
  const { isDark, toggleTheme } = useTheme();
  const [activeTab, setActiveTab] = useState<string>("Dashboard");
  const [searchQuery, setSearchQuery] = useState<string>("");
  const [period, setPeriod] = useState<string>("Last 7 Days");

  const filteredSms = mockSms.filter((item) => {
    const query = searchQuery.toLowerCase();
    return (
      item.sender.toLowerCase().includes(query) ||
      item.message.toLowerCase().includes(query) ||
      item.fraudType.toLowerCase().includes(query)
    );
  });

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
        return "";
    }
  };

  return (
    <div className="dashboard-container">
      <aside className="sidebar">
        <div className="logo">
          <div className="logo-circle">
            <i className="fa-solid fa-shield-halved"></i>
          </div>
          <div>
            <h2>SMS Guard</h2>
            <span>Fraud Detection</span>
          </div>
        </div>

        <nav className="menu">
          {[
            { name: "Dashboard", icon: "fa-house" },
            { name: "SMS Management", icon: "fa-message" },
            { name: "Fraud Detection", icon: "fa-triangle-exclamation" },
            { name: "Alerts", icon: "fa-bell", badge: 5 },
            { name: "Reports", icon: "fa-chart-line" },
            { name: "Users", icon: "fa-users" },
            { name: "Senders", icon: "fa-user-shield" },
            { name: "Settings", icon: "fa-gear" },
          ].map((item) => (
            <a
              key={item.name}
              href="#"
              className={`menu-item ${activeTab === item.name ? "active" : ""}`}
              onClick={(e) => {
                e.preventDefault();
                setActiveTab(item.name);
              }}
            >
              <i className={`fa-solid ${item.icon}`}></i>
              <span>{item.name}</span>
              {item.badge && (
                <span className="notification-badge">{item.badge}</span>
              )}
            </a>
          ))}
        </nav>

        <div className="sidebar-bottom">
          <a
            href="#"
            className="menu-item"
            onClick={(e) => {
              e.preventDefault();
              toggleTheme();
            }}
            style={{ marginBottom: "12px" }}
          >
            <i className={`fa-solid ${isDark ? "fa-sun" : "fa-moon"}`}></i>
            <span>{isDark ? "Light Mode" : "Dark Mode"}</span>
          </a>

          <div className="system-status">
            <span className="status-dot"></span>
            <div>
              <strong>System Online</strong>
              <small>All services running</small>
            </div>
          </div>

          <button className="logout" onClick={() => onNavigate("login")}>
            <i className="fa-solid fa-right-from-bracket"></i>
            <span>Logout</span>
          </button>
        </div>
      </aside>

      <main className="main">
        <header className="topbar">
          <div>
            <h1>Dashboard</h1>
            <p>Welcome back</p>
          </div>

          <div className="topbar-right">
            <div className="search-box">
              <i className="fa-solid fa-magnifying-glass"></i>
              <input
                type="text"
                placeholder="Search SMS..."
                value={searchQuery}
                onChange={(e: ChangeEvent<HTMLInputElement>) =>
                  setSearchQuery(e.target.value)
                }
              />
            </div>

            <button
              className="icon-button"
              onClick={() => alert("Viewing Notifications")}
            >
              <i className="fa-solid fa-bell"></i>
              <span className="notification-dot"></span>
            </button>

            <div className="admin-profile">
              <div className="avatar">AD</div>
              <div>
                <strong>Admin</strong>
                <small>Administrator</small>
              </div>
              <i className="fa-solid fa-chevron-down"></i>
            </div>
          </div>
        </header>

        <section className="stats-grid">
          {mockStats.map((stat) => (
            <div key={stat.id} className="stat-card">
              <div className={`stat-icon ${stat.category}`}>
                <i className={stat.icon}></i>
              </div>
              <div className="stat-info">
                <span>{stat.title}</span>
                <h2>{stat.value}</h2>
                <small className={stat.type}>
                  {stat.type !== "warning" && (
                    <i className="fa-solid fa-arrow-up"></i>
                  )}
                  {stat.change}
                </small>
              </div>
            </div>
          ))}
        </section>

        <section className="middle-grid">
          <div className="panel">
            <div className="panel-header">
              <div>
                <h3>Fraud Detection Trend</h3>
                <p>Number of fraudulent SMS detected</p>
              </div>
              <select
                value={period}
                onChange={(e: ChangeEvent<HTMLSelectElement>) =>
                  setPeriod(e.target.value)
                }
              >
                <option value="Last 7 Days">Last 7 Days</option>
                <option value="Last 30 Days">Last 30 Days</option>
              </select>
            </div>

            <div className="chart-container">
              <div className="chart-y-axis">
                <span>500</span>
                <span>400</span>
                <span>300</span>
                <span>200</span>
                <span>100</span>
                <span>0</span>
              </div>
              <div className="chart">
                {[0, 20, 40, 60, 80].map((top) => (
                  <div
                    key={top}
                    className="grid-line"
                    style={{ top: `${top}%` }}
                  ></div>
                ))}
                <div className="bars">
                  {mockChart.map((bar) => (
                    <div key={bar.day} className="bar-wrapper">
                      <div
                        className="bar"
                        style={{ height: `${bar.percentage}%` }}
                      ></div>
                      <span>{bar.day}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>

          <div className="panel">
            <div className="panel-header">
              <div>
                <h3>Recent Alerts</h3>
                <p>Latest system notifications</p>
              </div>
              <button
                className="view-all"
                onClick={() => alert("Opening alerts...")}
              >
                View All
              </button>
            </div>

            <div className="alerts-list">
              {mockAlerts.map((alertItem) => (
                <div
                  key={alertItem.id}
                  className={`alert-item ${alertItem.severity}`}
                >
                  <div className="alert-icon">
                    <i className={alertItem.icon}></i>
                  </div>
                  <div className="alert-content">
                    <strong>{alertItem.title}</strong>
                    <p>{alertItem.description}</p>
                    <small>{alertItem.timeAgo}</small>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="panel sms-panel">
          <div className="panel-header">
            <div>
              <h3>Recent Fraudulent SMS</h3>
              <p>Recently detected suspicious messages</p>
            </div>
            <button
              className="primary-button"
              onClick={() => alert("Opening SMS list...")}
            >
              <i className="fa-solid fa-plus"></i> View All SMS
            </button>
          </div>

          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th>Sender</th>
                  <th>Message</th>
                  <th>Fraud Type</th>
                  <th>Risk Score</th>
                  <th>Date</th>
                  <th>Status</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {filteredSms.map((sms) => (
                  <tr key={sms.id}>
                    <td>
                      <div className="sender">
                        <div className="sender-icon">
                          <i className="fa-solid fa-user"></i>
                        </div>
                        {sms.sender}
                      </div>
                    </td>
                    <td className="message">{sms.message}</td>
                    <td>
                      <span
                        className={`type-badge ${getBadgeClass(sms.fraudType)}`}
                      >
                        {sms.fraudType}
                      </span>
                    </td>
                    <td>
                      <div className="risk">
                        <span>{sms.riskScore}%</span>
                        <div className="risk-bar">
                          <div style={{ width: `${sms.riskScore}%` }}></div>
                        </div>
                      </div>
                    </td>
                    <td>{sms.date}</td>
                    <td>
                      <span
                        className={`status-badge ${sms.status === "Fraud" ? "danger" : "review"}`}
                      >
                        {sms.status}
                      </span>
                    </td>
                    <td>
                      <button
                        className="action-button"
                        onClick={() =>
                          alert(
                            `SMS DETAILS\n\nSender: ${sms.sender}\nMessage: ${sms.message}\nType: ${sms.fraudType}\nRisk: ${sms.riskScore}%`,
                          )
                        }
                      >
                        <i className="fa-solid fa-eye"></i>
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className="quick-actions">
          <h3>Quick Actions</h3>
          <div className="quick-grid">
            {[
              { label: "Analyze SMS", icon: "fa-message" },
              { label: "Generate Report", icon: "fa-file-lines" },
              { label: "Add User", icon: "fa-user-plus" },
              { label: "Manage Senders", icon: "fa-ban" },
            ].map((action) => (
              <button
                key={action.label}
                className="quick-card"
                onClick={() => alert(`${action.label} clicked`)}
              >
                <i className={`fa-solid ${action.icon}`}></i>
                <span>{action.label}</span>
              </button>
            ))}
          </div>
        </section>
      </main>
    </div>
  );
};

export default DashboardPage;