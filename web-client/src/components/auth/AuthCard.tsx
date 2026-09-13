import React from "react";
import "./AuthCard.css";

interface AuthCardProps {
  children: React.ReactNode;
  topAccent?: boolean;
}

const AuthCard: React.FC<AuthCardProps> = ({ children, topAccent }) => (
  <div
    className={`auth-card fade-slide ${topAccent ? "top-accent" : ""}`}
    style={{ animationDelay: "150ms" }}
  >
    {children}
  </div>
);

export default AuthCard;