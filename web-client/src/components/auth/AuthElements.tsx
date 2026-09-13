import React from "react";
import type { LucideIcon } from "lucide-react";
import inAppIcon from "../../assets/images/in_app_icon.png";
import "./AuthElements.css";

export const AuthIcon: React.FC<{ icon?: LucideIcon; size?: number; useBrandImage?: boolean }> = ({
  icon: Icon,
  size = 34,
  useBrandImage = true,
}) => (
  <div className="auth-icon-circle">
    {useBrandImage ? (
      <img src={inAppIcon} alt="Argus" style={{ width: size, height: size, objectFit: "contain" }} />
    ) : Icon ? (
      <Icon size={size} />
    ) : null}
  </div>
);

export const AuthTitle: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <h1 className="auth-title">{children}</h1>
);

export const AuthDescription: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <p className="auth-description">{children}</p>
);

export const FormMessage: React.FC<{ text: string; type: "error" | "success" }> = ({
  text,
  type,
}) => <p className={`form-message ${type}`}>{text}</p>;

interface AuthFieldProps {
  label: string;
  icon?: LucideIcon;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  type?: string;
}

export const AuthField: React.FC<AuthFieldProps> = ({
  label,
  icon: Icon,
  value,
  onChange,
  placeholder,
  type = "text",
}) => (
  <label className="field">
    <span className="field-label">{label}</span>
    <div className="field-input">
      {Icon && <Icon size={18} className="field-icon" />}
      <input
        type={type}
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
      />
    </div>
  </label>
);

interface AuthButtonProps {
  label: string;
  isLoading?: boolean;
  type?: "button" | "submit";
  onClick?: () => void;
}

export const AuthButton: React.FC<AuthButtonProps> = ({
  label,
  isLoading,
  type = "submit",
  onClick,
}) => (
  <button type={type} className="auth-button" disabled={isLoading} onClick={onClick}>
    {isLoading ? <span className="spinner" /> : label}
  </button>
);

export const AuthLink: React.FC<{
  children: React.ReactNode;
  onClick: () => void;
  muted?: boolean;
}> = ({ children, onClick, muted }) => (
  <button type="button" className={`auth-link ${muted ? "muted" : ""}`} onClick={onClick}>
    {children}
  </button>
);

export const AuthPrompt: React.FC<{
  prefix: string;
  linkText: string;
  onClick: () => void;
}> = ({ prefix, linkText, onClick }) => (
  <p className="auth-prompt">
    {prefix}
    <button type="button" className="auth-link" onClick={onClick}>
      {linkText}
    </button>
  </p>
);