import React from "react";
import { Sun, Moon } from "lucide-react";
import { useTheme } from "../../theme/ThemeContext";
import "./AuthLayout.css";

interface AuthLayoutProps {
  children: React.ReactNode;
}

const AuthLayout: React.FC<AuthLayoutProps> = ({ children }) => {
  const { isDark, toggleTheme } = useTheme();

  return (
    <div className="auth-page">
      <div className="hero-gradient" />
      <button
        className="theme-toggle"
        onClick={toggleTheme}
        aria-label="Toggle theme"
        type="button"
      >
        {isDark ? <Sun size={20} /> : <Moon size={20} />}
      </button>
      <div className="auth-content">{children}</div>
    </div>
  );
};

export default AuthLayout;