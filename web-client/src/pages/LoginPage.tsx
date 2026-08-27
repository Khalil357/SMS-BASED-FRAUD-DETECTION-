import React, { useState } from "react";
import type { FormEvent } from "react";
import "./LoginPage.css";
import { login } from "../services/authService";
import { useTheme } from "../theme/ThemeContext";
import { Phone, Lock, Sun, Moon } from "lucide-react";
import smsFraudIcon from "../assets/images/sms_fraud_app_icon.png";

type AuthPage = "login" | "signUp" | "forgotPassword" | "dashboard";

interface LoginPageProps {
  onNavigate: (page: AuthPage) => void;
}

interface FormErrors {
  phone?: string;
  password?: string;
}

const LoginPage: React.FC<LoginPageProps> = ({ onNavigate }) => {
  const { isDark, toggleTheme } = useTheme();

  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [errors, setErrors] = useState<FormErrors>({});
  const [isLoading, setIsLoading] = useState(false);
  const [toast, setToast] = useState<{ message: string; type: "success" | "error" } | null>(null);

  const validate = (): boolean => {
    const newErrors: FormErrors = {};

    if (!phone.trim()) {
      newErrors.phone = "Please enter your phone number";
    } else if (phone.trim().length < 9) {
      newErrors.phone = "Please enter a valid phone number";
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
      const result = await login({ phoneNumber: phone.trim(), password });

      if (result.success) {
        setToast({ message: result.message ?? "Login successful!", type: "success" });
        onNavigate("dashboard");
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
           <img src={smsFraudIcon} alt="Secure Signal" />
          </div>

          <div className="titles fade-slide" style={{ animationDelay: "200ms" }}>
            <h1 style={{}}>Argus</h1>
            
          </div>

          <div className="login-card fade-slide" style={{ animationDelay: "300ms" }}>
            <center><h2 className="admin-portal-name">Admin portal</h2></center>
            <label className="field">
              <span className="field-label">Phone Number</span>
              <div className="field-input">
                <Phone size={18} className="field-icon" />
                <input
                  type="tel"
                  placeholder="e.g. +2557567890"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                />
              </div>
              {errors.phone && <span className="field-error">{errors.phone}</span>}
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

            <button
              type="button"
              className="forgot-password"
              onClick={() => onNavigate("forgotPassword")}
            >
              Forgot Password?
            </button>

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