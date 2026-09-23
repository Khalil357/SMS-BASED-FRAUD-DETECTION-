import { useEffect, useState } from "react";
import LoginPage from "./pages/LoginPage";
import ForgotPasswordPage from "./pages/ForgotPasswordPage";
import VerificationPage from "./pages/VerificationPage";
import ResetPasswordPage from "./pages/ResetPasswordPage";
import DashboardPage from "./pages/DashboardPage";
import { ThemeProvider } from "./theme/ThemeContext";
import type { AuthPage } from "./types/auth";
import { clearToken, hasActiveSession } from "./services/authService";

function App() {
  const [page, setPage] = useState<AuthPage>(() =>
    hasActiveSession() ? "dashboard" : "login"
  );

  // Login -> OTP verification flow
  const [loginEmail, setLoginEmail] = useState("");

  // Separate forgot-password flow (kept in the codebase, not currently linked from login)
  const [resetPhone, setResetPhone] = useState("");
  const [resetCode] = useState("");

  const handleNavigate = (nextPage: AuthPage) => {
    if (nextPage === "login" && window.location.pathname !== "/login") {
      window.history.pushState(null, "", "/login");
    }
    setPage(nextPage);
  };

  useEffect(() => {
    const handleUnauthorized = () => {
      clearToken();
      handleNavigate("login");
    };
    window.addEventListener("argus:unauthorized", handleUnauthorized);
    return () => window.removeEventListener("argus:unauthorized", handleUnauthorized);
  }, []);

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
            onNavigate={handleNavigate}
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
            onNavigateToLogin={() => handleNavigate("login")}
          />
        );

      case "resetPassword":
        return (
          <ResetPasswordPage
            phoneNumber={resetPhone || "+255 000 000 000"}
            verificationCode={resetCode || "000000"}
            onNavigateToLogin={() => handleNavigate("login")}
          />
        );

      case "dashboard":
        return <DashboardPage onNavigate={handleNavigate} />;

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

  return <ThemeProvider>{renderPage()}</ThemeProvider>;
}

export default App;
