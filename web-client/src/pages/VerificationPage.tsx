import React, { useState, useEffect } from "react";
import { MailCheck } from "lucide-react";
import AuthLayout from "../components/auth/AuthLayout";
import AuthCard from "../components/auth/AuthCard";
import {
  AuthIcon,
  AuthTitle,
  AuthDescription,
  AuthButton,
  AuthPrompt,
  AuthLink,
  FormMessage,
} from "../components/auth/AuthElements";
import OtpFields from "../components/auth/OtpFields";
import { verifyLoginOtp, resendLoginOtp } from "../services/authService";

interface VerificationPageProps {
  email: string;
  onVerified: () => void;
  onNavigateToLogin?: () => void;
}

const VerificationPage: React.FC<VerificationPageProps> = ({
  email,
  onVerified,
  onNavigateToLogin,
}) => {
  const [digits, setDigits] = useState<string[]>(Array(6).fill(""));
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [infoMessage, setInfoMessage] = useState<string | null>(null);

  useEffect(() => {
    if (email && email !== "your email") {
      resendLoginOtp({ email }).then((res) => {
        if (res.success) {
          setInfoMessage("Verification code dispatched to " + email);
        }
      });
    }
  }, [email]);

  const handleVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);
    const code = digits.join("");

    if (code.length !== 6) {
      setErrorMessage("Please enter a valid 6-digit code");
      return;
    }

    setIsLoading(true);
    const result = await verifyLoginOtp({ email, verificationCode: code });
    setIsLoading(false);

    if (result.success) {
      onVerified();
    } else {
      setErrorMessage(result.message ?? "Verification failed");
    }
  };

  const handleResend = async () => {
    setErrorMessage(null);
    setInfoMessage(null);

    if (!email) {
      setErrorMessage("Email not available. Please go back and log in again.");
      return;
    }

    setIsLoading(true);
    const result = await resendLoginOtp({ email });
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
          We&apos;ve sent a 6-digit verification code to {email || "your email"}.
        </AuthDescription>

        <form onSubmit={handleVerify} noValidate>
          <OtpFields values={digits} onChange={setDigits} />

          {errorMessage && <FormMessage text={errorMessage} type="error" />}
          {infoMessage && <FormMessage text={infoMessage} type="success" />}

          <AuthButton label={isLoading ? "Verifying..." : "Verify & Continue"} isLoading={isLoading} />
        </form>

        <AuthPrompt prefix="Didn't receive the code? " linkText="Resend Code" onClick={handleResend} />

        {onNavigateToLogin && (
          <div style={{ marginTop: "1rem", textAlign: "center" }}>
            <AuthLink onClick={onNavigateToLogin}>← Back to Login</AuthLink>
          </div>
        )}
      </AuthCard>
    </AuthLayout>
  );
};

export default VerificationPage;