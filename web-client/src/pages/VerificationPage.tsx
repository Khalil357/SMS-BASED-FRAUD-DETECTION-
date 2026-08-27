import React, { useState } from "react";
import { MailCheck } from "lucide-react";
import AuthLayout from "../components/auth/AuthLayout";
import AuthCard from "../components/auth/AuthCard";
import {
  AuthIcon,
  AuthTitle,
  AuthDescription,
  AuthButton,
  AuthPrompt,
  FormMessage,
} from "../components/auth/AuthElements";
import OtpFields from "../components/auth/OtpFields";
import { verifyResetCode, resendCode } from "../services/authService";

interface VerificationPageProps {
  phoneNumber: string;
  onVerified: (code: string) => void;
}

const VerificationPage: React.FC<VerificationPageProps> = ({ phoneNumber, onVerified }) => {
  const [digits, setDigits] = useState<string[]>(Array(6).fill(""));
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [infoMessage, setInfoMessage] = useState<string | null>(null);

  const handleVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);
    const code = digits.join("");

    if (code.length !== 6) {
      setErrorMessage("Please enter a valid 6-digit code");
      return;
    }

    setIsLoading(true);
    const result = await verifyResetCode({ phoneNumber, verificationCode: code });
    setIsLoading(false);

    if (result.success) {
      onVerified(code);
    } else {
      setErrorMessage(result.message ?? "Verification failed");
    }
  };

  const handleResend = async () => {
    setErrorMessage(null);
    setInfoMessage(null);

    if (!phoneNumber) {
      setErrorMessage("Phone number not available. Please go back.");
      return;
    }

    setIsLoading(true);
    const result = await resendCode({ phoneNumber });
    setIsLoading(false);

    if (result.success) {
      setInfoMessage(result.message ?? "Code resent");
    } else {
      setErrorMessage(result.message ?? "Something went wrong");
    }
  };

  return (
    <AuthLayout>
      <AuthCard topAccent>
        <AuthIcon icon={MailCheck} size={38} />
        <AuthTitle>Verify Your Code</AuthTitle>
        <AuthDescription>
          We&apos;ve sent a 6-digit verification code to your phone.
        </AuthDescription>

        <form onSubmit={handleVerify} noValidate>
          <OtpFields values={digits} onChange={setDigits} />

          {errorMessage && <FormMessage text={errorMessage} type="error" />}
          {infoMessage && <FormMessage text={infoMessage} type="success" />}

          <AuthButton label={isLoading ? "Verifying..." : "Verify"} isLoading={isLoading} />
        </form>

        <AuthPrompt prefix="Didn't receive the code? " linkText="Resend Code" onClick={handleResend} />
      </AuthCard>
    </AuthLayout>
  );
};

export default VerificationPage;