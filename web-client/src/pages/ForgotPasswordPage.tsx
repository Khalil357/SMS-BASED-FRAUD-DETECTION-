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

    if (!phone.trim()) {
      setErrorMessage("Please enter your phone number");
      return;
    }

    setIsLoading(true);
    const result = await requestPasswordReset({ phoneNumber: phone.trim() });
    setIsLoading(false);

    if (result.success) {
      setSuccessMessage(result.message ?? "Reset code sent");
      setTimeout(() => onResetRequested(phone.trim()), 1000);
    } else {
      setErrorMessage(result.message ?? "Something went wrong");
    }
  };

  return (
    <AuthLayout>
      <AuthCard>
        <AuthIcon icon={KeyRound} size={40} />
        <AuthTitle>Forgot Password</AuthTitle>
        <AuthDescription>Enter your phone number to receive a reset code.</AuthDescription>

        <form onSubmit={handleSendCode} noValidate>
          <AuthField
            label="Phone Number"
            icon={Phone}
            type="tel"
            placeholder="+27 82 123 4567"
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