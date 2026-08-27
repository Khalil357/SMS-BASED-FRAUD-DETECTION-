import { useState } from "react";
import LoginPage from "./pages/LoginPage";
import ForgotPasswordPage from "./pages/ForgotPasswordPage";
import VerificationPage from "./pages/VerificationPage";
import ResetPasswordPage from "./pages/ResetPasswordPage";
import { ThemeProvider } from "./theme/ThemeContext";
import type { AuthPage } from "./types/auth";

function App() {
  const [page, setPage] = useState<AuthPage>("login");
  const [resetPhone, setResetPhone] = useState("");
  const [resetCode, setResetCode] = useState("");

  const renderPage = () => {
    switch (page) {
      case "login":
        return <LoginPage onNavigate={setPage} />;

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
            phoneNumber={resetPhone}
            onVerified={(code) => {
              setResetCode(code);
              setPage("resetPassword");
            }}
          />
        );

      case "resetPassword":
        return (
          <ResetPasswordPage
            phoneNumber={resetPhone}
            verificationCode={resetCode}
            onNavigateToLogin={() => setPage("login")}
          />
        );

      default:
        return <LoginPage onNavigate={setPage} />;
    }
  };

  return <ThemeProvider>{renderPage()}</ThemeProvider>;
}

export default App;