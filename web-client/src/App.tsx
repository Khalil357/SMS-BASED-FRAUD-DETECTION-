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

  useEffect(() => {
    const handleUnauthorized = () => {
      clearToken();
      setPage("login");
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
            onNavigateToLogin={() => setPage("login")}
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

  return <ThemeProvider>{renderPage()}</ThemeProvider>;
}

export default App;
