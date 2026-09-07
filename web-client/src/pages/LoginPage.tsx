import React, { useState } from "react";
import type { FormEvent } from "react";
import "./LoginPage.css";
import { login } from "../services/authService";
import { useTheme } from "../theme/ThemeContext";
import inAppIcon from "../assets/images/in_app_icon.png";
import { Mail, Lock, Sun, Moon, ShieldCheck } from "lucide-react";

interface LoginPageProps {
  onLoginSuccess: (email: string) => void;
}

interface FormErrors {
  email?: string;
  password?: string;
}

const LoginPage: React.FC<LoginPageProps> = ({ onLoginSuccess }) => {
  const { isDark, toggleTheme } = useTheme();

  const [email, setEmail] = useState("smsfraud.noreply@gmail.com");
  const [password, setPassword] = useState("Admin000!");
  const [errors, setErrors] = useState<FormErrors>({});
  const [isLoading, setIsLoading] = useState(false);
  const [toast, setToast] = useState<{ message: string; type: "success" | "error" } | null>(null);

  const validate = (): boolean => {
    const newErrors: FormErrors = {};

    if (!email.trim()) {
      newErrors.email = "Please enter your email address";
    } else if (!/^\S+@\S+\.\S+$/.test(email.trim())) {
      newErrors.email = "Please enter a valid email address";
    }

    if (!password.trim()) {
      newErrors.password = "Please enter your password";
    } else if (password.trim().length < 6) {
      newErrors.password = "Password must be at least 6 characters";
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleLogin = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!validate()) return;

    setIsLoading(true);
    setToast(null);

    try {
      const result = await login({ email: email.trim(), password });

      if (result.success) {
        setToast({ message: result.message ?? "Verification code sent!", type: "success" });
        onLoginSuccess(email.trim());
      } else {
        let message = result.message ?? "Login failed";
        if (message.includes("http://localhost:8080") || message.includes("Unsupported scheme")) {
          message = "Please configure your backend server URL in services/authService.ts";
        }
        setToast({ message, type: "error" });
      }
    } catch {
      setToast({ message: "Something went wrong. Please try again.", type: "error" });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="hero-gradient" />

      <button
        className="theme-toggle"
        onClick={toggleTheme}
        aria-label="Toggle theme"
        type="button"
      >
        {isDark ? <Sun size={20} /> : <Moon size={20} />}
      </button>

      <div className="login-content">
        <form className="login-form" onSubmit={handleLogin} noValidate>
          <div className="icon-circle fade-slide" style={{ animationDelay: "100ms" }}>
            <img src={inAppIcon} alt="Argus" />
          </div>

          <div className="titles fade-slide" style={{ animationDelay: "200ms" }}>
            <h1 style={{ color: "var(--primary)", margin: 0, fontSize: "2rem", fontWeight: 800 }}>Argus</h1>
            <p style={{ color: "var(--subtle)", margin: "4px 0 0 0", fontSize: "0.875rem" }}>SMS Fraud Detection System</p>
          </div>

          <div className="login-card fade-slide" style={{ animationDelay: "300ms" }}>
            <div style={{ textAlign: "center", marginBottom: "1.5rem" }}>
              <span style={{
                display: "inline-block",
                padding: "4px 12px",
                borderRadius: "20px",
                backgroundColor: "rgba(220, 38, 38, 0.1)",
                color: "var(--primary)",
                fontSize: "0.75rem",
                fontWeight: 700,
                letterSpacing: "0.05em",
                textTransform: "uppercase"
              }}>
                Admin Portal
              </span>
            </div>
            <label className="field">
              <span className="field-label">Email Address</span>
              <div className="field-input">
                <Mail size={18} className="field-icon" />
                <input
                  type="email"
                  placeholder="admin@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                />
              </div>
              {errors.email && <span className="field-error">{errors.email}</span>}
            </label>

            <label className="field">
              <span className="field-label">Password</span>
              <div className="field-input">
                <Lock size={18} className="field-icon" />
                <input
                  type="password"
                  placeholder="•••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
              </div>
              {errors.password && <span className="field-error">{errors.password}</span>}
            </label>

            <button type="submit" className="login-button" disabled={isLoading}>
              {isLoading ? <span className="spinner" /> : "Login to Console"}
            </button>

            <div className="login-security-footer">
              <ShieldCheck size={14} className="security-icon" />
              <span>256-Bit SSL Encrypted Admin Portal</span>
            </div>
          </div>
        </form>
      </div>

      {toast && <div className={`toast ${toast.type}`}>{toast.message}</div>}
    </div>
  );
};

export default LoginPage;