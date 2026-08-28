import { useState } from "react";
import LoginPage from "./pages/LoginPage";
import ForgotPasswordPage from "./pages/ForgotPasswordPage";
import VerificationPage from "./pages/VerificationPage";
import ResetPasswordPage from "./pages/ResetPasswordPage";
import DashboardPage from "./pages/DashboardPage";
import { ThemeProvider } from "./theme/ThemeContext";
import type { AuthPage } from "./types/auth";

const DEV_PAGES: AuthPage[] = ["login", "verification", "dashboard"];

function DevPageSwitcher({
  currentPage,
  onSelect,
}: {
  currentPage: AuthPage;
  onSelect: (page: AuthPage) => void;
}) {
  return (
    <div
      style={{
        position: "fixed",
        bottom: 12,
        left: 12,
        zIndex: 999,
        display: "flex",
        gap: 6,
        flexWrap: "wrap",
        background: "rgba(0,0,0,0.75)",
        padding: "8px 10px",
        borderRadius: 10,
        maxWidth: 320,
      }}
    >
      {DEV_PAGES.map((page) => (
        <button
          key={page}
          onClick={() => onSelect(page)}
          style={{
            fontSize: 11,
            padding: "4px 8px",
            borderRadius: 6,
            border: "none",
            cursor: "pointer",
            background: page === currentPage ? "#d32f2f" : "#333",
            color: "#fff",
          }}
        >
          {page}
        </button>
      ))}
    </div>
  );
}

function App() {
  const [page, setPage] = useState<AuthPage>("login");

  // Login -> OTP verification flow
  const [loginEmail, setLoginEmail] = useState("");

  // Separate forgot-password flow (kept in the codebase, not in the dev switcher)
  const [resetPhone, setResetPhone] = useState("");
  const [resetCode, setResetCode] = useState("");

  const renderPage = () => {
    switch (page) {
      case "login":
        return (
          <LoginPage
            onLoginSuccess={(email) => {
              setLoginEmail(email);
              setPage("verification");
            }}
          />
        );

      case "forgotPassword":
        return (
          <ForgotPasswordPage
            onNavigate={setPage}
            onResetRequested={(phone) => {
              setResetPhone(phone);
              setPage("verification");
            }}
          />
        );

      case "verification":
        return (
          <VerificationPage
            email={loginEmail || "your email"}
            onVerified={() => setPage("dashboard")}
          />
        );

      case "resetPassword":
        return (
          <ResetPasswordPage
            phoneNumber={resetPhone || "+255 000 000 000"}
            verificationCode={resetCode || "000000"}
            onNavigateToLogin={() => setPage("login")}
          />
        );

      case "dashboard":
        return <DashboardPage onNavigate={setPage} />;

      default:
        return (
          <LoginPage
            onLoginSuccess={(email) => {
              setLoginEmail(email);
              setPage("verification");
            }}
          />
        );
    }
  };

  return (
    <ThemeProvider>
      {renderPage()}
      {import.meta.env.DEV && (
        <DevPageSwitcher currentPage={page} onSelect={setPage} />
      )}
    </ThemeProvider>
  );
}

export default App;