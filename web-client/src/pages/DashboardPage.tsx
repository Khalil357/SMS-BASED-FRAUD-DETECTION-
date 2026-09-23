import React, { useEffect, useState, useMemo } from "react";
import "./DashboardPage.css";
import type {
  StatCardData,
  SmsRecord,
} from "../types/dashboard";
import type { AuthPage } from "../types/auth";
import { useTheme } from "../theme/ThemeContext";
import {
  ShieldAlert,
  MessageSquare,
  Users,
  Activity,
  Trash2,
  Eye,
  EyeOff,
  CheckCircle2,
  XCircle,
  Moon,
  Sun,
  LogOut,
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
  deleteFraudScan,
} from "../services/adminService";
import type { AdminUser, FraudTrendPoint } from "../services/adminService";
import { clearToken } from "../services/authService";

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

const emptyStats: StatCardData[] = [
  {
    id: "1",
    title: "Total SMS Scanned",
    value: "0",
    change: "Database total",
    type: "positive",
    category: "total",
  },
  {
    id: "2",
    title: "Fraud & Scams Detected",
    value: "0",
    change: "0% detection rate",
    type: "negative",
    category: "fraud",
  },
];

export const DashboardPage: React.FC<DashboardPageProps> = ({ onNavigate }) => {
  const { isDark, toggleTheme } = useTheme();

  const handleLogout = () => {
    clearToken();
    localStorage.removeItem("user");
    window.history.pushState(null, "", "/login");
    onNavigate("login");
  };

  // Mobile Navigation Drawer Toggle State
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  // ── URL ↔ Tab sync ──────────────────────────────────────────────
  const TAB_SLUGS: Record<string, string> = {
    "Overview":              "/",
    "SMS Ingestion Logs":    "/logs",
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
  const [statsCards, setStatsCards] = useState<StatCardData[]>(emptyStats);
  const [smsList, setSmsList] = useState<SmsRecord[]>([]);
  const [markingSafeScanId, setMarkingSafeScanId] = useState<string | null>(null);
  const [fraudTrend, setFraudTrend] = useState<FraudTrendPoint[]>([]);
  const [usersList, setUsersList] = useState<AdminUser[]>([]);
  const [usersLoading, setUsersLoading] = useState(false);
  const [usersError, setUsersError] = useState<string | null>(null);
  const [toast, setToast] = useState<{ type: "success" | "error"; message: string } | null>(null);

  // SEARCH, FILTER & CLICK-TO-SORT STATES

  // 1. Team Tab
  const [teamSearch, setTeamSearch] = useState("");
  const [teamVerificationFilter, setTeamVerificationFilter] = useState<"All" | "Verified" | "Pending">("All");
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

  // Admin Profile state
  const [adminName, setAdminName] = useState("System Admin");

  const [hoveredTelemetryIndex, setHoveredTelemetryIndex] = useState<number | null>(null);

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
    const res = await getFraudTrend(7);
    setFraudTrend(res.success && res.data ? res.data : []);
  }

  async function loadSmsAuditScans() {
    const res = await getSmsScans("Fraud", 0, 100);
    if (res.success && res.data) {
      const records = Array.isArray(res.data) ? res.data : (res.data as any)?.content || [];
      const mapped: SmsRecord[] = records.map((item: any) => {
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
            id: item.id ? `SMS-${String(item.id).substring(0, 6).toUpperCase()}` : "Unknown",
            scanId: item.id ? String(item.id) : "",
            sender: item.sender || "Unknown",
            message: item.message || "",
            fraudType: (item.fraud_type || item.fraudType || "Clean") as SmsRecord["fraudType"],
            riskScore: Math.round(
              Number(item.risk_score ?? item.riskScore ?? 0)
                * (Number(item.risk_score ?? item.riskScore ?? 0) <= 1 ? 100 : 1)
            ),
            date: dateStr,
            status: "Fraud",
          };
      });
      setSmsList(mapped);
    }
  }

  async function handleMarkSmsSafe(scanId: string) {
    if (!scanId || markingSafeScanId) return;
    setMarkingSafeScanId(scanId);
    const res = await deleteFraudScan(scanId);
    if (res.success) {
      setSmsList((prev) => prev.filter((sms) => sms.scanId !== scanId));
      showToast("success", "Fraud record marked as safe and removed");
      void loadDashboardStats();
      void loadFraudTrends();
    } else {
      showToast("error", res.message ?? "Failed to mark fraud record as safe");
    }
    setMarkingSafeScanId(null);
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
    if (activeTab === "Overview") {
      void loadUsers();
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
  const teamAdmins = useMemo(() =>
    usersList.filter((u: any) => {
      const roleVal = String(u.role || u.role_id || "").toUpperCase();
      return roleVal === "ADMIN" || roleVal === "ROLE_ADMIN" || roleVal === "1";
    }), [usersList]);

  const verifiedTeamCount = teamAdmins.filter((u) => u.verified).length;
  const pendingTeamCount = teamAdmins.length - verifiedTeamCount;

  const filteredTeamList = useMemo(() => {
    let list = teamAdmins;

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

    if (teamVerificationFilter !== "All") {
      const isVerified = teamVerificationFilter === "Verified";
      list = list.filter((u) => u.verified === isVerified);
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
  }, [teamAdmins, teamSearch, teamVerificationFilter, teamStatusFilter, teamSortField, teamSortDir]);

  // Reset Team Filters
  const isTeamFiltered = teamSearch !== "" || teamVerificationFilter !== "All" || teamStatusFilter !== "All" || teamSortField !== "full_name" || teamSortDir !== "asc";
  function resetTeamFilters() {
    setTeamSearch("");
    setTeamVerificationFilter("All");
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

  const trendChart = useMemo(() => {
    const counts = fraudTrend.map((point) => Number(point.count) || 0);
    const maxCount = Math.max(1, ...counts);
    const points = fraudTrend.map((point, index) => {
      const x = fraudTrend.length <= 1 ? 375 : 60 + (630 * index) / (fraudTrend.length - 1);
      const count = Number(point.count) || 0;
      const y = 190 - (count / maxCount) * 150;
      return {
        ...point,
        count,
        x,
        y,
        peak: count > 0 && count === maxCount,
      };
    });

    return {
      points,
      maxCount,
      total: counts.reduce((sum, count) => sum + count, 0),
      polyline: points.map((point) => `${point.x},${point.y}`).join(" "),
      area: points.length > 0
        ? `60,190 ${points.map((point) => `${point.x},${point.y}`).join(" ")} 690,190`
        : "",
      ticks: [maxCount, Math.ceil(maxCount * 2 / 3), Math.ceil(maxCount / 3), 0],
    };
  }, [fraudTrend]);

  // Sidebar Menu items
  const navMenuItems = [
    { name: "Overview", icon: Activity },
    { name: "SMS Ingestion Logs", icon: MessageSquare, badge: smsList.length },
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

          <button type="button" className="logout-btn" onClick={handleLogout}>
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

            {/* FRAUD TREND CHART PANEL */}
            <section className="middle-dashboard-grid single-column">
              <div className="admin-panel telemetry-chart-panel">
                <div className="panel-top flex-wrap">
                  <div>
                    <h3>Fraud Message Trend</h3>
                    <p>Daily fraud messages stored in the sms_scans table over the last seven days</p>
                  </div>
                  <div className="telemetry-chart-legend">
                    <span className="legend-pill fraud-pill">
                      <span className="pill-dot red" /> Fraud Intercepts ({trendChart.total.toLocaleString()})
                    </span>
                  </div>
                </div>

                <div className="telemetry-chart-wrapper">
                  <div className="telemetry-svg-container">
                    <svg viewBox="0 0 720 220" className="telemetry-svg" role="img" aria-label="Seven-day fraud message trend">
                      <defs>
                        <linearGradient id="fraudSmsGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="#ef4444" stopOpacity="0.28" />
                          <stop offset="100%" stopColor="#ef4444" stopOpacity="0.0" />
                        </linearGradient>
                      </defs>

                      <g className="grid-lines-horizontal" stroke="var(--border)" strokeDasharray="4 4" strokeWidth="1">
                        {[40, 90, 140, 190].map((y) => (
                          <line key={`horizontal-${y}`} x1="55" y1={y} x2="700" y2={y} />
                        ))}
                      </g>

                      <g className="grid-lines-vertical" stroke="var(--border)" strokeDasharray="3 3" strokeWidth="1" opacity="0.5">
                        {trendChart.points.map((point) => (
                          <line key={`vertical-${point.day}`} x1={point.x} y1="25" x2={point.x} y2="190" />
                        ))}
                      </g>

                      <g className="y-axis-labels" fill="var(--subtle)" fontSize="10" fontWeight="700" textAnchor="end">
                        {trendChart.ticks.map((tick, index) => (
                          <text key={`tick-${index}`} x="48" y={44 + index * 50}>
                            {tick.toLocaleString()}
                          </text>
                        ))}
                      </g>

                      {trendChart.points.length === 0 ? (
                        <text x="375" y="115" fill="var(--subtle)" fontSize="13" textAnchor="middle">
                          Fraud trend data is unavailable
                        </text>
                      ) : (
                        <>
                          <polygon points={trendChart.area} fill="url(#fraudSmsGradient)" />
                          <polyline
                            points={trendChart.polyline}
                            fill="none"
                            stroke="var(--primary)"
                            strokeWidth="3"
                            strokeLinecap="round"
                            strokeLinejoin="round"
                          />

                          {hoveredTelemetryIndex !== null && trendChart.points[hoveredTelemetryIndex] && (
                            <line
                              x1={trendChart.points[hoveredTelemetryIndex].x}
                              y1="25"
                              x2={trendChart.points[hoveredTelemetryIndex].x}
                              y2="190"
                              stroke="var(--primary)"
                              strokeDasharray="3 3"
                              strokeWidth="1.5"
                              opacity="0.9"
                            />
                          )}

                          {trendChart.points.map((point, index) => {
                            const isHovered = hoveredTelemetryIndex === index;
                            return (
                              <g
                                key={`fraud-node-${point.day}`}
                                className="interactive-node-group"
                                onMouseEnter={() => setHoveredTelemetryIndex(index)}
                                onMouseLeave={() => setHoveredTelemetryIndex(null)}
                                style={{ cursor: "pointer" }}
                              >
                                {isHovered && (
                                  <circle
                                    cx={point.x}
                                    cy={point.y}
                                    r="12"
                                    fill="rgba(239, 68, 68, 0.22)"
                                    stroke="var(--primary)"
                                    strokeWidth="1.5"
                                  />
                                )}
                                <circle
                                  cx={point.x}
                                  cy={point.y}
                                  r={isHovered ? 7 : point.peak ? 6 : 5}
                                  fill="var(--primary)"
                                  stroke="var(--card)"
                                  strokeWidth="2.5"
                                />
                                {(isHovered || point.peak) && (
                                  <g className="callout-badges pointer-events-none">
                                    <rect
                                      x={point.x - 42}
                                      y={Math.max(4, point.y - 32)}
                                      width="84"
                                      height="22"
                                      rx="6"
                                      fill={isHovered ? "#08090d" : "var(--primary)"}
                                      stroke={isHovered ? "var(--primary)" : "none"}
                                      strokeWidth="1"
                                    />
                                    <text
                                      x={point.x}
                                      y={Math.max(19, point.y - 17)}
                                      fill="#ffffff"
                                      fontSize="10"
                                      fontWeight="800"
                                      textAnchor="middle"
                                    >
                                      {point.count.toLocaleString()} Fraud
                                    </text>
                                  </g>
                                )}
                              </g>
                            );
                          })}
                        </>
                      )}
                    </svg>
                  </div>

                  <div className="telemetry-x-labels">
                    {trendChart.points.map((point, index) => (
                      <div
                        key={point.day}
                        className={`x-label-item ${point.peak ? "active-peak" : ""} ${hoveredTelemetryIndex === index ? "hovered-label" : ""}`}
                        onMouseEnter={() => setHoveredTelemetryIndex(index)}
                        onMouseLeave={() => setHoveredTelemetryIndex(null)}
                        style={{ cursor: "pointer" }}
                      >
                        <span>{point.day}</span>
                        <small className={point.peak ? "peak-val" : "subtle-val"}>
                          {point.count.toLocaleString()} Fraud
                        </small>
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
                          <span>Scan Time</span>
                          {logsSortField === "date" ? (
                            <span className="sort-indicator">{logsSortDir === "asc" ? "▲" : "▼"}</span>
                          ) : (
                            <span className="sort-indicator neutral">▲▼</span>
                          )}
                        </div>
                      </th>
                      <th>Status</th>
                      <th>Inspect</th>
                      <th>Mark as Safe</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredLogsList.length === 0 ? (
                      <tr>
                        <td colSpan={7} className="subtle-text">No audit logs match your search.</td>
                      </tr>
                    ) : (
                      filteredLogsList.map((sms) => (
                        <tr key={sms.scanId}>
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
                          <td>
                            <button
                              type="button"
                              className="icon-action-btn safe"
                              onClick={() => void handleMarkSmsSafe(sms.scanId)}
                              disabled={!sms.scanId || markingSafeScanId !== null}
                              title="Mark as safe and remove this fraud record"
                              aria-label={`Mark ${sms.id} as safe and remove it`}
                            >
                              <CheckCircle2 size={16} />
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

        {/* TAB 4: TEAM (ADMINS) */}
        {activeTab === "Team" && (
          <div className="tab-content fade-slide">
            <div className="admin-panel">
              <div className="panel-top">
                <div>
                  <h3>Team Administrators</h3>
                  <p>Authorized platform admins ({filteredTeamList.length} members; {verifiedTeamCount} verified, {pendingTeamCount} pending)</p>
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
                      value={teamVerificationFilter}
                      onChange={(e) => setTeamVerificationFilter(e.target.value as "All" | "Verified" | "Pending")}
                      className="filter-select"
                      aria-label="Filter admins by verification"
                    >
                      <option value="All">All Verifications ({teamAdmins.length})</option>
                      <option value="Verified">Verified Only ({verifiedTeamCount})</option>
                      <option value="Pending">Pending Only ({pendingTeamCount})</option>
                    </select>
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
                      <th>Verification</th>
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
                        <td colSpan={5} className="subtle-text">Loading admin team…</td>
                      </tr>
                    ) : usersError ? (
                      <tr>
                        <td colSpan={5} className="subtle-text" style={{ color: "var(--primary)" }}>
                          {usersError}
                        </td>
                      </tr>
                    ) : filteredTeamList.length === 0 ? (
                      <tr>
                        <td colSpan={5} className="subtle-text">No administrators match your search/filter criteria.</td>
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
