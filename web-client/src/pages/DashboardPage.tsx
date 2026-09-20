import React, { useEffect, useState, useMemo } from "react";
import "./DashboardPage.css";
import type {
  StatCardData,
  SmsRecord,
  DetectionRule,
} from "../types/dashboard";
import type { AuthPage } from "../types/auth";
import { useTheme } from "../theme/ThemeContext";
import {
  ShieldAlert,
  MessageSquare,
  Users,
  Activity,
  Plus,
  Trash2,
  Eye,
  EyeOff,
  CheckCircle2,
  XCircle,
  Moon,
  Sun,
  LogOut,
  Sliders,
  UserPlus,
  X,
  Pencil,
  KeyRound,
  UserCheck,
  Search,
  Filter,
  RotateCcw,
  Menu,
} from "lucide-react";
import inAppIcon from "../assets/images/in_app_icon.png";
import {
  getUsers,
  createUser,
  updateUser,
  resetUserPassword,
  deleteUser,
  getCurrentUserId,
  getAdminStats,
  getFraudTrend,
  getSmsScans,
} from "../services/adminService";
import type { AdminUser } from "../services/adminService";

interface DashboardPageProps {
  onNavigate: (page: AuthPage) => void;
}

/** Strict email format: local@domain.tld ending with valid domain. */
const EMAIL_PATTERN = /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$/;

/** Tanzanian Phone Validation: +255 followed by 9 digits starting with 6 or 7. */
const TZ_PHONE_PATTERN = /^\+255[67]\d{8}$/;

/** Strict Password Validator: Min 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special character. */
function validatePasswordStrength(pass: string): string | null {
  if (!pass) return "Password is required";
  if (pass.length < 8) return "Password must be at least 8 characters long";
  if (!/[A-Z]/.test(pass)) return "Password must contain at least one uppercase letter (A-Z)";
  if (!/[a-z]/.test(pass)) return "Password must contain at least one lowercase letter (a-z)";
  if (!/[0-9]/.test(pass)) return "Password must contain at least one number (0-9)";
  if (!/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(pass)) {
    return "Password must contain at least one special character (!@#$%...)";
  }
  return null;
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
    title: "Fraud & Scams Detected",
    value: "2,840",
    change: "98.4% detection rate",
    type: "negative",
    category: "fraud",
  },
];

