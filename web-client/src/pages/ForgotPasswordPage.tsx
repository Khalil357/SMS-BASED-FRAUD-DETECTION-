import React, { useState } from "react";
import { KeyRound, Phone } from "lucide-react";
import AuthLayout from "../components/auth/AuthLayout";
import AuthCard from "../components/auth/AuthCard";
import {
  AuthIcon,
  AuthTitle,
  AuthDescription,
  AuthButton,
  AuthLink,
  FormMessage,
  AuthField,
} from "../components/auth/AuthElements";
import { requestPasswordReset } from "../services/authService";
import type { Navigate } from "../types/auth";

interface ForgotPasswordPageProps {
  onNavigate: Navigate;
  onResetRequested: (phone: string) => void;
}

const ForgotPasswordPage: React.FC<ForgotPasswordPageProps> = ({
  onNavigate,
  onResetRequested,
}) => {
  const [phone, setPhone] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const handleSendCode = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);
    setSuccessMessage(null);

    const cleanPhone = phone.trim();
    if (!cleanPhone) {
      setErrorMessage("Please enter your phone number");
      return;
    }

    if (!/^\+255[67]\d{8}$/.test(cleanPhone)) {
      setErrorMessage("Please enter a valid Tanzanian phone number (e.g. +255754000000)");
      return;
    }

    setIsLoading(true);
    const result = await requestPasswordReset({ phoneNumber: cleanPhone });
    setIsLoading(false);

    if (result.success) {
      setSuccessMessage(result.message ?? "Reset code sent");
      setTimeout(() => onResetRequested(cleanPhone), 1000);
    } else {
      setErrorMessage(result.message ?? "Something went wrong");
    }
  };

  return (
    <AuthLayout>
      <AuthCard>
        <AuthIcon icon={KeyRound} size={40} />
        <AuthTitle>Forgot Password</AuthTitle>
        <AuthDescription>Enter your Tanzanian phone number to receive a reset code.</AuthDescription>

        <form onSubmit={handleSendCode} noValidate>
          <AuthField
            label="Phone Number"
            icon={Phone}
            type="tel"
            placeholder="+255754000000"
            value={phone}
            onChange={setPhone}
          />

          {errorMessage && <FormMessage text={errorMessage} type="error" />}
          {successMessage && <FormMessage text={successMessage} type="success" />}

          <AuthButton label={isLoading ? "Sending..." : "Send Reset Code"} isLoading={isLoading} />
        </form>

        <AuthLink onClick={() => onNavigate("login")}>← Back to Login</AuthLink>
      </AuthCard>
    </AuthLayout>
  );
};

export default ForgotPasswordPage;