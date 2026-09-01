import React, { useState } from "react";
import type { FormEvent } from "react";
import "./LoginPage.css";
import { login } from "../services/authService";
import { useTheme } from "../theme/ThemeContext";
import { Mail, Lock, Sun, Moon } from "lucide-react";
import smsFraudIcon from "../assets/images/sms_fraud_app_icon.png";

interface LoginPageProps {
  onLoginSuccess: (email: string) => void;
}

interface FormErrors {
  email?: string;
  password?: string;
}

const LoginPage: React.FC<LoginPageProps> = ({ onLoginSuccess }) => {
  const { isDark, toggleTheme } = useTheme();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
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
            <img src={smsFraudIcon} alt="Argus" />
          </div>

          <div className="titles fade-slide" style={{ animationDelay: "200ms" }}>
            <h1 style={{ color: "#D32f2f" }}>Argus</h1>
          </div>

          <div className="login-card fade-slide" style={{ animationDelay: "300ms" }}>
            <center><h2 className="admin-portal-name">Admin Portal</h2></center>
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
              {isLoading ? <span className="spinner" /> : "Login"}
            </button>
          </div>
        </form>
      </div>

      {toast && <div className={`toast ${toast.type}`}>{toast.message}</div>}
    </div>
  );
};

export default LoginPage;