const initialSmsRecords: SmsRecord[] = [
  {
    id: "SMS-8910",
    sender: "+255746046202",
    message: "Hongera! Umeshinda TZS 2,500,000 kutoka Vodacom. Bonyeza link http://voda-tuzo.com au piga 0746046202 kudai zawadi yako.",
    fraudType: "Phishing",
    riskScore: 96,
    date: "03 Sep 2026 14:22",
    status: "Fraud",
  },
  {
    id: "SMS-8909",
    sender: "+255754123890",
    message: "Tuma zile pesa elfu 50 kwenye namba hii 0754123890 kwa jina la Juma Kabwe. Usipime namba ile nyingine imefungwa.",
    fraudType: "Impersonation",
    riskScore: 91,
    date: "03 Sep 2026 13:45",
    status: "Fraud",
  },
  {
    id: "SMS-8908",
    sender: "+255713456789",
    message: "LOAN APPROVED! Mkopo wako wa TZS 500,000 umekubaliwa. Lipia ada ya usajili TZS 10,000 kupitia http://mkopo-fast.com",
    fraudType: "Loan Scam",
    riskScore: 88,
    date: "03 Sep 2026 12:10",
    status: "Fraud",
  },
  {
    id: "SMS-8907",
    sender: "+255765222111",
    message: "Ndugu mteja, akaunti yako ya Benki imefungwa kwa muda. Tafadhali thibitisha taarifa zako sasa hivi hapa: http://crdb-verify.org",
    fraudType: "Phishing",
    riskScore: 94,
    date: "03 Sep 2026 11:05",
    status: "Fraud",
  },
  {
    id: "SMS-8906",
    sender: "+255789900112",
    message: "Kaka hio hela ya kodi tuma kwenye hii namba badala ya ile ya mwanzo. Namba mpya ni 0789900112 Asante.",
    fraudType: "Impersonation",
    riskScore: 78,
    date: "03 Sep 2026 09:30",
    status: "Fraud",
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

export const DashboardPage: React.FC<DashboardPageProps> = ({ onNavigate }) => {
  const { isDark, toggleTheme } = useTheme();

  // Mobile Navigation Drawer Toggle State
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  // ── URL ↔ Tab sync ──────────────────────────────────────────────
  const TAB_SLUGS: Record<string, string> = {
    "Overview":              "/",
    "SMS Ingestion Logs":    "/logs",
    "Rules & Threat Engine": "/rules",
    "Team":                  "/team",
    "Users":                 "/users",
  };
  const SLUG_TABS: Record<string, string> = Object.fromEntries(
    Object.entries(TAB_SLUGS).map(([tab, slug]) => [slug, tab])
  );

  function tabFromPath(): string {
    const slug = window.location.pathname;
    return SLUG_TABS[slug] ?? "Overview";
  }

  // Active Tab
  const [activeTab, setActiveTab] = useState<string>(() => tabFromPath());

  // Helper to switch tab & auto-close drawer on mobile
  const handleTabClick = (tabName: string) => {
    setActiveTab(tabName);
    setMobileMenuOpen(false);
  };

  // Main Data States
  const [statsCards, setStatsCards] = useState<StatCardData[]>(mockStats);
  const [smsList, setSmsList] = useState<SmsRecord[]>(initialSmsRecords);
  const [rulesList, setRulesList] = useState<DetectionRule[]>(initialRules);
  const [usersList, setUsersList] = useState<AdminUser[]>([]);
  const [usersLoading, setUsersLoading] = useState(false);
  const [usersError, setUsersError] = useState<string | null>(null);
  const [toast, setToast] = useState<{ type: "success" | "error"; message: string } | null>(null);

  // SEARCH, FILTER & CLICK-TO-SORT STATES

  // 1. Team Tab
  const [teamSearch, setTeamSearch] = useState("");
  const [teamStatusFilter, setTeamStatusFilter] = useState<"All" | "Active" | "Inactive">("All");
  const [teamSortField, setTeamSortField] = useState<"full_name" | "email" | "active">("full_name");
  const [teamSortDir, setTeamSortDir] = useState<"asc" | "desc">("asc");

  // 2. Users Tab
  const [appUsersSearch, setAppUsersSearch] = useState("");
  const [appUsersVerificationFilter, setAppUsersVerificationFilter] = useState<"All" | "Verified" | "Pending">("All");
  const [appUsersStatusFilter, setAppUsersStatusFilter] = useState<"All" | "Active" | "Inactive">("All");
  const [appUsersSortField, setAppUsersSortField] = useState<"user_id" | "full_name" | "email" | "verified" | "active">("full_name");
  const [appUsersSortDir, setAppUsersSortDir] = useState<"asc" | "desc">("asc");

  // 3. SMS Ingestion Logs Tab
  const [logsSearch, setLogsSearch] = useState("");
  const [logsSortField, setLogsSortField] = useState<"id" | "sender" | "date">("date");
  const [logsSortDir, setLogsSortDir] = useState<"asc" | "desc">("desc");

  // 4. Rules & Threat Engine Tab
  const [rulesSearch, setRulesSearch] = useState("");
  const [rulesTypeFilter, setRulesTypeFilter] = useState<string>("All");
  const [rulesStatusFilter, setRulesStatusFilter] = useState<"All" | "Active" | "Disabled">("All");
  const [rulesSortField, setRulesSortField] = useState<"id" | "name" | "type" | "riskWeight" | "matchesCount" | "enabled">("matchesCount");
  const [rulesSortDir, setRulesSortDir] = useState<"asc" | "desc">("desc");

  // Add Admin form state
  const [isAddUserOpen, setIsAddUserOpen] = useState(false);
  const [addUserBusy, setAddUserBusy] = useState(false);
  const [addUserFullName, setAddUserFullName] = useState("");
  const [addUserEmail, setAddUserEmail] = useState("");
  const [addUserPhone, setAddUserPhone] = useState("+255");
  const [addUserPassword, setAddUserPassword] = useState("");
  const [addUserConfirmPassword, setAddUserConfirmPassword] = useState("");
  const [addUserGender, setAddUserGender] = useState<"MALE" | "FEMALE" | "">("");
  const [showAddUserPassword, setShowAddUserPassword] = useState(false);
  const [showAddUserConfirmPassword, setShowAddUserConfirmPassword] = useState(false);
  const [addUserErrors, setAddUserErrors] = useState<Record<string, string>>({});

  // Edit User form state
  const [isEditUserOpen, setIsEditUserOpen] = useState(false);
  const [editUserBusy, setEditUserBusy] = useState(false);
  const [editUserId, setEditUserId] = useState<string>("");
  const [editUserFullName, setEditUserFullName] = useState("");
  const [editUserEmail, setEditUserEmail] = useState("");
  const [editUserPhone, setEditUserPhone] = useState("+255");
  const [editUserActive, setEditUserActive] = useState(true);
  const [editUserErrors, setEditUserErrors] = useState<Record<string, string>>({});

  // Reset Password state
  const [isResetPasswordOpen, setIsResetPasswordOpen] = useState(false);
  const [resetPasswordBusy, setResetPasswordBusy] = useState(false);
  const [resetPasswordValue, setResetPasswordValue] = useState("");
  const [resetPasswordConfirm, setResetPasswordConfirm] = useState("");
  const [showResetPassword, setShowResetPassword] = useState(false);
  const [showResetPasswordConfirm, setShowResetPasswordConfirm] = useState(false);
  const [resetPasswordErrors, setResetPasswordErrors] = useState<Record<string, string>>({});

  // Delete User state
  const [deleteTarget, setDeleteTarget] = useState<AdminUser | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);

  // Modals
  const [selectedSms, setSelectedSms] = useState<SmsRecord | null>(null);
  const [isAddRuleOpen, setIsAddRuleOpen] = useState(false);

  // Admin Profile state
  const [adminName, setAdminName] = useState("System Admin");

  const [hoveredTelemetryIndex, setHoveredTelemetryIndex] = useState<number | null>(null);

  // Form states for rules
  const [newRuleName, setNewRuleName] = useState("");
  const [newRulePattern, setNewRulePattern] = useState("");
  const [newRuleType, setNewRuleType] = useState<DetectionRule["type"]>("Keyword");
  const [newRuleWeight, setNewRuleWeight] = useState(85);

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

  const currentUserId = getCurrentUserId();

  function showToast(type: "success" | "error", message: string) {
    setToast({ type, message });
    window.setTimeout(() => setToast(null), 3500);
  }

  async function loadDashboardStats() {
    const res = await getAdminStats();
    if (res.success && res.data) {
      setStatsCards([
        {
          id: "1",
          title: "Total SMS Scanned",
          value: Number(res.data.total_sms).toLocaleString(),
          change: "Database total",
          type: "positive",
          category: "total",
        },
        {
          id: "2",
          title: "Fraud & Scams Detected",
          value: Number(res.data.fraud_detected).toLocaleString(),
          change: `${res.data.total_sms > 0 ? ((res.data.fraud_detected / res.data.total_sms) * 100).toFixed(1) : "0"}% detection rate`,
          type: "negative",
          category: "fraud",
        },
      ]);
    }
  }

  async function loadFraudTrends() {
    await getFraudTrend(7);
  }

  async function loadSmsAuditScans() {
    const res = await getSmsScans("Fraud", 0, 100);
    if (res.success && res.data) {
      const records = Array.isArray(res.data) ? res.data : (res.data as any)?.content || [];
      if (records.length > 0) {
        const mapped: SmsRecord[] = records.map((item: any, idx: number) => {
          let dateStr = "Recently";
          if (item.timestamp) {
            try {
              dateStr = new Date(item.timestamp).toLocaleString("en-GB", {
                day: "2-digit",
                month: "short",
                year: "numeric",
                hour: "2-digit",
                minute: "2-digit",
              });
            } catch {
              dateStr = item.timestamp;
            }
          }
          return {
            id: item.id ? `SMS-${String(item.id).substring(0, 6).toUpperCase()}` : `SMS-${8910 - idx}`,
            sender: item.sender || "+255746046202",
            message: item.message || "",
            fraudType: (item.fraudType || "Phishing") as SmsRecord["fraudType"],
            riskScore: Math.round(item.riskScore || 90),
            date: dateStr,
            status: "Fraud",
          };
        });
        setSmsList(mapped);
      }
    }
  }

  async function loadUsers() {
    setUsersLoading(true);
    setUsersError(null);
    const res = await getUsers();
    setUsersLoading(false);
    if (res.success && res.data) {
      setUsersList(res.data);

      if (currentUserId) {
        const currentUser = res.data.find((u) => u.user_id === currentUserId);
        if (currentUser && currentUser.full_name) {
          setAdminName(currentUser.full_name);
        } else if (currentUser && currentUser.email) {
          setAdminName(currentUser.email);
        }
      } else if (res.data.length > 0 && res.data[0].full_name) {
        setAdminName(res.data[0].full_name);
      }
    } else {
      setUsersError(res.message ?? "Failed to load users");
    }
  }

  useEffect(() => {
    void loadUsers();
    void loadDashboardStats();
    void loadFraudTrends();
    void loadSmsAuditScans();
  }, []);

  useEffect(() => {
    if (activeTab === "Overview") {
      void loadDashboardStats();
      void loadFraudTrends();
      void loadSmsAuditScans();
    } else if (activeTab === "SMS Ingestion Logs") {
      void loadSmsAuditScans();
    } else if (activeTab === "Team" || activeTab === "Users") {
      void loadUsers();
    }
  }, [activeTab]);

  // ── Keep browser URL in sync with active tab ─────────────────────
  useEffect(() => {
    const slug = TAB_SLUGS[activeTab] ?? "/";
    if (window.location.pathname !== slug) {
      window.history.pushState(null, "", slug);
    }
  }, [activeTab]);

  // Click-to-Sort Handler Helper
  function handleSortToggle<T extends string>(
    field: T,
    currentField: T,
    currentDir: "asc" | "desc",
    setField: (f: T) => void,
    setDir: (d: "asc" | "desc") => void
  ) {
    if (currentField === field) {
      setDir(currentDir === "asc" ? "desc" : "asc");
    } else {
      setField(field);
      setDir("asc");
    }
  }

  // 1. Team Administrators List Logic
  const filteredTeamList = useMemo(() => {
    let list = usersList.filter((u: any) => {
      const roleVal = String(u.role || u.role_id || "").toUpperCase();
      return roleVal === "ADMIN" || roleVal === "ROLE_ADMIN" || roleVal === "1";
    });

    if (teamSearch.trim()) {
      const q = teamSearch.toLowerCase().trim();
      list = list.filter(
        (u) =>
          (u.full_name && u.full_name.toLowerCase().includes(q)) ||
          u.email.toLowerCase().includes(q) ||
          (u.phone && u.phone.includes(q))
      );
    }

    if (teamStatusFilter !== "All") {
      const isActive = teamStatusFilter === "Active";
      list = list.filter((u) => u.active === isActive);
    }

    return [...list].sort((a, b) => {
      let valA: string | number | boolean = "";
      let valB: string | number | boolean = "";

      if (teamSortField === "full_name") {
        valA = (a.full_name || a.email).toLowerCase();
        valB = (b.full_name || b.email).toLowerCase();
      } else if (teamSortField === "email") {
        valA = a.email.toLowerCase();
        valB = b.email.toLowerCase();
      } else if (teamSortField === "active") {
        valA = a.active ? 1 : 0;
        valB = b.active ? 1 : 0;
      }

      if (valA < valB) return teamSortDir === "asc" ? -1 : 1;
      if (valA > valB) return teamSortDir === "asc" ? 1 : -1;
      return 0;
    });
  }, [usersList, teamSearch, teamStatusFilter, teamSortField, teamSortDir]);

  // Reset Team Filters
  const isTeamFiltered = teamSearch !== "" || teamStatusFilter !== "All" || teamSortField !== "full_name" || teamSortDir !== "asc";
  function resetTeamFilters() {
    setTeamSearch("");
    setTeamStatusFilter("All");
    setTeamSortField("full_name");
    setTeamSortDir("asc");
  }

  // 2. Mobile App Users List Logic
  const filteredAppUsersList = useMemo(() => {
    let list = usersList.filter((u: any) => {
      const roleVal = String(u.role || u.role_id || "").toUpperCase();
      return roleVal === "USER" || roleVal === "ROLE_USER" || roleVal === "2" || !u.role;
    });

    if (appUsersSearch.trim()) {
      const q = appUsersSearch.toLowerCase().trim();
      list = list.filter(
        (u) =>
          (u.full_name && u.full_name.toLowerCase().includes(q)) ||
          u.email.toLowerCase().includes(q) ||
          (u.phone && u.phone.includes(q)) ||
          u.user_id.toLowerCase().includes(q)
      );
    }

    if (appUsersVerificationFilter !== "All") {
      const isVerified = appUsersVerificationFilter === "Verified";
      list = list.filter((u) => u.verified === isVerified);
    }

    if (appUsersStatusFilter !== "All") {
      const isActive = appUsersStatusFilter === "Active";
      list = list.filter((u) => u.active === isActive);
    }

    return [...list].sort((a, b) => {
      let valA: string | number | boolean = "";
      let valB: string | number | boolean = "";

      if (appUsersSortField === "user_id") {
        valA = a.user_id;
        valB = b.user_id;
      } else if (appUsersSortField === "full_name") {
        valA = (a.full_name || a.email).toLowerCase();
        valB = (b.full_name || b.email).toLowerCase();
      } else if (appUsersSortField === "email") {
        valA = a.email.toLowerCase();
        valB = b.email.toLowerCase();
      } else if (appUsersSortField === "verified") {
        valA = a.verified ? 1 : 0;
        valB = b.verified ? 1 : 0;
      } else if (appUsersSortField === "active") {
        valA = a.active ? 1 : 0;
        valB = b.active ? 1 : 0;
      }

      if (valA < valB) return appUsersSortDir === "asc" ? -1 : 1;
      if (valA > valB) return appUsersSortDir === "asc" ? 1 : -1;
      return 0;
    });
  }, [usersList, appUsersSearch, appUsersVerificationFilter, appUsersStatusFilter, appUsersSortField, appUsersSortDir]);

  // Reset Users Filters
  const isAppUsersFiltered = appUsersSearch !== "" || appUsersVerificationFilter !== "All" || appUsersStatusFilter !== "All" || appUsersSortField !== "full_name" || appUsersSortDir !== "asc";
  function resetAppUsersFilters() {
    setAppUsersSearch("");
    setAppUsersVerificationFilter("All");
    setAppUsersStatusFilter("All");
    setAppUsersSortField("full_name");
    setAppUsersSortDir("asc");
  }

  // 3. SMS Ingestion Logs Logic
  const filteredLogsList = useMemo(() => {
    let list = smsList;

    if (logsSearch.trim()) {
      const q = logsSearch.toLowerCase().trim();
      list = list.filter(
        (s) =>
          s.id.toLowerCase().includes(q) ||
          s.sender.toLowerCase().includes(q) ||
          s.message.toLowerCase().includes(q)
      );
    }

    return [...list].sort((a, b) => {
      let valA: string = "";
      let valB: string = "";

      if (logsSortField === "id") {
        valA = a.id;
        valB = b.id;
      } else if (logsSortField === "sender") {
        valA = a.sender;
        valB = b.sender;
      } else if (logsSortField === "date") {
        valA = a.date;
        valB = b.date;
      }

      if (valA < valB) return logsSortDir === "asc" ? -1 : 1;
      if (valA > valB) return logsSortDir === "asc" ? 1 : -1;
      return 0;
    });
  }, [smsList, logsSearch, logsSortField, logsSortDir]);

  const isLogsFiltered = logsSearch !== "" || logsSortField !== "date" || logsSortDir !== "desc";
  function resetLogsFilters() {
    setLogsSearch("");
    setLogsSortField("date");
    setLogsSortDir("desc");
  }

  // 4. Rules Engine Logic
  const filteredRulesList = useMemo(() => {
    let list = rulesList;

    if (rulesSearch.trim()) {
      const q = rulesSearch.toLowerCase().trim();
      list = list.filter(
        (r) =>
          r.name.toLowerCase().includes(q) ||
          r.pattern.toLowerCase().includes(q) ||
          r.id.toLowerCase().includes(q)
      );
    }

    if (rulesTypeFilter !== "All") {
      list = list.filter((r) => r.type === rulesTypeFilter);
    }

    if (rulesStatusFilter !== "All") {
      const isEnabled = rulesStatusFilter === "Active";
      list = list.filter((r) => r.enabled === isEnabled);
    }

    return [...list].sort((a, b) => {
      let valA: string | number = "";
      let valB: string | number = "";

      if (rulesSortField === "id") {
        valA = a.id;
        valB = b.id;
      } else if (rulesSortField === "name") {
        valA = a.name.toLowerCase();
        valB = b.name.toLowerCase();
      } else if (rulesSortField === "type") {
        valA = a.type;
        valB = b.type;
      } else if (rulesSortField === "riskWeight") {
        valA = a.riskWeight;
        valB = b.riskWeight;
      } else if (rulesSortField === "matchesCount") {
        valA = a.matchesCount;
        valB = b.matchesCount;
      } else if (rulesSortField === "enabled") {
        valA = a.enabled ? 1 : 0;
        valB = b.enabled ? 1 : 0;
      }

      if (valA < valB) return rulesSortDir === "asc" ? -1 : 1;
      if (valA > valB) return rulesSortDir === "asc" ? 1 : -1;
      return 0;
    });
  }, [rulesList, rulesSearch, rulesTypeFilter, rulesStatusFilter, rulesSortField, rulesSortDir]);

  const isRulesFiltered = rulesSearch !== "" || rulesTypeFilter !== "All" || rulesStatusFilter !== "All" || rulesSortField !== "matchesCount" || rulesSortDir !== "desc";
  function resetRulesFilters() {
    setRulesSearch("");
    setRulesTypeFilter("All");
    setRulesStatusFilter("All");
    setRulesSortField("matchesCount");
    setRulesSortDir("desc");
  }

  async function handleCreateUser(e: React.FormEvent) {
    e.preventDefault();
    const errors: Record<string, string> = {};

    if (!addUserFullName.trim()) errors.fullName = "Full name is required";

    if (!addUserEmail.trim()) {
      errors.email = "Email is required";
    } else if (!EMAIL_PATTERN.test(addUserEmail.trim())) {
      errors.email = "Enter a valid email address (e.g. admin@gmail.com)";
    }

    const cleanPhone = addUserPhone.trim().replace(/\s+/g, "");
    if (!cleanPhone || cleanPhone === "+255") {
      errors.phone = "Phone number is required";
    } else if (!TZ_PHONE_PATTERN.test(cleanPhone)) {
      errors.phone = "Enter a valid Tanzanian phone number (e.g. +255754000000)";
    }

    if (!addUserGender) {
      errors.gender = "Please select gender";
    }

    const passErr = validatePasswordStrength(addUserPassword);
    if (passErr) {
      errors.password = passErr;
    }

    if (addUserConfirmPassword !== addUserPassword) {
      errors.confirmPassword = "Passwords do not match";
    }

    setAddUserErrors(errors);
    if (Object.keys(errors).length > 0) return;

    setAddUserBusy(true);
    const res = await createUser({
      full_name: addUserFullName.trim(),
      email: addUserEmail.trim(),
      phone_number: cleanPhone,
      password: addUserPassword,
      gender: addUserGender || undefined,
    });
    setAddUserBusy(false);
    if (res.success && res.data) {
      setUsersList((prev) => [...prev, res.data!]);
      showToast("success", `Admin ${res.data.email} created`);
      setAddUserFullName("");
      setAddUserEmail("");
      setAddUserPhone("+255");
      setAddUserPassword("");
      setAddUserConfirmPassword("");
      setAddUserGender("");
      setAddUserErrors({});
      setIsAddUserOpen(false);
    } else {
      showToast("error", res.message ?? "Failed to create admin");
    }
  }

  function openEditUser(user: AdminUser) {
    setEditUserId(user.user_id);
    setEditUserFullName(user.full_name ?? "");
    setEditUserEmail(user.email ?? "");
    setEditUserPhone(user.phone || "+255");
    setEditUserActive(user.active);
    setEditUserErrors({});
    setIsEditUserOpen(true);
  }

  async function handleUpdateUser(e: React.FormEvent) {
    e.preventDefault();
    const errors: Record<string, string> = {};

    if (!editUserFullName.trim()) errors.fullName = "Full name is required";

    if (!editUserEmail.trim()) {
      errors.email = "Email is required";
    } else if (!EMAIL_PATTERN.test(editUserEmail.trim())) {
      errors.email = "Enter a valid email address (e.g. admin@gmail.com)";
    }

    const cleanPhone = editUserPhone.trim().replace(/\s+/g, "");
    if (!cleanPhone || cleanPhone === "+255") {
      errors.phone = "Phone number is required";
    } else if (!TZ_PHONE_PATTERN.test(cleanPhone)) {
      errors.phone = "Enter a valid Tanzanian phone number (e.g. +255754000000)";
    }

    setEditUserErrors(errors);
    if (Object.keys(errors).length > 0) return;

    setEditUserBusy(true);
    const res = await updateUser(editUserId, {
      full_name: editUserFullName.trim(),
      email: editUserEmail.trim(),
      phone_number: cleanPhone,
      active: editUserActive,
    });
    setEditUserBusy(false);
    if (res.success && res.data) {
      setUsersList((prev) => prev.map((u) => (u.user_id === res.data!.user_id ? res.data! : u)));
      showToast("success", `${res.data.email} updated`);
      setIsEditUserOpen(false);
    } else {
      showToast("error", res.message ?? "Failed to update user");
    }
  }

  function openResetPassword() {
    setResetPasswordValue("");
    setResetPasswordConfirm("");
    setResetPasswordErrors({});
    setShowResetPassword(false);
    setShowResetPasswordConfirm(false);
    setIsResetPasswordOpen(true);
  }

  async function handleResetPassword(e: React.FormEvent) {
    e.preventDefault();
    const errors: Record<string, string> = {};

    const passErr = validatePasswordStrength(resetPasswordValue);
    if (passErr) {
      errors.password = passErr;
    }

    if (resetPasswordConfirm !== resetPasswordValue) {
      errors.confirmPassword = "Passwords do not match";
    }

    setResetPasswordErrors(errors);
    if (Object.keys(errors).length > 0) return;

    setResetPasswordBusy(true);
    const res = await resetUserPassword(editUserId, resetPasswordValue);
    setResetPasswordBusy(false);
    if (res.success) {
      showToast("success", "Password reset successfully");
      setIsResetPasswordOpen(false);
    } else {
      showToast("error", res.message ?? "Failed to reset password");
    }
  }

  function handleDeleteClick(user: AdminUser) {
    if (user.user_id === currentUserId) {
      showToast("error", "You cannot delete your own account");
      return;
    }
    setDeleteTarget(user);
  }

  async function handleDeleteUser() {
    if (!deleteTarget) return;
    const target = deleteTarget;
    setDeleteBusy(true);
    const res = await deleteUser(target.user_id);
    setDeleteBusy(false);
    if (res.success) {
      setUsersList((prev) => prev.filter((u) => u.user_id !== target.user_id));
      showToast("success", `${target.email} deleted`);
    } else {
      showToast("error", res.message ?? "Failed to delete user");
    }
    setDeleteTarget(null);
  }

  // Sidebar Menu items
  const navMenuItems = [
    { name: "Overview", icon: Activity },
    { name: "SMS Ingestion Logs", icon: MessageSquare, badge: smsList.length },
    { name: "Rules & Threat Engine", icon: Sliders, badge: rulesList.filter((r) => r.enabled).length },
    { name: "Team", icon: UserCheck, badge: filteredTeamList.length },
    { name: "Users", icon: Users, badge: filteredAppUsersList.length },
  ];

  return (
    <div className="admin-portal-container">
      {/* MOBILE BACKDROP OVERLAY */}
      {mobileMenuOpen && (
        <div
          className="sidebar-mobile-overlay"
          onClick={() => setMobileMenuOpen(false)}
        />
      )}

      {/* FLOATING EXECUTIVE SIDEBAR WITH RESPONSIVE MOBILE DRAWER CLASS */}
      <aside className={`admin-sidebar ${mobileMenuOpen ? "mobile-open" : ""}`}>
        <div className="sidebar-brand">
          <div className="brand-icon-wrapper">
            <img src={inAppIcon} alt="Argus Logo" className="brand-logo-img" />
          </div>
          <div className="brand-text">
            <h2>Argus</h2>
          </div>
        </div>

        {/* Clean, uninterrupted navbar list */}
        <nav className="sidebar-menu">
          {navMenuItems.map((item) => {
            const Icon = item.icon;
            const isActive = activeTab === item.name;
            return (
              <button
                key={item.name}
                type="button"
                className={`sidebar-link ${isActive ? "active" : ""}`}
                onClick={() => handleTabClick(item.name)}
              >
                <Icon size={18} className="sidebar-link-icon" />
                <span>{item.name}</span>
                {item.badge !== undefined && item.badge > 0 && (
                  <span className="menu-badge danger">
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

          <button type="button" className="logout-btn" onClick={() => onNavigate("login")}>
            <LogOut size={18} />
            <span>Logout</span>
          </button>
        </div>
      </aside>

      {/* MAIN CONTENT AREA */}
      <main className="admin-main">
        {/* EXECUTIVE TOPBAR HEADER */}
        <header className="admin-topbar">
          <div className="topbar-left-group">
            {/* Mobile Hamburger Drawer Toggle Button */}
            <button
              type="button"
              className="mobile-hamburger-btn"
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              aria-label="Toggle Navigation Menu"
            >
              <Menu size={20} />
            </button>

            <div className="topbar-title">
              <h1>{activeTab}</h1>
              <p className="topbar-subtitle">Argus Executive SMS Security Console</p>
            </div>
          </div>

          <div className="topbar-actions">
            <div className="admin-profile-pill">
              <div className="admin-avatar">
                {adminName.substring(0, 2).toUpperCase()}
              </div>
              <div className="admin-info">
                <strong>{adminName}</strong>
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
              {statsCards.map((stat) => (
                <div key={stat.id} className={`stat-card-box category-${stat.category}`}>
                  <div className="stat-header">
                    <span className="stat-title">{stat.title}</span>
                    <div className={`stat-icon-badge ${stat.category}`}>
                      {stat.category === "total" && <MessageSquare size={18} />}
                      {stat.category === "fraud" && <ShieldAlert size={18} />}
                    </div>
                  </div>
                  <h2 className="stat-number">{stat.value}</h2>
                  <div className="stat-footer">
                    <span className={`change-indicator ${stat.type}`}>{stat.change}</span>
                  </div>
                </div>
              ))}
            </section>

            {/* TRAFFIC OVERVIEW CHART PANEL */}
            <section className="middle-dashboard-grid single-column">
              <div className="admin-panel telemetry-chart-panel">
                <div className="panel-top flex-wrap">
                  <div>
                    <h3>SMS Traffic & Interception Overview</h3>
                    <p>Live trend analysis across intercepted SMS message volume</p>
                  </div>
                  <div className="telemetry-chart-legend">
                    <span className="legend-pill total-pill">
                      <span className="pill-dot blue" /> Total SMS (14,890)
                    </span>
                    <span className="legend-pill fraud-pill">
                      <span className="pill-dot red" /> Fraud Intercepts (2,840)
                    </span>
                  </div>
                </div>

                <div className="telemetry-chart-wrapper">
                  <div className="telemetry-svg-container">
                    <svg viewBox="0 0 720 220" className="telemetry-svg">
                      <defs>
                        <linearGradient id="totalSmsGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="#3b82f6" stopOpacity="0.22" />
                          <stop offset="100%" stopColor="#3b82f6" stopOpacity="0.0" />
                        </linearGradient>
                        <linearGradient id="fraudSmsGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="#ef4444" stopOpacity="0.28" />
                          <stop offset="100%" stopColor="#ef4444" stopOpacity="0.0" />
                        </linearGradient>
                      </defs>

                      {/* Horizontal Grid Lines */}
                      <g className="grid-lines-horizontal" stroke="var(--border)" strokeDasharray="4 4" strokeWidth="1">
                        <line x1="55" y1="30" x2="700" y2="30" />
                        <line x1="55" y1="75" x2="700" y2="75" />
                        <line x1="55" y1="120" x2="700" y2="120" />
                        <line x1="55" y1="165" x2="700" y2="165" />
                      </g>

                      {/* Vertical Day Grid Lines */}
                      <g className="grid-lines-vertical" stroke="var(--border)" strokeDasharray="3 3" strokeWidth="1" opacity="0.5">
                        <line x1="60" y1="25" x2="60" y2="190" />
                        <line x1="165" y1="25" x2="165" y2="190" />
                        <line x1="270" y1="25" x2="270" y2="190" />
                        <line x1="375" y1="25" x2="375" y2="190" />
                        <line x1="480" y1="25" x2="480" y2="190" />
                        <line x1="585" y1="25" x2="585" y2="190" />
                        <line x1="690" y1="25" x2="690" y2="190" />
                      </g>

                      {/* Y-Axis Scale Labels */}
                      <g className="y-axis-labels" fill="var(--subtle)" fontSize="10" fontWeight="700" textAnchor="end">
                        <text x="48" y="34">2,000</text>
                        <text x="48" y="79">1,500</text>
                        <text x="48" y="124">1,000</text>
                        <text x="48" y="169">500</text>
                      </g>

                      {/* Area Fill 1: Total SMS Ingested */}
                      <path
                        d="M 60,110 C 112.5,95 112.5,80 165,80 C 217.5,80 217.5,60 270,60 C 322.5,60 322.5,40 375,40 C 427.5,40 427.5,50 480,50 C 532.5,50 532.5,30 585,30 C 637.5,30 637.5,30 690,30 L 690,190 L 60,190 Z"
                        fill="url(#totalSmsGradient)"
                      />

                      {/* Spline Line 1: Total SMS Ingested */}
                      <path
                        d="M 60,110 C 112.5,95 112.5,80 165,80 C 217.5,80 217.5,60 270,60 C 322.5,60 322.5,40 375,40 C 427.5,40 427.5,50 480,50 C 532.5,50 532.5,30 585,30 C 637.5,30 637.5,30 690,30"
                        fill="none"
                        stroke="#3b82f6"
                        strokeWidth="2.5"
                        strokeLinecap="round"
                      />

                      {/* Area Fill 2: Fraud Intercepts */}
                      <path
                        d="M 60,150 C 112.5,140 112.5,130 165,130 C 217.5,130 217.5,95 270,95 C 322.5,95 322.5,45 375,45 C 427.5,45 427.5,110 480,110 C 532.5,110 532.5,50 585,50 C 637.5,50 637.5,80 690,80 L 690,190 L 60,190 Z"
                        fill="url(#fraudSmsGradient)"
                      />

                      {/* Spline Line 2: Fraud Intercepts */}
                      <path
                        d="M 60,150 C 112.5,140 112.5,130 165,130 C 217.5,130 217.5,95 270,95 C 322.5,95 322.5,45 375,45 C 427.5,45 427.5,110 480,110 C 532.5,110 532.5,50 585,50 C 637.5,50 637.5,80 690,80"
                        fill="none"
                        stroke="var(--primary)"
                        strokeWidth="3"
                        strokeLinecap="round"
                      />

                      {/* Interactive Hover Crosshair */}
                      {hoveredTelemetryIndex !== null && (
                        <line
                          x1={[60, 165, 270, 375, 480, 585, 690][hoveredTelemetryIndex]}
                          y1="25"
                          x2={[60, 165, 270, 375, 480, 585, 690][hoveredTelemetryIndex]}
                          y2="190"
                          stroke="var(--primary)"
                          strokeDasharray="3 3"
                          strokeWidth="1.5"
                          opacity="0.9"
                        />
                      )}

                      {/* Total SMS Data Node Circles */}
                      {[
                        { day: "Mon", x: 60, y: 110 },
                        { day: "Tue", x: 165, y: 80 },
                        { day: "Wed", x: 270, y: 60 },
                        { day: "Thu", x: 375, y: 40 },
                        { day: "Fri", x: 480, y: 50 },
                        { day: "Sat", x: 585, y: 30 },
                        { day: "Sun", x: 690, y: 30 },
                      ].map((pt, idx) => {
                        const isHovered = hoveredTelemetryIndex === idx;
                        return (
                          <circle
                            key={`total-node-${pt.day}`}
                            cx={pt.x}
                            cy={pt.y}
                            r={isHovered ? 6 : 4}
                            fill="#3b82f6"
                            stroke="var(--card)"
                            strokeWidth="2"
                            pointerEvents="none"
                          />
                        );
                      })}

                      {/* Fraud Data Node Circles */}
                      {[
                        { day: "Mon", x: 60, y: 150, count: "850 Fraud" },
                        { day: "Tue", x: 165, y: 130, count: "1,240 Fraud" },
                        { day: "Wed", x: 270, y: 95, count: "1,100 Fraud" },
                        { day: "Thu", x: 375, y: 45, count: "1,890 Fraud", peak: true },
                        { day: "Fri", x: 480, y: 110, count: "1,450 Fraud" },
                        { day: "Sat", x: 585, y: 50, count: "2,100 Fraud", peak: true },
                        { day: "Sun", x: 690, y: 80, count: "1,620 Fraud" },
                      ].map((pt, idx) => {
                        const isHovered = hoveredTelemetryIndex === idx;
                        return (
                          <g
                            key={`fraud-node-${pt.day}`}
                            className="interactive-node-group"
                            onMouseEnter={() => setHoveredTelemetryIndex(idx)}
                            onMouseLeave={() => setHoveredTelemetryIndex(null)}
                            style={{ cursor: "pointer" }}
                          >
                            {isHovered && (
                              <circle
                                cx={pt.x}
                                cy={pt.y}
                                r="12"
                                fill="rgba(239, 68, 68, 0.22)"
                                stroke="var(--primary)"
                                strokeWidth="1.5"
                              />
                            )}
                            <circle
                              cx={pt.x}
                              cy={pt.y}
                              r={isHovered ? 7 : pt.peak ? 6 : 5}
                              fill="var(--primary)"
                              stroke="var(--card)"
                              strokeWidth="2.5"
                            />
                          </g>
                        );
                      })}

                      {/* Callout Hover Badges */}
                      {[
                        { day: "Mon", x: 60, y: 150, count: "850 Fraud" },
                        { day: "Tue", x: 165, y: 130, count: "1,240 Fraud" },
                        { day: "Wed", x: 270, y: 95, count: "1,100 Fraud" },
                        { day: "Thu", x: 375, y: 45, count: "1,890 Fraud", peak: true },
                        { day: "Fri", x: 480, y: 110, count: "1,450 Fraud" },
                        { day: "Sat", x: 585, y: 50, count: "2,100 Fraud", peak: true },
                        { day: "Sun", x: 690, y: 80, count: "1,620 Fraud" },
                      ].map((pt, idx) => {
                        const isHovered = hoveredTelemetryIndex === idx;
                        if (!isHovered && !pt.peak) return null;

                        return (
                          <g key={`badge-${pt.day}`} className="callout-badges pointer-events-none">
                            <rect
                              x={pt.x - 44}
                              y={pt.y - 32}
                              width="88"
                              height="22"
                              rx="6"
                              fill={isHovered ? "#08090d" : "var(--primary)"}
                              stroke={isHovered ? "var(--primary)" : "none"}
                              strokeWidth="1"
                            />
                            <text
                              x={pt.x}
                              y={pt.y - 17}
                              fill="#ffffff"
                              fontSize="10"
                              fontWeight="800"
                              textAnchor="middle"
                            >
                              {pt.count}
                            </text>
                          </g>
                        );
                      })}
                    </svg>
                  </div>

                  {/* X-Axis Labels Row */}
                  <div className="telemetry-x-labels">
                    {[
                      { day: "Mon", val: "850 Scans", idx: 0 },
                      { day: "Tue", val: "1,240 Scans", idx: 1 },
                      { day: "Wed", val: "1,100 Scans", idx: 2 },
                      { day: "Thu", val: "1,890 (Peak)", idx: 3, peak: true },
                      { day: "Fri", val: "1,450 Scans", idx: 4 },
                      { day: "Sat", val: "2,100 (Peak)", idx: 5, peak: true },
                      { day: "Sun", val: "1,620 Scans", idx: 6 },
                    ].map((lbl) => (
                      <div
                        key={lbl.day}
                        className={`x-label-item ${lbl.peak ? "active-peak" : ""} ${hoveredTelemetryIndex === lbl.idx ? "hovered-label" : ""}`}
                        onMouseEnter={() => setHoveredTelemetryIndex(lbl.idx)}
                        onMouseLeave={() => setHoveredTelemetryIndex(null)}
                        style={{ cursor: "pointer" }}
                      >
                        <span>{lbl.day}</span>
                        <small className={lbl.peak ? "peak-val" : "subtle-val"}>{lbl.val}</small>
                      </div>
                    ))}
                  </div>
                </div>
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
                  <p>Audit trail of all intercepted fraud messages ({filteredLogsList.length} records)</p>
                </div>
              </div>

              {/* TOOLBAR */}
              <div className="toolbar-row">
                <div className="search-input-wrapper">
                  <Search size={16} className="search-icon" />
                  <input
                    type="text"
                    placeholder="Search logs by ID, sender, or message body..."
                    value={logsSearch}
                    onChange={(e) => setLogsSearch(e.target.value)}
                    className="search-input"
                  />
                  {logsSearch && (
                    <button type="button" className="clear-search-btn" onClick={() => setLogsSearch("")}>
                      <X size={14} />
                    </button>
                  )}
                </div>

                {isLogsFiltered && (
                  <button type="button" className="btn-reset" onClick={resetLogsFilters}>
                    <RotateCcw size={14} /> Reset Filters
                  </button>
                )}
              </div>

              <div className="table-wrapper">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("id", logsSortField, logsSortDir, setLogsSortField, setLogsSortDir)}
                      >
                        <div className="th-content">
                          <span>Record ID</span>
                          {logsSortField === "id" ? (
                            <span className="sort-indicator">{logsSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("sender", logsSortField, logsSortDir, setLogsSortField, setLogsSortDir)}
                      >
                        <div className="th-content">
                          <span>Sender</span>
                          {logsSortField === "sender" ? (
                            <span className="sort-indicator">{logsSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th>Message Body</th>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("date", logsSortField, logsSortDir, setLogsSortField, setLogsSortDir)}
                      >
                        <div className="th-content">
                          <span>Intercept Time</span>
                          {logsSortField === "date" ? (
                            <span className="sort-indicator">{logsSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th>Status</th>
                      <th>Inspect</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredLogsList.length === 0 ? (
                      <tr>
                        <td colSpan={6} className="subtle-text">No audit logs match your search.</td>
                      </tr>
                    ) : (
                      filteredLogsList.map((sms) => (
                        <tr key={sms.id}>
                          <td><code className="code-tag">{sms.id}</code></td>
                          <td className="font-semibold">{sms.sender}</td>
                          <td className="message-cell">{sms.message}</td>
                          <td className="subtle-text">{sms.date}</td>
                          <td>
                            <span className="status-pill fraud">
                              FRAUD
                            </span>
                          </td>
                          <td>
                            <button
                              type="button"
                              className="icon-action-btn"
                              onClick={() => setSelectedSms(sms)}
                              title="Inspect Log Payload"
                            >
                              <Eye size={16} />
                            </button>
                          </td>
                        </tr>
                      ))
                    )}
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

              {/* TOOLBAR */}
              <div className="toolbar-row">
                <div className="search-input-wrapper">
                  <Search size={16} className="search-icon" />
                  <input
                    type="text"
                    placeholder="Search rules by name or pattern..."
                    value={rulesSearch}
                    onChange={(e) => setRulesSearch(e.target.value)}
                    className="search-input"
                  />
                  {rulesSearch && (
                    <button type="button" className="clear-search-btn" onClick={() => setRulesSearch("")}>
                      <X size={14} />
                    </button>
                  )}
                </div>

                <div className="toolbar-controls">
                  <div className="flex-align gap-2">
                    <Filter size={14} className="subtle-text" />
                    <select
                      value={rulesTypeFilter}
                      onChange={(e) => setRulesTypeFilter(e.target.value)}
                      className="filter-select"
                    >
                      <option value="All">All Types</option>
                      <option value="Keyword">Keyword</option>
                      <option value="Regex Pattern">Regex Pattern</option>
                      <option value="Link Analyzer">Link Analyzer</option>
                      <option value="Sender Spoofing">Sender Spoofing</option>
                    </select>

                    <select
                      value={rulesStatusFilter}
                      onChange={(e) => setRulesStatusFilter(e.target.value as "All" | "Active" | "Disabled")}
                      className="filter-select"
                    >
                      <option value="All">All Statuses</option>
                      <option value="Active">Active Only</option>
                      <option value="Disabled">Disabled Only</option>
                    </select>
                  </div>

                  {isRulesFiltered && (
                    <button type="button" className="btn-reset" onClick={resetRulesFilters}>
                      <RotateCcw size={14} /> Reset Filters
                    </button>
                  )}
                </div>
              </div>

              <div className="table-wrapper">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("id", rulesSortField, rulesSortDir, setRulesSortField, setRulesSortDir)}
                      >
                        <div className="th-content">
                          <span>Rule ID</span>
                          {rulesSortField === "id" ? (
                            <span className="sort-indicator">{rulesSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("name", rulesSortField, rulesSortDir, setRulesSortField, setRulesSortDir)}
                      >
                        <div className="th-content">
                          <span>Rule Name</span>
                          {rulesSortField === "name" ? (
                            <span className="sort-indicator">{rulesSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("type", rulesSortField, rulesSortDir, setRulesSortField, setRulesSortDir)}
                      >
                        <div className="th-content">
                          <span>Type</span>
                          {rulesSortField === "type" ? (
                            <span className="sort-indicator">{rulesSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th>Pattern Definition</th>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("riskWeight", rulesSortField, rulesSortDir, setRulesSortField, setRulesSortDir)}
                      >
                        <div className="th-content">
                          <span>Weight</span>
                          {rulesSortField === "riskWeight" ? (
                            <span className="sort-indicator">{rulesSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("matchesCount", rulesSortField, rulesSortDir, setRulesSortField, setRulesSortDir)}
                      >
                        <div className="th-content">
                          <span>Detections</span>
                          {rulesSortField === "matchesCount" ? (
                            <span className="sort-indicator">{rulesSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("enabled", rulesSortField, rulesSortDir, setRulesSortField, setRulesSortDir)}
                      >
                        <div className="th-content">
                          <span>Status</span>
                          {rulesSortField === "enabled" ? (
                            <span className="sort-indicator">{rulesSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th>Toggle</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredRulesList.length === 0 ? (
                      <tr>
                        <td colSpan={8} className="subtle-text">No rules match your filter criteria.</td>
                      </tr>
                    ) : (
                      filteredRulesList.map((rule) => (
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
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* TAB 4: TEAM (ADMINS) */}
        {activeTab === "Team" && (
          <div className="tab-content fade-slide">
            <div className="admin-panel">
              <div className="panel-top">
                <div>
                  <h3>Team Administrators</h3>
                  <p>Authorized platform admins ({filteredTeamList.length} members)</p>
                </div>
                <button type="button" className="btn-primary" onClick={() => {
                  setAddUserPhone("+255");
                  setAddUserGender("");
                  setAddUserErrors({});
                  setIsAddUserOpen(true);
                }}>
                  <UserPlus size={16} /> Add Admin
                </button>
              </div>

              {/* TOOLBAR */}
              <div className="toolbar-row">
                <div className="search-input-wrapper">
                  <Search size={16} className="search-icon" />
                  <input
                    type="text"
                    placeholder="Search admins by name, email, or phone..."
                    value={teamSearch}
                    onChange={(e) => setTeamSearch(e.target.value)}
                    className="search-input"
                  />
                  {teamSearch && (
                    <button type="button" className="clear-search-btn" onClick={() => setTeamSearch("")}>
                      <X size={14} />
                    </button>
                  )}
                </div>

                <div className="toolbar-controls">
                  <div className="flex-align gap-2">
                    <Filter size={14} className="subtle-text" />
                    <select
                      value={teamStatusFilter}
                      onChange={(e) => setTeamStatusFilter(e.target.value as "All" | "Active" | "Inactive")}
                      className="filter-select"
                    >
                      <option value="All">All Statuses</option>
                      <option value="Active">Active Only</option>
                      <option value="Inactive">Inactive Only</option>
                    </select>
                  </div>

                  {isTeamFiltered && (
                    <button type="button" className="btn-reset" onClick={resetTeamFilters}>
                      <RotateCcw size={14} /> Reset Filters
                    </button>
                  )}
                </div>
              </div>

              <div className="table-wrapper">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("full_name", teamSortField, teamSortDir, setTeamSortField, setTeamSortDir)}
                      >
                        <div className="th-content">
                          <span>Admin Name</span>
                          {teamSortField === "full_name" ? (
                            <span className="sort-indicator">{teamSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("email", teamSortField, teamSortDir, setTeamSortField, setTeamSortDir)}
                      >
                        <div className="th-content">
                          <span>Email / Contact</span>
                          {teamSortField === "email" ? (
                            <span className="sort-indicator">{teamSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("active", teamSortField, teamSortDir, setTeamSortField, setTeamSortDir)}
                      >
                        <div className="th-content">
                          <span>Status</span>
                          {teamSortField === "active" ? (
                            <span className="sort-indicator">{teamSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {usersLoading ? (
                      <tr>
                        <td colSpan={4} className="subtle-text">Loading admin team…</td>
                      </tr>
                    ) : usersError ? (
                      <tr>
                        <td colSpan={4} className="subtle-text" style={{ color: "var(--primary)" }}>
                          {usersError}
                        </td>
                      </tr>
                    ) : filteredTeamList.length === 0 ? (
                      <tr>
                        <td colSpan={4} className="subtle-text">No administrators match your search/filter criteria.</td>
                      </tr>
                    ) : (
                      filteredTeamList.map((user) => (
                        <tr key={user.user_id}>
                          <td className="font-semibold">{user.full_name || "—"}</td>
                          <td>
                            <div>{user.email}</div>
                            <small className="subtle-text">{user.phone}</small>
                          </td>
                          <td>
                            <span className={`status-pill ${user.active ? "safe" : "danger"}`}>
                              {user.active ? "Active" : "Inactive"}
                            </span>
                          </td>
                          <td>
                            <div className="action-buttons-row">
                              <button
                                type="button"
                                className="icon-action-btn"
                                onClick={() => openEditUser(user)}
                                title="Edit Admin"
                              >
                                <Pencil size={16} />
                              </button>
                              <button
                                type="button"
                                className="icon-action-btn danger"
                                onClick={() => handleDeleteClick(user)}
                                title="Delete Admin"
                              >
                                <Trash2 size={16} />
                              </button>
                            </div>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* TAB 5: USERS (MOBILE APP USERS) */}
        {activeTab === "Users" && (
          <div className="tab-content fade-slide">
            <div className="admin-panel">
              <div className="panel-top">
                <div>
                  <h3>Registered Mobile Users</h3>
                  <p>Mobile app users synchronized from database ({filteredAppUsersList.length} users)</p>
                </div>
              </div>

              {/* TOOLBAR */}
              <div className="toolbar-row">
                <div className="search-input-wrapper">
                  <Search size={16} className="search-icon" />
                  <input
                    type="text"
                    placeholder="Search mobile users by name, email, phone, or ID..."
                    value={appUsersSearch}
                    onChange={(e) => setAppUsersSearch(e.target.value)}
                    className="search-input"
                  />
                  {appUsersSearch && (
                    <button type="button" className="clear-search-btn" onClick={() => setAppUsersSearch("")}>
                      <X size={14} />
                    </button>
                  )}
                </div>

                <div className="toolbar-controls">
                  <div className="flex-align gap-2">
                    <Filter size={14} className="subtle-text" />
                    <select
                      value={appUsersVerificationFilter}
                      onChange={(e) => setAppUsersVerificationFilter(e.target.value as "All" | "Verified" | "Pending")}
                      className="filter-select"
                    >
                      <option value="All">All Verifications</option>
                      <option value="Verified">Verified Only</option>
                      <option value="Pending">Pending Only</option>
                    </select>

                    <select
                      value={appUsersStatusFilter}
                      onChange={(e) => setAppUsersStatusFilter(e.target.value as "All" | "Active" | "Inactive")}
                      className="filter-select"
                    >
                      <option value="All">All Statuses</option>
                      <option value="Active">Active Only</option>
                      <option value="Inactive">Inactive Only</option>
                    </select>
                  </div>

                  {isAppUsersFiltered && (
                    <button type="button" className="btn-reset" onClick={resetAppUsersFilters}>
                      <RotateCcw size={14} /> Reset Filters
                    </button>
                  )}
                </div>
              </div>

              <div className="table-wrapper">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("user_id", appUsersSortField, appUsersSortDir, setAppUsersSortField, setAppUsersSortDir)}
                      >
                        <div className="th-content">
                          <span>User ID</span>
                          {appUsersSortField === "user_id" ? (
                            <span className="sort-indicator">{appUsersSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("full_name", appUsersSortField, appUsersSortDir, setAppUsersSortField, setAppUsersSortDir)}
                      >
                        <div className="th-content">
                          <span>Full Name</span>
                          {appUsersSortField === "full_name" ? (
                            <span className="sort-indicator">{appUsersSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("email", appUsersSortField, appUsersSortDir, setAppUsersSortField, setAppUsersSortDir)}
                      >
                        <div className="th-content">
                          <span>Email Address</span>
                          {appUsersSortField === "email" ? (
                            <span className="sort-indicator">{appUsersSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th>Phone Number</th>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("verified", appUsersSortField, appUsersSortDir, setAppUsersSortField, setAppUsersSortDir)}
                      >
                        <div className="th-content">
                          <span>Verification</span>
                          {appUsersSortField === "verified" ? (
                            <span className="sort-indicator">{appUsersSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th
                        className="sortable"
                        onClick={() => handleSortToggle("active", appUsersSortField, appUsersSortDir, setAppUsersSortField, setAppUsersSortDir)}
                      >
                        <div className="th-content">
                          <span>Status</span>
                          {appUsersSortField === "active" ? (
                            <span className="sort-indicator">{appUsersSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {usersLoading ? (
                      <tr>
                        <td colSpan={6} className="subtle-text">Loading registered users…</td>
                      </tr>
                    ) : usersError ? (
                      <tr>
                        <td colSpan={6} className="subtle-text" style={{ color: "var(--primary)" }}>
                          {usersError}
                        </td>
                      </tr>
                    ) : filteredAppUsersList.length === 0 ? (
                      <tr>
                        <td colSpan={6} className="subtle-text">No registered mobile users match your search/filter criteria.</td>
                      </tr>
                    ) : (
                      filteredAppUsersList.map((user) => (
                        <tr key={user.user_id}>
                          <td><code className="code-tag">{user.user_id.substring(0, 8)}</code></td>
                          <td className="font-semibold">{user.full_name || "Mobile User"}</td>
                          <td>{user.email}</td>
                          <td className="font-semibold">{user.phone || "—"}</td>
                          <td>
                            {user.verified ? (
                              <span className="badge-inline green"><CheckCircle2 size={14} /> Verified</span>
                            ) : (
                              <span className="badge-inline amber"><XCircle size={14} /> Pending</span>
                            )}
                          </td>
                          <td>
                            <span className={`status-pill ${user.active ? "safe" : "danger"}`}>
                              {user.active ? "Active" : "Inactive"}
                            </span>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* INSPECT SMS LOG DIALOG */}
      {selectedSms && (
        <div className="modal-backdrop" onClick={() => setSelectedSms(null)}>
          <div className="modal-card fade-slide" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <div className="flex-align">
                <ShieldAlert size={22} style={{ color: "var(--primary)" }} />
                <h3>SMS Log Inspection Payload</h3>
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
                <div className="message-box" style={{
                  backgroundColor: "var(--bg)",
                  padding: "14px",
                  borderRadius: "10px",
                  border: "1px solid var(--border)",
                  fontSize: "0.875rem",
                  lineHeight: 1.5,
                  marginTop: "6px"
                }}>
                  {selectedSms.message}
                </div>
              </div>

              <div className="modal-info-row margin-top">
                <div>
                  <small>CLASSIFICATION</small>
                  <span className="status-pill fraud" style={{ marginTop: "4px" }}>
                    FRAUD
                  </span>
                </div>
              </div>
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

      {/* ADD ADMIN MODAL */}
      {isAddUserOpen && (
        <div className="modal-backdrop" onClick={() => !addUserBusy && setIsAddUserOpen(false)}>
          <div className="modal-card fade-slide" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <div className="flex-align">
                <UserPlus size={20} style={{ color: "var(--primary)" }} />
                <h3>Add New Admin</h3>
              </div>
              <button type="button" className="close-btn" onClick={() => setIsAddUserOpen(false)} disabled={addUserBusy}>
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleCreateUser} noValidate>
              <div className="modal-body">
                <div className="form-grid">
                  <div className="form-group">
                    <label>Full Name</label>
                    <input
                      type="text"
                      placeholder="e.g. Juma Kabwe"
                      value={addUserFullName}
                      onChange={(e) => setAddUserFullName(e.target.value)}
                      className={addUserErrors.fullName ? "input-error" : ""}
                    />
                    {addUserErrors.fullName && <span className="form-error">{addUserErrors.fullName}</span>}
                  </div>

                  <div className="form-group">
                    <label>Email Address</label>
                    <input
                      type="email"
                      placeholder="admin@gmail.com"
                      value={addUserEmail}
                      onChange={(e) => setAddUserEmail(e.target.value)}
                      className={addUserErrors.email ? "input-error" : ""}
                    />
                    {addUserErrors.email && <span className="form-error">{addUserErrors.email}</span>}
                  </div>

                  <div className="form-group">
                    <label>Phone Number (Tanzania)</label>
                    <input
                      type="tel"
                      placeholder="+255754000000"
                      value={addUserPhone}
                      onChange={(e) => setAddUserPhone(e.target.value)}
                      className={addUserErrors.phone ? "input-error" : ""}
                    />
                    {addUserErrors.phone && <span className="form-error">{addUserErrors.phone}</span>}
                  </div>

                  <div className="form-group">
                    <label>Gender</label>
                    <select
                      value={addUserGender}
                      onChange={(e) => setAddUserGender(e.target.value as "MALE" | "FEMALE")}
                      className={addUserErrors.gender ? "input-error" : ""}
                    >
                      <option value="">Select Gender</option>
                      <option value="MALE">Male</option>
                      <option value="FEMALE">Female</option>
                    </select>
                    {addUserErrors.gender && <span className="form-error">{addUserErrors.gender}</span>}
                  </div>

                  <div className="form-group">
                    <label>Password</label>
                    <div className="password-input-wrapper">
                      <input
                        type={showAddUserPassword ? "text" : "password"}
                        placeholder="••••••••"
                        value={addUserPassword}
                        onChange={(e) => setAddUserPassword(e.target.value)}
                        className={addUserErrors.password ? "input-error" : ""}
                      />
                      <button
                        type="button"
                        className="password-toggle-btn"
                        onClick={() => setShowAddUserPassword(!showAddUserPassword)}
                        aria-label="Toggle password visibility"
                      >
                        {showAddUserPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                      </button>
                    </div>
                    {addUserErrors.password && <span className="form-error">{addUserErrors.password}</span>}
                  </div>

                  <div className="form-group">
                    <label>Confirm Password</label>
                    <div className="password-input-wrapper">
                      <input
                        type={showAddUserConfirmPassword ? "text" : "password"}
                        placeholder="••••••••"
                        value={addUserConfirmPassword}
                        onChange={(e) => setAddUserConfirmPassword(e.target.value)}
                        className={addUserErrors.confirmPassword ? "input-error" : ""}
                      />
                      <button
                        type="button"
                        className="password-toggle-btn"
                        onClick={() => setShowAddUserConfirmPassword(!showAddUserConfirmPassword)}
                        aria-label="Toggle password visibility"
                      >
                        {showAddUserConfirmPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                      </button>
                    </div>
                    {addUserErrors.confirmPassword && <span className="form-error">{addUserErrors.confirmPassword}</span>}
                  </div>
                </div>
              </div>

              <div className="modal-footer">
                <button type="button" className="btn-secondary" onClick={() => setIsAddUserOpen(false)} disabled={addUserBusy}>
                  Cancel
                </button>
                <button type="submit" className="btn-primary" disabled={addUserBusy}>
                  {addUserBusy ? "Creating…" : "Add Admin"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* EDIT USER MODAL */}
      {isEditUserOpen && (
        <div className="modal-backdrop" onClick={() => !editUserBusy && setIsEditUserOpen(false)}>
          <div className="modal-card fade-slide" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <div className="flex-align">
                <Pencil size={20} style={{ color: "var(--primary)" }} />
                <h3>Edit Admin Account</h3>
              </div>
              <button type="button" className="close-btn" onClick={() => setIsEditUserOpen(false)} disabled={editUserBusy}>
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleUpdateUser} noValidate>
              <div className="modal-body">
                <div className="form-group">
                  <label>Full Name</label>
                  <input
                    type="text"
                    value={editUserFullName}
                    onChange={(e) => setEditUserFullName(e.target.value)}
                    className={editUserErrors.fullName ? "input-error" : ""}
                  />
                  {editUserErrors.fullName && <span className="form-error">{editUserErrors.fullName}</span>}
                </div>

                <div className="form-group">
                  <label>Email Address</label>
                  <input
                    type="email"
                    value={editUserEmail}
                    onChange={(e) => setEditUserEmail(e.target.value)}
                    className={editUserErrors.email ? "input-error" : ""}
                  />
                  {editUserErrors.email && <span className="form-error">{editUserErrors.email}</span>}
                </div>

                <div className="form-group">
                  <label>Phone Number (Tanzania)</label>
                  <input
                    type="tel"
                    value={editUserPhone}
                    onChange={(e) => setEditUserPhone(e.target.value)}
                    className={editUserErrors.phone ? "input-error" : ""}
                  />
                  {editUserErrors.phone && <span className="form-error">{editUserErrors.phone}</span>}
                </div>

                <div className="form-group">
                  <label className="flex-align" style={{ gap: "8px", cursor: "pointer" }}>
                    <input
                      type="checkbox"
                      checked={editUserActive}
                      onChange={(e) => setEditUserActive(e.target.checked)}
                      style={{ width: "auto" }}
                    />
                    Account active
                  </label>
                </div>
              </div>

              <div className="modal-footer">
                <button type="button" className="btn-secondary" onClick={openResetPassword} disabled={editUserBusy}>
                  <KeyRound size={16} /> Reset Password
                </button>
                <button type="submit" className="btn-primary" disabled={editUserBusy}>
                  {editUserBusy ? "Saving…" : "Save Changes"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* RESET PASSWORD MODAL */}
      {isResetPasswordOpen && (
        <div className="modal-backdrop" onClick={() => !resetPasswordBusy && setIsResetPasswordOpen(false)}>
          <div className="modal-card fade-slide" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <div className="flex-align">
                <KeyRound size={20} style={{ color: "var(--primary)" }} />
                <h3>Reset Password</h3>
              </div>
              <button type="button" className="close-btn" onClick={() => setIsResetPasswordOpen(false)} disabled={resetPasswordBusy}>
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleResetPassword} noValidate>
              <div className="modal-body">
                <div className="form-group">
                  <label>New Password</label>
                  <div className="password-input-wrapper">
                    <input
                      type={showResetPassword ? "text" : "password"}
                      placeholder="••••••••"
                      value={resetPasswordValue}
                      onChange={(e) => setResetPasswordValue(e.target.value)}
                      className={resetPasswordErrors.password ? "input-error" : ""}
                    />
                    <button
                      type="button"
                      className="password-toggle-btn"
                      onClick={() => setShowResetPassword(!showResetPassword)}
                      aria-label="Toggle password visibility"
                    >
                      {showResetPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                    </button>
                  </div>
                  {resetPasswordErrors.password && <span className="form-error">{resetPasswordErrors.password}</span>}
                </div>

                <div className="form-group">
                  <label>Confirm New Password</label>
                  <div className="password-input-wrapper">
                    <input
                      type={showResetPasswordConfirm ? "text" : "password"}
                      placeholder="••••••••"
                      value={resetPasswordConfirm}
                      onChange={(e) => setResetPasswordConfirm(e.target.value)}
                      className={resetPasswordErrors.confirmPassword ? "input-error" : ""}
                    />
                    <button
                      type="button"
                      className="password-toggle-btn"
                      onClick={() => setShowResetPasswordConfirm(!showResetPasswordConfirm)}
                      aria-label="Toggle password visibility"
                    >
                      {showResetPasswordConfirm ? <EyeOff size={18} /> : <Eye size={18} />}
                    </button>
                  </div>
                  {resetPasswordErrors.confirmPassword && <span className="form-error">{resetPasswordErrors.confirmPassword}</span>}
                </div>
              </div>

              <div className="modal-footer">
                <button type="button" className="btn-secondary" onClick={() => setIsResetPasswordOpen(false)} disabled={resetPasswordBusy}>
                  Cancel
                </button>
                <button type="submit" className="btn-primary" disabled={resetPasswordBusy}>
                  {resetPasswordBusy ? "Saving…" : "Set New Password"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* DELETE USER CONFIRM MODAL */}
      {deleteTarget && (
        <div className="modal-backdrop" onClick={() => !deleteBusy && setDeleteTarget(null)}>
          <div className="modal-card fade-slide" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <div className="flex-align">
                <Trash2 size={20} style={{ color: "var(--primary)" }} />
                <h3>Delete Account</h3>
              </div>
              <button type="button" className="close-btn" onClick={() => setDeleteTarget(null)} disabled={deleteBusy}>
                <X size={18} />
              </button>
            </div>
            <div className="modal-body">
              <p>
                Are you sure you want to delete{" "}
                <strong>{deleteTarget.full_name || deleteTarget.email}</strong>?
                This action cannot be undone.
              </p>
            </div>
            <div className="modal-footer">
              <button type="button" className="btn-secondary" onClick={() => setDeleteTarget(null)} disabled={deleteBusy}>
                Cancel
              </button>
              <button
                type="button"
                className="btn-primary danger"
                onClick={() => void handleDeleteUser()}
                disabled={deleteBusy}
              >
                {deleteBusy ? "Deleting…" : "Delete"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* TOAST NOTIFICATION */}
      {toast && (
        <div className={`toast toast-${toast.type}`}>
          {toast.type === "success" ? <CheckCircle2 size={16} /> : <XCircle size={16} />}
          <span>{toast.message}</span>
        </div>
      )}
    </div>
  );
};

export default DashboardPage;